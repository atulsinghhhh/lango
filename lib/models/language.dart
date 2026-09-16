enum TargetLanguage {
  korean('ko', 'Korean', '🇰🇷', 'ko-KR'),
  japanese('ja', 'Japanese', '🇯🇵', 'ja-JP');

  const TargetLanguage(this.code, this.label, this.flag, this.ttsLocale);

  final String code;
  final String label;
  final String flag;
  final String ttsLocale;

  static TargetLanguage fromCode(String code) =>
      values.firstWhere((l) => l.code == code);
}

enum ProficiencyLevel {
  completeBeginner('complete_beginner', 'Complete beginner'),
  beginner('beginner', 'Beginner'),
  elementary('elementary', 'Elementary'),
  intermediate('intermediate', 'Intermediate'),
  advanced('advanced', 'Advanced');

  const ProficiencyLevel(this.code, this.label);

  final String code;
  final String label;

  static ProficiencyLevel fromCode(String code) =>
      values.firstWhere((l) => l.code == code,
          orElse: () => ProficiencyLevel.beginner);
}

const learningGoals = <String>[
  'Conversation',
  'Travel',
  'Reading',
  'Work',
  'Study',
  'TOPIK',
  'JLPT',
  'Media comprehension',
  'General fluency',
];

const dailyGoalOptions = <int>[5, 10, 20, 30, 60];
