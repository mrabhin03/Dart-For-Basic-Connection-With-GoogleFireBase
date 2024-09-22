import 'dart:async';
import 'dart:ffi';

import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class Database {
  //Send TheMessage
  Future SendMessage(
      Map<String, dynamic> data, String Username, String SessionUser) async {
    String paths1 = generateHash(Username + SessionUser);
    String paths2 = generateHash(SessionUser + Username);
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('TheMessage')
        .where('WhoToSend', whereIn: [paths1, paths2]).get();
    if (querySnapshot.docs.length == 0) {
      addDataToUser(Username, SessionUser);
      addDataToUser(SessionUser, Username);
    }
    return await FirebaseFirestore.instance
        .collection("TheMessage")
        .doc()
        .set(data);
  }

//Delete TheMessage
  void deleteTheMessage(String data) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final docRef =
          FirebaseFirestore.instance.collection('TheMessage').doc(data);
      batch.update(docRef, {'Views': 2});
      await batch.commit();
    } catch (e) {}
  }

  Future CheckUser(Usernamevalue) async {
    Usernamevalue = Usernamevalue.toLowerCase();
    DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
        .collection('TheUser')
        .doc(Usernamevalue)
        .get();

    if (docSnapshot.exists) {
      return 1;
    } else {
      return 0;
    }
  }

//Sign up
  Future CreateUser(Usernamevalue, Evalue, Passvalue) async {
    String User = Usernamevalue.toLowerCase();
    Map<String, dynamic> data = {
      "Username": User,
      "Values": "",
      "E": generateHash(Evalue),
      "Name": Usernamevalue,
      "Pass": generateHash(Passvalue),
      "Photo": "Default.png",
      "TheUsersThatChats": []
    };
    return await FirebaseFirestore.instance
        .collection("TheUser")
        .doc(User)
        .set(data);
  }

//People details
  Future<List<String>> Userdetails(String Username, Mode) async {
    Map<String, dynamic> data = {};
    var TheUserdata = <String>[];
    var Present = [""];
    TheUserdata = [""];

    try {
      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
          .collection('TheUser')
          .doc(Username)
          .get();

      if (docSnapshot.exists) {
        Present = ["Present"];
        data = docSnapshot.data() as Map<String, dynamic>;
        if (data.containsKey('TheUsersThatChats')) {
          TheUserdata = List<String>.from(data['TheUsersThatChats']);
          if (TheUserdata.length != 0) {
            for (int i = 0; i < TheUserdata.length; i++) {
              TheUserdata[i] = decryptString(TheUserdata[i]);
            }
          } else {
            TheUserdata = [""];
          }
        } else {}
      }
    } catch (e) {}
    var orderedChats = await SortUserByTime(TheUserdata, Username);
    if (Mode == 1) {
      return orderedChats;
    } else {
      return Present;
    }
  }

//Notifications
  Future<List<String>> SortUserByTime(TheUserdata, Username) async {
    List<String> Pathsaver = [];
    List<String> Patharray = [];
    List<Map<String, dynamic>> TheMessage = [];

    if (TheUserdata[0] != "") {
      for (var userData in TheUserdata) {
        var paths1 = generateHash(userData + Username);
        var paths2 = generateHash(Username + userData);

        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('TheMessage')
            .where('WhoToSend', whereIn: [paths1, paths2])
            .orderBy('Time', descending: true)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          var messageData =
              querySnapshot.docs.first.data() as Map<String, dynamic>;
          TheMessage.add(messageData);
          if (messageData['WhoToSend'] == paths1) {
            Pathsaver.add(userData + Username);
          } else {
            Pathsaver.add(Username + userData);
          }
        }
      }
      TheMessage.sort((a, b) => b['Time'].compareTo(a['Time']));
      List<String> WhoToSend = [];
      for (var message in TheMessage) {
        WhoToSend.add(message['WhoToSend']);
        Patharray.add("0");
      }
      for (int i = 0; i < Pathsaver.length; i++) {
        int val = WhoToSend.indexOf(generateHash(Pathsaver[i]));
        Patharray[val] = Pathsaver[i].replaceAll(Username, "");
      }
    } else {
      Patharray = [""];
    }

    return Patharray;
  }

//Searching people
  Future<List<String>> Search(String Username, String Sessionuser) async {
    List<String> usernames = [""];
    Username = Username.toLowerCase();
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('TheUser')
          .where('Username', isNotEqualTo: Sessionuser)
          .where('Username', isGreaterThanOrEqualTo: Username)
          .where('Username', isLessThanOrEqualTo: '$Username\uf8ff')
          .get();

      for (var doc in querySnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        usernames.add(data['Username']);
      }
    } catch (e) {}

    return usernames;
  }

//Chatted with whom
  Future<void> addDataToUser(String username, String newData) async {
    try {
      newData = encryptString(newData);
      DocumentReference userDocRef =
          FirebaseFirestore.instance.collection('TheUser').doc(username);

      await userDocRef.update({
        'TheUsersThatChats': FieldValue.arrayUnion([newData])
      });
    } catch (e) {}
  }

