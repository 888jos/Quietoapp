import 'session_model.dart';

class CategoryModel {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final List<SessionModel> sessions;

  /// true → abonnement requis pour accéder à cette catégorie.
  final bool isPremium;

  /// true → afficher le badge "New !" (Actualité uniquement pour le MVP).
  final bool isNew;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.sessions,
    this.isPremium = true,
    this.isNew = false,
  });

  int get totalMinutes =>
      sessions.fold(0, (sum, s) => sum + s.durationMinutes);

  CategoryModel copyWith({
    String? id,
    String? name,
    String? emoji,
    String? description,
    List<SessionModel>? sessions,
    bool? isPremium,
    bool? isNew,
  }) =>
      CategoryModel(
        id: id ?? this.id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        description: description ?? this.description,
        sessions: sessions ?? this.sessions,
        isPremium: isPremium ?? this.isPremium,
        isNew: isNew ?? this.isNew,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CategoryModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
