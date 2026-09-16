import 'language.dart';

class UserLanguage {
  const UserLanguage({
    required this.language,
    required this.level,
    this.goals = const [],
  });

  final TargetLanguage language;
  final ProficiencyLevel level;
  final List<String> goals;

  factory UserLanguage.fromJson(Map<String, dynamic> json) => UserLanguage(
        language: TargetLanguage.fromCode(json['language'] as String),
        level: ProficiencyLevel.fromCode(json['level'] as String),
        goals: (json['goals'] as List?)?.cast<String>() ?? const [],
      );
}

class Profile {
  const Profile({
    required this.id,
    this.onboardingComplete = false,
    this.dailyGoalMinutes = 10,
    this.languages = const [],
  });

  final String id;
  final bool onboardingComplete;
  final int dailyGoalMinutes;
  final List<UserLanguage> languages;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        onboardingComplete: json['onboarding_complete'] as bool? ?? false,
        dailyGoalMinutes: (json['daily_goal_minutes'] as num?)?.toInt() ?? 10,
        languages: (json['user_languages'] as List?)
                ?.map((e) => UserLanguage.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
