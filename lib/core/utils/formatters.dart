import 'package:intl/intl.dart';

class DateFormatters {
  static final DateFormat shortDate = DateFormat('dd/MM/yyyy');
  static final DateFormat timeOnly = DateFormat('HH:mm');
  static final DateFormat dateTime = DateFormat('dd/MM/yyyy HH:mm');

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}