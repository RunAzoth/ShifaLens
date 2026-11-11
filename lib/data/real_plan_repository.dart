import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/models.dart';
import '../core/services/plan_repository.dart';

class RealPlanRepository implements PlanRepository {
  static const String _kLatestPlanPrefsKey = 'shifalens_latest_daily_plan';
  static const String _kTicksPrefsKey = 'shifalens_tick_entries';

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  DailyPlan? _memoryLatestPlan;
  final List<TickEntry> _memoryTicks = [];
  final StreamController<List<TickEntry>> _ticksController =
      StreamController<List<TickEntry>>.broadcast();

  RealPlanRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestoreOverride = firestore,
        _authOverride = auth;

  Future<String?> _ensureAnonymousUid() async {
    if (_authOverride == null && Firebase.apps.isEmpty) return null;
    try {
      final auth = _authOverride ?? FirebaseAuth.instance;
      final current = auth.currentUser;
      if (current != null) return current.uid;
      final cred = await auth
          .signInAnonymously()
          .timeout(const Duration(seconds: 5));
      return cred.user?.uid;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> savePlan(DailyPlan p) async {
    _memoryLatestPlan = p;
    final jsonMap = p.toJson();

    // 1. Always persist locally for instant offline access
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLatestPlanPrefsKey, jsonEncode(jsonMap));
    } catch (_) {}

    // 2. Persist to Firestore under users/{uid}/plans/{planId} (no images, no PII)
    final uid = await _ensureAnonymousUid();
    if (uid == null) return;

    try {
      final db = _firestoreOverride ?? FirebaseFirestore.instance;
      await db
          .collection('users')
          .doc(uid)
          .collection('plans')
          .doc(p.id)
          .set({
            ...jsonMap,
            'savedAtIso': DateTime.now().toUtc().toIso8601String(),
          })
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  @override
  Future<DailyPlan?> loadLatest() async {
    // 1. Try Firestore users/{uid}/plans ordered by savedAtIso descending
    final uid = await _ensureAnonymousUid();
    if (uid != null) {
      try {
        final db = _firestoreOverride ?? FirebaseFirestore.instance;
        final snap = await db
            .collection('users')
            .doc(uid)
            .collection('plans')
            .orderBy('savedAtIso', descending: true)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 4));
        if (snap.docs.isNotEmpty) {
          final plan = DailyPlan.fromJson(snap.docs.first.data());
          _memoryLatestPlan = plan;
          return plan;
        }
      } catch (_) {}
    }

    // 2. Fallback to SharedPreferences / memory
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLatestPlanPrefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final plan = DailyPlan.fromJson(decoded);
        _memoryLatestPlan = plan;
        return plan;
      }
    } catch (_) {}

    return _memoryLatestPlan;
  }

  @override
  Future<void> saveTick(TickEntry t) async {
    _memoryTicks.removeWhere(
      (e) => e.doseKey == t.doseKey && e.date == t.date,
    );
    _memoryTicks.add(t);
    _ticksController.add(List.unmodifiable(_memoryTicks));

    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = jsonEncode(
        _memoryTicks.map((e) => e.toJson()).toList(),
      );
      await prefs.setString(_kTicksPrefsKey, serialized);
    } catch (_) {}

    final uid = await _ensureAnonymousUid();
    if (uid == null) return;

    try {
      final db = _firestoreOverride ?? FirebaseFirestore.instance;
      final safeDocId =
          '${t.date}_${t.doseKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}';
      await db
          .collection('users')
          .doc(uid)
          .collection('ticks')
          .doc(safeDocId)
          .set(t.toJson())
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  @override
  Stream<List<TickEntry>> tickLog({int lastDays = 7}) async* {
    await _loadLocalTicksIntoMemory();
    final cutoff = DateTime.now().subtract(Duration(days: lastDays));

    List<TickEntry> filterRecent(List<TickEntry> items) {
      return items.where((t) => !t.at.isBefore(cutoff)).toList()
        ..sort((a, b) => b.at.compareTo(a.at));
    }

    yield filterRecent(_memoryTicks);

    final uid = await _ensureAnonymousUid();
    if (uid != null) {
      try {
        final db = _firestoreOverride ?? FirebaseFirestore.instance;
        final firestoreStream = db
            .collection('users')
            .doc(uid)
            .collection('ticks')
            .snapshots()
            .map((snap) {
              final list = snap.docs
                  .map((d) => TickEntry.fromJson(d.data()))
                  .toList();
              return filterRecent(list);
            });
        yield* firestoreStream;
        return;
      } catch (_) {}
    }

    yield* _ticksController.stream.map(filterRecent);
  }

  Future<void> _loadLocalTicksIntoMemory() async {
    if (_memoryTicks.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kTicksPrefsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final item in list) {
          _memoryTicks.add(
            TickEntry.fromJson(Map<String, dynamic>.from(item as Map)),
          );
        }
      }
    } catch (_) {}
  }
}
