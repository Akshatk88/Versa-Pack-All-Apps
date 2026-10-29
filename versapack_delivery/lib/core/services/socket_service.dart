import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/app_constants.dart';

/// Wraps the Socket.IO connection to the delivery backend and exposes
/// broadcast streams for the events documented in the realtime section
/// of DELIVERY_API_SPEC.md. Polling `/orders/available` remains the
/// required fallback — this is a convenience layer on top, not a
/// replacement for it.
/// One tag for the whole new-order offer path, across transports.
///
/// An offer that never reaches the partner can die in six places — the rider is
/// filtered out by dispatch, the socket is down, the push is dropped, the
/// payload is unreadable, the controller de-dupes it, the alert is withdrawn —
/// and every one of them looks identical from the outside: no alert. Grep
/// `adb logcat | grep '\[offer\]'` and the surviving line says which.
void offerLog(String message) => debugPrint('[offer] $message');

class SocketService {
  io.Socket? _socket;
  Timer? _retryTimer;

  final _newOrderController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _orderClaimedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _orderDeassignedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _orderReadyController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _orderStatusUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _locationUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _chatMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _chatTypingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get onNewOrderAvailable =>
      _newOrderController.stream;
  Stream<Map<String, dynamic>> get onOrderClaimed =>
      _orderClaimedController.stream;
  Stream<Map<String, dynamic>> get onOrderDeassigned =>
      _orderDeassignedController.stream;
  Stream<Map<String, dynamic>> get onOrderReady => _orderReadyController.stream;
  Stream<Map<String, dynamic>> get onOrderStatusUpdate =>
      _orderStatusUpdateController.stream;
  Stream<Map<String, dynamic>> get onLocationUpdate =>
      _locationUpdateController.stream;
  Stream<Map<String, dynamic>> get onChatMessage =>
      _chatMessageController.stream;
  Stream<Map<String, dynamic>> get onChatTyping =>
      _chatTypingController.stream;
  Stream<bool> get onConnectionChange => _connectionController.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// [latestToken] is read on every (re)connect handshake. The access token
  /// rotates; a socket that kept presenting the one it was opened with was
  /// rejected on its first reconnect after expiry and — because Socket.IO does
  /// not retry a handshake the server refused — stayed dead until the app was
  /// restarted, with every realtime offer lost in the meantime.
  void connect({
    required String accessToken,
    required String partnerId,
    Future<String?> Function()? latestToken,
  }) {
    disconnect();

    _socket = io.io(
      AppConstants.apiHost,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuthFn((callback) {
            final pending = latestToken?.call() ?? Future.value(accessToken);
            pending
                .then((t) => callback({
                      'token': (t == null || t.isEmpty) ? accessToken : t,
                    }))
                .catchError((_) => callback({'token': accessToken}));
          })
          .enableReconnection()
          .disableAutoConnect()
          .build(),
    );

    final socket = _socket!;

    socket.onConnect((_) {
      offerLog('socket connected — joining delivery room $partnerId');
      _retryTimer?.cancel();
      _retryTimer = null;
      _connectionController.add(true);
      socket.emit('join-delivery', partnerId);
    });
    socket.onDisconnect((_) {
      offerLog('socket DISCONNECTED — realtime offers cannot arrive');
      _connectionController.add(false);
    });
    socket.onConnectError((e) {
      offerLog('socket connect error: $e');
      _connectionController.add(false);
      _scheduleRetry(socket);
    });

    socket.on('new_order_available', (data) {
      offerLog('socket new_order_available ${_orderRef(data)}');
      _newOrderController.add(_asMap(data));
    });
    // Primary dispatch broadcasts use 'new_order'; re-offer rounds use
    // 'new_order_available' — both feed the same incoming-order stream.
    socket.on('new_order', (data) {
      offerLog('socket new_order ${_orderRef(data)}');
      _newOrderController.add(_asMap(data));
    });
    socket.on('order_claimed', (data) {
      offerLog('socket order_claimed ${_orderRef(data)}');
      _orderClaimedController.add(_asMap(data));
    });
    socket.on(
      'order_deassigned',
      (data) => _orderDeassignedController.add(_asMap(data)),
    );
    socket.on('order_ready', (data) => _orderReadyController.add(_asMap(data)));
    socket.on(
      'order_status_update',
      (data) => _orderStatusUpdateController.add(_asMap(data)),
    );
    socket.on(
      'location-update',
      (data) => _locationUpdateController.add(_asMap(data)),
    );
    socket.on(
      'chat:message',
      (data) => _chatMessageController.add(_asMap(data)),
    );
    socket.on(
      'chat:typing',
      (data) => _chatTypingController.add(_asMap(data)),
    );

    socket.connect();
  }

  void joinTracking(String orderId) => _socket?.emit('join-tracking', orderId);

  void leaveTracking(String orderId) =>
      _socket?.emit('leave-tracking', orderId);

  void sendLocationUpdate({
    required String orderId,
    required double lat,
    required double lng,
    String? userId,
    String? restaurantId,
    double? heading,
    double? speed,
    double? accuracy,
  }) {
    _socket?.emit('update-location', {
      'orderId': orderId,
      'lat': lat,
      'lng': lng,
      if (userId != null) 'userId': userId,
      if (restaurantId != null) 'restaurantId': restaurantId,
      if (heading != null) 'heading': heading,
      if (speed != null) 'speed': speed,
      if (accuracy != null) 'accuracy': accuracy,
    });
  }

  void sendChatTyping({
    required String toRole,
    String? toId,
    required String conversationId,
    required bool typing,
  }) {
    _socket?.emit('chat:typing', {
      'toRole': toRole,
      if (toId != null) 'toId': toId,
      'conversationId': conversationId,
      'typing': typing,
    });
  }

  /// Re-dials after a refused handshake, which Socket.IO's own reconnection
  /// does not cover. Each attempt re-reads the token through the auth callback.
  void _scheduleRetry(io.Socket socket) {
    if (_retryTimer?.isActive ?? false) return;
    _retryTimer = Timer(const Duration(seconds: 10), () {
      _retryTimer = null;
      if (!identical(_socket, socket) || socket.connected || socket.active) {
        return;
      }
      offerLog('socket retrying connection');
      socket.connect();
    });
  }

  void disconnect() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _newOrderController.close();
    _orderClaimedController.close();
    _orderDeassignedController.close();
    _orderReadyController.close();
    _orderStatusUpdateController.close();
    _locationUpdateController.close();
    _chatMessageController.close();
    _chatTypingController.close();
    _connectionController.close();
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  /// Just enough of an event to follow one order through the log without
  /// dumping a whole payload on every emit.
  String _orderRef(dynamic data) {
    final map = _asMap(data);
    if (map.isEmpty) return '(unreadable payload: $data)';
    final id = map['orderMongoId'] ?? map['_id'] ?? map['orderId'];
    return '${map['orderDisplayId'] ?? map['orderNumber'] ?? ''} id=$id';
  }
}

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  ref.onDispose(service.dispose);
  return service;
});
