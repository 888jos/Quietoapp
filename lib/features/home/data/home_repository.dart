import '../../../core/models/category_model.dart';
import '../../../core/models/session_model.dart';

class HomeRepository {
  /// Retourne toutes les catégories avec leurs séances.
  /// Source statique pour le MVP — à remplacer par une API/remote config.
  List<CategoryModel> fetchCategories() {
    return [
      CategoryModel(
        id: 'stress',
        name: 'Gestion du stress',
        emoji: '🌊',
        description:
            'Apaisez votre mental et trouvez le calme intérieur.',
        sessions: [
          const SessionModel(
            id: 'stress_1',
            title: 'Respiration 4-7-8',
            description:
                'Une technique de respiration puissante pour calmer le système nerveux.',
            durationMinutes: 5,
            audioFile: 'stress_breathing_478.mp3',
            categoryId: 'stress',
          ),
          const SessionModel(
            id: 'stress_2',
            title: 'Body scan de détente',
            description:
                'Parcourez votre corps pour relâcher les tensions accumulées.',
            durationMinutes: 15,
            audioFile: 'stress_body_scan.mp3',
            categoryId: 'stress',
            isPremium: true,
          ),
        ],
      ),
      CategoryModel(
        id: 'sleep',
        name: 'Sommeil',
        emoji: '🌙',
        description: 'Préparez votre corps et votre esprit au repos.',
        sessions: [
          const SessionModel(
            id: 'sleep_1',
            title: 'Détente du soir',
            description:
                'Une méditation douce pour préparer votre endormissement.',
            durationMinutes: 10,
            audioFile: 'sleep_evening.mp3',
            categoryId: 'sleep',
          ),
          const SessionModel(
            id: 'sleep_2',
            title: 'Visualisation apaisante',
            description:
                'Voyage mental dans un lieu calme et sécurisant.',
            durationMinutes: 20,
            audioFile: 'sleep_visualization.mp3',
            categoryId: 'sleep',
            isPremium: true,
          ),
        ],
      ),
      CategoryModel(
        id: 'focus',
        name: 'Concentration',
        emoji: '🎯',
        description: 'Affûtez votre attention et boostez votre clarté.',
        sessions: [
          const SessionModel(
            id: 'focus_1',
            title: 'Pleine conscience 5 min',
            description:
                'Ancrez-vous dans le moment présent rapidement.',
            durationMinutes: 5,
            audioFile: 'focus_mindfulness_5.mp3',
            categoryId: 'focus',
          ),
          const SessionModel(
            id: 'focus_2',
            title: 'Méditation pomodoro',
            description:
                'Allez entrez en focus profond avant une session de travail.',
            durationMinutes: 10,
            audioFile: 'focus_pomodoro.mp3',
            categoryId: 'focus',
            isPremium: true,
          ),
        ],
      ),
      CategoryModel(
        id: 'anxiety',
        name: 'Anxiété',
        emoji: '💚',
        description: 'Libérez l\'inquiétude et retrouvez votre ancrage.',
        sessions: [
          const SessionModel(
            id: 'anxiety_1',
            title: 'Technique du 5-4-3-2-1',
            description:
                'Revenez dans le présent avec vos 5 sens.',
            durationMinutes: 8,
            audioFile: 'anxiety_54321.mp3',
            categoryId: 'anxiety',
          ),
          const SessionModel(
            id: 'anxiety_2',
            title: 'Méditation de l\'arbre',
            description:
                'Enracinez-vous comme un arbre face à la tempête.',
            durationMinutes: 12,
            audioFile: 'anxiety_tree.mp3',
            categoryId: 'anxiety',
            isPremium: true,
          ),
        ],
      ),
    ];
  }
}
