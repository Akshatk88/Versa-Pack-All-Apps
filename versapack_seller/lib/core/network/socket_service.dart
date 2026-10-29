import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:quick_commerce_seller/config/constants/app_constants.dart';
import 'package:quick_commerce_seller/core/providers/core_providers.dart';
import 'package:quick_commerce_seller/features/orders/presentation/controllers/orders_controller.dart';

final socketServiceProvider = Provider<SocketService>((ref) => SocketService(ref));

/// Live order push while the app is foregrounded.
///
/// The backend auto-joins an authenticated RESTAURANT socket into room
/// `restaurant:<id>` (`config/socket.js`) and emits `new_order` /
/// `order_status_update` / `order_deleted` there. FCM already covers
/// background/terminated notification delivery — this only refreshes the
/// in-app order list instantly while the seller has the app open, instead of
/// waiting for the next manual pull-to-refresh.
class SocketService {
  SocketService(this._ref);

  final Ref _ref;
  socket_io.Socket? _socket;

  Future<void> connect() async {
    if (_socket != null) return;

    final token = await _ref.read(tokenStorageProvider).accessToken;
    if (token == null || token.isEmpty) return;

    _socket = socket_io.io(
      AppConstants.socketUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .build(),
    );

    _socket!
      ..on('new_order', (_) => _refreshOrders())
      ..on('order_status_update', (_) => _refreshOrders())
      ..on('order_deleted', (_) => _refreshOrders());
  }

  void _refreshOrders() {
    _ref.read(ordersControllerProvider.notifier).refresh();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
