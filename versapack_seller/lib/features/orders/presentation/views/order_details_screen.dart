import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';
import 'package:quick_commerce_seller/core/audio/app_sounds.dart';
import 'package:quick_commerce_seller/core/widgets/app_toast.dart';
import 'package:quick_commerce_seller/core/widgets/async_state_view.dart';
import 'package:quick_commerce_seller/features/orders/domain/order_model.dart';
import 'package:quick_commerce_seller/features/orders/presentation/controllers/orders_controller.dart';

/// One order, fetched by id.
///
/// Everything here comes from the order payload. Where the backend has no
/// field — a live courier distance, an accept-by countdown — the row is left
/// out rather than filled with a plausible-looking number, because a seller
/// deciding whether to accept cannot tell an invented figure from a real one.
class OrderDetailsScreen extends ConsumerWidget {
  const OrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderByIdProvider(orderId));

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.chevron_left_rounded,
            color: context.textPrimary,
            size: 28,
          ),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Text(
              'Order Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            Text(
              order.value?.orderNumber.isNotEmpty == true
                  ? order.value!.orderNumber
                  : '',
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/support'),
            icon: Icon(
              Icons.help_outline_rounded,
              color: context.textPrimary,
              size: 20,
            ),
            label: Text(
              'Help',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: AsyncStateView<OrderModel?>(
          value: order,
          onRetry: () => ref.invalidate(orderByIdProvider(orderId)),
          isEmpty: (data) => data == null,
          emptyIcon: Icons.receipt_long_outlined,
          emptyTitle: 'Order not found',
          emptyMessage: 'This order is no longer available.',
          enableRefresh: false,
          builder: (data) {
            final o = data!;

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopStatusBanner(o),
                        const SizedBox(height: 16),
                        _buildCustomerAddressCard(context, o),
                        // Between address and items, and only when the order
                        // actually carries both coordinates.
                        if (o.hasRoute) ...[
                          const SizedBox(height: 16),
                          _buildRouteCard(context, o),
                        ],
                        const SizedBox(height: 16),
                        _buildOrderItemsCard(context, o),
                        const SizedBox(height: 16),
                        if ((o.customer.instructions ?? '').trim().isNotEmpty)
                          _buildCustomerNoteBox(o.customer.instructions!.trim()),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                _buildActions(context, ref, o),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The seller's available transitions. A delivered or cancelled order has
  /// none, so the bar disappears rather than offering a button that would be
  /// rejected by the backend.
  Widget _buildActions(BuildContext context, WidgetRef ref, OrderModel o) {
    /// [leaveScreen] distinguishes the two shapes of outcome. Rejecting ends
    /// the seller's involvement, so the screen goes with it. Accepting starts
    /// the next step — the bar below becomes "Mark Ready" — and popping back to
    /// the list would hide the very transition they just unlocked.
    Future<void> apply(
      OrderStatus next,
      String done, {
      bool leaveScreen = false,
    }) async {
      await ref.read(ordersControllerProvider.notifier).updateStatus(o.id, next);
      if (!context.mounted) return;

      final failed = ref.read(ordersControllerProvider).hasError;
      // Silenced the moment the answer lands, not when the refetch that
      // follows it returns — the seller has acted and should hear that at once.
      if (!failed) AppSounds.resolveOrder(o.id);
      AppToast.show(context, failed ? 'Could not update the order.' : done);
      if (failed) return;

      // Refetched, not patched locally: the backend also stamps timings and
      // may attach a rider, and guessing at those puts the screen out of step
      // with what the seller would see on a reload.
      ref.invalidate(orderByIdProvider(o.id));
      ref.invalidate(orderHistoryProvider);
      if (leaveScreen) context.pop();
    }

    switch (o.status) {
      case OrderStatus.newOrder:
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        apply(OrderStatus.newOrder, 'Order accepted.'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFD9027),
                      foregroundColor: const Color(0xFF181C2E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: context.textPrimary,
                    ),
                    label: Text(
                      'Accept Order',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmReject(context, () async {
                      await apply(
                        OrderStatus.cancelled,
                        'Order rejected.',
                        leaveScreen: true,
                      );
                    }),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFFEF4444),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.cancel_outlined,
                      size: 20,
                      color: Color(0xFFEF4444),
                    ),
                    label: const Text(
                      'Reject Order',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

      // These two keep the pop they have always had — the seller's next move is
      // the next order, not this one.
      case OrderStatus.preparing:
        return _singleAction(
          context,
          'Mark Ready',
          () => apply(OrderStatus.ready, 'Order marked ready.', leaveScreen: true),
        );

      case OrderStatus.ready:
        return _singleAction(
          context,
          'Handed Over',
          () =>
              apply(OrderStatus.delivered, 'Order handed over.', leaveScreen: true),
        );

      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        return const SizedBox.shrink();
    }
  }

  Widget _singleAction(
    BuildContext context,
    String label,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFD9027),
            foregroundColor: const Color(0xFF181C2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  /// Rejecting is not reversible from this app, so it asks first.
  void _confirmReject(BuildContext context, VoidCallback onConfirm) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject this order?'),
        content: const Text(
          'The customer will be notified and the order cannot be restored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onConfirm();
            },
            child: const Text(
              'Reject',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopStatusBanner(OrderModel o) {
    final (label, labelBg, labelFg) = switch (o.status) {
      OrderStatus.newOrder => (
        'New Order',
        const Color(0xFFEFF6FF),
        const Color(0xFF2563EB),
      ),
      OrderStatus.preparing => (
        'Preparing',
        const Color(0xFFECFDF5),
        const Color(0xFF059669),
      ),
      OrderStatus.ready => (
        'Ready',
        const Color(0xFFEFF6FF),
        const Color(0xFF2563EB),
      ),
      OrderStatus.delivered => (
        'Completed',
        const Color(0xFFF3F4F6),
        const Color(0xFF6B7280),
      ),
      OrderStatus.cancelled => (
        'Cancelled',
        const Color(0xFFFEE2E2),
        const Color(0xFFDC2626),
      ),
    };

    final count = o.items.fold<int>(0, (n, i) => n + i.quantity);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFEF08A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: labelBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: labelFg,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Order received at',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat(
                        'd MMM yyyy, h:mm a',
                      ).format(o.createdAt.toLocal()),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF181C2E),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Order Amount',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${o.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF181C2E),
                    ),
                  ),
                  Text(
                    '$count item${count == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: 16,
                color: Color(0xFF059669),
              ),
              const SizedBox(width: 6),
              const Text(
                'Payment',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  o.paymentMethod.isEmpty ? 'Not specified' : o.paymentMethod,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF181C2E),
                  ),
                ),
              ),
            ],
          ),
          if ((o.deliveryRiderName ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.two_wheeler_rounded,
                  size: 16,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    o.deliveryRiderName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerAddressCard(BuildContext context, OrderModel o) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Color(0xFFD97706),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.customer.name.isEmpty ? 'Customer' : o.customer.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    if (o.customer.phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: context.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            o.customer.phone,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (o.customer.address.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: context.borderColor),
            const SizedBox(height: 12),
            Text(
              'Delivery Address',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              o.customer.address,
              style: TextStyle(
                fontSize: 13,
                color: context.textSecondary,
                height: 1.35,
              ),
            ),
            if (_distanceLabel(o) != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.directions_bike_rounded,
                    size: 14,
                    color: context.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _distanceLabel(o)!,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
          if ((o.storeName ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: context.borderColor),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 14,
                  color: context.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    o.storeName!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Pickup → drop, with a compact map between them.
  ///
  /// Only ever built when [OrderModel.hasRoute] is true, so every pin here is a
  /// real coordinate off the order.
  Widget _buildRouteCard(BuildContext context, OrderModel o) {
    final store = LatLng(o.storeLat!, o.storeLng!);
    final customer = LatLng(o.customerLat!, o.customerLng!);
    final km = _routeKm(o);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _routeEndpoint(
                  context,
                  icon: Icons.storefront_rounded,
                  background: const Color(0xFFFEF3C7),
                  iconColor: const Color(0xFFD97706),
                  label: 'Pickup from',
                  value: (o.storeName ?? '').trim().isEmpty
                      ? 'Your store'
                      : o.storeName!.trim(),
                ),
                Container(
                  width: 1,
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: context.borderColor,
                ),
                Column(
                  children: [
                    Text(
                      'Distance',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.textSecondary,
                      ),
                    ),
                    Text(
                      '${km.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _routeGreen,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: context.borderColor,
                ),
                _routeEndpoint(
                  context,
                  icon: Icons.location_on_rounded,
                  background: const Color(0xFFDCFCE7),
                  iconColor: _routeGreen,
                  label: 'Deliver to',
                  value: o.customer.name.isEmpty ? 'Customer' : o.customer.name,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 150,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  (store.latitude + customer.latitude) / 2,
                  (store.longitude + customer.longitude) / 2,
                ),
                zoom: _zoomFor(km),
              ),
              // Lite mode renders a static bitmap: far cheaper than a live map
              // for a card this size, and it cannot swallow the page's scroll.
              // Android only — the option is unsupported on iOS.
              liteModeEnabled: Platform.isAndroid,
              zoomGesturesEnabled: false,
              scrollGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              markers: {
                Marker(
                  markerId: const MarkerId('store'),
                  position: store,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueOrange,
                  ),
                  infoWindow: InfoWindow(title: o.storeName ?? 'Your store'),
                ),
                Marker(
                  markerId: const MarkerId('customer'),
                  position: customer,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
                  infoWindow: InfoWindow(title: o.customer.name),
                ),
              },
              polylines: {
                // A direct line, not a driving route. Road geometry needs a
                // Directions request per order, and the figure beside it is
                // already the backend's road distance where it has one — so a
                // drawn road here would be the only invented thing on screen.
                Polyline(
                  polylineId: const PolylineId('store_to_customer'),
                  points: [store, customer],
                  color: _routeGreen,
                  width: 4,
                ),
              },
            ),
          ),
          if (o.durationMinutes != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: context.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Approx. ${o.durationMinutes} min drive',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static const Color _routeGreen = Color(0xFF16A34A);

  Widget _routeEndpoint(
    BuildContext context, {
    required IconData icon,
    required Color background,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: background, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: context.textSecondary),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The backend's road distance when it resolved one, otherwise the
  /// great-circle distance between the two pins. Never a constant.
  static double _routeKm(OrderModel o) {
    final fromServer = o.distanceKm;
    if (fromServer != null && fromServer > 0) return fromServer;
    return _haversineKm(
      o.storeLat!,
      o.storeLng!,
      o.customerLat!,
      o.customerLng!,
    );
  }

  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    double toRad(double deg) => deg * math.pi / 180.0;

    final dLat = toRad(lat2 - lat1);
    final dLon = toRad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRad(lat1)) *
            math.cos(toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Zoom that keeps both pins in frame.
  ///
  /// ponytail: a step table, not a fitted LatLngBounds. Bounds fitting needs
  /// the map controller after first frame, which lite mode does not reliably
  /// honour; swap to `animateCamera(newLatLngBounds)` if lite mode is ever
  /// dropped.
  static double _zoomFor(double km) {
    if (km < 1) return 14;
    if (km < 3) return 13;
    if (km < 6) return 12;
    if (km < 12) return 11;
    if (km < 25) return 10;
    return 9;
  }

  /// "3.2 km · ~14 min", or whichever half the backend resolved. Null when it
  /// resolved neither — see the note at the top of this file about not filling
  /// a missing figure with a plausible one.
  static String? _distanceLabel(OrderModel o) {
    final parts = [
      if (o.distanceKm != null) '${o.distanceKm!.toStringAsFixed(1)} km',
      if (o.durationMinutes != null) '~${o.durationMinutes} min',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Widget _buildOrderItemsCard(BuildContext context, OrderModel o) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Items',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 14),

          ...o.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  _buildItemThumbnail(item),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${item.price.toStringAsFixed(2)} x ${item.quantity}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                        if ((item.variant ?? '').isNotEmpty)
                          Text(
                            item.variant!,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textSecondary,
                            ),
                          ),
                        if (item.addons.isNotEmpty)
                          Text(
                            item.addons.join(', '),
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${item.totalPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 24, color: Color(0xFFF3F4F6)),

          _buildBillRow('Item Total', '₹${o.subtotal.toStringAsFixed(2)}'),
          if (o.deliveryFee > 0) ...[
            const SizedBox(height: 8),
            _buildBillRow(
              'Delivery Fee',
              '₹${o.deliveryFee.toStringAsFixed(2)}',
            ),
          ],
          if (o.tax > 0) ...[
            const SizedBox(height: 8),
            _buildBillRow('Taxes', '₹${o.tax.toStringAsFixed(2)}'),
          ],
          if (o.discount > 0) ...[
            const SizedBox(height: 8),
            _buildBillRow(
              'Discount',
              '- ₹${o.discount.toStringAsFixed(2)}',
              isGreen: true,
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: context.borderColor),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Total Amount',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
              ),
              Text(
                '₹${o.totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The product photo, or the icon tile this screen has always used when the
  /// line carries no image — which is every order placed before the backend
  /// started snapshotting one, so the fallback is the common case, not an edge.
  Widget _buildItemThumbnail(OrderItemModel item) {
    const placeholder = ColoredBox(
      color: Color(0xFFFEF3C7),
      child: Center(
        child: Icon(
          Icons.fastfood_rounded,
          color: Color(0xFFD97706),
          size: 22,
        ),
      ),
    );

    final url = (item.imageUrl ?? '').trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 44,
        height: 44,
        child: url.isEmpty
            ? placeholder
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => placeholder,
                errorWidget: (_, _, _) => placeholder,
              ),
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool isGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: isGreen
                  ? const Color(0xFF10B981)
                  : const Color(0xFF6B7280),
              fontWeight: isGreen ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isGreen ? const Color(0xFF10B981) : const Color(0xFF181C2E),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerNoteBox(String note) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFEF08A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFFDE68A),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: Color(0xFFD97706),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Note from customer',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF181C2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  note,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
