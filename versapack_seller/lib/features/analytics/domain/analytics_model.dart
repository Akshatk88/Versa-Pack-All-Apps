/// Headline numbers for the analytics screen.
///
/// Every figure is derived from the seller's own orders. The backend has no
/// analytics endpoint, and inventing one client-side is honest only as long as
/// the arithmetic is stated plainly, which is what [AnalyticsSummary] is for.
class AnalyticsSummary {
  const AnalyticsSummary({
    required this.totalSales,
    required this.totalOrders,
    required this.averageOrderValue,
    required this.itemsSold,
    required this.newCustomers,
    required this.returningCustomers,
    required this.salesTrendPercent,
    required this.ordersTrendPercent,
  });

  const AnalyticsSummary.empty()
    : totalSales = 0,
      totalOrders = 0,
      averageOrderValue = 0,
      itemsSold = 0,
      newCustomers = 0,
      returningCustomers = 0,
      salesTrendPercent = null,
      ordersTrendPercent = null;

  final double totalSales;
  final int totalOrders;
  final double averageOrderValue;
  final int itemsSold;

  /// Customers whose first order with this store falls in the window.
  final int newCustomers;
  final int returningCustomers;

  /// Change against the previous window of the same length. Null when there is
  /// no previous window to compare against -- a store's first week has no
  /// "versus last week", and showing 0% would read as flat rather than unknown.
  final double? salesTrendPercent;
  final double? ordersTrendPercent;
}
