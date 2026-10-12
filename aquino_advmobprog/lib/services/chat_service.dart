import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;

  // name to show for a user, falls back to username then "Unknown"
  static String displayName(Map<String, dynamic> user) {
    final full =
        '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    if (full.isNotEmpty) return full;
    final username = (user['username'] ?? '').toString();
    return username.isNotEmpty ? username : 'Unknown';
  }

  // get all users except the logged-in one
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection("Users").snapshots().map((snapshot) {
      final me = firebaseAuth.currentUser;
      final myEmail = (me?.email ?? '').toLowerCase();

      return snapshot.docs
          .map((doc) {
            final user = Map<String, dynamic>.from(doc.data());
            // some docs may not have a uid field, use the doc id instead
            if ((user['uid'] ?? '').toString().isEmpty) user['uid'] = doc.id;
            return user;
          })
          .where((user) {
            final sameUid = user['uid'] == me?.uid;
            final sameEmail = myEmail.isNotEmpty &&
                (user['email'] ?? '').toString().toLowerCase() == myEmail;
            return !sameUid && !sameEmail; // skip myself
          })
          .toList();
    });
  }

  // send message
  Future<void> sendMessage(String receiverId, message) async {
    final String currentUserId = firebaseAuth.currentUser!.uid;
    final String? currentUserEmail = firebaseAuth.currentUser!.email;
    final Timestamp timestamp = Timestamp.now();

    MessageModel newMessage = MessageModel(
      senderId: currentUserId,
      senderEmail: currentUserEmail ?? "",
      receiverId: receiverId,
      message: message,
      timestamp: timestamp,
    );

    // construct chat room ID for the two users (sorted to ensure uniqueness)
    List<String> ids = [currentUserId, receiverId];
    ids.sort(); // same chatRoomID for any 2 people
    String chatRoomID = ids.join("_");

    // add new message to database
    await _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .add(newMessage.toMap());
  }

  // get message
  Stream<QuerySnapshot> getMessage(String userID, otherUserID) {
    List<String> ids = [userID, otherUserID];
    ids.sort();
    String chatRoomID = ids.join("_");

    return _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .orderBy('timestamp', descending: true)
        // metadata changes tell us if a message is still sending
        .snapshots(includeMetadataChanges: true);
  }

  // mark received messages as seen
  Future<void> markMessagesAsSeen(List<DocumentReference> refs) async {
    if (refs.isEmpty) return;
    final batch = _firestore.batch();
    for (final ref in refs) {
      batch.update(ref, {'seen': true, 'seenAt': Timestamp.now()});
    }
    await batch.commit();
  }

  Future<String?> getUidByEmail(String email) async {
    final q = await _firestore
        .collection('Users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    // Ensure your Users doc actually stores the Firebase Auth UID in a field "uid"
    return (q.docs.first.data()['uid'] ?? '').toString();
  }
}