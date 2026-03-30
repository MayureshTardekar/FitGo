import 'package:hive/hive.dart';

part 'weight_entry.g.dart';

@HiveType(typeId: 1)
class WeightEntry extends HiveObject {
  @HiveField(0)
  final String dateKey;

  @HiveField(1)
  final double weight;

  WeightEntry({required this.dateKey, required this.weight});
}
