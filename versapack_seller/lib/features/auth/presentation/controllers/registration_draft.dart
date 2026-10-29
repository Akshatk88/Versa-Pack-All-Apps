import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_commerce_seller/features/auth/data/registration_api.dart';

/// What the seller has typed so far, carried across registration steps 1 to 4.
class RegistrationDraft {
  const RegistrationDraft({
    // Step 1 - Seller Information
    this.storeName = '',
    this.storeType = '',
    this.businessCategory = '',
    this.businessSubCategory = '',
    this.ownerName = '',
    this.ownerEmail = '',
    this.phone = '',
    this.alternatePhone = '',

    // Step 2 - Location & Timings
    //
    // No seeded address or coordinates. The backend resolves the store's
    // delivery zone from latitude/longitude, so a default would silently
    // register every seller at the same place and hand them someone else's
    // zone. Empty means "not captured" and is omitted from the request.
    this.storeAddress = '',
    this.latitude = '',
    this.longitude = '',
    this.openingTime = '09:00 AM',
    this.closingTime = '10:00 PM',
    this.openAllDays = true,
    this.weeklyOff = '',
    this.estimatedDeliveryTime = 30,
    this.selectedCategories = const [],

    // Step 3 - Documents & Compliance
    this.logoPath = '',
    this.storePhotos = const [],
    this.isGstRegistered = true,
    this.panNumber = '',
    this.nameOnPan = '',
    this.panImagePath = '',
    this.gstNumber = '',
    this.gstImagePath = '',
    this.fssaiNumber = '',
    this.fssaiExpiryDate = '',
    this.fssaiImagePath = '',

    // Step 4 - Bank & Review
    this.accountHolderName = '',
    this.accountNumber = '',
    this.ifscCode = '',
    this.accountType = 'Savings',
    this.lastCompletedStep = 0,
  });

  // Step 1
  final String storeName;
  final String storeType;
  final String businessCategory;
  final String businessSubCategory;
  final String ownerName;
  final String ownerEmail;
  final String phone;
  final String alternatePhone;

  // Step 2
  final String storeAddress;
  final String latitude;
  final String longitude;
  final String openingTime;
  final String closingTime;
  final bool openAllDays;
  final String weeklyOff;
  final int estimatedDeliveryTime;
  final List<String> selectedCategories;

  // Step 3
  final String logoPath;
  final List<String> storePhotos;
  final bool isGstRegistered;
  final String panNumber;
  final String nameOnPan;
  final String panImagePath;
  final String gstNumber;
  final String gstImagePath;
  final String fssaiNumber;
  final String fssaiExpiryDate;
  final String fssaiImagePath;

  // Step 4
  final String accountHolderName;
  final String accountNumber;
  final String ifscCode;
  final String accountType;

  /// Highest step index the seller has finished (0 = none).
  ///
  /// The backend has no draft endpoint — `/register` is a single one-shot
  /// multipart submit — so resume is local by necessity. See the note on
  /// [registrationDraftProvider].
  final int lastCompletedStep;

