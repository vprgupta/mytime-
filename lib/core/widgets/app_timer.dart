import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class AppTimer extends StatelessWidget {
  final Duration remainingTime;
  final Duration totalTime;
  final bool isRunning;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onReset;

  const AppTimer({
    super.key,
    required this.remainingTime,
    required this.totalTime,
    required this.isRunning,
    this.onStart,
    this.onPause,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalTime.inSeconds == 0
        ? 0.0
        : 1 - (remainingTime.inSeconds / totalTime.inSeconds);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularPercentIndicator(
          radius: 120,
          lineWidth: 12,
          percent: progress.clamp(0.0, 1.0),
          center: Text(
            _formatTime(remainingTime),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          progressColor: Theme.of(context).primaryColor,
          backgroundColor: Colors.grey[300]!,
          circularStrokeCap: CircularStrokeCap.round,
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (onStart != null && onPause != null)
              ElevatedButton(
                onPressed: isRunning ? onPause : onStart,
                child: Text(isRunning ? 'Pause' : 'Start'),
              ),
            if (onStart != null && onPause != null && onReset != null)
              const SizedBox(width: 20),
            if (onReset != null)
              ElevatedButton(
                onPressed: onReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Reset'),
              ),
          ],
        ),
      ],
    );
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}