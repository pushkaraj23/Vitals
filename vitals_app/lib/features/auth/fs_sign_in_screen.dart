import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../data/auth_service.dart';
import '../onboarding/onboarding_parts.dart';

final _authServiceProvider = Provider<AuthService>((ref) => AuthService());

class FsSignInScreen extends ConsumerStatefulWidget {
  const FsSignInScreen({super.key});

  @override
  ConsumerState<FsSignInScreen> createState() => _FsSignInScreenState();
}

class _FsSignInScreenState extends ConsumerState<FsSignInScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(_authServiceProvider);
      await svc.signInWithEmail(email, pass);
      if (mounted) context.go('/home');
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SoftSurface(
                color: AppColors.lavenderCard,
                radius: 32,
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LogoTile(size: 64),
                    const SizedBox(height: 20),
                    Text(
                      'VitalWatch',
                      style: GoogleFonts.manrope(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Welcome back — sign in to your personal wellness baseline.',
                      style: AppText.bodyMuted.copyWith(fontSize: 15),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SoftSurface(
                color: AppColors.surface,
                radius: 28,
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sign in',
                      style: AppText.cardTitle.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 16),
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
                        if (!_loading) _signIn();
                      },
                      style: AppText.body,
                      decoration: InputDecoration(
                        hintText: '••••••••',
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
                      label: _loading ? 'Signing in…' : 'Sign in',
                      icon: Icons.arrow_forward_rounded,
                      loading: _loading,
                      onPressed: _loading ? null : _signIn,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/sign-up'),
                        child: Text(
                          'Create a new account',
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
              const SizedBox(height: 16),
              const _DemoCard(),
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

class _DemoCard extends ConsumerWidget {
  const _DemoCard();

  Future<void> _enterDemo(
    BuildContext context,
    WidgetRef ref,
    String email,
  ) async {
    final svc = ref.read(_authServiceProvider);
    try {
      await svc.signInWithEmail(email, 'Demo@12345');
      if (context.mounted) context.go('/home');
    } catch (_) {
      if (context.mounted) {
        showSnack(context, 'Could not load demo. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SoftSurface(
      color: AppColors.creamCard,
      radius: 28,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'DEMO MODE',
              style: AppText.caption.copyWith(
                color: AppColors.surface,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Just exploring?', style: AppText.cardTitle.copyWith(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            'Try demo accounts with synthetic data. No real data is stored.',
            style: AppText.bodyMuted,
          ),
          const SizedBox(height: 14),
          SoftSurface(
            color: AppColors.mintCard,
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            onTap: () =>
                _enterDemo(context, ref, 'healthy@demo.vitalwatch.app'),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.flagGreen,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Healthy demo',
                        style: AppText.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text('Stable patterns', style: AppText.caption),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SoftSurface(
            color: AppColors.peachCard,
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            onTap: () =>
                _enterDemo(context, ref, 'concerning@demo.vitalwatch.app'),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.flagAmber,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Concerning demo',
                        style: AppText.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text('Flags & drifts to explore', style: AppText.caption),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