  RegistrationDraft copyWith({
    String? storeName,
    String? storeType,
    String? businessCategory,
    String? businessSubCategory,
    String? ownerName,
    String? ownerEmail,
    String? phone,
    String? alternatePhone,
    String? storeAddress,
    String? latitude,
    String? longitude,
    String? openingTime,
    String? closingTime,
    bool? openAllDays,
    String? weeklyOff,
    int? estimatedDeliveryTime,
    List<String>? selectedCategories,
    String? logoPath,
    List<String>? storePhotos,
    bool? isGstRegistered,
    String? panNumber,
    String? nameOnPan,
    String? panImagePath,
    String? gstNumber,
    String? gstImagePath,
    String? fssaiNumber,
    String? fssaiExpiryDate,
    String? fssaiImagePath,
    String? accountHolderName,
    String? accountNumber,
    String? ifscCode,
    String? accountType,
    int? lastCompletedStep,
  }) => RegistrationDraft(
    storeName: storeName ?? this.storeName,
    storeType: storeType ?? this.storeType,
    businessCategory: businessCategory ?? this.businessCategory,
    businessSubCategory: businessSubCategory ?? this.businessSubCategory,
    ownerName: ownerName ?? this.ownerName,
    ownerEmail: ownerEmail ?? this.ownerEmail,
    phone: phone ?? this.phone,
    alternatePhone: alternatePhone ?? this.alternatePhone,
    storeAddress: storeAddress ?? this.storeAddress,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    openingTime: openingTime ?? this.openingTime,
    closingTime: closingTime ?? this.closingTime,
    openAllDays: openAllDays ?? this.openAllDays,
    weeklyOff: weeklyOff ?? this.weeklyOff,
    estimatedDeliveryTime: estimatedDeliveryTime ?? this.estimatedDeliveryTime,
    selectedCategories: selectedCategories ?? this.selectedCategories,
    logoPath: logoPath ?? this.logoPath,
    storePhotos: storePhotos ?? this.storePhotos,
    isGstRegistered: isGstRegistered ?? this.isGstRegistered,
    panNumber: panNumber ?? this.panNumber,
    nameOnPan: nameOnPan ?? this.nameOnPan,
    panImagePath: panImagePath ?? this.panImagePath,
    gstNumber: gstNumber ?? this.gstNumber,
    gstImagePath: gstImagePath ?? this.gstImagePath,
    fssaiNumber: fssaiNumber ?? this.fssaiNumber,
    fssaiExpiryDate: fssaiExpiryDate ?? this.fssaiExpiryDate,
    fssaiImagePath: fssaiImagePath ?? this.fssaiImagePath,
    accountHolderName: accountHolderName ?? this.accountHolderName,
    accountNumber: accountNumber ?? this.accountNumber,
    ifscCode: ifscCode ?? this.ifscCode,
    accountType: accountType ?? this.accountType,
    lastCompletedStep: lastCompletedStep ?? this.lastCompletedStep,
  );

  /// True once everything the backend insists on is present.
  ///
  /// The phone matters as much as the rest: sign-in finds a store by it, so
  /// registering without one produces a store nobody can reach.
  bool get isComplete =>
      storeName.trim().isNotEmpty &&
      ownerName.trim().isNotEmpty &&
      ownerEmail.trim().isNotEmpty &&
      phone.trim().isNotEmpty;

  /// Round-trips the draft through preferences. Only typed values — picked file
  /// paths are included but may not survive an OS cache eviction, so the
  /// documents step re-validates them on resume.
  Map<String, dynamic> toJson() => {
    'storeName': storeName,
    'storeType': storeType,
    'businessCategory': businessCategory,
    'businessSubCategory': businessSubCategory,
    'ownerName': ownerName,
    'ownerEmail': ownerEmail,
    'phone': phone,
    'alternatePhone': alternatePhone,
    'storeAddress': storeAddress,
    'latitude': latitude,
    'longitude': longitude,
    'openingTime': openingTime,
    'closingTime': closingTime,
    'openAllDays': openAllDays,
    'weeklyOff': weeklyOff,
    'estimatedDeliveryTime': estimatedDeliveryTime,
    'selectedCategories': selectedCategories,
    'logoPath': logoPath,
    'storePhotos': storePhotos,
    'isGstRegistered': isGstRegistered,
    'panNumber': panNumber,
    'nameOnPan': nameOnPan,
    'panImagePath': panImagePath,
    'gstNumber': gstNumber,
    'gstImagePath': gstImagePath,
    'fssaiNumber': fssaiNumber,
    'fssaiExpiryDate': fssaiExpiryDate,
    'fssaiImagePath': fssaiImagePath,
    'accountHolderName': accountHolderName,
    'accountNumber': accountNumber,
    'ifscCode': ifscCode,
    'accountType': accountType,
    'lastCompletedStep': lastCompletedStep,
  };

  /// Defensive throughout: a draft written by an older build must never crash
  /// the screen that reads it.
  factory RegistrationDraft.fromJson(Map<String, dynamic> json) {
    String str(String key, [String fallback = '']) =>
        (json[key] ?? fallback).toString();
    List<String> list(String key) =>
        (json[key] as List?)?.map((e) => e.toString()).toList() ?? const [];

    return RegistrationDraft(
      storeName: str('storeName'),
      storeType: str('storeType'),
      businessCategory: str('businessCategory'),
      businessSubCategory: str('businessSubCategory'),
      ownerName: str('ownerName'),
      ownerEmail: str('ownerEmail'),
      phone: str('phone'),
      alternatePhone: str('alternatePhone'),
      storeAddress: str('storeAddress'),
      latitude: str('latitude'),
      longitude: str('longitude'),
      openingTime: str('openingTime', '09:00 AM'),
      closingTime: str('closingTime', '10:00 PM'),
      openAllDays: json['openAllDays'] != false,
      weeklyOff: str('weeklyOff'),
      estimatedDeliveryTime:
          int.tryParse(str('estimatedDeliveryTime', '30')) ?? 30,
      selectedCategories: list('selectedCategories'),
      logoPath: str('logoPath'),
      storePhotos: list('storePhotos'),
      isGstRegistered: json['isGstRegistered'] != false,
      panNumber: str('panNumber'),
      nameOnPan: str('nameOnPan'),
      panImagePath: str('panImagePath'),
      gstNumber: str('gstNumber'),
      gstImagePath: str('gstImagePath'),
      fssaiNumber: str('fssaiNumber'),
      fssaiExpiryDate: str('fssaiExpiryDate'),
      fssaiImagePath: str('fssaiImagePath'),
      accountHolderName: str('accountHolderName'),
      accountNumber: str('accountNumber'),
      ifscCode: str('ifscCode'),
      accountType: str('accountType', 'Savings'),
      lastCompletedStep: int.tryParse(str('lastCompletedStep', '0')) ?? 0,
    );
  }

