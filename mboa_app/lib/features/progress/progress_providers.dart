import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../learning/data/learning_repository.dart';
import '../learning/domain/models.dart';

class ProgressSnapshot {
  const ProgressSnapshot({
    required this.totalXp,
    required this.todayXp,
    required this.dailyGoalXp,
    required this.lessonsCompleted,
    required this.streakDays,
    required this.longestStreak,
    required this.mastery,
    required this.itemsDue,
  });

  factory ProgressSnapshot.fromJson(Map<String, dynamic> j) => ProgressSnapshot(
    totalXp: j['total_xp'] as int,
    todayXp: j['today_xp'] as int,
    dailyGoalXp: j['daily_goal_xp'] as int,
    lessonsCompleted: j['lessons_completed'] as int,
    streakDays: j['streak']['current_days'] as int,
    longestStreak: j['streak']['longest_days'] as int,
    mastery: Map<String, int>.from(j['mastery'] as Map),
    itemsDue: j['items_due'] as int,
  );

  final int totalXp;
  final int todayXp;
  final int dailyGoalXp;
  final int lessonsCompleted;
  final int streakDays;
  final int longestStreak;
  final Map<String, int> mastery;
  final int itemsDue;

  double get goalRatio =>
      dailyGoalXp == 0 ? 0 : (todayXp / dailyGoalXp).clamp(0, 1);
  bool get goalReached => todayXp >= dailyGoalXp;
}

final languagesProvider = FutureProvider<List<Language>>(
  (ref) => ref.watch(learningRepositoryProvider).languages(),
);

final progressProvider = FutureProvider<ProgressSnapshot>((ref) async {
  final data = await ref.watch(learningRepositoryProvider).progress();
  return ProgressSnapshot.fromJson(data);
});

/// Le parcours de la langue choisie. Recalculé par le serveur (déverrouillage).
final pathProvider = FutureProvider<LearningPath?>((ref) async {
  final languageId = ref.watch(sessionProvider.select((s) => s.languageId));
  if (languageId == null) return null;
  return ref.watch(learningRepositoryProvider).path(languageId);
});

final selectedLanguageProvider = FutureProvider<Language?>((ref) async {
  final languageId = ref.watch(sessionProvider.select((s) => s.languageId));
  final languages = await ref.watch(languagesProvider.future);
  return languages.where((l) => l.id == languageId).firstOrNull;
});
