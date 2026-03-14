import '../../../core/models/category_model.dart';
import '../../../core/models/session_model.dart';

class HomeRepository {
  /// Retourne toutes les catégories avec leurs séances.
  /// Source statique pour le MVP — à remplacer par une API/remote config.
  List<CategoryModel> fetchCategories() {
    return [
      CategoryModel(
        id: 'stress',
        name: 'Stress',
        emoji: '😤',
        description: 'Apaisez votre mental et trouvez le calme intérieur.',
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
            description: 'Voyage mental dans un lieu calme et sécurisant.',
            durationMinutes: 20,
            audioFile: 'sleep_visualization.mp3',
            categoryId: 'sleep',
            isPremium: true,
          ),
        ],
      ),
      CategoryModel(
        id: 'focus',
        name: 'Focus',
        emoji: '🎯',
        description: 'Affûtez votre attention et boostez votre clarté.',
        sessions: [
          const SessionModel(
            id: 'focus_1',
            title: 'Pleine conscience 5 min',
            description: 'Ancrez-vous dans le moment présent rapidement.',
            durationMinutes: 5,
            audioFile: 'focus_mindfulness_5.mp3',
            categoryId: 'focus',
          ),
          const SessionModel(
            id: 'focus_2',
            title: 'Méditation pomodoro',
            description:
                'Entrez en focus profond avant une session de travail.',
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
        emoji: '💭',
        description: 'Libérez l\'inquiétude et retrouvez votre ancrage.',
        sessions: [
          const SessionModel(
            id: 'anxiety_1',
            title: 'Technique du 5-4-3-2-1',
            description: 'Revenez dans le présent avec vos 5 sens.',
            durationMinutes: 8,
            audioFile: 'anxiety_54321.mp3',
            categoryId: 'anxiety',
          ),
          const SessionModel(
            id: 'anxiety_2',
            title: 'Méditation de l\'arbre',
            description: 'Enracinez-vous comme un arbre face à la tempête.',
            durationMinutes: 12,
            audioFile: 'anxiety_tree.mp3',
            categoryId: 'anxiety',
            isPremium: true,
          ),
        ],
      ),
      CategoryModel(
        id: 'breathing',
        name: 'Respiration',
        emoji: '🌬️',
        description: 'Retrouvez l\'équilibre par le souffle conscient.',
        sessions: [
          const SessionModel(
            id: 'breathing_1',
            title: 'Cohérence cardiaque',
            description:
                'Synchronisez votre respiration pour équilibrer le système nerveux.',
            durationMinutes: 5,
            audioFile: 'breathing_coherence.mp3',
            categoryId: 'breathing',
          ),
          const SessionModel(
            id: 'breathing_2',
            title: 'Respiration boîte',
            description:
                'La technique des forces spéciales pour retrouver le calme.',
            durationMinutes: 10,
            audioFile: 'breathing_box.mp3',
            categoryId: 'breathing',
            isPremium: true,
          ),
        ],
      ),
      CategoryModel(
        id: 'confidence',
        name: 'Confiance',
        emoji: '💪',
        description: 'Renforcez l\'estime de soi et votre puissance intérieure.',
        sessions: [
          const SessionModel(
            id: 'confidence_1',
            title: 'Affirmations positives',
            description:
                'Reprogrammez vos croyances limitantes en douceur.',
            durationMinutes: 7,
            audioFile: 'confidence_affirmations.mp3',
            categoryId: 'confidence',
          ),
          const SessionModel(
            id: 'confidence_2',
            title: 'Visualisation du succès',
            description:
                'Projetez-vous dans la version la plus accomplie de vous-même.',
            durationMinutes: 12,
            audioFile: 'confidence_success.mp3',
            categoryId: 'confidence',
            isPremium: true,
          ),
        ],
      ),
      CategoryModel(
        id: 'mindfulness',
        name: 'Pleine conscience',
        emoji: '🧘',
        description: 'Habitez pleinement l\'instant présent.',
        sessions: [
          const SessionModel(
            id: 'mindfulness_1',
            title: 'Scan des sensations',
            description:
                'Explorez votre corps avec une attention bienveillante.',
            durationMinutes: 10,
            audioFile: 'mindfulness_scan.mp3',
            categoryId: 'mindfulness',
          ),
          const SessionModel(
            id: 'mindfulness_2',
            title: 'Méditation du miroir',
            description: 'Observez vos pensées sans jugement ni attachement.',
            durationMinutes: 15,
            audioFile: 'mindfulness_mirror.mp3',
            categoryId: 'mindfulness',
            isPremium: true,
          ),
        ],
      ),
      CategoryModel(
        id: 'news',
        name: 'Actualité',
        emoji: '🌍',
        description: 'Restez ancré face au flux d\'informations quotidien.',
        sessions: [
          const SessionModel(
            id: 'news_1',
            title: 'Détox numérique',
            description:
                'Déconnectez votre esprit du bruit informationnel.',
            durationMinutes: 8,
            audioFile: 'news_detox.mp3',
            categoryId: 'news',
          ),
          const SessionModel(
            id: 'news_2',
            title: 'Ancrage face à l\'incertitude',
            description:
                'Trouvez la sérénité malgré un monde en constante évolution.',
            durationMinutes: 12,
            audioFile: 'news_grounding.mp3',
            categoryId: 'news',
            isPremium: true,
          ),
        ],
      ),
    ];
  }

  /// Retourne la séance mise en avant du jour.
  SessionModel fetchFeaturedSession() {
    return const SessionModel(
      id: 'sleep_1',
      title: 'Détente du soir',
      description: 'Une méditation douce pour préparer votre endormissement.',
      durationMinutes: 10,
      audioFile: 'sleep_evening.mp3',
      categoryId: 'sleep',
    );
  }
}
