import 'package:material_ui/material_ui.dart';

/// Softly fades the left/right edges of a chart so lines don't end abruptly.
class FadeChart extends StatelessWidget {
  const FadeChart({
    super.key,
    required this.child,
    this.fadeFraction = 0.1,
  });

  final Widget child;
  final double fadeFraction;

  @override
  Widget build(BuildContext context) {
    final edge = fadeFraction.clamp(0.04, 0.2);
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Color(0x00FFFFFF),
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: [0, edge, 1 - edge, 1],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}
