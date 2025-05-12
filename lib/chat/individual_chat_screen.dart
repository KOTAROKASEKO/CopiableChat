// lib/screens/individual_chat_screen.dart
import 'dart:async';
import 'dart:io'; // For File type with image_picker
import 'package:chatapp/chat/database_helper.dart';
import 'package:chatapp/chat/message_model.dart';
import 'package:chatapp/chat/threadModel/chat_thread.dart';
import 'package:chatapp/user_data.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class IndividualChatScreen extends StatefulWidget {
  final String chatThreadId;
  final String otherUserUid;
  final String otherUserName;

  const IndividualChatScreen({
    super.key,
    required this.chatThreadId,
    required this.otherUserUid,
    required this.otherUserName,
  });

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  List<dynamic> displayItems = [];

  List<MessageModel> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  MessageModel? _editingMessage;
  StreamSubscription? _firebaseMessagesSubscription;

  // Pagination
  final int _messagesPerPage = 20;
  bool _isLoadingMore = false;
  bool _canLoadMore = true;


  @override
  void initState() {
    super.initState();
    print('thread id is : ${widget.chatThreadId}');
    _loadInitialMessages();
    _listenToFirebaseMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _firebaseMessagesSubscription?.cancel();
    // DatabaseHelper.instance.close(); // Usually not closed here, but on app dispose
    super.dispose();
  }

  Future<void> _loadInitialMessages() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final messages = await DatabaseHelper.instance.getMessagesForChatRoom(
        widget.chatThreadId,
        limit: _messagesPerPage
      );
      if (mounted) {
        setState(() {
          
         _messages = messages;
         displayItems = _buildDisplayListWithDates(_messages);
        _isLoading = false;
        _canLoadMore = messages.length == _messagesPerPage;
        });
        _scrollToBottom(isAnimated: false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("Error loading initial messages from SQLite: $e");
      // Show error SnackBar
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_canLoadMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final olderMessagesFromDb = await DatabaseHelper.instance.getMessagesForChatRoom(
      widget.chatThreadId,
      limit: _messagesPerPage,
      offset: _messages.length // これまでのメッセージ数をオフセットとして渡す
    );
      if (mounted) {
        setState(() {
          
          _messages.insertAll(0, olderMessagesFromDb);
          displayItems = _buildDisplayListWithDates(_messages);
        _isLoadingMore = false;
        _canLoadMore = olderMessagesFromDb.length == _messagesPerPage;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
      print("Error loading more messages from SQLite: $e");
    }
  }


  void _listenToFirebaseMessages() {
    // This listener handles incoming messages from other users and updates for own sent messages
    _firebaseMessagesSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatThreadId)
        .collection('messages')
        .where('timestamp', isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(_messages.isNotEmpty ? _messages.last.timestamp.millisecondsSinceEpoch : DateTime(2000).millisecondsSinceEpoch)) // Listen for newer messages
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) async {
          print("Listening to Firebase messages for ${widget.chatThreadId}");
      if (!mounted) return;
      bool newMessagesAdded = false;
      for (var change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;
        final serverMessageId = change.doc.id;
        final existingLocalMessage = await DatabaseHelper.instance.getMessageByServerId(serverMessageId);
        if (change.type == DocumentChangeType.added) {
          if (existingLocalMessage == null) {
            final newMessage = MessageModel(
              messageId: serverMessageId,
              chatRoomId: widget.chatThreadId,
              whoSent: data['whoSentId'] as String,
              whoReceived: data['whoReceivedId'] as String,
              isOutgoing: (data['whoSentId'] as String) == CurrentUser.currentUserUid,
              messageText: data['text'] as String?,
              messageType: data['messageType'] as String,
              operation: data['operation'] as String? ?? 'normal',
              status: 'sent',
              timestamp: (data['timestamp'] as Timestamp).toDate(),
              editedAt: data['editedAt'] == null ? null : (data['editedAt'] as Timestamp).toDate(),
              remoteUrl: data['remoteUrl'] as String?,
            );

            await DatabaseHelper.instance.createMessage(newMessage);
            newMessagesAdded = true;
            print("New message $serverMessageId from Firestore added to SQLite");
          }
        } else if (change.type == DocumentChangeType.modified) {
          if (existingLocalMessage != null) {
            final updatedMessage = existingLocalMessage.copyWith(
              messageText: data['text'] as String?,
              operation: data['operation'] as String? ?? existingLocalMessage.operation,
              status: data['status'] as String? ?? existingLocalMessage.status,
              editedAt: data['editedAt'] == null ? null : (data['editedAt'] as Timestamp).toDate(),
              remoteUrl: data['remoteUrl'] as String? ?? existingLocalMessage.remoteUrl,
            );
            await DatabaseHelper.instance.updateMessageByServerId(updatedMessage);
            newMessagesAdded = true;
             print("Message $serverMessageId from Firestore MODIFIED in SQLite");
          }
        } else if (change.type == DocumentChangeType.removed) {
           if (existingLocalMessage != null) {
             await DatabaseHelper.instance.deleteMessageByLocalId(existingLocalMessage.id!); // or mark as deleted
             setState(() {
               displayItems = _buildDisplayListWithDates(_messages);
             });
             newMessagesAdded = true; // Force refresh
             print("Message $serverMessageId from Firestore REMOVED from SQLite");
           }
        }
      }
      if (newMessagesAdded && mounted) {
        // Reload messages from SQLite to reflect all changes (adds, updates, deletes)
        // This is a simple way; for more granular updates, you could update the _messages list directly.
        _refreshMessagesFromDb();
      }
    }, onError: (error) {
      print("Error listening to Firebase messages: $error");
    });
  }

  Future<void> _refreshMessagesFromDb() async {
     final currentMessages = await DatabaseHelper.instance.getMessagesForChatRoom(
        widget.chatThreadId,
        limit: _messages.length > _messagesPerPage ? _messages.length : _messagesPerPage // Load at least as many as currently shown
      );
      if (mounted) {
        setState(() {
          _messages = currentMessages;
          displayItems = _buildDisplayListWithDates(_messages);
          
        });
        _scrollToBottom(isAnimated: true);
      }
  }


  // lib/screens/individual_chat_screen.dart (or wherever _sendMessage is defined)