  /// The seven weekdays, in the order the backend stores them.
  static const List<String> weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// The days the store actually trades, honouring the chosen weekly off.
  ///
  /// The previous version sent the literal string "Monday to Saturday" whenever
  /// the seller was not open all week, which threw away their actual choice and
  /// is not a day list the backend can split on commas.
  List<String> get openDaysList {
    if (openAllDays || weeklyOff.trim().isEmpty) return weekdays;
    final off = weeklyOff.trim().toLowerCase();
    return weekdays.where((d) => d.toLowerCase() != off).toList();
  }

  /// Converts the draft into the multipart text fields accepted by
  /// `POST /food/restaurant/register`.
  ///
  /// Field names and formats come from `restaurant.validator.js`. Anything the
  /// seller left blank is omitted rather than sent empty — the backend treats
  /// most fields as optional, but validates the format of any it receives, so
  /// an empty PAN would fail the regex instead of being ignored.
  Map<String, dynamic> toRegisterFields() {
    final pan = panNumber.trim().toUpperCase();
    final gst = gstNumber.trim().toUpperCase();
    final fssai = fssaiNumber.trim();
    final address = storeAddress.trim();
    final email = ownerEmail.trim();

    return {
      'restaurantName': storeName.trim(),
      'ownerName': ownerName.trim(),
      'ownerEmail': email,
      if (phone.trim().isNotEmpty) 'ownerPhone': phone.trim(),
      if (alternatePhone.trim().isNotEmpty)
        'primaryContactNumber': alternatePhone.trim()
      else if (phone.trim().isNotEmpty)
        'primaryContactNumber': phone.trim(),
      'pureVegRestaurant': 'false',
      if (address.isNotEmpty) 'addressLine1': address,
      if (address.isNotEmpty) 'formattedAddress': address,
      // Only sent when actually captured — see the note on the defaults above.
      if (latitude.trim().isNotEmpty) 'latitude': latitude.trim(),
      if (longitude.trim().isNotEmpty) 'longitude': longitude.trim(),
      if (selectedCategories.isNotEmpty)
        'cuisines': selectedCategories.join(','),
      'openingTime': openingTime,
      'closingTime': closingTime,
      'openDays': openDaysList.join(','),
      'estimatedDeliveryTime': '$estimatedDeliveryTime',
      if (pan.isNotEmpty) 'panNumber': pan,
      if (nameOnPan.trim().isNotEmpty) 'nameOnPan': nameOnPan.trim(),
      'gstRegistered': isGstRegistered ? 'true' : 'false',
      if (isGstRegistered && gst.isNotEmpty) 'gstNumber': gst,
      if (fssai.isNotEmpty) 'fssaiNumber': fssai,
      if (fssaiExpiryDate.isNotEmpty) 'fssaiExpiry': fssaiExpiryDate,
      if (accountHolderName.trim().isNotEmpty)
        'accountHolderName': accountHolderName.trim(),
      if (accountNumber.trim().isNotEmpty)
        'accountNumber': accountNumber.trim(),
      if (ifscCode.trim().isNotEmpty) 'ifscCode': ifscCode.trim().toUpperCase(),
      if (accountType.trim().isNotEmpty) 'accountType': accountType.trim(),
    };
  }

