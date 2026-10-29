import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:quick_commerce_seller/core/network/api_exception.dart';
import 'package:quick_commerce_seller/core/providers/core_providers.dart';
import 'package:quick_commerce_seller/core/widgets/app_toast.dart';
import 'package:quick_commerce_seller/features/auth/data/registration_api.dart';
import 'package:quick_commerce_seller/features/auth/domain/seller_model.dart';
import 'package:quick_commerce_seller/features/location/data/location_service.dart';
import 'package:quick_commerce_seller/features/location/domain/store_location.dart';
import 'package:quick_commerce_seller/features/location/presentation/views/location_picker_screen.dart';
import 'package:quick_commerce_seller/features/auth/presentation/controllers/auth_controller.dart';
import 'package:quick_commerce_seller/features/auth/presentation/controllers/auth_state.dart';
import 'package:quick_commerce_seller/features/auth/presentation/controllers/registration_draft.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  int _currentStep = 0; // 0 = Step 1, 1 = Step 2, 2 = Step 3, 3 = Step 4
  bool _isSubmitting = false;

  // Step 1 Controllers
  final _formKeyStep1 = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _alternatePhoneController = TextEditingController();
  String _selectedStoreType = 'Quick Commerce';

  /// Null until the seller picks, or until a restored draft supplies one.
  ///
  /// Must never hold a value that is absent from [_businessCategories]:
  /// `DropdownButton` asserts that its value matches exactly one item, and the
  /// list now comes from the backend, so no hardcoded default is safe.
  String? _selectedCategory;
  String _selectedSubCategory = 'General Retail';

  // Step 2 Controllers
  final _formKeyStep2 = GlobalKey<FormState>();
  String _storeAddress = '';

  /// The confirmed pin. Null until the seller places one — the backend zones
  /// the store on these coordinates, so a guessed default is worse than none.
  StoreLocation? _storeLocation;
  bool _locating = false;
  String _openingTime = '09:00 AM';
  String _closingTime = '10:00 PM';
  bool _openAllDays = true;
  String? _weeklyOff;
  int _estimatedDeliveryTime = 30;

  /// Chosen by the seller only. Pre-selecting categories meant a seller who
  /// never touched this step still registered as selling dairy.
  final Set<String> _selectedStoreCategories = {};

  // Step 3 Controllers & Image State
  final _formKeyStep3 = GlobalKey<FormState>();
  String? _logoPath;
  final List<String> _storePhotos = [];
  bool _isGstRegistered = true;
  final _panNumberController = TextEditingController();
  final _nameOnPanController = TextEditingController();
  String? _panImagePath;
  final _gstNumberController = TextEditingController();
  String? _gstImagePath;
  final _fssaiNumberController = TextEditingController();
  final _fssaiExpiryController = TextEditingController();
  String? _fssaiImagePath;

  // Step 4 Controllers
  final _formKeyStep4 = GlobalKey<FormState>();
  final _accountHolderController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  String _accountType = 'Savings'; // 'Savings' or 'Current'

  final ImagePicker _picker = ImagePicker();

  final List<String> _storeTypes = [
    'Quick Commerce',
    'Supermarket / Kirana Store',
    'Specialty Retailer',
    'Cloud Store / Dark Store',
    'Brand / Manufacturer',
  ];

  static const List<String> _defaultCategories = [
    'Grocery & Supermarket',
    'Fruits & Vegetables',
    'Bakery & Confectionery',
    'Dairy & Eggs',
    'Personal Care & Cosmetics',
    'Household & Cleaning Essentials',
    'Snacks & Beverages',
    'Meat, Fish & Seafood',
    'Electronics & Gadgets',
    'General Retail & Convenience',
  ];

  List<String> get _businessCategories {
    final fetched = ref.watch(registrationCategoriesProvider).value ?? const [];
    if (fetched.isNotEmpty) return fetched;
    return _defaultCategories;
  }

  final List<String> _subCategories = [
    'General Retail',
    'Fresh Produce',
    'Packaged Foods',
    'Beverages',
    'Personal Hygiene',
  ];

  final List<String> _openingTimes = [
    '06:00 AM',
    '07:00 AM',
    '08:00 AM',
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
  ];

  final List<String> _closingTimes = [
    '08:00 PM',
    '09:00 PM',
    '10:00 PM',
    '11:00 PM',
    '12:00 AM',
  ];

  final List<String> _daysOfWeek = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authControllerProvider);
      if (authState is AuthNeedsRegistration && authState.phone.isNotEmpty) {
        if (_phoneController.text.isEmpty) {
          _phoneController.text = authState.phone.replaceAll('+91', '').trim();
        }
      }
      final draft = ref.read(registrationDraftProvider);
      if (draft.storeName.isNotEmpty) {
        _storeNameController.text = draft.storeName;
      }
      if (draft.ownerName.isNotEmpty) {
        _ownerNameController.text = draft.ownerName;
      }
      if (draft.ownerEmail.isNotEmpty) _emailController.text = draft.ownerEmail;
      if (draft.phone.isNotEmpty) _phoneController.text = draft.phone;
      if (draft.storeAddress.isNotEmpty) _storeAddress = draft.storeAddress;

      // Rebuild the pin from the stored coordinates so the map preview and the
      // submitted latitude/longitude survive a restart.
      final lat = double.tryParse(draft.latitude);
      final lng = double.tryParse(draft.longitude);
      if (lat != null && lng != null) {
        _storeLocation = StoreLocation(
          latitude: lat,
          longitude: lng,
          formattedAddress: draft.storeAddress,
        );
      }

      // Resume where the seller stopped. Clamped to the last step so a draft
      // from a build with more steps cannot index past the end.
      final resumeAt = draft.lastCompletedStep.clamp(0, 3);
      if (resumeAt > 0) _currentStep = resumeAt;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _alternatePhoneController.dispose();
    _panNumberController.dispose();
    _nameOnPanController.dispose();
    _gstNumberController.dispose();
    _fssaiNumberController.dispose();
    _fssaiExpiryController.dispose();
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  /// Review rows show what the seller actually entered. An invented placeholder
  /// here means they approve a summary that is not their application.
  String _orNotProvided(String value) =>
      value.trim().isEmpty ? 'Not provided' : value.trim();

  /// Mirrors what `RegistrationDraft.openDaysList` will send.
  String get _openDaysSummary {
    if (_openAllDays || (_weeklyOff ?? '').isEmpty) return 'Every day';
    return 'Every day except $_weeklyOff';
  }

  void _saveDraftFromStep1() {
    ref
        .read(registrationDraftProvider.notifier)
        .update(
          (d) => d.copyWith(
            storeName: _storeNameController.text.trim(),
            storeType: _selectedStoreType,
            businessCategory: _selectedCategory ?? '',
            businessSubCategory: _selectedSubCategory,
            ownerName: _ownerNameController.text.trim(),
            ownerEmail: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            alternatePhone: _alternatePhoneController.text.trim(),
          ),
        );
  }

  /// Opens the full-screen map, seeded with the current pin when there is one.
  Future<void> _openLocationPicker() async {
    final picked = await Navigator.of(context).push<StoreLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initial: _storeLocation),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _storeLocation = picked;
      // Only overwrite a typed address when the map produced a real one.
      if (picked.hasAddress) _storeAddress = picked.formattedAddress;
    });
  }

  /// Drops the pin on the device's position and resolves its address.
  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final located = await ref
          .read(locationServiceProvider)
          .currentLocationWithAddress();
      if (!mounted) return;
      setState(() {
        _storeLocation = located;
        if (located.hasAddress) _storeAddress = located.formattedAddress;
        _locating = false;
      });
      AppToast.showSuccess(context, 'Location set from GPS');
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() => _locating = false);
      AppToast.showError(context, e.message);
    }
  }

  void _saveDraftFromStep2() {
    ref
        .read(registrationDraftProvider.notifier)
        .update(
          (d) => d.copyWith(
            storeAddress: _storeAddress,
            latitude: _storeLocation?.latitude.toString() ?? '',
            longitude: _storeLocation?.longitude.toString() ?? '',
            openingTime: _openingTime,
            closingTime: _closingTime,
            openAllDays: _openAllDays,
            weeklyOff: _weeklyOff ?? '',
            estimatedDeliveryTime: _estimatedDeliveryTime,
            selectedCategories: _selectedStoreCategories.toList(),
          ),
        );
  }

  void _saveDraftFromStep3() {
    ref
        .read(registrationDraftProvider.notifier)
        .update(
          (d) => d.copyWith(
            logoPath: _logoPath ?? '',
            storePhotos: _storePhotos,
            isGstRegistered: _isGstRegistered,
            panNumber: _panNumberController.text.trim(),
            nameOnPan: _nameOnPanController.text.trim(),
            panImagePath: _panImagePath ?? '',
            gstNumber: _gstNumberController.text.trim(),
            gstImagePath: _gstImagePath ?? '',
            fssaiNumber: _fssaiNumberController.text.trim(),
            fssaiExpiryDate: _fssaiExpiryController.text.trim(),
            fssaiImagePath: _fssaiImagePath ?? '',
          ),
        );
  }

  void _saveDraftFromStep4() {
    ref
        .read(registrationDraftProvider.notifier)
        .update(
          (d) => d.copyWith(
            accountHolderName: _accountHolderController.text.trim(),
            accountNumber: _accountNumberController.text.trim(),
            ifscCode: _ifscController.text.trim(),
            accountType: _accountType,
          ),
        );
  }

  void _nextStep() {
    FocusScope.of(context).unfocus();

    if (_currentStep == 0) {
      // Validation failures are usually on fields below the fold, so without a
      // message Next looks like a dead button.
      if (!_formKeyStep1.currentState!.validate()) {
        AppToast.showError(context, 'Please complete the highlighted fields');
        return;
      }
      if (_selectedCategory == null || _selectedCategory!.trim().isEmpty) {
        // A DropdownButtonFormField without a validator never reports itself as
        // invalid, so this required field has to be checked by hand.
        AppToast.showError(context, 'Select a business category to continue');
        return;
      }
      _saveDraftFromStep1();
      ref.read(registrationDraftProvider.notifier).markStepCompleted(0);
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (_selectedStoreCategories.isEmpty) {
        AppToast.showError(
          context,
          'Please select at least one store category',
        );
        return;
      }
      _saveDraftFromStep2();
      ref.read(registrationDraftProvider.notifier).markStepCompleted(1);
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      if (!_formKeyStep3.currentState!.validate()) return;
      _saveDraftFromStep3();
      ref.read(registrationDraftProvider.notifier).markStepCompleted(2);
      setState(() => _currentStep = 3);
    }
  }

  void _prevStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep == 0) {
      context.pop();
    } else {
      setState(() => _currentStep--);
    }
  }

  Future<void> _pickImage(Function(String) onPicked) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file != null) {
        onPicked(file.path);
        setState(() {});
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, 'Failed to select image: $e');
    }
  }

  Future<void> _submitRegistration() async {
    FocusScope.of(context).unfocus();
    _saveDraftFromStep1();
    _saveDraftFromStep2();
    _saveDraftFromStep3();
    _saveDraftFromStep4();

    final draft = ref.read(registrationDraftProvider);

    // Mirrors the server's validators, so several megabytes of multipart are
    // not spent discovering a malformed PAN.
    final problem = draft.validateForSubmit();
    if (problem != null) {
      AppToast.showError(context, problem);
      if (draft.storeName.trim().isEmpty || draft.ownerName.trim().isEmpty) {
        setState(() => _currentStep = 0);
      }
      return;
    }

    // The button is disabled while in flight, but a fast second tap can land
    // before the rebuild — and a duplicate application is not undoable.
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final registered = await ref
          .read(registrationApiProvider)
          .register(
            fields: draft.toRegisterFields(),
            documents: draft.toDocumentFiles(),
            galleryImagePaths: draft.storePhotos,
          );

      // `/register` is public and returns no tokens — the seller is not signed
      // in yet. Persist what identifies them so the status screen and the next
      // sign-in have something to work with.
      final seller = SellerModel.fromJson(registered);
      await ref
          .read(tokenStorageProvider)
          .saveSeller(
            id: seller.id,
            status: seller.status.isNotEmpty ? seller.status : 'pending',
            phone: seller.phone.isNotEmpty ? seller.phone : draft.phone.trim(),
            storeName: seller.displayName,
            submittedAt: seller.createdAt,
          );

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ref.read(registrationDraftProvider.notifier).reset();
      AppToast.showSuccess(context, 'Application submitted for review');
      context.pushReplacement('/registration-success');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppToast.showError(context, _messageFor(e));
    }
  }

  /// The backend returns one validation message at a time and its wording is
  /// more specific than anything the client can invent, so it is shown
  /// verbatim. Never `e.toString()` — that puts a DioException in front of a
  /// seller.
  String _messageFor(Object error) {
    if (error is DioException && error.error is ApiException) {
      return (error.error as ApiException).message;
    }
    if (error is ApiException) return error.message;
    return 'Could not submit your application. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation & Step Indicator Header
            _buildTopHeader(),

            // Scrollable Step Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepHeaderTitle(),
                    const SizedBox(height: 16),
                    if (_currentStep == 0) _buildStep1Form(),
                    if (_currentStep == 1) _buildStep2Form(),
                    if (_currentStep == 2) _buildStep3Form(),
                    if (_currentStep == 3) _buildStep4Form(),
                  ],
                ),
              ),
            ),

            // Bottom Navigation Bar
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // Header matching screenshots
  Widget _buildTopHeader() {
    final stepPercentage = [25, 50, 75, 100][_currentStep];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  _currentStep == 0
                      ? Icons.close_rounded
                      : Icons.arrow_back_rounded,
                  color: const Color(0xFF15803D),
                  size: 24,
                ),
                onPressed: _prevStep,
              ),
              const Expanded(
                child: Text(
                  'Seller Onboarding',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(width: 24),
            ],
          ),
          const SizedBox(height: 14),

          // Stepper Node Circle Line
          Row(
            children: List.generate(4, (index) {
              final isCompleted = index < _currentStep;
              final isActive = index == _currentStep;

              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? const Color(0xFF16A34A)
                            : (isActive
                                  ? const Color(0xFFFD9027)
                                  : Colors.white),
                        border: Border.all(
                          color: isCompleted
                              ? const Color(0xFF16A34A)
                              : (isActive
                                    ? const Color(0xFFFD9027)
                                    : const Color(0xFFD1D5DB)),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 16,
                              )
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isActive
                                      ? const Color(0xFF1F2937)
                                      : const Color(0xFF9CA3AF),
                                ),
                              ),
                      ),
                    ),
                    if (index < 3)
                      Expanded(
                        child: Container(
                          height: 3,
                          color: index < _currentStep
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          // Step Pill Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'STEP ${_currentStep + 1} OF 4',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15803D),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$stepPercentage% Completed',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeaderTitle() {
    final titles = [
      'Seller Information',
      'Location & Timings',
      'Documents & Compliance',
      'Bank & Review',
    ];
    final subtitles = [
      'Tell us about your business',
      'Add your store address, location and working hours',
      'Submit your legal documents and store photos',
      'Add your bank details and review your information before submitting',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titles[_currentStep],
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1F2937),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitles[_currentStep],
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            height: 1.3,
          ),
        ),
      ],
    );
  }

  // ------------------- STEP 1 FORM -------------------
  Widget _buildStep1Form() {
    return Form(
      key: _formKeyStep1,
      child: Column(
        children: [
          // Business Information Card
          _buildCardContainer(
            icon: Icons.storefront_rounded,
            title: 'Business Information',
            children: [
              _buildFieldLabel('Store / Business Name'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _storeNameController,
                decoration: _buildInputDecoration(
                  hintText: 'Enter store name',
                  prefixIcon: Icons.storefront_outlined,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter store name' : null,
              ),
              const SizedBox(height: 16),

              _buildFieldLabel('Store Type'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedStoreType,
                isExpanded: true,
                decoration: _buildInputDecoration(
                  prefixIcon: Icons.store_outlined,
                ),
                items: _storeTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedStoreType = val!),
              ),
              const SizedBox(height: 16),

              _buildFieldLabel('Business Category'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                // Guard against a stale draft value that is no longer in the
                // server's list — showing the hint beats crashing the screen.
                initialValue: _businessCategories.contains(_selectedCategory)
                    ? _selectedCategory
                    : null,
                isExpanded: true,
                decoration: _buildInputDecoration(
                  prefixIcon: Icons.grid_view_outlined,
                ),
                items: _businessCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCategory = val),
              ),
              const SizedBox(height: 16),

              _buildFieldLabel('Business Sub Category', isRequired: false),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedSubCategory,
                isExpanded: true,
                decoration: _buildInputDecoration(
                  prefixIcon: Icons.category_outlined,
                ),
                items: _subCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedSubCategory = val!),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Owner Details Card
          _buildCardContainer(
            icon: Icons.person_outline_rounded,
            title: 'Owner Details',
            subtitle:
                'These details will be used for all business communications and updates.',
            children: [
              _buildFieldLabel('Full Name'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _ownerNameController,
                textCapitalization: TextCapitalization.words,
                decoration: _buildInputDecoration(
                  hintText: 'Enter full name',
                  prefixIcon: Icons.person_outline_rounded,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter full name' : null,
              ),
              const SizedBox(height: 16),

              _buildFieldLabel('Email Address'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _buildInputDecoration(
                  hintText: 'Enter email address',
                  prefixIcon: Icons.mail_outline_rounded,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Enter email address';
                  }
                  if (!RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  ).hasMatch(v.trim())) {
                    return 'Enter valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildFieldLabel('Phone Number'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          color: Color(0xFF16A34A),
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '+91',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: Color(0xFF6B7280),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _buildInputDecoration(
                        hintText: 'Enter phone number',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter phone number'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildFieldLabel(
                'Alternate Contact Number (If different)',
                isRequired: false,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          color: Color(0xFF16A34A),
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '+91',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: Color(0xFF6B7280),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _alternatePhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _buildInputDecoration(
                        hintText: 'Enter alternate number',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------- STEP 2 FORM -------------------
  /// A tappable mini-map once a pin exists, the original prompt before that.
  /// The preview is non-interactive on purpose — dragging inside a 140px box
  /// fights the page scroll, so the full picker owns the gestures.
  Widget _buildMapPreview() {
    final location = _storeLocation;
    if (location == null) {
      return InkWell(
        onTap: _openLocationPicker,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x3316A34A),
              ),
            ),
            const Icon(
              Icons.location_on_rounded,
              size: 42,
              color: Color(0xFF16A34A),
            ),
          ],
        ),
      );
    }

    final target = LatLng(location.latitude, location.longitude);
    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: target, zoom: 16),
          markers: {
            Marker(markerId: const MarkerId('store'), position: target),
          },
          liteModeEnabled: true,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
        ),
        // Lite mode renders a static bitmap, so the whole box is one tap
        // target that opens the editable map.
        Material(
          color: Colors.transparent,
          child: InkWell(onTap: _openLocationPicker),
        ),
      ],
    );
  }

  /// Emoji for a category name. Presentation only — the names themselves come
  /// from the backend, so anything unrecognised gets a neutral basket.
  String _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('fruit') || n.contains('vegetab')) return '🍎';
    if (n.contains('dairy') || n.contains('milk') || n.contains('curd')) {
      return '🥛';
    }
    if (n.contains('bread') || n.contains('bakery')) return '🍞';
    if (n.contains('snack') || n.contains('chips')) return '🍿';
    if (n.contains('beverage') || n.contains('drink') || n.contains('juice')) {
      return '🥤';
    }
    if (n.contains('personal') || n.contains('beauty')) return '🧴';
    if (n.contains('home') || n.contains('clean')) return '🧹';
    if (n.contains('baby')) return '🍼';
    if (n.contains('meat') || n.contains('seafood')) return '🍗';
    if (n.contains('frozen')) return '🧊';
    return '🛒';
  }

  Widget _buildStep2Form() {
    return Form(
      key: _formKeyStep2,
      child: Column(
        children: [
          // Store Location Card
          _buildCardContainer(
            icon: Icons.location_on_rounded,
            title: 'Store Location',
            subtitle:
                'Pin your location\nDrag the pin or tap the map to set your store\'s exact location.',
            children: [
              // Simulated Map Box with Pin
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFFE8F5E9),
                  border: Border.all(color: const Color(0xFFC8E6C9)),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildMapPreview(),
              ),
              const SizedBox(height: 12),

              // Selected Location Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFF16A34A),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selected Location',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF15803D),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _storeAddress,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF374151),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _openLocationPicker,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Row(
                        children: [
                          Text(
                            'Change',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Color(0xFF16A34A),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(
                    _locating ? 'Getting location…' : 'Use Current Location',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFD9027),
                    foregroundColor: const Color(0xFF1F2937),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _showManualAddressModal,
                  icon: const Icon(
                    Icons.edit_note_rounded,
                    size: 20,
                    color: Color(0xFF15803D),
                  ),
                  label: const Text(
                    'Enter Location Manually',
                    style: TextStyle(
                      color: Color(0xFF15803D),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFF16A34A),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Store Timings Card
          _buildCardContainer(
            icon: Icons.access_time_rounded,
            title: 'Store Timings',
            subtitle: 'Set your store working hours and days',
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Opening Time'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _openingTime,
                          decoration: _buildInputDecoration(
                            prefixIcon: Icons.access_time_rounded,
                          ),
                          items: _openingTimes
                              .map(
                                (t) =>
                                    DropdownMenuItem(value: t, child: Text(t)),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _openingTime = val!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Closing Time'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _closingTime,
                          decoration: _buildInputDecoration(
                            prefixIcon: Icons.access_time_rounded,
                          ),
                          items: _closingTimes
                              .map(
                                (t) =>
                                    DropdownMenuItem(value: t, child: Text(t)),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _closingTime = val!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_month_outlined,
                              color: Color(0xFF16A34A),
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Open All Days',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Keep store open all 7 days',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _openAllDays,
                    activeThumbColor: const Color(0xFF16A34A),
                    onChanged: (val) => setState(() => _openAllDays = val),
                  ),
                ],
              ),

              if (!_openAllDays) ...[
                const SizedBox(height: 12),
                _buildFieldLabel('Weekly Off (Optional)', isRequired: false),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _weeklyOff,
                  hint: const Text('Select Day'),
                  decoration: _buildInputDecoration(
                    prefixIcon: Icons.calendar_today_rounded,
                  ),
                  items: _daysOfWeek
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (val) => setState(() => _weeklyOff = val),
                ),
              ],
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.local_shipping_outlined,
                              color: Color(0xFF16A34A),
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Estimated Delivery Time',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Time taken to deliver orders',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Counter Stepper - / +
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.remove_rounded,
                            size: 18,
                            color: Color(0xFFFD9027),
                          ),
                          onPressed: () {
                            if (_estimatedDeliveryTime > 10) {
                              setState(() => _estimatedDeliveryTime -= 5);
                            }
                          },
                        ),
                        Text(
                          '$_estimatedDeliveryTime mins',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: Color(0xFFFD9027),
                          ),
                          onPressed: () {
                            if (_estimatedDeliveryTime < 120) {
                              setState(() => _estimatedDeliveryTime += 5);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Store Category Multi-select Card
          _buildCardContainer(
            icon: Icons.grid_view_rounded,
            title: 'Store Category',
            subtitle: 'Select categories that best describe your store',
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: _businessCategories.map((name) {
                  final icon = _iconFor(name);
                  final isSelected = _selectedStoreCategories.contains(name);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedStoreCategories.remove(name);
                        } else {
                          _selectedStoreCategories.add(name);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFDF8E2)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFD9027)
                              : const Color(0xFFE5E7EB),
                          width: isSelected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(icon, style: const TextStyle(fontSize: 15)),
                          const SizedBox(width: 6),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------- STEP 3 FORM -------------------
  Widget _buildStep3Form() {
    return Form(
      key: _formKeyStep3,
      child: Column(
        children: [
          // Store Photos Card
          _buildCardContainer(
            icon: Icons.storefront_rounded,
            title: 'Store Photos',
            subtitle: 'Upload your store logo and photos',
            children: [
              _buildFieldLabel('Store Logo / Profile Photo'),
              const SizedBox(height: 6),
              _buildDottedUploadBox(
                label: 'Upload Logo',
                sublabel: 'JPG, PNG • Max 5MB',
                filePath: _logoPath,
                onTap: () => _pickImage((path) => _logoPath = path),
                onClear: () => setState(() => _logoPath = null),
              ),
              const SizedBox(height: 16),

              _buildFieldLabel('Store Photos (up to 10)', isRequired: false),
              const SizedBox(height: 6),
              SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Add Photo Box
                    InkWell(
                      onTap: () => _pickImage((path) => _storePhotos.add(path)),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD1D5DB)),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              color: Color(0xFF16A34A),
                              size: 24,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Add Photo',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    ..._storePhotos.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final path = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(left: 10),
                        width: 80,
                        height: 80,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(path),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _storePhotos.removeAt(idx)),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Color(0xCC000000),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    if (_storePhotos.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: InkWell(
                          onTap: () =>
                              _pickImage((path) => _storePhotos.add(path)),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  color: Color(0xFF15803D),
                                  size: 24,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Add More',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Registered for GST Switch Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        color: Color(0xFF16A34A),
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Registered for GST?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            Text(
                              'Enable if you have a GST number',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _isGstRegistered,
                  activeThumbColor: const Color(0xFF16A34A),
                  onChanged: (val) => setState(() => _isGstRegistered = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // PAN Details Card
          _buildCardContainer(
            icon: Icons.subtitles_outlined,
            title: 'PAN Details',
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('PAN Number'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _panNumberController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: _buildInputDecoration(
                            hintText: 'ABCDE1234F',
                          ),
                          validator: (v) => (v == null || v.trim().length != 10)
                              ? 'Enter 10-character PAN'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Name on PAN'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameOnPanController,
                          textCapitalization: TextCapitalization.words,
                          decoration: _buildInputDecoration(
                            hintText: 'Rahul Sharma',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter name on PAN'
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildFieldLabel('PAN Card Image'),
              const SizedBox(height: 6),
              _buildDottedUploadBox(
                label: 'Upload PAN Card',
                sublabel: 'JPG, PNG or PDF • Max size 5MB',
                filePath: _panImagePath,
                onTap: () => _pickImage((path) => _panImagePath = path),
                onClear: () => setState(() => _panImagePath = null),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // GST Details Card (If GST enabled)
          if (_isGstRegistered) ...[
            _buildCardContainer(
              icon: Icons.receipt_long_outlined,
              title: 'GST Details',
              subtitle: 'Enable if you have a GST number',
              children: [
                _buildFieldLabel('GSTIN Number'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _gstNumberController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _buildInputDecoration(
                    hintText: '22ABCDE1234F1Z5',
                  ),
                ),
                const SizedBox(height: 16),

                _buildFieldLabel('GST Certificate Image', isRequired: false),
                const SizedBox(height: 6),
                _buildDottedUploadBox(
                  label: 'Upload GST Certificate',
                  sublabel: 'JPG, PNG or PDF • Max size 5MB',
                  filePath: _gstImagePath,
                  onTap: () => _pickImage((path) => _gstImagePath = path),
                  onClear: () => setState(() => _gstImagePath = null),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // FSSAI License Card
          _buildCardContainer(
            icon: Icons.workspace_premium_outlined,
            title: 'FSSAI License',
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('FSSAI License Number'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _fssaiNumberController,
                          keyboardType: TextInputType.number,
                          decoration: _buildInputDecoration(
                            hintText: 'Enter FSSAI license number',
                          ),
                          validator: (v) => (v == null || v.trim().length < 14)
                              ? 'Enter 14-digit FSSAI'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Expiry Date'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _fssaiExpiryController,
                          readOnly: true,
                          decoration: _buildInputDecoration(
                            hintText: 'Select expiry date',
                            suffixIcon: Icons.calendar_today_rounded,
                          ),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 3650),
                              ),
                            );
                            if (date != null && mounted) {
                              setState(() {
                                _fssaiExpiryController.text = DateFormat(
                                  'yyyy-MM-dd',
                                ).format(date);
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildFieldLabel('FSSAI License Image'),
              const SizedBox(height: 6),
              _buildDottedUploadBox(
                label: 'Upload License',
                sublabel: 'JPG, PNG or PDF • Max size 5MB',
                filePath: _fssaiImagePath,
                onTap: () => _pickImage((path) => _fssaiImagePath = path),
                onClear: () => setState(() => _fssaiImagePath = null),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Compliance Notice Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF15803D),
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Please ensure all documents are clear and valid.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF15803D),
                        ),
                      ),
                      Text(
                        'We will verify and get back to you.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------- STEP 4 FORM -------------------
  Widget _buildStep4Form() {
    return Form(
      key: _formKeyStep4,
      child: Column(
        children: [
          // Bank Details Card
          _buildCardContainer(
            icon: Icons.account_balance_outlined,
            title: 'Bank Details',
            subtitle: 'Used for payouts and settlements',
            children: [
              _buildFieldLabel('Account Holder Name'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _accountHolderController,
                textCapitalization: TextCapitalization.words,
                decoration: _buildInputDecoration(
                  hintText: 'Enter account holder name',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter account holder name'
                    : null,
              ),
              const SizedBox(height: 16),

              _buildFieldLabel('Account Number'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration(
                  hintText: 'Enter account number',
                ),
                validator: (v) => (v == null || v.trim().length < 9)
                    ? 'Enter valid account number'
                    : null,
              ),
              const SizedBox(height: 16),

              _buildFieldLabel('IFSC Code'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _ifscController,
                textCapitalization: TextCapitalization.characters,
                decoration: _buildInputDecoration(hintText: 'Enter IFSC code'),
                validator: (v) => (v == null || v.trim().length != 11)
                    ? 'Enter 11-digit IFSC'
                    : null,
              ),
              const SizedBox(height: 16),

              _buildFieldLabel('Account Type'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildAccountTypeButton('Savings')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildAccountTypeButton('Current')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Review Application Card
          _buildCardContainer(
            icon: Icons.assignment_outlined,
            title: 'Review Your Application',
            subtitle: 'Please review all the details before submitting',
            children: [
              _buildReviewRow(
                'Store Name',
                _orNotProvided(_storeNameController.text),
              ),
              _buildReviewRow('Store Type', _selectedStoreType),
              _buildReviewRow(
                'Owner Name',
                _orNotProvided(_ownerNameController.text),
              ),
              _buildReviewRow(
                'Phone Number',
                _phoneController.text.trim().isEmpty
                    ? 'Not provided'
                    : '+91 ${_phoneController.text.trim()}',
              ),
              _buildReviewRow('Store Address', _orNotProvided(_storeAddress)),
              _buildReviewRow(
                'Categories',
                _orNotProvided(_selectedStoreCategories.join(', ')),
              ),
              _buildReviewRow('Opening Days', _openDaysSummary),
              _buildReviewRow(
                'Operating Hours',
                '$_openingTime – $_closingTime',
              ),
              _buildReviewRow('Delivery Time', '$_estimatedDeliveryTime mins'),
              _buildReviewRow(
                'Store Photos',
                '${_storePhotos.length} uploaded',
                isChecked: _storePhotos.isNotEmpty,
              ),
              _buildReviewRow(
                'PAN',
                _orNotProvided(_panNumberController.text),
                isChecked: _panNumberController.text.trim().isNotEmpty,
              ),
              _buildReviewRow(
                'GST',
                _isGstRegistered
                    ? _orNotProvided(_gstNumberController.text)
                    : 'Not Registered',
                isChecked:
                    _isGstRegistered &&
                    _gstNumberController.text.trim().isNotEmpty,
                isWarning: !_isGstRegistered,
              ),
              _buildReviewRow(
                'FSSAI License',
                _orNotProvided(_fssaiNumberController.text),
                isChecked: _fssaiNumberController.text.trim().isNotEmpty,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTypeButton(String type) {
    final isSelected = _accountType == type;

    return InkWell(
      onTap: () => setState(() => _accountType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFD9027) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFD9027)
                : const Color(0xFF16A34A),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_balance_outlined,
              size: 18,
              color: Color(0xFF1F2937),
            ),
            const SizedBox(width: 8),
            Text(
              type,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewRow(
    String label,
    String value, {
    bool isChecked = false,
    bool isWarning = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (isChecked)
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: 18,
            ),
          if (isWarning)
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFF59E0B),
              size: 18,
            ),
        ],
      ),
    );
  }

  // Common Dotted Upload Card
  Widget _buildDottedUploadBox({
    required String label,
    required String sublabel,
    String? filePath,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final hasFile = filePath != null && filePath.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasFile ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasFile ? const Color(0xFF16A34A) : const Color(0xFFD1D5DB),
            width: hasFile ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              hasFile ? Icons.task_alt_rounded : Icons.cloud_upload_outlined,
              color: const Color(0xFF16A34A),
              size: 32,
            ),
            const SizedBox(height: 6),
            Text(
              hasFile ? 'File Attached' : label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hasFile ? filePath.split('/').last : sublabel,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
            if (hasFile) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 14,
                  color: Colors.red,
                ),
                label: const Text(
                  'Remove File',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Card Layout Container
  Widget _buildCardContainer({
    required IconData icon,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF15803D), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, {bool isRequired = true}) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF374151),
        ),
        children: [
          TextSpan(text: label),
          if (isRequired)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    String? hintText,
    IconData? prefixIcon,
    IconData? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: const Color(0xFF16A34A), size: 20)
          : null,
      suffixIcon: suffixIcon != null
          ? Icon(suffixIcon, color: const Color(0xFF6B7280), size: 20)
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFD9027), width: 1.8),
      ),
    );
  }

  // Manual Address Modal Dialog
  void _showManualAddressModal() {
    final controller = TextEditingController(text: _storeAddress);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter Store Address Manually',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                maxLines: 3,
                decoration: _buildInputDecoration(
                  hintText:
                      'Building, Shop No., Street, Landmark, City, Pincode',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      setState(() => _storeAddress = controller.text.trim());
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFD9027),
                    foregroundColor: const Color(0xFF1F2937),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save Address'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Bottom Navigation Buttons
  Widget _buildBottomBar() {
    final isLastStep = _currentStep == 3;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _currentStep == 0 ? 'Cancel' : 'Back',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : (isLastStep ? _submitRegistration : _nextStep),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFD9027),
                  foregroundColor: const Color(0xFF1F2937),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF1F2937),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isLastStep
                                ? 'Submit Application'
                                : (_currentStep == 1 ? 'Continue' : 'Next'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
