import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/circular_icon_button.dart';
import '../../core/widgets/pill_button.dart';
import '../../core/widgets/soft_surface.dart';
import 'onboarding_parts.dart';

const _stepTitles = ['About you', 'Medical history', 'Family history'];
const _stepSubtitles = [
  'A few basics help us set sensible ranges.',
  'Select anything that applies. This stays private.',
  'Family patterns can shape which trends matter most.',
];

const _sexOptions = ['Female', 'Male', 'Other', 'Prefer not to say'];
const _conditions = [
  'Hypertension',
  'Diabetes',
  'Asthma',
  'Thyroid condition',
  'Heart condition',
  'Sleep apnea',
  'None',
];
const _familyConditions = [
  'Heart disease',
  'Diabetes',
  'Stroke',
  'High blood pressure',
  'Cancer',
  'None known',
];

/// 3-step skippable intake. Data is held locally for the demo.
class IntakeScreen extends StatefulWidget {
  const IntakeScreen({super.key});

  @override
  State<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends State<IntakeScreen> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _meds = TextEditingController();
  String? _sex;
  final Set<String> _myConditions = {};
  final Set<String> _family = {};
  int _step = 0;

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _meds.dispose();
    super.dispose();
  }

  bool get _isLast => _step == _stepTitles.length - 1;

  void _done() => context.go('/connect');

  void _next() {
    FocusScope.of(context).unfocus();
    if (_isLast) {
      _done();
    } else {
      setState(() => _step++);
    }
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_step > 0) setState(() => _step--);
  }

  void _toggle(Set<String> set, String value, String noneLabel) {
    setState(() {
      if (set.contains(value)) {
        set.remove(value);
      } else {
        if (value == noneLabel) {
          set.clear();
        } else {
          set.remove(noneLabel);
        }
        set.add(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kScreenPadding,
                12,
                kScreenPadding,
                0,
              ),
              child: Row(
                children: [
                  if (_step > 0)
                    CircularIconButton(
                      icon: Icons.arrow_back_rounded,
                      semanticLabel: 'Previous step',
                      background: AppColors.surface,
                      onPressed: _back,
                    )
                  else
                    const SizedBox(height: 44),
                  const Spacer(),
                  SoftPill(label: 'Skip for now', onPressed: _done),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kScreenPadding,
                20,
                kScreenPadding,
                0,
              ),
              child: _StepHeader(current: _step),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(kScreenPadding),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: _buildStep(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kScreenPadding,
                8,
                kScreenPadding,
                20,
              ),
              child: PillButton(
                label: _isLast ? 'Finish' : 'Next',
                icon: _isLast
                    ? Icons.check_rounded
                    : Icons.arrow_forward_rounded,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_stepTitles[_step], style: AppText.screenTitle),
        const SizedBox(height: 6),
        Text(
          _stepSubtitles[_step],
          style: AppText.bodyMuted.copyWith(fontSize: 15),
        ),
        const SizedBox(height: 20),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        switch (_step) {
          0 => _aboutYou(),
          1 => _medical(),
          _ => _familyHistory(),
        },
      ],
    );
  }

  Widget _aboutYou() {
    return SoftSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabeledField(
            label: 'First name',
            controller: _name,
            hint: 'Asha',
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 16),
          Text('Age', style: AppText.label),
          const SizedBox(height: 8),
          TextField(
            controller: _age,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            style: AppText.body,
            decoration: const InputDecoration(
              hintText: '34',
              prefixIcon: Icon(
                Icons.cake_outlined,
                color: AppColors.muted,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Sex', style: AppText.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _sexOptions)
                SelectPill(
                  label: s,
                  selected: _sex == s,
                  onTap: () => setState(() => _sex = s),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _medical() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoftSurface(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Existing conditions', style: AppText.label),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _conditions)
                    SelectPill(
                      label: c,
                      selected: _myConditions.contains(c),
                      onTap: () => _toggle(_myConditions, c, 'None'),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SoftSurface(
          padding: const EdgeInsets.all(18),
          child: LabeledField(
            label: 'Current medications (optional)',
            controller: _meds,
            hint: 'e.g. Amlodipine 5 mg',
            maxLines: 2,
            prefixIcon: Icons.medication_outlined,
          ),
        ),
      ],
    );
  }

  Widget _familyHistory() {
    return SoftSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Close relatives have had', style: AppText.label),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _familyConditions)
                SelectPill(
                  label: c,
                  selected: _family.contains(c),
                  onTap: () => _toggle(_family, c, 'None known'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < _stepTitles.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= current ? AppColors.ink : AppColors.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Step ${current + 1} of ${_stepTitles.length}',
          style: AppText.caption,
        ),
      ],
    );
  }
}