  /// Client-side mirror of the server's validators, so the seller is told what
  /// is wrong before a multipart upload of several megabytes is attempted.
  /// Returns null when the draft is submittable.
  ///
  /// These duplicate `restaurant.validator.js` deliberately — the server stays
  /// the authority and its rejection is still surfaced verbatim.
  String? validateForSubmit() {
    if (storeName.trim().isEmpty) return 'Store name is required';
    if (ownerName.trim().isEmpty) return 'Owner name is required';

    final email = ownerEmail.trim();
    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address';
    }

    // Backend: /^[6-9]\d{9}$/
    final indianMobile = RegExp(r'^[6-9]\d{9}$');
    final phoneValue = phone.trim();
    if (phoneValue.isNotEmpty && !indianMobile.hasMatch(phoneValue)) {
      return 'Enter a valid 10-digit phone number starting with 6-9';
    }
    final altValue = alternatePhone.trim();
    if (altValue.isNotEmpty && !indianMobile.hasMatch(altValue)) {
      return 'Enter a valid 10-digit alternate number starting with 6-9';
    }

    // Backend: /^[A-Z]{5}[0-9]{4}[A-Z]{1}$/
    final pan = panNumber.trim().toUpperCase();
    if (pan.isNotEmpty && !RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan)) {
      return 'Enter a valid PAN, e.g. ABCDE1234F';
    }

    if (isGstRegistered && gstNumber.trim().isEmpty) {
      return 'Enter your GSTIN, or turn off GST registered';
    }

    // The server rejects equal or reversed times outright.
    final open = _minutesOf(openingTime);
    final close = _minutesOf(closingTime);
    if (open != null && close != null) {
      if (open == close) return 'Opening and closing time cannot be the same';
      if (close < open) return 'Closing time cannot be before opening time';
    }

    return null;
  }

  /// Parses `HH:mm` or `hh:mm AM/PM` into minutes past midnight, matching the
  /// server's `normalizeTimeValue`. Null when unparseable.
  static int? _minutesOf(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;

    final hhmm = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw);
    if (hhmm != null) {
      final h = int.parse(hhmm.group(1)!);
      final m = int.parse(hhmm.group(2)!);
      if (h > 23 || m > 59) return null;
      return h * 60 + m;
    }

    final ampm = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$').firstMatch(raw);
    if (ampm != null) {
      var h = int.parse(ampm.group(1)!);
      final m = int.parse(ampm.group(2)!);
      final period = ampm.group(3)!.toUpperCase();
      if (h < 1 || h > 12 || m > 59) return null;
      if (period == 'AM') h = h == 12 ? 0 : h;
      if (period == 'PM') h = h == 12 ? 12 : h + 12;
      return h * 60 + m;
    }

    return null;
  }

  /// Maps selected local document file paths to StoreDocument enum keys.
  Map<StoreDocument, String> toDocumentFiles() {
    return {
      if (panImagePath.isNotEmpty) StoreDocument.pan: panImagePath,
      if (isGstRegistered && gstImagePath.isNotEmpty)
        StoreDocument.gst: gstImagePath,
      if (fssaiImagePath.isNotEmpty) StoreDocument.fssai: fssaiImagePath,
      if (logoPath.isNotEmpty) StoreDocument.storePhoto: logoPath,
    };
  }
}

/// Holds the in-progress application and mirrors it to disk.
///
/// **The backend has no draft or partial-registration endpoint** — the seller
/// surface is a single `POST /food/restaurant/register` that takes the whole
/// application at once. So progress is saved locally: preferences, not secure
/// storage, because none of it is a credential and it must survive a restart.
class RegistrationDraftController extends Notifier<RegistrationDraft> {
  static const String _key = 'registration_draft';

  @override
  RegistrationDraft build() {
    _restore();
    return const RegistrationDraft();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      state = RegistrationDraft.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      // A draft written by an incompatible build is discarded rather than
      // blocking onboarding forever.
      await prefs.remove(_key);
    }
  }

  Future<void> _persist(RegistrationDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(draft.toJson()));
  }

  void update(RegistrationDraft Function(RegistrationDraft) change) {
    state = change(state);
    _persist(state);
  }

  /// Records that [step] (zero-based) is finished, never moving backwards — a
  /// seller revisiting step 1 has not undone steps 2 and 3.
  void markStepCompleted(int step) {
    if (step + 1 <= state.lastCompletedStep) return;
    update((d) => d.copyWith(lastCompletedStep: step + 1));
  }

  Future<void> reset() async {
    state = const RegistrationDraft();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

final registrationDraftProvider =
    NotifierProvider<RegistrationDraftController, RegistrationDraft>(
      RegistrationDraftController.new,
    );
