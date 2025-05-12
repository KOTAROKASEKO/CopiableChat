// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_thread.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatThreadAdapter extends TypeAdapter<ChatThread> {
  @override
  final int typeId = 0;

  @override
  ChatThread read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatThread(
      whoSent: fields[0] as String,
      whoReceived: fields[1] as String,
      lastMessage: fields[2] as String,
      timeStamp: fields[3] as Timestamp,
      messageType: fields[4] as String,
      lastMessageId: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ChatThread obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.whoSent)
      ..writeByte(1)
      ..write(obj.whoReceived)
      ..writeByte(2)
      ..write(obj.lastMessage)
      ..writeByte(3)
      ..write(obj.timeStamp)
      ..writeByte(4)
      ..write(obj.messageType)
      ..writeByte(5)
      ..write(obj.lastMessageId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatThreadAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
