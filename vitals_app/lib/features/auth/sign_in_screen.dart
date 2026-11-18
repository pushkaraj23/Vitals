import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/pill_button.dart';
import '../../core/widgets/soft_surface.dart';
import '../../providers/session_provider.dart';
import '../onboarding/onboarding_parts.dart';

enum _Method { phone, email }

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _controller = TextEditingController();
  _Method _method = _Method.phone;
  bool _touched = false;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _value => _controller.text.trim();

  bool get _valid {
    if (_method == _Method.phone) {
      return _value.replaceAll(RegExp(r'\D'), '').length >= 10;
    }
    return _emailRe.hasMatch(_value);
  }

  String? get _error {
    if (!_touched || _value.isEmpty || _valid) return null;
    return _method == _Method.phone
        ? 'Enter a 10-digit phone number'
        : 'Enter a valid email address';
  }

  void _setMethod(_Method m) {
    if (m == _method) return;
    setState(() {
      _method = m;
      _controller.clear();
      _touched = false;
    });
  }

  void _continue() {
    setState(() => _touched = true);
    if (!_valid) return;
    FocusScope.of(context).unfocus();
    context.push('/otp', extra: _value);
  }

  void _enterDemo() {
    ref.read(sessionProvider.notifier).enterDemo();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = _method == _Method.phone;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(kScreenPadding),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const LogoTile(size: 56),
              const SizedBox(height: 28),
              Text('Welcome to VitalWatch', style: AppText.screenTitle),
              const SizedBox(height: 8),
              Text(
                "Enter your phone or email and we'll send a one-time code.",
                style: AppText.bodyMuted.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                children: [
                  SelectPill(
                    label: 'Phone',
                    icon: Icons.phone_iphone_rounded,
                    selected: isPhone,
                    onTap: () => _setMethod(_Method.phone),
                  ),
                  SelectPill(
                    label: 'Email',
                    icon: Icons.mail_outline_rounded,
                    selected: !isPhone,
                    onTap: () => _setMethod(_Method.email),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LabeledField(
                key: ValueKey(_method),
                label: isPhone ? 'Phone number' : 'Email address',
                controller: _controller,
                hint: isPhone ? '98765 43210' : 'you@example.com',
                prefixIcon: isPhone
                    ? Icons.phone_iphone_rounded
                    : Icons.alternate_email_rounded,
                keyboardType:
                    isPhone ? TextInputType.phone : TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                errorText: _error,
                onChanged: (_) => setState(() => _touched = true),
              ),
              const SizedBox(height: 20),
              PillButton(
                label: 'Continue',
                icon: Icons.arrow_forward_rounded,
                onPressed: _valid ? _continue : null,
              ),
              const SizedBox(height: 28),
              _DemoCard(onEnter: _enterDemo),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'By continuing you agree to the Terms and Privacy Policy.',
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

class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.onEnter});

  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      color: AppColors.creamCard,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            ],
          ),
          const SizedBox(height: 12),
          Text('Just exploring?', style: AppText.cardTitle),
          const SizedBox(height: 4),
          Text(
            'Skip sign-in and open the app with sample data. Nothing real is '
            'stored or shared.',
            style: AppText.body,
          ),
          const SizedBox(height: 14),
          PillButton(
            label: 'Enter demo mode',
            icon: Icons.play_arrow_rounded,
            variant: PillButtonVariant.secondary,
            onPressed: onEnter,
          ),
        ],
      ),
    );
  }
}