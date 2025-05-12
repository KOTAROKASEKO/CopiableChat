import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp type

part 'chat_thread.g.dart'; // Will be generated

@HiveType(typeId: 0) // Unique typeId for ChatThread
class ChatThread extends HiveObject {
  @HiveField(0)
  final String whoSent;

  @HiveField(1)
  final String whoReceived;

  @HiveField(2)
  final String lastMessage;

  @HiveField(3)
  final Timestamp timeStamp; // Using Firestore Timestamp

  @HiveField(4)
  final String messageType;

  @HiveField(5)
  final String lastMessageId;

  // Hive key (Firestore document ID) will be managed by HiveObject or explicitly set
  // String firestoreDocumentId;

  ChatThread({
    required this.whoSent,
    required this.whoReceived,
    required this.lastMessage,
    required this.timeStamp,
    required this.messageType,
    required this.lastMessageId,
    // this.firestoreDocumentId,
  });

  // Optional: copyWith method for easier updates if needed elsewhere
  ChatThread copyWith({
    String? whoSent,
    String? whoReceived,
    String? lastMessage,
    Timestamp? timeStamp,
    String? messageType,
    String? lastMessageId,
    // String? firestoreDocumentId,
  }) {
    return ChatThread(
      whoSent: whoSent ?? this.whoSent,
      whoReceived: whoReceived ?? this.whoReceived,
      lastMessage: lastMessage ?? this.lastMessage,
      timeStamp: timeStamp ?? this.timeStamp,
      messageType: messageType ?? this.messageType,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      // firestoreDocumentId: firestoreDocumentId ?? this.firestoreDocumentId,
    );
  }
}