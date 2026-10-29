import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_seller/features/auth/presentation/controllers/application_status.dart';

ApplicationSummary summary({
  String storeName = 'Tanu Fresh Mart',
  String applicationId = '65f1c2a4e9b1d2003a7c1234',
  String submittedAt = '2026-05-20T05:00:00.000Z',
  String phone = '9876543210',
}) => ApplicationSummary(
  storeName: storeName,
  applicationId: applicationId,
  submittedAt: submittedAt,
  phone: phone,
);

void main() {
  group('reference code', () {
    test('is derived from the real application id', () {
      // The screen previously showed a fixed 'APPZ123456789' for every seller.
      expect(summary().referenceCode, 'APZ-3A7C1234');
    });

    test('is empty when no id was captured', () {
      expect(summary(applicationId: '').referenceCode, isEmpty);
      expect(summary(applicationId: '').hasApplicationId, isFalse);
    });

    test('a short id does not throw', () {
      expect(summary(applicationId: 'abc').referenceCode, 'APZ-ABC');
    });
  });

  group('submitted date', () {
    test('formats a real ISO timestamp', () {
      final label = summary().submittedOnLabel;
      expect(label, isNotEmpty);
      expect(label, contains('2026'));
      expect(label, contains('May'));
    });

    test('is empty rather than fabricated when absent', () {
      expect(summary(submittedAt: '').submittedOnLabel, isEmpty);
    });

    test('an unparseable value degrades to empty instead of throwing', () {
      expect(summary(submittedAt: 'not-a-date').submittedOnLabel, isEmpty);
    });
  });

  group('store name', () {
    test('reports whether one was captured', () {
      expect(summary().hasStoreName, isTrue);
      expect(summary(storeName: '').hasStoreName, isFalse);
    });
  });
}
