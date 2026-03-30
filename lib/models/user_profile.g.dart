// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 2;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      weightKg: fields[0] as double,
      heightCm: fields[1] as double,
      age: fields[2] as int,
      gender: fields[3] as String,
      calorieGoal: fields[4] as int?,
      waterGoalMl: fields[5] as int?,
      weeklyCalorieGoal: fields[6] == null ? 0 : fields[6] as int?,
      weightGoal: fields[7] == null ? 'maintain' : fields[7] as String,
      dobString: fields[8] == null ? '' : fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.weightKg)
      ..writeByte(1)
      ..write(obj.heightCm)
      ..writeByte(2)
      ..write(obj.age)
      ..writeByte(3)
      ..write(obj.gender)
      ..writeByte(4)
      ..write(obj.calorieGoal)
      ..writeByte(5)
      ..write(obj.waterGoalMl)
      ..writeByte(6)
      ..write(obj.weeklyCalorieGoal)
      ..writeByte(7)
      ..write(obj.weightGoal)
      ..writeByte(8)
      ..write(obj.dobString);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