// ... (other parts of your _sendMessage function) ...

Future<void> _sendMessage({String? text, XFile? imageFile}) async {

  
  _messageController.clear(); // Clear input field after sending
  if ((text == null || text.isEmpty) && imageFile == null) return;
  if (_isSending) return;

  setState(() => _isSending = true);

  final String tempMessageId = FirebaseFirestore.instance.collection('_').doc().id; // Temporary unique ID for the new message
  final DateTime now = DateTime.now(); // Use a single timestamp for consistency
  String messageType = 'text';
  String? localImagePath;

  if (imageFile != null) {
    messageType = 'image';
    localImagePath = imageFile.path;
  }

  // 1. Optimistically add to local DB & UI
  MessageModel optimisticMessage = MessageModel(
    messageId: tempMessageId, // Use temp ID for now
    chatRoomId: widget.chatThreadId,
    whoSent: CurrentUser.currentUserUid,
    whoReceived: widget.otherUserUid,
    isOutgoing: true,
    messageText: text,
    messageType: messageType,
    status: 'sending',
    timestamp: now, // Use the defined 'now'
    localPath: localImagePath,
  );

  final savedOptimisticMessage = await DatabaseHelper.instance.createMessage(optimisticMessage);
  if(mounted) {
    setState(() {
      displayItems = _buildDisplayListWithDates(_messages);
      _messages.add(savedOptimisticMessage);
    });
    _scrollToBottom();
  }

  Map<String, dynamic> firebaseMessageData = {
    'whoSentId': CurrentUser.currentUserUid,
    'whoReceivedId': widget.otherUserUid,
    'messageType': messageType,
    'timestamp': Timestamp.fromDate(now), // Firestore Timestamp using defined 'now'
    'status': 'sent', // Initial server status (will be updated by listener if needed for 'delivered', 'read')
    // 'lastMessageId': tempMessageId, // REMOVED: Individual messages usually don't store the thread's lastMessageId
  };

  if (messageType == 'text') {
    firebaseMessageData['text'] = text;
  } else if (messageType == 'image' && imageFile != null) {
    firebaseMessageData['text'] = null;
    firebaseMessageData['remoteUrl'] = "placeholder_image_url_after_upload";
    print("Image sending: Firebase upload not implemented in this example.");
  }

  try {
    // 3. Send to Firebase (messages subcollection)
    DocumentReference messageDocRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatThreadId)
        .collection('messages')
        .doc(tempMessageId); // Use tempMessageId as the document ID
    await messageDocRef.set(firebaseMessageData);

    // 4. Update local message with 'sent' status (optional, listener might handle it better)
    final MessageModel finalMessage = savedOptimisticMessage.copyWith(
      status: 'sent',
      // messageId is already tempMessageId which is now the server ID too
    );
    await DatabaseHelper.instance.updateMessage(finalMessage); // Update by local SQLite ID

    if (mounted) {
      setState(() {
        final index = _messages.indexWhere((m) => m.id == finalMessage.id);
        if (index != -1) _messages[index] = finalMessage;
        displayItems = _buildDisplayListWithDates(_messages);
        // _isSending should ideally be set to false after all operations, including thread update
      });
    }

    // 5. Update ChatThread summary in Firestore (important for chat list screen)
    //    This is where you add lastMessageId
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatThreadId)
        .set({
      'lastMessage': messageType == 'text' ? text : (messageType == 'image' ? '[Image]' : '[Media]'),
      'timeStamp': Timestamp.fromDate(now), // Use the same 'now' for consistency
      'whoSent': CurrentUser.currentUserUid,
      'whoReceived': widget.otherUserUid,
      'messageType': messageType,
      'lastMessageId': tempMessageId,
      'lastUpdatedAt': FieldValue.serverTimestamp(), // Good practice to track updates
    }, SetOptions(merge: true)); // merge:true is important to not overwrite other fields like 'participants'

    Hive.box<ChatThread>('chatThreadsBox').put(
      widget.chatThreadId,
      ChatThread(
        whoSent: CurrentUser.currentUserUid,
        whoReceived: widget.otherUserUid,
        lastMessage: messageType == 'text' ? text??'' : (messageType == 'image' ? '[Image]' : '[Media]'),
        timeStamp: Timestamp.fromDate(now),
        messageType: messageType,
        lastMessageId: tempMessageId,
      ),
    );

    if(mounted){
        setState(() {
             _isSending = false; // Set isSending to false after all async operations complete successfully
        });
    }

  } catch (e) {
    print("Error sending message to Firebase: $e");
    if (mounted) {
      final MessageModel failedMessage = savedOptimisticMessage.copyWith(status: 'failed');
      await DatabaseHelper.instance.updateMessage(failedMessage);
      setState(() {
        final index = _messages.indexWhere((m) => m.id == failedMessage.id);
        if (index != -1) _messages[index] = failedMessage;
        displayItems = _buildDisplayListWithDates(_messages);
        _isSending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }
}

// ... (rest of your code) ...
  void _scrollToBottom({bool isAnimated = true}) {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) { // Ensure build is complete
        if (isAnimated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        } else {
           _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        // Optimistically add to UI and then send
        _sendMessage(imageFile: pickedFile, text: null); // Or "[Image]" as text
      }
    } catch (e) {
      print("Image picker error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick image: $e')),
      );
    }
  }

  bool isSameDay(DateTime dateA, DateTime dateB) {
    return dateA.year == dateB.year &&
          dateA.month == dateB.month &&
          dateA.day == dateB.day;
  }

  Future<void> _saveEditedMessage() async {
  if (_editingMessage == null || _messageController.text.trim().isEmpty) {
    // If no message is being edited or the text is empty after trimming
    _cancelEditing(); // Just cancel the editing mode
    return;
  }

  if (!mounted) return; // Check if the widget is still mounted

  final String editedText = _messageController.text.trim();
  final MessageModel originalMessage = _editingMessage!;
  final DateTime now = DateTime.now(); // Timestamp for the edit

  // 1. Optimistically update local DB and UI
  final MessageModel updatedLocalMessage = originalMessage.copyWith(
    messageText: editedText,
    status: 'sent', // Or 'editing'/'edited' status locally? Depends on your UI needs.
    editedAt: now, // Mark the edit timestamp
    operation: 'edited', // Add an operation flag
  );

  try {
    // Update the message in the local database (assuming updateMessage uses the local 'id')
    await DatabaseHelper.instance.updateMessage(updatedLocalMessage);

    // Update the UI list
    if (mounted) {
      setState(() {
        final index = _messages.indexWhere((m) => m.id == originalMessage.id);
        if (index != -1) {
          _messages[index] = updatedLocalMessage;
        }
        displayItems = _buildDisplayListWithDates(_messages);
        // Clear editing state
        _editingMessage = null;
        _messageController.clear();
      });
      _scrollToBottom(); // Optional: Scroll to bottom if the edited message is near the bottom
    }

    DocumentReference messageDocRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(originalMessage.chatRoomId) // Use the correct chatRoomId
        .collection('messages')
        .doc(originalMessage.messageId); // Use the Firestore messageId

    await messageDocRef.update({
      'text': editedText,
      'editedAt': Timestamp.fromDate(now),
      'operation': 'edited',
    });

     await FirebaseFirestore.instance
        .collection('chats')
        .doc(originalMessage.chatRoomId)
        .set({
          // Check if this is still the latest message before updating summary fields
          'lastMessage': editedText, // Update last message text
          'timeStamp': Timestamp.fromDate(originalMessage.timestamp), // Keep original timestamp for sorting threads
          // 'whoSent', 'whoReceived', 'messageType', 'lastMessageId' ideally don't change on edit
           'lastUpdatedAt': FieldValue.serverTimestamp(), // Update the overall thread update time
        }, SetOptions(merge: true));

    if (mounted) {
       // _isSending state is usually not used for editing, but if you had one, reset it here
    }

  } catch (e) {
    print("Error saving edited message to Firebase: $e");
    if (mounted) {
       setState(() {
        _editingMessage = null;
        _messageController.clear();
       });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save edited message: $e')),
      );
    }
  }
}

  _cancelEditing() {
    setState(() {
      _editingMessage = null;
      _messageController.clear();
    });
  }

  List<dynamic> _buildDisplayListWithDates(List<MessageModel> messages) {
    if (messages.isEmpty) return [];
    List<dynamic> displayList = [];
    DateTime? lastDate;
    for (var message in messages) { // messagesはASCでソートされている想定
      final messageDate = DateTime(message.timestamp.year, message.timestamp.month, message.timestamp.day);
      if (lastDate == null || !isSameDay(lastDate, messageDate)) {
        displayList.add(messageDate); // 日付ヘッダーを追加
        lastDate = messageDate;
      }
      displayList.add(message); // メッセージを追加
    }
    return displayList;
  }

  // In _IndividualChatScreenState
  Widget _buildDateSeparator(DateTime date) {
    return Center(
      child: Container(
        key: ValueKey(date), // Unique key for each date
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blueGrey[50], // 少し目立つ色
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          DateFormat.yMMMd().format(date), // 例: "May 11, 2025" や "2025年5月11日"
          style: TextStyle(
            fontSize: 12,
            color: Colors.blueGrey[700],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem(MessageModel message,{Key? key}) {
    print("Building message item for ${message.messageId}");
    final bool isMe = message.isOutgoing;
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = isMe ? Colors.deepPurple[400] : Colors.grey[300];
    final textColor = isMe ? Colors.white : Colors.black87;

    // Handle deleted messages
    if (message.operation == 'deleted') {
      return Container(
        key: key,
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
                Text(
                'This message was deleted',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600]),
                ),
            ],
        ),
      );
    }


    Widget messageContent;

    if (message.messageType == 'image') {
      messageContent = message.localPath != null && File(message.localPath!).existsSync()
          ? Image.file(File(message.localPath!), width: 200, height: 200, fit: BoxFit.cover)
          : (message.remoteUrl != null
              ? Image.network(message.remoteUrl!, width: 200, height: 200, fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(width: 200, height: 200, color: Colors.grey[200], child: Center(child: CircularProgressIndicator()));
                  },
                  errorBuilder: (context, error, stackTrace) => Container(width:200, height:200, color: Colors.grey[200], child: Icon(Icons.broken_image, color: Colors.grey))
                )
              : Container(width:200, height:200, color: Colors.grey[200], child: Icon(Icons.image, color: Colors.grey)));
    } else { // 'text' or other
      messageContent = Text(message.messageText ?? '', style: TextStyle(color: textColor));
    }

    return GestureDetector(
      
      onLongPress: (){
        // Show options to delete or edit
        showModalBottomSheet(
          context: context,
          builder: (context) {
            return Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(context);

                    setState(() {
                      _editingMessage = message;
                      _messageController.text = message.messageText ?? '';
                      _messageController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _messageController.text.length),
                      );
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Delete'),
                  onTap: () {
                    // Handle delete action
                    print('firebase id is ${message.messageId}');

                    DatabaseHelper.instance.deleteMessageForEveryone(message);
                    setState(() {
                      displayItems = _buildDisplayListWithDates(_messages);
                      _messages.remove(message);
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },

      child:Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row( // To align bubble and status correctly
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                child: Card(
                  elevation: 1,
                  color: color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: messageContent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Text(
                  DateFormat('hh:mm a').format(message.timestamp),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.status == 'read' ? Icons.done_all : 
                    (message.status == 'delivered' || message.status == 'sent' ? Icons.done : 
                    (message.status == 'sending' ? Icons.access_time : Icons.error_outline)),
                    size: 14,
                    color: message.status == 'read' ? Colors.blue : Colors.grey,
                  ),
                ],
                 if (message.operation == 'edited' || message.editedAt != null) ... [
                  const SizedBox(width: 4),
                  Text('(edited)', style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
                 ]
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }


  @override
  Widget build(BuildContext context) {

    // String otherUserName = widget.otherUserName; // Use passed name
    String otherUserName = widget.otherUserUid; // Placeholder: get actual name via a provider or another DB call

    return Scaffold(
      appBar: AppBar(
        title: Text(otherUserName), // Display other user's name
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (_isLoading) const Expanded(child: Center(child: CircularProgressIndicator())),
          if (!_isLoading && _messages.isEmpty)
            const Expanded(child: Center(child: Text('No messages yet. Say something!'))),
          if (!_isLoading && _messages.isNotEmpty)
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (scrollNotification) {
                  if (scrollNotification.metrics.pixels == scrollNotification.metrics.minScrollExtent &&
                      !_isLoadingMore && _canLoadMore) {
                    _loadMoreMessages();
                  }
                  return false;
                },
                child: ListView.builder(
              controller: _scrollController,
              reverse: false, // User's current setting
              padding: const EdgeInsets.all(8.0),
              itemCount: (_isLoadingMore && displayItems.isNotEmpty ? 1 : 0) + displayItems.length, // ローディングインジケータを考慮
              itemBuilder: (context, index) {
                int itemIndex = index;
                if (_isLoadingMore && displayItems.isNotEmpty) { // ローディングインジケータが先頭にある場合
                  if (index == 0) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(strokeWidth: 2.0),
                    ));
                  }
                  itemIndex = index - 1; // インデックスを調整
                }

                final item = displayItems[itemIndex];
                if (item is DateTime) { // itemがDateTime型なら日付セパレーター
                  return _buildDateSeparator(item);
                } else if (item is MessageModel) { // itemがMessageModel型ならメッセージバブル
                  return _buildMessageItem(item, key: ValueKey(item.messageId));
                }
                return const SizedBox.shrink(); //念のため
              },
            ),
              ),
            ),
          // Message Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, -1),
                  blurRadius: 1,
                  color: Colors.grey.withOpacity(0.1),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_camera_outlined, color: Colors.deepPurple),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.multiline,
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    ),
                    onSubmitted: (text) => _sendMessage(text: text),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                if (_editingMessage != null) // If we are editing a message
                Row( // Wrap in Row to potentially add a cancel button
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check), // Save button
                      color: Theme.of(context).primaryColor,
                      onPressed: () {
                        // Call the save edit function
                        _saveEditedMessage();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel), // Cancel button
                      color: Colors.grey,
                      onPressed: () {
                        // Call the cancel edit function
                        _cancelEditing();
                      },
                    ),
                  ],
                )
              else // If we are sending a new message
                IconButton(
                  icon: const Icon(Icons.send), // Send button
                  color: Theme.of(context).primaryColor,
                  onPressed: () {
                    // Call the original send message function
                    // Make sure to check _messageController.text is not empty before sending
                    if (_messageController.text.trim().isNotEmpty) {
                      _sendMessage(text: _messageController.text);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
}