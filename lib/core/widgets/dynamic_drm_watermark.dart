import 'dart:async';
import 'package:flutter/material.dart';

/// Floating, dynamic DRM watermark that periodically translates position across the video canvas.
/// Prevents external camera piracy by making it impossible to crop out student identity.
class DynamicDrmWatermark extends StatefulWidget {
  final String text;
  final Duration interval;

  const DynamicDrmWatermark({
    super.key,
    required this.text,
    this.interval = const Duration(seconds: 9),
  });

  @override
  State<DynamicDrmWatermark> createState() => _DynamicDrmWatermarkState();
}

class _DynamicDrmWatermarkState extends State<DynamicDrmWatermark> {
  Timer? _timer;
  int _currentPositionIndex = 0;

  static const List<Alignment> _positions = [
    Alignment(-0.85, -0.80), // Top Left
    Alignment(0.85, -0.75), // Top Right
    Alignment(0.70, 0.15), // Center Right
    Alignment(-0.70, 0.20), // Center Left
    Alignment(0.80, 0.70), // Bottom Right
    Alignment(-0.80, 0.65), // Bottom Left
  ];

  @override
  void initState() {
    super.initState();
    _startWatermarkCycle();
  }

  void _startWatermarkCycle() {
    _timer = Timer.periodic(widget.interval, (_) {
      if (mounted) {
        setState(() {
          _currentPositionIndex =
              (_currentPositionIndex + 1) % _positions.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeAlignment = _positions[_currentPositionIndex];

    return IgnorePointer(
      child: AnimatedAlign(
        alignment: activeAlignment,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 11,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  widget.text,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
