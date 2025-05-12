// chat_threads_screen.dart

// Ensure these imports are correct for your project structure
import 'package:chatapp/chat/chat_Thread.dart';
import 'package:chatapp/chat/individual_chat_screen.dart'; // Assuming this is your IndividualChatScreen
import 'package:chatapp/user_data.dart'; // Assuming this is where CurrentUser is defined
import 'package:firebase_auth/firebase_auth.dart'; // For FirebaseAuth.instance.currentUser in initState (though prefer passing uid)
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'threadModel/chat_thread.dart'; // Your ChatThread model

class ChatThreadsScreen extends StatefulWidget {
  // It's good practice to pass currentUserUid if possible, rather than relying solely on a static variable.
  // final String currentUserUid;
  // const ChatThreadsScreen({super.key, required this.currentUserUid});

  const ChatThreadsScreen({super.key}); // Using your current constructor

  @override
  State<ChatThreadsScreen> createState() => _ChatThreadsScreenState();
}

class _ChatThreadsScreenState extends State<ChatThreadsScreen> {
  final TextEditingController _otherUserIdController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Simple in-memory cache for usernames
  final Map<String, String> _userNamesCache = {};

  @override
  void initState() {
    super.initState();
    if (CurrentUser.currentUserUid.isEmpty && FirebaseAuth.instance.currentUser != null) {
      ChatService().listenToChatThreads();

      CurrentUser.updateUser(FirebaseAuth.instance.currentUser);
      print("ChatThreadsScreen initState: Updated CurrentUser.currentUserUid");
    }
  }

  @override
  void dispose() {
    _otherUserIdController.dispose();
    super.dispose();
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    if (dateTime.isAfter(today)) {
      return DateFormat.jm().format(dateTime);
    } else if (dateTime.isAfter(yesterday)) {
      return 'Yesterday';
    } else {
      return DateFormat.yMd().format(dateTime);
    }
  }

  // Identifies the other user's ID in the thread
  String _getOtherParticipantId(ChatThread thread, String currentUserId) {
    if (thread.whoSent == currentUserId) {
      return thread.whoReceived;
    } else {
      return thread.whoSent;
    }
  }

  // Fetches username from Firestore with caching
  Future<String> _getUserName(String userId) async {
    if (userId.isEmpty) return "Unknown User";
    if (_userNamesCache.containsKey(userId)) {
      return _userNamesCache[userId]!;
    }
    try {
      final docSnapshot = await _firestore.collection('users').doc(userId).get();
      if (docSnapshot.exists && docSnapshot.data() != null && docSnapshot.data()!.containsKey('name')) {
        final name = docSnapshot.data()!['name'] as String;
        _userNamesCache[userId] = name; // Cache it
        return name;
      } else {
        _userNamesCache[userId] = userId; // Cache the ID itself if name not found to avoid re-fetching
        return userId; // Fallback to userId if name not found
      }
    } catch (e) {
      print("Error fetching username for $userId: $e");
      _userNamesCache[userId] = userId; // Cache the ID on error
      return userId; // Fallback to userId on error
    }
  }


  String _generateChatThreadId(String uid1, String uid2) {
    List<String> uids = [uid1, uid2];
    uids.sort();
    return uids.join('_');
  }

  void _showStartChatDialog(BuildContext context) {
    if (CurrentUser.currentUserUid.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not properly initialized. Please restart.')),
        );
        return;
    }
    _otherUserIdController.clear();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Start New Chat'),
          content: TextField(
            controller: _otherUserIdController,
            decoration: const InputDecoration(
              hintText: "Enter other user's ID",
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Chat'),
              onPressed: () {
                final otherUserId = _otherUserIdController.text.trim();
                if (otherUserId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User ID cannot be empty.')),
                  );
                  return;
                }
                if (otherUserId == CurrentUser.currentUserUid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('You cannot chat with yourself.')),
                  );
                  return;
                }

