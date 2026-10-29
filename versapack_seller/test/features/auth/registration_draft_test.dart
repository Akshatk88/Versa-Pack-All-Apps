import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_seller/features/auth/data/registration_api.dart';
import 'package:quick_commerce_seller/features/auth/presentation/controllers/registration_draft.dart';

/// A draft that passes validation, so each test can vary one thing.
RegistrationDraft valid({
  String storeName = 'Tanu Fresh Mart',
  String ownerName = 'Tanu Chouhan',
  String ownerEmail = '',
  String phone = '9876543210',
  String alternatePhone = '',
  String panNumber = '',
  bool isGstRegistered = false,
  String gstNumber = '',
  String openingTime = '09:00 AM',
  String closingTime = '10:00 PM',
}) => RegistrationDraft(
  storeName: storeName,
  ownerName: ownerName,
  ownerEmail: ownerEmail,
  phone: phone,
  alternatePhone: alternatePhone,
  panNumber: panNumber,
  isGstRegistered: isGstRegistered,
  gstNumber: gstNumber,
  openingTime: openingTime,
  closingTime: closingTime,
);

void main() {
  group('no seeded data reaches the server', () {
    test('a fresh draft carries no address or coordinates', () {
      const draft = RegistrationDraft();

      // These were seeded with a real Indore address and its lat/lng, which the
      // backend uses to resolve the store's delivery zone — every seller who
      // did not edit them would have registered at the same place.
      expect(draft.storeAddress, isEmpty);
      expect(draft.latitude, isEmpty);
      expect(draft.longitude, isEmpty);
      expect(draft.selectedCategories, isEmpty);
    });

    test('empty optional fields are omitted, not sent blank', () {
      final fields = const RegistrationDraft(
        storeName: 'S',
        ownerName: 'O',
      ).toRegisterFields();

      for (final key in [
        'latitude',
        'longitude',
        'addressLine1',
        'formattedAddress',
        'cuisines',
        'panNumber',
        'accountNumber',
        'ifscCode',
      ]) {
        expect(fields.containsKey(key), isFalse, reason: '$key was sent empty');
      }
    });
  });

  group('field mapping matches restaurant.validator.js', () {
    test('required fields are always present', () {
      final fields = valid().toRegisterFields();

      expect(fields['restaurantName'], 'Tanu Fresh Mart');
      expect(fields['ownerName'], 'Tanu Chouhan');
      // Required by the schema with no default — omitting it fails the request.
      expect(fields['pureVegRestaurant'], 'false');
      // Accepts a valid email or the empty string, nothing between.
      expect(fields['ownerEmail'], '');
    });

    test('phone maps to ownerPhone and alternate to primaryContactNumber', () {
      final fields = valid(
        phone: '9876543210',
        alternatePhone: '8765432109',
      ).toRegisterFields();

      expect(fields['ownerPhone'], '9876543210');
      expect(fields['primaryContactNumber'], '8765432109');
    });

    test('PAN and IFSC are upper-cased for the server regex', () {
      final fields = valid(panNumber: 'abcde1234f').toRegisterFields();
      expect(fields['panNumber'], 'ABCDE1234F');

      final bank = const RegistrationDraft(
        storeName: 'S',
        ownerName: 'O',
        ifscCode: 'hdfc0001234',
      ).toRegisterFields();
      expect(bank['ifscCode'], 'HDFC0001234');
    });

    test('categories are comma-joined for the cuisines field', () {
      final fields = const RegistrationDraft(
        storeName: 'S',
        ownerName: 'O',
        selectedCategories: ['Grocery', 'Dairy & Eggs'],
      ).toRegisterFields();

      // The server splits on ',' — a ', ' join leaves leading spaces it trims,
      // but the plain comma is what the contract describes.
      expect(fields['cuisines'], 'Grocery,Dairy & Eggs');
    });

    test('GST number is only sent when the seller is registered', () {
      final off = valid(
        isGstRegistered: false,
        gstNumber: '22ABCDE1234F1Z5',
      ).toRegisterFields();
      expect(off['gstRegistered'], 'false');
      expect(off.containsKey('gstNumber'), isFalse);

      final on = valid(
        isGstRegistered: true,
        gstNumber: '22abcde1234f1z5',
      ).toRegisterFields();
      expect(on['gstRegistered'], 'true');
      expect(on['gstNumber'], '22ABCDE1234F1Z5');
    });
  });

  group('open days honour the weekly off', () {
    test('open all days sends all seven', () {
      final fields = const RegistrationDraft(
        storeName: 'S',
        ownerName: 'O',
      ).toRegisterFields();

      expect(fields['openDays'], RegistrationDraft.weekdays.join(','));
    });

    test('a weekly off removes exactly that day', () {
      const draft = RegistrationDraft(
        storeName: 'S',
        ownerName: 'O',
        openAllDays: false,
        weeklyOff: 'Tuesday',
      );

      // Previously this sent the literal "Monday to Saturday", discarding the
      // seller's choice and giving the server nothing it could split on.
      expect(draft.openDaysList, hasLength(6));
      expect(draft.openDaysList.contains('Tuesday'), isFalse);
      expect(draft.toRegisterFields()['openDays'], isNot(contains('Tuesday')));
    });
  });

  group('validateForSubmit mirrors the server', () {
    test('a complete draft passes', () {
      expect(valid().validateForSubmit(), isNull);
    });

    test('store name and owner name are required', () {
      expect(valid(storeName: '').validateForSubmit(), contains('Store name'));
      expect(valid(ownerName: '').validateForSubmit(), contains('Owner name'));
    });

    test('phone must be a 10-digit Indian mobile', () {
      // Server regex: /^[6-9]\d{9}$/
      expect(valid(phone: '1234567890').validateForSubmit(), isNotNull);
      expect(valid(phone: '98765').validateForSubmit(), isNotNull);
      expect(valid(phone: '5876543210').validateForSubmit(), isNotNull);
      expect(valid(phone: '6876543210').validateForSubmit(), isNull);
      // Blank is allowed — the field is optional server-side.
      expect(valid(phone: '').validateForSubmit(), isNull);
    });

    test('PAN must match the server format', () {
      expect(valid(panNumber: 'ABCDE1234F').validateForSubmit(), isNull);
      expect(valid(panNumber: 'abcde1234f').validateForSubmit(), isNull);
      expect(valid(panNumber: 'ABCD1234F').validateForSubmit(), isNotNull);
      expect(valid(panNumber: 'ABCDE12345').validateForSubmit(), isNotNull);
    });

    test('email must be valid when provided', () {
      expect(valid(ownerEmail: 'not-an-email').validateForSubmit(), isNotNull);
      expect(valid(ownerEmail: 'a@b.co').validateForSubmit(), isNull);
      expect(valid(ownerEmail: '').validateForSubmit(), isNull);
    });

    test('GST registered without a number is rejected', () {
      expect(
        valid(isGstRegistered: true, gstNumber: '').validateForSubmit(),
        isNotNull,
      );
    });

    test('closing time must be after opening time', () {
      // The server rejects both of these outright.
      expect(
        valid(
          openingTime: '10:00 AM',
          closingTime: '10:00 AM',
        ).validateForSubmit(),
        contains('same'),
      );
      expect(
        valid(
          openingTime: '10:00 PM',
          closingTime: '09:00 AM',
        ).validateForSubmit(),
        contains('before'),
      );
      expect(
        valid(
          openingTime: '09:00 AM',
          closingTime: '10:00 PM',
        ).validateForSubmit(),
        isNull,
      );
    });

    test('24-hour times parse as well as 12-hour ones', () {
      expect(
        valid(openingTime: '09:00', closingTime: '22:00').validateForSubmit(),
        isNull,
      );
      expect(
        valid(openingTime: '22:00', closingTime: '09:00').validateForSubmit(),
        isNotNull,
      );
    });
  });

  group('document mapping', () {
    test('only attached documents are included', () {
      const draft = RegistrationDraft(
        storeName: 'S',
        ownerName: 'O',
        panImagePath: '/tmp/pan.jpg',
        logoPath: '/tmp/logo.jpg',
      );

      final docs = draft.toDocumentFiles();
      expect(docs[StoreDocument.pan], '/tmp/pan.jpg');
      expect(docs[StoreDocument.storePhoto], '/tmp/logo.jpg');
      expect(docs.containsKey(StoreDocument.fssai), isFalse);
    });

    test('the GST document is dropped when GST is switched off', () {
      const draft = RegistrationDraft(
        storeName: 'S',
        ownerName: 'O',
        isGstRegistered: false,
        gstImagePath: '/tmp/gst.jpg',
      );

      expect(draft.toDocumentFiles().containsKey(StoreDocument.gst), isFalse);
    });

    test('document field names match the backend multipart keys', () {
      // multer is configured with exactly these names; a file sent under any
      // other key is accepted and then silently discarded.
      expect(StoreDocument.pan.field, 'panImage');
      expect(StoreDocument.gst.field, 'gstImage');
      expect(StoreDocument.fssai.field, 'fssaiImage');
      expect(StoreDocument.storePhoto.field, 'profileImage');
      expect(StoreDocument.cover.field, 'coverImage');
    });
  });

  group('draft persistence for resume', () {
    test('round-trips through JSON without losing a field', () {
      const original = RegistrationDraft(
        storeName: 'Tanu Fresh Mart',
        ownerName: 'Tanu Chouhan',
        phone: '9876543210',
        storeAddress: '12 Main Rd, Indore',
        latitude: '22.7196',
        longitude: '75.8577',
        selectedCategories: ['Grocery', 'Dairy & Eggs'],
        openAllDays: false,
        weeklyOff: 'Tuesday',
        isGstRegistered: false,
        panNumber: 'ABCDE1234F',
        accountNumber: '123456789012',
        ifscCode: 'HDFC0001234',
        lastCompletedStep: 2,
      );

      final restored = RegistrationDraft.fromJson(original.toJson());

      expect(restored.storeName, original.storeName);
      expect(restored.ownerName, original.ownerName);
      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.selectedCategories, original.selectedCategories);
      expect(restored.openAllDays, isFalse);
      expect(restored.weeklyOff, 'Tuesday');
      expect(restored.isGstRegistered, isFalse);
      expect(restored.panNumber, 'ABCDE1234F');
      expect(restored.lastCompletedStep, 2);
    });

    test('an empty payload yields defaults instead of throwing', () {
      final restored = RegistrationDraft.fromJson(const {});

      expect(restored.storeName, isEmpty);
      expect(restored.lastCompletedStep, 0);
      // Booleans default the same way the constructor does.
      expect(restored.openAllDays, isTrue);
      expect(restored.isGstRegistered, isTrue);
      expect(restored.openingTime, '09:00 AM');
    });

    test('a partial payload from an older build still parses', () {
      final restored = RegistrationDraft.fromJson(const {
        'storeName': 'Only This',
        'lastCompletedStep': '3',
      });

      expect(restored.storeName, 'Only This');
      expect(restored.lastCompletedStep, 3);
      expect(restored.estimatedDeliveryTime, 30);
    });

    test('the restored coordinates still reach the request', () {
      final restored = RegistrationDraft.fromJson(
        const RegistrationDraft(
          storeName: 'S',
          ownerName: 'O',
          latitude: '22.7196',
          longitude: '75.8577',
        ).toJson(),
      );

      final fields = restored.toRegisterFields();
      expect(fields['latitude'], '22.7196');
      expect(fields['longitude'], '75.8577');
    });
  });
}
