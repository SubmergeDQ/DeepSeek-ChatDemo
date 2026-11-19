import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 随麦克风音量起伏的录音波形。
class VoiceWave extends StatefulWidget {
  const VoiceWave({
    super.key,
    required this.level,
    this.color = Colors.white,
    this.bars = 44,
    this.height = 64,
  });

  final ValueListenable<double> level;
  final Color color;
  final int bars;
  final double height;

  @override
  State<VoiceWave> createState() => _VoiceWaveState();
}

class _VoiceWaveState extends State<VoiceWave> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WavePainter(
          level: widget.level,
          animation: _controller,
          color: widget.color,
          bars: widget.bars,
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.level,
    required this.animation,
    required this.color,
    required this.bars,
  }) : super(repaint: Listenable.merge([level, animation]));

  final ValueListenable<double> level;
  final Animation<double> animation;
  final Color color;
  final int bars;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final paint = Paint()
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final gap = size.width / bars;
    final t = animation.value * math.pi * 2;
    final amp = level.value.clamp(0.0, 1.0);
    for (var i = 0; i < bars; i++) {
      final phase = i * 0.68;
      final wobble = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(t * 1.6 + phase));
      final texture = 0.55 + 0.45 * (0.5 + 0.5 * math.sin(phase * 2.1 + t * 0.8));
      final strength = (0.1 + amp * 0.9) * wobble * texture;
      final height = 3.0 + strength * (size.height - 6);
      final x = gap * i + gap / 2;
      paint.color = color.withValues(alpha: 0.45 + 0.55 * strength);
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.bars != bars || oldDelegate.level != level;
}
