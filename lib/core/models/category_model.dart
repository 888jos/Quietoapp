import 'session_model.dart';

class CategoryModel {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final List<SessionModel> sessions;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.sessions,
  });

  int get totalMinutes =>
      sessions.fold(0, (sum, s) => sum + s.durationMinutes);

  bool get isPremium => sessions.any((s) => s.isPremium);

  CategoryModel copyWith({
    String? id,
    String? name,
    String? emoji,
    String? description,
    List<SessionModel>? sessions,
  }) =>
      CategoryModel(
        id: id ?? this.id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        description: description ?? this.description,
        sessions: sessions ?? this.sessions,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CategoryModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
