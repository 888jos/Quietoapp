class SessionModel {
  final String id;
  final String title;
  final String description;
  final int durationMinutes;
  final String audioFile;
  final String categoryId;
  final bool isPremium;

  const SessionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.audioFile,
    required this.categoryId,
    this.isPremium = false,
  });

  String get durationLabel {
    if (durationMinutes < 60) return '$durationMinutes min';
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h${m}min';
  }

  SessionModel copyWith({
    String? id,
    String? title,
    String? description,
    int? durationMinutes,
    String? audioFile,
    String? categoryId,
    bool? isPremium,
  }) =>
      SessionModel(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        audioFile: audioFile ?? this.audioFile,
        categoryId: categoryId ?? this.categoryId,
        isPremium: isPremium ?? this.isPremium,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SessionModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
