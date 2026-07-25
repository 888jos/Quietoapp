import 'session_model.dart';

class CategoryModel {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final List<SessionModel> sessions;

  /// true → abonnement requis pour accéder à cette catégorie.
  final bool isPremium;

  /// Texte de la pastille sur la carte ('New !', 'Flash ⚡'…), null = rien.
  final String? badge;

  /// Image de couverture en haut de la page catégorie (style Notion),
  /// chemin relatif à assets/images/ (ex. 'categories/sleep.png').
  /// Null → l'image de la première séance sert de couverture.
  final String? coverImage;

  /// Cadrage vertical du recadrage de la couverture : -1 = haut de l'image,
  /// 0 = centre, 1 = bas. À régler quand le sujet (lune, visage…) n'est pas
  /// au milieu de l'image source, pour qu'il reste visible dans le bandeau.
  final double coverAlignmentY;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.sessions,
    this.isPremium = true,
    this.badge,
    this.coverImage,
    this.coverAlignmentY = 0,
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
    String? badge,
    String? coverImage,
    double? coverAlignmentY,
  }) =>
      CategoryModel(
        id: id ?? this.id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        description: description ?? this.description,
        sessions: sessions ?? this.sessions,
        isPremium: isPremium ?? this.isPremium,
        badge: badge ?? this.badge,
        coverImage: coverImage ?? this.coverImage,
        coverAlignmentY: coverAlignmentY ?? this.coverAlignmentY,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CategoryModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
