import 'dart:async';
import 'package:chatapp/chat/threadModel/chat_thread.dart';
import 'package:chatapp/user_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart'; // Your ChatThread model

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Box<ChatThread> _chatThreadsBox;
  StreamSubscription? _chatThreadsSubscription;

  // In a real app, get this from your auth provider

  ChatService() {
    _chatThreadsBox = Hive.box<ChatThread>('chatThreadsBox'); // Ensure box is opened before use
  }

  void listenToChatThreads() {
    print('ChatService: Starting to listen for chat threads for user $CurrentUser.currentUserUid');
    _chatThreadsSubscription?.cancel(); // Cancel any existing subscription

    _chatThreadsSubscription = _firestore
        .collection('chats')
        .where(Filter.or(
          Filter('whoSent', isEqualTo: CurrentUser.currentUserUid),
          Filter('whoReceived', isEqualTo: CurrentUser.currentUserUid),
        ))
        // Order by timestamp if you want Firestore to initially sort them.
        // Hive itself won't maintain this order strictly in box.values unless you sort it later.
        // .orderBy('timeStamp', descending: true)
        .snapshots()
        .listen((querySnapshot) {
      print('ChatService: Received ${querySnapshot.docChanges.length} changes from Firestore.');
      for (var docChange in querySnapshot.docChanges) {
        final docId = docChange.doc.id;
        final data = docChange.doc.data();

        if (data == null) {
          if (docChange.type == DocumentChangeType.removed) {
            _chatThreadsBox.delete(docId);
            print('ChatService: Deleted thread $docId from Hive.');
          }
          continue;
        }

        try {
          final chatThread = ChatThread(
            whoSent: data['whoSent'] as String,
            whoReceived: data['whoReceived'] as String,
            lastMessage: data['lastMessage'] as String,
            timeStamp: data['timeStamp'] as Timestamp,
            messageType: data['messageType'] as String,
            lastMessageId: data['lastMessageId'] as String,
          );

          if (docChange.type == DocumentChangeType.added || docChange.type == DocumentChangeType.modified) {
            _chatThreadsBox.put(docId, chatThread);
            print('ChatService: Added/Modified thread $docId in Hive.');
          } else if (docChange.type == DocumentChangeType.removed) {
            _chatThreadsBox.delete(docId);
            print('ChatService: Deleted thread $docId from Hive.');
          }
        } catch (e) {
          print('ChatService: Error processing document $docId: $e');
          print('ChatService: Faulty data: $data');
        }
      }
    }, onError: (error) {
      print('ChatService: Error listening to chat threads: $error');
    });
  }

  void dispose() {
    print('ChatService: Disposing chat service and canceling subscription.');
    _chatThreadsSubscription?.cancel();
  }
}