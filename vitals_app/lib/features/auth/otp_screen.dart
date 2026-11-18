import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/circular_icon_button.dart';
import '../../core/widgets/pill_button.dart';
import '../../providers/session_provider.dart';
import '../onboarding/onboarding_parts.dart';

/// 6-digit one-time-code entry. Demo build: any 6 digits are accepted.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, this.destination});

  /// Phone/email the code was "sent" to (shown for context).
  final String? destination;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _length = 6;
  static const _resendSeconds = 30;

  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _remaining = _resendSeconds;
  bool _verifying = false;

  bool get _complete => _controller.text.length == _length;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _controller.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _remaining = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remaining <= 1) {
        t.cancel();
      }
      setState(() => _remaining = _remaining - 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_complete || _verifying) return;
    setState(() => _verifying = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    ref.read(sessionProvider.notifier).signIn();
    context.go('/consent');
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/sign-in');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dest = widget.destination;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(kScreenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircularIconButton(
                icon: Icons.arrow_back_rounded,
                semanticLabel: 'Back',
                background: AppColors.surface,
                onPressed: _back,
              ),
              const SizedBox(height: 28),
              Text('Enter your code', style: AppText.screenTitle),
              const SizedBox(height: 8),
              Text(
                dest == null || dest.isEmpty
                    ? 'We sent a 6-digit code to you.'
                    : 'We sent a 6-digit code to $dest.',
                style: AppText.bodyMuted.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 28),
              _CodeBoxes(
                controller: _controller,
                focus: _focus,
                length: _length,
              ),
              const SizedBox(height: 14),
              Text(
                'Demo build: any 6-digit code works.',
                style: AppText.caption,
              ),
              const SizedBox(height: 24),
              PillButton(
                label: 'Verify',
                icon: Icons.verified_outlined,
                loading: _verifying,
                onPressed: _complete ? _verify : null,
              ),
              const SizedBox(height: 12),
              Center(
                child: _remaining > 0
                    ? Text(
                        'Resend code in 0:${_remaining.toString().padLeft(2, '0')}',
                        style: AppText.caption,
                      )
                    : PillButton(
                        label: 'Resend code',
                        variant: PillButtonVariant.ghost,
                        expanded: false,
                        height: 44,
                        onPressed: () {
                          _controller.clear();
                          _startTimer();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('New code sent')),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({
    required this.controller,
    required this.focus,
    required this.length,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final int length;

  @override
  Widget build(BuildContext context) {
    final text = controller.text;
    final active = focus.hasFocus ? text.length.clamp(0, length - 1) : -1;
    return SizedBox(
      height: 60,
      child: Stack(
        children: [
          Row(
            children: [
              for (var i = 0; i < length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: i == active ? AppColors.ink : AppColors.line,
                        width: i == active ? 1.6 : 1,
                      ),
                    ),
                    child: Text(
                      i < text.length ? text[i] : '',
                      style: AppText.sectionTitle,
                    ),
                  ),
                ),
              ],
            ],
          ),
          // Invisible field on top captures taps and keyboard input.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focus,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: length,
                showCursor: false,
                enableInteractiveSelection: false,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(counterText: ''),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
