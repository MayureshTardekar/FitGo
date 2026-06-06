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
      proteinGrams: fields[13] == null ? 0 : fields[13] as int,
      carbsGrams: fields[14] == null ? 0 : fields[14] as int,
      fatGrams: fields[15] == null ? 0 : fields[15] as int,
      fiberGrams: fields[16] == null ? 0 : fields[16] as int,
      sugarGrams: fields[17] == null ? 0 : fields[17] as int,
      nutritionEntries: fields[18] == null
          ? []
          : (fields[18] as List?)?.cast<String>(),
      fastingReminderMinutes: fields[19] == null ? 60 : fields[19] as int,
      fastingReminderEnabled: fields[20] == null ? true : fields[20] as bool,
      fastingLastReminderEpoch: fields[21] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, DailyMetrics obj) {
    writer
      ..writeByte(22)
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
      ..write(obj.sleepWakeTime)
      ..writeByte(13)
      ..write(obj.proteinGrams)
      ..writeByte(14)
      ..write(obj.carbsGrams)
      ..writeByte(15)
      ..write(obj.fatGrams)
      ..writeByte(16)
      ..write(obj.fiberGrams)
      ..writeByte(17)
      ..write(obj.sugarGrams)
      ..writeByte(18)
      ..write(obj.nutritionEntries)
      ..writeByte(19)
      ..write(obj.fastingReminderMinutes)
      ..writeByte(20)
      ..write(obj.fastingReminderEnabled)
      ..writeByte(21)
      ..write(obj.fastingLastReminderEpoch);
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
