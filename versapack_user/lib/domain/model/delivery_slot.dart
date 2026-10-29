/// A delivery window. Quick-commerce defaults to "as soon as possible"; the
/// scheduled variants map to the backend's optional `scheduledAt`.
class DeliverySlot {
  const DeliverySlot({
    required this.id,
    required this.label,
    this.scheduledAt,
  });

  final String id;
  final String label;
  final DateTime? scheduledAt;

  bool get isImmediate => scheduledAt == null;

  static const asap = DeliverySlot(id: 'asap', label: 'As soon as possible');

  /// Hourly windows for the rest of the day, starting two hours out.
  static List<DeliverySlot> upcoming(DateTime now, {int count = 6}) {
    final start = DateTime(now.year, now.month, now.day, now.hour + 2);
    return List.generate(count, (i) {
      final from = start.add(Duration(hours: i));
      final to = from.add(const Duration(hours: 1));
      return DeliverySlot(
        id: 'slot-${from.millisecondsSinceEpoch}',
        label: '${_hour(from)} – ${_hour(to)}',
        scheduledAt: from,
      );
    });
  }

  static String _hour(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  bool operator ==(Object other) => other is DeliverySlot && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
