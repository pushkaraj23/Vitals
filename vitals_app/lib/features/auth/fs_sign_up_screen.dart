import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/ink_app_bar.dart';
import '../../core/widgets/widgets.dart';
import '../../data/auth_service.dart';
import '../onboarding/onboarding_parts.dart';

final _authServiceProvider2 = Provider<AuthService>((ref) => AuthService());

class FsSignUpScreen extends ConsumerStatefulWidget {
  const FsSignUpScreen({super.key});

  @override
  ConsumerState<FsSignUpScreen> createState() => _FsSignUpScreenState();
}

class _FsSignUpScreenState extends ConsumerState<FsSignUpScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please fill in all required fields.');
      return;
    }
    if (pass.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final svc = ref.read(_authServiceProvider2);
      final user = await svc.createAccount(email, pass);
      await svc.createUserDoc(
        user.uid,
        email,
        name: name.isNotEmpty ? name : null,
      );
      if (mounted) context.go('/onboard/consent');
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: InkAppBar(
        title: 'Create account',
        subtitle: 'Start your baseline',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/sign-in'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SoftSurface(
                color: AppColors.skyCard,
                radius: 28,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Join VitalWatch',
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create an account to start building your personal health baseline from wearable patterns.',
                      style: AppText.bodyMuted.copyWith(fontSize: 15),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SoftSurface(
                color: AppColors.surface,
                radius: 28,
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LabeledField(
                      label: 'Full name (optional)',
                      controller: _nameCtrl,
                      hint: 'Your name',
                      prefixIcon: Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    LabeledField(
                      label: 'Email address',
                      controller: _emailCtrl,
                      hint: 'you@example.com',
                      prefixIcon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    Text('Password', style: AppText.label),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!_loading) _createAccount();
                      },
                      style: AppText.body,
                      decoration: InputDecoration(
                        hintText: 'At least 8 characters',
                        errorText: _error,
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.muted,
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    PillButton(
                      label: _loading ? 'Creating account…' : 'Create account',
                      icon: Icons.arrow_forward_rounded,
                      loading: _loading,
                      onPressed: _loading ? null : _createAccount,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/sign-in'),
                        child: Text(
                          'Already have an account? Sign in',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'VitalWatch provides wellness insights, not medical diagnoses.',
                  textAlign: TextAlign.center,
                  style: AppText.caption,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
