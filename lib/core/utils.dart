String formatDuration(Duration d) {
  final hours = d.inHours.toString().padLeft(2, '0');
  final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String formatDurationShort(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  return '${hours}h ${minutes}m';
}