//Logins
  Future login(Username, Pass) async {
    Username = Username.toLowerCase();
    DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
        .collection('TheUser')
        .doc(Username)
        .get();
    if (docSnapshot.exists) {
      var data = docSnapshot.data() as Map<String, dynamic>;

      if (data["Pass"] == generateHash(Pass)) {
        return 1;
      }
      return 0;
    } else {
      return 0;
    }
  }

//People who chated with
  Future<Stream<QuerySnapshot>> GetChats(data) async {
    final query = FirebaseFirestore.instance
        .collection('TheUser')
        .where('Username', isEqualTo: data);

    return await query.snapshots();
  }

//Getting all TheMessage received and sented
  Stream<List> getTheMessagetream(String username, String sessionUser) {
    String paths1 = generateHash(username + sessionUser);
    String paths2 = generateHash(sessionUser + username);
    return FirebaseFirestore.instance
        .collection('TheMessage')
        .where('WhoToSend', whereIn: [paths1, paths2])
        .orderBy('Time', descending: true)
        .limit(1)
        .snapshots()
        .asyncMap((querySnapshot) async {
          var basic = [
            "...",
            0,
            DateFormat('h:mm a').format(DateTime.now()).toString(),
            0,
            ""
          ];
          if (querySnapshot.docs.isNotEmpty) {
            final latestDoc = querySnapshot.docs.first;
            final data = latestDoc.data() as Map<String, dynamic>;
            basic[0] = data['Message'] ?? "...";
            basic[2] = TimeCalculation(data['Time'], 1) ?? "...";

            final notification = await FirebaseFirestore.instance
                .collection('TheMessage')
                .where('WhoToSend', isEqualTo: paths1)
                .where('Views', isEqualTo: 0)
                .get();
            basic[1] = notification.docs.length;
            basic[3] = data['Views'];
            if (generateHash(username) == data['To']) {
              if (data['Views'] == 0) {
                basic[4] = "Unread: ";
              } else if (data['Views'] == 1) {
                basic[4] = "Seen: ";
              }
            }
          }
          return basic;
        });
  }

//How many TheMessage got
  Future<int> getmessage_count(Path) async {
    final notification = await FirebaseFirestore.instance
        .collection('TheMessage')
        .where('WhoToSend', isEqualTo: Path)
        .where('Views', isEqualTo: 0)
        .get();
    return notification.docs.length;
  }

//Mark as read the message
  void MarkasRead(Username, SessionUser) async {
    String paths1 = generateHash(Username + SessionUser);
    try {
      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('TheMessage')
          .where('WhoToSend', isEqualTo: paths1)
          .where('Views', isEqualTo: 0)
          .get();
      final batch = FirebaseFirestore.instance.batch();

      for (DocumentSnapshot doc in querySnapshot.docs) {
        batch.update(doc.reference, {'Views': 1});
      }
      await batch.commit();
    } catch (e) {}
  }

//Data Calculation
  String TimeCalculation(Timestamp timestamp, Mode) {
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(
      timestamp.seconds * 1000 + timestamp.nanoseconds ~/ 1000000,
    );

    DateTime today = DateTime.now();
    if (Mode == 1) {
      if (dateTime.year == today.year &&
          dateTime.month == today.month &&
          dateTime.day == today.day) {
        return DateFormat('h:mm a').format(dateTime);
      } else if (dateTime.year == today.year &&
          dateTime.month == today.month &&
          dateTime.day == today.day - 1) {
        return "Yesterday";
      } else {
        return DateFormat('MMM d, y').format(dateTime);
      }
    } else if (Mode == 0) {
      return DateFormat('h:mm a').format(dateTime);
    } else {
      if (dateTime.year == today.year &&
          dateTime.month == today.month &&
          dateTime.day == today.day) {
        return "Today";
      } else if (dateTime.year == today.year &&
          dateTime.month == today.month &&
          dateTime.day == today.day - 1) {
        return "Yesterday";
      } else {
        return DateFormat('MMM d, y').format(dateTime);
      }
    }
  }

//App Version check
  Future<List<String>> getAppinfo(Mode) async {
    var details = ["", "", ""];
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('MyFriends')
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final latestDoc = querySnapshot.docs.first;
        final data = latestDoc.data() as Map<String, dynamic>;
        details[0] = data['bannedversion'].toString();
        details[1] = data['latestversion'].toString();
        details[2] = data['DownloadUrl'].toString();
      }
    } catch (e) {}
    return details;
  }

//Encrypting Message
  String encryptString(String plainText) {
    String passphrase = "TheKEY";
    final key = Key.fromUtf8(passphrase.padRight(32, '\x00'));
    final iv = IV.fromLength(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    final combined = iv.base64 + encrypted.base64;
    return combined;
  }

//Decrypting Message
  String decryptString(String combinedText) {
    if (combinedText != "...") {
      String passphrase = "KEY";
      final key = Key.fromUtf8(passphrase.padRight(32, '\x00'));
      final ivBase64 = combinedText.substring(0, 24);
      final encryptedBase64 = combinedText.substring(24);
      final iv = IV.fromBase64(ivBase64);
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final decrypted = encrypter.decrypt64(encryptedBase64, iv: iv);
      return decrypted;
    } else {
      return combinedText;
    }
  }

//Hashing data
  String generateHash(String input) {
    var bytes = utf8.encode(input);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }
}
