class UserProgressModel {
  /// sessionId → true si complétée
  final Map<String, bool> completedSessions;

  /// sessionId → dernière position en secondes
  final Map<String, int> lastPositions;

  /// Temps total réellement médité, en **secondes**.
  /// On stocke des secondes (et non des minutes) pour compter le temps
  /// réellement écouté avec précision, et accumuler les petits bouts.
  final int totalSeconds;

  /// Date de la dernière session
  final DateTime? lastSessionDate;

  const UserProgressModel({
    this.completedSessions = const {},
    this.lastPositions = const {},
    this.totalSeconds = 0,
    this.lastSessionDate,
  });

  /// Minutes méditées, dérivées des secondes (pour l'affichage).
  int get totalMinutes => totalSeconds ~/ 60;

  bool isCompleted(String sessionId) =>
      completedSessions[sessionId] ?? false;

  int lastPosition(String sessionId) =>
      lastPositions[sessionId] ?? 0;

  int get completedCount =>
      completedSessions.values.where((v) => v).length;

  UserProgressModel copyWith({
    Map<String, bool>? completedSessions,
    Map<String, int>? lastPositions,
    int? totalSeconds,
    DateTime? lastSessionDate,
  }) =>
      UserProgressModel(
        completedSessions: completedSessions ?? this.completedSessions,
        lastPositions: lastPositions ?? this.lastPositions,
        totalSeconds: totalSeconds ?? this.totalSeconds,
        lastSessionDate: lastSessionDate ?? this.lastSessionDate,
      );

  /// Marque une séance comme complétée. N'ajoute PAS de temps : le temps
  /// médité est compté en temps réel pendant l'écoute (voir addListenedSeconds).
  UserProgressModel markCompleted(String sessionId) {
    final updated = Map<String, bool>.from(completedSessions);
    updated[sessionId] = true;
    return copyWith(
      completedSessions: updated,
      lastSessionDate: DateTime.now(),
    );
  }

  /// Ajoute du temps réellement écouté (en secondes) au total cumulé.
  /// Appelé régulièrement pendant la lecture. Cumulatif : réécouter une
  /// séance rajoute bien du temps.
  UserProgressModel addListenedSeconds(int seconds) {
    if (seconds <= 0) return this;
    return copyWith(
      totalSeconds: totalSeconds + seconds,
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
        'totalSeconds': totalSeconds,
        'lastSessionDate': lastSessionDate?.toIso8601String(),
      };

  factory UserProgressModel.fromJson(Map<String, dynamic> json) =>
      UserProgressModel(
        completedSessions: Map<String, bool>.from(
            json['completedSessions'] as Map? ?? {}),
        lastPositions: Map<String, int>.from(
            json['lastPositions'] as Map? ?? {}),
        // Migration : si une ancienne sauvegarde n'a que 'totalMinutes',
        // on la convertit en secondes pour ne pas perdre l'historique.
        totalSeconds: json['totalSeconds'] as int? ??
            ((json['totalMinutes'] as int? ?? 0) * 60),
        lastSessionDate: json['lastSessionDate'] != null
            ? DateTime.tryParse(json['lastSessionDate'] as String)
            : null,
      );
}
