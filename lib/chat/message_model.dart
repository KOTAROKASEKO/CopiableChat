// lib/models/message_model.dart
  // For potential conversion, not direct storage type

// Defines the field names for the SQLite table to avoid typos
class MessageFields {
  static final List<String> values = [
    id, messageId, chatRoomId, whoSent, whoReceived, isOutgoing, messageText,
    messageType, operation, status, timestamp, editedAt, localPath, remoteUrl,
    thumbnailPath, replyToMessageId
  ];

  static const String id = '_id'; // SQLite convention for primary key (local DB id)
  static const String messageId = 'messageId'; // Unique ID for the message (e.g., Firestore Document ID)
  static const String chatRoomId = 'chatRoomId';
  static const String whoSent = 'whoSent';
  static const String whoReceived = 'whoReceived';
  static const String isOutgoing = 'isOutgoing'; // 1 if sent by current user, 0 if received
  static const String messageText = 'messageText';
  static const String messageType = 'messageType'; // 'text', 'image', 'video'
  static const String operation = 'operation';   // 'normal', 'deleted', 'edited'
  static const String status = 'status';         // 'sending', 'sent', 'delivered', 'read', 'failed'
  static const String timestamp = 'timestamp';   // Store as INTEGER (millisecondsSinceEpoch)
  static const String editedAt = 'editedAt';     // Store as INTEGER (millisecondsSinceEpoch)
  static const String localPath = 'localPath';   // Local path for media files
  static const String remoteUrl = 'remoteUrl';   // Remote URL for media files
  static const String thumbnailPath = 'thumbnailPath';
  static const String replyToMessageId = 'replyToMessageId'; // local _id of the message being replied to
}

class MessageModel {
  final int? id; // Local SQLite ID, auto-incremented
  final String messageId; // Server-generated unique ID (e.g., Firestore doc ID)
  final String chatRoomId;
  final String whoSent;
  final String whoReceived; // Important for routing messages to the correct recipient on server
  final bool isOutgoing;
  final String? messageText;
  final String messageType;
  final String operation;
  final String status;
  final DateTime timestamp;
  final DateTime? editedAt;
  final String? localPath;
  final String? remoteUrl;
  final String? thumbnailPath;
  final int? replyToMessageId; // Refers to local SQLite 'id'

  const MessageModel({
    this.id,
    required this.messageId,
    required this.chatRoomId,
    required this.whoSent,
    required this.whoReceived,
    required this.isOutgoing,
    this.messageText,
    required this.messageType,
    this.operation = 'normal',
    this.status = 'sending', // Default when a new message is created by user
    required this.timestamp,
    this.editedAt,
    this.localPath,
    this.remoteUrl,
    this.thumbnailPath,
    this.replyToMessageId,
  });

  MessageModel copyWith({
    int? id,
    String? messageId,
    String? chatRoomId,
    String? whoSent,
    String? whoReceived,
    bool? isOutgoing,
    String? messageText,
    String? messageType,
    String? operation,
    String? status,
    DateTime? timestamp,
    DateTime? editedAt,
    String? localPath,
    String? remoteUrl,
    String? thumbnailPath,
    int? replyToMessageId,
  }) =>
      MessageModel(
        id: id ?? this.id,
        messageId: messageId ?? this.messageId,
        chatRoomId: chatRoomId ?? this.chatRoomId,
        whoSent: whoSent ?? this.whoSent,
        whoReceived: whoReceived ?? this.whoReceived,
        isOutgoing: isOutgoing ?? this.isOutgoing,
        messageText: messageText ?? this.messageText,
        messageType: messageType ?? this.messageType,
        operation: operation ?? this.operation,
        status: status ?? this.status,
        timestamp: timestamp ?? this.timestamp,
        editedAt: editedAt ?? this.editedAt,
        localPath: localPath ?? this.localPath,
        remoteUrl: remoteUrl ?? this.remoteUrl,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      );

  // For converting a map from SQLite to a MessageModel object
  static MessageModel fromJson(Map<String, Object?> json) => MessageModel(
        id: json[MessageFields.id] as int?,
        messageId: json[MessageFields.messageId] as String,
        chatRoomId: json[MessageFields.chatRoomId] as String,
        whoSent: json[MessageFields.whoSent] as String,
        whoReceived: json[MessageFields.whoReceived] as String,
        isOutgoing: json[MessageFields.isOutgoing] == 1,
        messageText: json[MessageFields.messageText] as String?,
        messageType: json[MessageFields.messageType] as String,
        operation: json[MessageFields.operation] as String? ?? 'normal',
        status: json[MessageFields.status] as String? ?? 'sent', // Default from DB could be 'sent'
        timestamp: DateTime.fromMillisecondsSinceEpoch(json[MessageFields.timestamp] as int),
        editedAt: json[MessageFields.editedAt] == null ? null : DateTime.fromMillisecondsSinceEpoch(json[MessageFields.editedAt] as int),
        localPath: json[MessageFields.localPath] as String?,
        remoteUrl: json[MessageFields.remoteUrl] as String?,
        thumbnailPath: json[MessageFields.thumbnailPath] as String?,
        replyToMessageId: json[MessageFields.replyToMessageId] as int?,
      );

  // For converting a MessageModel object to a map for SQLite
  Map<String, Object?> toJson() => {
        MessageFields.id: id, // SQLite handles auto-increment, so this might be null on insert
        MessageFields.messageId: messageId,
        MessageFields.chatRoomId: chatRoomId,
        MessageFields.whoSent: whoSent,
        MessageFields.whoReceived: whoReceived,
        MessageFields.isOutgoing: isOutgoing ? 1 : 0,
        MessageFields.messageText: messageText,
        MessageFields.messageType: messageType,
        MessageFields.operation: operation,
        MessageFields.status: status,
        MessageFields.timestamp: timestamp.millisecondsSinceEpoch,
        MessageFields.editedAt: editedAt?.millisecondsSinceEpoch,
        MessageFields.localPath: localPath,
        MessageFields.remoteUrl: remoteUrl,
        MessageFields.thumbnailPath: thumbnailPath,
        MessageFields.replyToMessageId: replyToMessageId,
      };

  static const String tableName = 'Messages'; // Table name for SQLite
}