                final chatThreadId = _generateChatThreadId(CurrentUser.currentUserUid, otherUserId);
                Navigator.of(dialogContext).pop();

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => IndividualChatScreen( // Ensure this is your correct chat screen widget
                      chatThreadId: chatThreadId,
                      otherUserUid: otherUserId,
                      otherUserName: "New User", // You might want to fetch the name here as well
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showLongPressOptions(BuildContext context, ChatThread thread, String otherParticipantId, String otherParticipantName) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext ctx) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text('Delete Chat with $otherParticipantName'),
              onTap: () {
                Navigator.pop(ctx); // Close the bottom sheet
                _confirmDeleteChat(context, thread, otherParticipantName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.orange),
              title: Text('Block $otherParticipantName'),
              onTap: () {
                Navigator.pop(ctx); // Close the bottom sheet
                _blockUser(context, otherParticipantId, otherParticipantName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined),
              title: const Text('Cancel'),
              onTap: () {
                Navigator.pop(ctx);
              },
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteChat(BuildContext context, ChatThread thread, String otherParticipantName) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Delete Chat?'),
          content: Text('Are you sure you want to delete your chat with $otherParticipantName? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Close confirmation dialog
                await _performDeleteChat(thread);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _performDeleteChat(ChatThread thread) async {
    final String chatThreadId = thread.key.toString(); // Hive key should be the Firestore document ID
    print('Attempting to delete chat thread: $chatThreadId');

    try {
      Hive.box<ChatThread>('chatThreadsBox').delete(chatThreadId);
      print('Chat thread $chatThreadId deleted from Firestore.');

      final messagesQuery = await _firestore.collection('chats').doc(chatThreadId).collection('messages').get();
      WriteBatch batch = _firestore.batch();
      for (var doc in messagesQuery.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('Messages subcollection for $chatThreadId also targeted for deletion.');

    } catch (e) {
      print('Error deleting chat: $e');
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete chat: $e')),
        );
      }
    }
  }

  void _blockUser(BuildContext context, String otherParticipantId, String otherParticipantName) {
    // Placeholder for block user logic
    print('Attempting to block user: $otherParticipantId ($otherParticipantName)');
    // Implementation would involve:
    // 1. Adding otherParticipantId to a 'blockedUsers' list/subcollection for CurrentUser.currentUserUid in Firestore.
    //    e.g., _firestore.collection('users').doc(CurrentUser.currentUserUid).collection('blockedByMe').doc(otherParticipantId).set({'blockedAt': Timestamp.now()});
    // 2. Updating your Firestore security rules to prevent message exchange.
    // 3. Modifying your ChatService's Firestore query to filter out threads with blocked users,
    //    OR visually indicating blocked status in the UI.
    // 4. Preventing new chats from being initiated with a blocked user.

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block $otherParticipantName?'),
        content: Text(
            'If you block $otherParticipantName, you will no longer see their messages, and they won\'t see yours in new chats you initiate (existing messages might remain unless deleted). Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Actual block logic:
              try {
                await _firestore
                  .collection('users')
                  .doc(CurrentUser.currentUserUid)
                  .collection('blockedUsers') // Storing who CurrentUser has blocked
                  .doc(otherParticipantId)
                  .set({
                    'blockedAt': Timestamp.now(),
                    'name': otherParticipantName // Store name for easier display in a "blocked list" UI
                  });
                
                // You might also want to remove/hide the chat thread locally or from Firestore view
                // For example, you might delete the local Hive entry or the Firestore chat document
                // This part depends on desired UX. For now, just show a confirmation.
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$otherParticipantName has been blocked.')),
                );
                 // Refresh UI or remove thread from list if needed.
                 // If ChatService filters based on blocked list, Hive will update automatically.

              } catch (e) {
                 ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to block user: $e')),
                );
              }
            },
            child: Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Ensure CurrentUser.currentUserUid is available. If not, show loading or prompt login.
    if (CurrentUser.currentUserUid.isEmpty) {
      // This check might be too late if initState didn't populate it and no auth wrapper is used.
      // Consider using an AuthWrapper pattern as discussed previously.
      return Scaffold(
          appBar: AppBar(title: const Text('My Chats'), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
          body: const Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text("Initializing user...")
            ],
          )));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Chats'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: ValueListenableBuilder<Box<ChatThread>>(
        valueListenable: Hive.box<ChatThread>('chatThreadsBox').listenable(),
        builder: (context, box, _) {
          if (box.values.isEmpty) {
            return const Center( /* ... No chats message ... */ );
          }
          var threads = box.values.toList();
          threads.sort((a, b) => b.timeStamp.compareTo(a.timeStamp));

          return ListView.builder(
            itemCount: threads.length,
            itemBuilder: (context, index) {
              final thread = threads[index];
              final otherParticipantId = _getOtherParticipantId(thread, CurrentUser.currentUserUid);
              final lastMessage = thread.lastMessage;
              final formattedTimestamp = _formatTimestamp(thread.timeStamp);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                elevation: 1.0,
                child: FutureBuilder<String>( // Use FutureBuilder for the username
                  future: _getUserName(otherParticipantId),
                  builder: (context, snapshot) {
                    String displayName = "Loading"; // Default to ID
                    if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                      displayName = snapshot.data!;
                    } else if (snapshot.connectionState == ConnectionState.waiting) {
                      return Shimmer.fromColors(
                        baseColor: const Color.fromARGB(255, 79, 79, 79),
                        highlightColor: const Color.fromARGB(255, 91, 91, 91),
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: Colors.white),
                          title: Container(height: 16.0, width: MediaQuery.of(context).size.width * 0.4, color: Colors.white),
                          subtitle: Container(height: 14.0, width: MediaQuery.of(context).size.width * 0.6, color: Colors.white),
                          trailing: Container(height: 12.0, width: 40.0, color: Colors.white),
                        ),
                      );
                    }else if (snapshot.hasError) {
                      displayName = otherParticipantId;
                      print("Error in FutureBuilder for username: ${snapshot.error}");
                    }
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepPurple[100],
                        foregroundColor: Colors.deepPurple,
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        displayName, // Display fetched name or ID
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: 
                        otherParticipantId == CurrentUser.currentUserUid
                            ?Text(displayName+" : "+lastMessage, maxLines: 1, overflow: TextOverflow.visible)
                            : Text("You: "+lastMessage,maxLines: 1, style: TextStyle(fontWeight: FontWeight.bold),overflow: TextOverflow.visible,),
                        
                      
                      trailing: Text(
                        formattedTimestamp,
                        style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => IndividualChatScreen(
                              chatThreadId: thread.key.toString(),
                              otherUserUid: otherParticipantId,
                              otherUserName: displayName,
                            ),
                          ),
                        );
                      },
                      onLongPress: () {
                        _showLongPressOptions(context, thread, otherParticipantId, displayName);
                      },
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showStartChatDialog(context); // Call the dialog showing method
        },
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white, // For the icon color if not explicitly set
        child: const Icon(Icons.add_comment_outlined),
        tooltip: 'New Chat',
      ),
    );
  }
}