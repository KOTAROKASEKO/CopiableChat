// lib/helpers/database_helper.dart
import 'package:chatapp/chat/message_model.dart'; // MessageModel と MessageFields が定義されていると仮定
import 'package:chatapp/chat/threadModel/chat_thread.dart';
import 'package:chatapp/user_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('chat_app_messages.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);
    print("Database path: $path");
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idAutoType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT';
    const textNotNullType = 'TEXT NOT NULL';
    const integerType = 'INTEGER';
    const integerNotNullType = 'INTEGER NOT NULL';

    // MessageModel.tableName と MessageFields.values が正しく定義されていることを確認してください
    await db.execute('''
CREATE TABLE ${MessageModel.tableName} ( 
  ${MessageFields.id} $idAutoType, 
  ${MessageFields.messageId} $textType UNIQUE,
  ${MessageFields.chatRoomId} $textNotNullType,
  ${MessageFields.whoSent} $textNotNullType,
  ${MessageFields.whoReceived} $textNotNullType,
  ${MessageFields.isOutgoing} $integerNotNullType,
  ${MessageFields.messageText} $textType,
  ${MessageFields.messageType} $textNotNullType,
  ${MessageFields.operation} $textNotNullType,
  ${MessageFields.status} $textNotNullType,
  ${MessageFields.timestamp} $integerNotNullType,
  ${MessageFields.editedAt} $integerType,
  ${MessageFields.localPath} $textType,
  ${MessageFields.remoteUrl} $textType,
  ${MessageFields.thumbnailPath} $textType,
  ${MessageFields.replyToMessageId} $integerType
  )
''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_chatroomid_timestamp ON ${MessageModel.tableName} (${MessageFields.chatRoomId}, ${MessageFields.timestamp})');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_messageid ON ${MessageModel.tableName} (${MessageFields.messageId}) WHERE ${MessageFields.messageId} IS NOT NULL');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_status ON ${MessageModel.tableName} (${MessageFields.status})');
    print("Message table created with indexes.");
  }

  Future<MessageModel> createMessage(MessageModel message) async {
    final db = await instance.database;
    final Map<String, Object?> json = message.toJson();
    if (message.id == null) {
      json.remove(MessageFields.id);
    }
    final id = await db.insert(MessageModel.tableName, json);
    print('Message inserted with local id: $id, server id: ${message.messageId}');
    return message.copyWith(id: id);
  }

  Future<MessageModel?> getMessageByLocalId(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      MessageModel.tableName,
      columns: MessageFields.values,
      where: '${MessageFields.id} = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return MessageModel.fromJson(maps.first);
    } else {
      return null;
    }
  }

  Future<MessageModel?> getMessageByServerId(String messageId) async {
    final db = await instance.database;
    final maps = await db.query(
      MessageModel.tableName,
      columns: MessageFields.values,
      where: '${MessageFields.messageId} = ?',
      whereArgs: [messageId],
    );
    if (maps.isNotEmpty) {
      return MessageModel.fromJson(maps.first);
    } else {
      return null;
    }
  }

  Future<List<MessageModel>> getMessagesForChatRoom(String chatRoomId, {int limit = 20, int? offset}) async {
    final db = await instance.database;
    final orderBy = '${MessageFields.timestamp} ASC'; // チャットは通常、古い順に取得し、UIで逆順リスト表示することが多い

    List<Map<String, Object?>> result;
    // offset を使用する場合、SQLiteでは古いメッセージから順に取得し、
    // UI側で逆順にして表示（新しいメッセージが下に来るように）するのが一般的です。
    // もし新しいメッセージから取得したい場合は orderBy を DESC にし、UIのロジックも合わせる必要があります。
    if (offset != null && offset > 0) {
        result = await db.query(
        MessageModel.tableName,
        where: '${MessageFields.chatRoomId} = ?',
        whereArgs: [chatRoomId],
        orderBy: orderBy,
        limit: limit,
        // SQLite の offset は、limit と併用してページネーションに使います。
        // 例えば、limit=20, offset=0 なら最初の20件。offset=20なら次の20件。
        offset: offset,
      );
    } else {
        result = await db.query(
        MessageModel.tableName,
        where: '${MessageFields.chatRoomId} = ?',
        whereArgs: [chatRoomId],
        orderBy: orderBy,
        limit: limit,
      );
    }
    print("Fetched ${result.length} messages for $chatRoomId from SQLite (ASC) offset $offset");
    return result.map((json) => MessageModel.fromJson(json)).toList();
  }

  Future<int> updateMessage(MessageModel message) async {
    final db = await instance.database;
    return db.update(
      MessageModel.tableName,
      message.toJson(),
      where: '${MessageFields.id} = ?',
      whereArgs: [message.id],
    );
  }

  Future<int> updateMessageByServerId(MessageModel message) async {
    final db = await instance.database;
    final data = message.toJson();
    data.remove(MessageFields.id); // ローカルIDは更新条件に使わないので除去
    return db.update(
      MessageModel.tableName,
      data,
      where: '${MessageFields.messageId} = ?',
      whereArgs: [message.messageId],
    );
  }
  
  /// Firestoreなどからの指示で、メッセージの状態を「システムにより削除済み」に更新します。
  /// これには「全員に対して削除」された場合などが該当します。
  /// messageText を "This message was deleted" に更新し、関連情報をクリアします。
  Future<int> updateMessageToSystemDeletedState(String messageServerId, {required String newStatus}) async {
    final db = await instance.database;
    print("Updating message $messageServerId to system deleted state (status: $newStatus) locally.");
    return await db.update(
      MessageModel.tableName,
      {
        MessageFields.status: newStatus, // Firestoreから受け取った新しいステータス
        MessageFields.messageText: "This message was deleted", // 固定テキストに変更
        MessageFields.messageType: 'text', // 内容がテキストに変わるためタイプも変更
        MessageFields.localPath: null,     // ローカルメディアパスをクリア
        MessageFields.remoteUrl: null,     // リモートURLをクリア
        MessageFields.thumbnailPath: null, // サムネイルパスをクリア
        MessageFields.replyToMessageId: null, // 必要に応じて返信情報もクリア
        MessageFields.editedAt: null,      // 編集情報をクリア
        // operation フィールドも適切な値 (例: 'system_action_acknowledged') に更新することを検討
        MessageFields.operation: 'system_deleted_ack',
      },
      where: '${MessageFields.messageId} = ?',
      whereArgs: [messageServerId],
    );
  }

  /// 自分に対してのみメッセージを削除（ローカルでの非表示化）する場合。
  /// サーバーID (messageId) を使って対象を特定します。
  Future<int> markMessageAsDeletedForMeByServerId(String messageServerId) async {
    final db = await instance.database;
    print("Marking message $messageServerId as deleted for me locally.");
    return await db.update(
      MessageModel.tableName,
      {
        // 'deleted_for_me' のような専用のステータスや操作タイプを設定
        MessageFields.status: 'deleted_for_me', // または MessageFields.operation: 'deleted_for_me',
        MessageFields.messageText: null,
        MessageFields.localPath: null,
        MessageFields.remoteUrl: null,
        MessageFields.thumbnailPath: null,
      },
      where: '${MessageFields.messageId} = ?',
      whereArgs: [messageServerId],
    );
  }

  Future<int> deleteMessageByLocalId(int id) async {
    try {
      print('Deleting message with local ID: $id');
      final db = await instance.database;
      return await db.delete(
        MessageModel.tableName,
        where: '${MessageFields.id} = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print("Error deleting message with local ID $id: $e");
      return 0;
    }
  }

  // サーバー側のメッセージを永続的に削除するのではなく、ローカルで「削除済み」としてマークする機能
  // こちらは markMessageAsDeletedForMeByServerId に役割が統合されたため、コメントアウトまたは削除を検討
  /*
  Future<int> markMessageAsLocallyDeleted(String messageId) async {
    final db = await instance.database;
    print("Marking message $messageId as deleted locally.");
    return await db.update(
      MessageModel.tableName,
      {
        MessageFields.operation: 'deleted', 
        MessageFields.messageText: null,
        MessageFields.localPath: null,
        MessageFields.remoteUrl: null,
        MessageFields.thumbnailPath: null,
      },
      where: '${MessageFields.messageId} = ?',
      whereArgs: [messageId],
    );
  }
  */

  /// 新規メッセージを保存、または既存メッセージをサーバーIDで更新します。
  /// Firestoreリスナーなどで使用します。
  Future<void> createOrUpdateMessage(MessageModel message) async {
    if (message.messageId == null || message.messageId!.isEmpty) {
      print('Error: messageId is null or empty, cannot create or update.');
      return;
    }
    final existingMessage = await getMessageByServerId(message.messageId!);
    if (existingMessage != null) {
      // 既存メッセージを更新。ローカルIDを保持する。
      // Firestore から来たデータで status が 'deleted_for_everyone' などであれば、
      // こちらではなく updateMessageToSystemDeletedState を呼び出すロジックがリスナー側にある想定。
      // 通常のメッセージ内容の更新（編集など）はこちら。
      if (message.status == 'deleted_for_everyone' || message.status == 'deleted') { // Firestoreのステータス名に合わせてください
         await updateMessageToSystemDeletedState(message.messageId!, newStatus: message.status);
      } else {
         await updateMessageByServerId(message.copyWith(id: existingMessage.id));
      }
      print('Message updated by serverId: ${message.messageId}');
    } else {
      // 新規メッセージとしてローカルに保存
      await createMessage(message);
      print('Message created from server data, serverId: ${message.messageId}');
    }
  }


  Future close() async {
    final db = await instance.database;
    db.close();
    _database = null;
  }

  Future<void> deleteMessageForEveryone(MessageModel message) async {
    final db = await instance.database;
    print("Deleting message $message.messageId for everyone.");

    // Firestore からのメッセージ削除リクエストを受け取った場合、
    var lastMessage = Hive.box<ChatThread>('chatThreadsBox').get(message.chatRoomId);
    
    FirebaseFirestore.instance
        .collection('chats')
        .doc(message.chatRoomId)
        .collection('messages')
        .doc(message.messageId)
        .set({
          'status': 'deleted_for_everyone',
          'text': 'This message was deleted',
        }, SetOptions(merge: true));

        print('should update thread?? ${message.messageId}');
        print('should update thread?? ${ lastMessage?.lastMessageId}');
        if(message.messageId == lastMessage?.lastMessageId) {

          print('Updating last message in chat thread to deleted for everyone');
          FirebaseFirestore.instance
            .collection('chats')
            .doc(message.chatRoomId)
            .set({
              'status': 'deleted_for_everyone',
              'lastMessage': 'This message was deleted',
            }, SetOptions(merge: true));
          
          Hive.box<ChatThread>('chatThreadsBox').put(
            message.chatRoomId,
            ChatThread(
              whoSent: CurrentUser.currentUserUid,
              whoReceived: message.whoReceived,
              lastMessage: 'This message was deleted',
              timeStamp: Timestamp.fromDate(message.timestamp),
              messageType: 'text',
              lastMessageId: message.messageId,
            ),
          );
        }
  }
}