class UserProgressModel {
  /// sessionId → true si complétée
  final Map<String, bool> completedSessions;

  /// sessionId → dernière position en secondes
  final Map<String, int> lastPositions;

  /// Nombre total de minutes méditées
  final int totalMinutes;

  /// Date de la dernière session
  final DateTime? lastSessionDate;

  const UserProgressModel({
    this.completedSessions = const {},
    this.lastPositions = const {},
    this.totalMinutes = 0,
    this.lastSessionDate,
  });

  bool isCompleted(String sessionId) =>
      completedSessions[sessionId] ?? false;

  int lastPosition(String sessionId) =>
      lastPositions[sessionId] ?? 0;

  int get completedCount =>
      completedSessions.values.where((v) => v).length;

  UserProgressModel copyWith({
    Map<String, bool>? completedSessions,
    Map<String, int>? lastPositions,
    int? totalMinutes,
    DateTime? lastSessionDate,
  }) =>
      UserProgressModel(
        completedSessions: completedSessions ?? this.completedSessions,
        lastPositions: lastPositions ?? this.lastPositions,
        totalMinutes: totalMinutes ?? this.totalMinutes,
        lastSessionDate: lastSessionDate ?? this.lastSessionDate,
      );

  UserProgressModel markCompleted(String sessionId, int durationMinutes) {
    final updated = Map<String, bool>.from(completedSessions);
    updated[sessionId] = true;
    return copyWith(
      completedSessions: updated,
      totalMinutes: totalMinutes + durationMinutes,
      lastSessionDate: DateTime.now(),
    );
  }

  UserProgressModel savePosition(String sessionId, int positionSeconds) {
    final updated = Map<String, int>.from(lastPositions);
    updated[sessionId] = positionSeconds;
    return copyWith(lastPositions: updated);
  }

  Map<String, dynamic> toJson() => {
        'completedSessions': completedSessions,
        'lastPositions': lastPositions,
        'totalMinutes': totalMinutes,
        'lastSessionDate': lastSessionDate?.toIso8601String(),
      };

  factory UserProgressModel.fromJson(Map<String, dynamic> json) =>
      UserProgressModel(
        completedSessions: Map<String, bool>.from(
            json['completedSessions'] as Map? ?? {}),
        lastPositions: Map<String, int>.from(
            json['lastPositions'] as Map? ?? {}),
        totalMinutes: json['totalMinutes'] as int? ?? 0,
        lastSessionDate: json['lastSessionDate'] != null
            ? DateTime.tryParse(json['lastSessionDate'] as String)
            : null,
      );
}
