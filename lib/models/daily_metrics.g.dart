// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_metrics.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyMetricsAdapter extends TypeAdapter<DailyMetrics> {
  @override
  final int typeId = 0;

  @override
  DailyMetrics read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyMetrics(
      dateKey: fields[0] as String,
      totalCalories: fields[1] as int,
      waterMl: fields[2] as int,
      weight: fields[3] as double?,
      fastingStartEpoch: fields[4] as int?,
      fastingDurationMinutes: fields[5] as int,
      calorieEntries: (fields[6] as List?)?.cast<int>(),
      steps: fields[7] == null ? 0 : fields[7] as int,
      caloriesBurned: fields[8] == null ? 0 : fields[8] as int,
      activities: fields[9] == null ? [] : (fields[9] as List?)?.cast<String>(),
      sleepMinutes: fields[10] == null ? 0 : fields[10] as int,
      sleepBedtime: fields[11] == null ? '' : fields[11] as String,
      sleepWakeTime: fields[12] == null ? '' : fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DailyMetrics obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.dateKey)
      ..writeByte(1)
      ..write(obj.totalCalories)
      ..writeByte(2)
      ..write(obj.waterMl)
      ..writeByte(3)
      ..write(obj.weight)
      ..writeByte(4)
      ..write(obj.fastingStartEpoch)
      ..writeByte(5)
      ..write(obj.fastingDurationMinutes)
      ..writeByte(6)
      ..write(obj.calorieEntries)
      ..writeByte(7)
      ..write(obj.steps)
      ..writeByte(8)
      ..write(obj.caloriesBurned)
      ..writeByte(9)
      ..write(obj.activities)
      ..writeByte(10)
      ..write(obj.sleepMinutes)
      ..writeByte(11)
      ..write(obj.sleepBedtime)
      ..writeByte(12)
      ..write(obj.sleepWakeTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyMetricsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
