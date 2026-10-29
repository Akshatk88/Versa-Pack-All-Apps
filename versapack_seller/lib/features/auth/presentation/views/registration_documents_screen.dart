import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';
import 'package:quick_commerce_seller/core/widgets/app_toast.dart';
import 'package:quick_commerce_seller/features/auth/data/registration_api.dart';
import 'package:quick_commerce_seller/features/auth/presentation/controllers/registration_draft.dart';

/// Step 4: the papers a store is verified against.
///
/// Each document uploads the moment it is picked rather than all of them at
/// submit. A seller on a patchy connection finds out immediately which file
/// failed, instead of losing four of them and being asked to start again.
class RegistrationDocumentsScreen extends ConsumerStatefulWidget {
  const RegistrationDocumentsScreen({super.key});

  @override
  ConsumerState<RegistrationDocumentsScreen> createState() =>
      _RegistrationDocumentsScreenState();
}

class _RegistrationDocumentsScreenState
    extends ConsumerState<RegistrationDocumentsScreen> {
  static const _accent = Color(0xFFFD9027);
  static const _ink = Color(0xFF181C2E);

  final _picker = ImagePicker();

  /// Document → the URL the backend stored it at. Present means uploaded, not
  /// merely chosen.
  final Map<StoreDocument, String> _uploaded = {};

  /// The same documents as local paths. `register` posts the files themselves
  /// rather than URLs, so the earlier upload serves only to fail fast on a file
  /// the server will not take.
  final Map<StoreDocument, String> _paths = {};
  StoreDocument? _busy;
  bool _submitting = false;

  static const _documents = [
    StoreDocument.pan,
    StoreDocument.gst,
    StoreDocument.fssai,
    StoreDocument.storePhoto,
  ];

  Future<void> _pick(StoreDocument doc) async {
    if (_busy != null || _submitting) return;

    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      // The backend re-encodes anyway; sending a 12MP original just makes the
      // seller wait on a phone connection.
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _busy = doc);
    try {
      final url = await ref
          .read(registrationApiProvider)
          .uploadAttachment(filePath: file.path);
      if (!mounted) return;
      setState(() {
        _uploaded[doc] = url;
        _paths[doc] = file.path;
      });
      AppToast.showSuccess(context, '${doc.label} uploaded');
    } catch (e) {
      if (mounted) AppToast.showError(context, '${doc.label} failed to upload');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _submit() async {
    // Store photo is the only optional one; the three legal papers are what the
    // review actually checks.
    final missing = _documents
        .where(
          (d) => d != StoreDocument.storePhoto && !_uploaded.containsKey(d),
        )
        .toList();
    if (missing.isNotEmpty) {
      AppToast.showError(context, 'Please attach your ${missing.first.label}');
      return;
    }

    setState(() => _submitting = true);
    try {
      // This is the call that actually creates the store. Without it the
      // wizard collected everything, uploaded the papers, and registered
      // nothing.
      final draft = ref.read(registrationDraftProvider);
      // Refusing here is better than registering a store the seller can never
      // sign into. Missing details mean the earlier steps were skipped, so send
      // them back rather than creating an unreachable account.
      if (!draft.isComplete) {
        if (mounted) {
          AppToast.showError(
            context,
            'Some details are missing. Please go back and complete the form.',
          );
          setState(() => _submitting = false);
        }
        return;
      }
      await ref
          .read(registrationApiProvider)
          .register(fields: draft.toRegisterFields(), documents: _paths);

      // No session is re-read here: registering does not issue a token, so
      // asking who we are would 401 and report a failure for an application
      // that was in fact accepted. The store signs in again afterwards, and
      // the backend answers that login with its approval state.
      if (mounted) context.go('/registration-success');
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          'Could not submit your application. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surface,
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
        title: Text(
          'Step 4 of 4',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Row(
                children: List.generate(
                  4,
                  (_) => Expanded(
                    child: Container(
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF6D6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.description_rounded,
                            color: Color(0xFFD97706),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Documents',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Upload your papers for verification',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ..._documents.map(_buildDocumentRow),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFF0BF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 20,
                              color: Color(0xFFD97706),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'What happens next?',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'We review your application and your documents. '
                                  'You will see the outcome on your application '
                                  'status screen — usually within 48 hours.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.45,
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    disabledBackgroundColor: _accent.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation(_ink),
                          ),
                        )
                      : const Text(
                          'Submit application',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _ink,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentRow(StoreDocument doc) {
    final done = _uploaded.containsKey(doc);
    final busy = _busy == doc;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: busy ? null : () => _pick(doc),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: done ? const Color(0xFFFFFBEB) : context.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: done ? _accent : context.borderColor,
              width: done ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              if (busy)
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Color(0xFFD97706)),
                  ),
                )
              else if (done)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFFD97706),
                  size: 26,
                )
              else
                Icon(
                  Icons.upload_file_rounded,
                  color: context.textSecondary,
                  size: 26,
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  doc.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
              Text(
                busy ? 'Uploading…' : (done ? 'Attached' : 'Upload'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: done ? const Color(0xFFD97706) : context.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
