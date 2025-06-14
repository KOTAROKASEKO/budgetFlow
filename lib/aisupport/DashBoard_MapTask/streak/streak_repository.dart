// lib/aisupport/DashBoard_MapTask/streak/streak_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/streak/streak_hive_model.dart';
import 'package:moneymanager/security/uid.dart';

class StreakRepository {
  static const String _boxName = 'userStreak_v1';

  Future<Box<StreakHiveModel>> _getBox() async {
    if (!Hive.isAdapterRegistered(StreakHiveModelAdapter().typeId)) {
      Hive.registerAdapter(StreakHiveModelAdapter());
    }
    return await Hive.openBox<StreakHiveModel>(_boxName);
  }

  Future<StreakHiveModel?> getStreak() async {
    final box = await _getBox();
    if (box.isEmpty) {
      if (kDebugMode) {
        print('Since Hive box is empty, looking up firestore');
      }
      final streak = await fetchStreakFromFirestore();
      if (streak != null) {
        if (kDebugMode) {
        print('Found a record of this user in the firestore');
      }
        await box.put(StreakHiveModel.streakKey, streak);
      }else{
          if (kDebugMode) {
          print('Not found on firestore');
        }
      }
    }
    // There should only be one streak object per user, stored with a constant key
    return box.get(StreakHiveModel.streakKey);
  }

  Future<StreakHiveModel?> fetchStreakFromFirestore() async {
      final firestore = FirebaseFirestore.instance;
      final doc = await firestore.collection('streak').doc(userId.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return StreakHiveModel(
          id: userId.uid,
          currentStreak: data['streakCount'] ?? 0,
          lastCompletionDate: data['lastUpdated'] != null
              ? DateTime.parse(data['lastUpdated'])
              : null,
          totalPoints: data['totalPoint'],
        );
      }
      return null;
    }


  Future<void> saveStreak(StreakHiveModel streak) async {
    final box = await _getBox();
    await box.put(StreakHiveModel.streakKey, streak);
    // saveStreakToFirestore(userId.uid, streak);
  }

  // Save streak to Firestore under streak/userId/streak
  Future<void> saveStreakToFirestore(String userId, StreakHiveModel streak) async {
    // Import these in your file:
    // import 'package:cloud_firestore/cloud_firestore.dart';
    if(kDebugMode){
      print('Saving on Firestore');
    }
    final firestore = FirebaseFirestore.instance;
    await firestore
        .collection('streak')
        .doc(userId)
        .set(streak.toJson(streak));
  }
}