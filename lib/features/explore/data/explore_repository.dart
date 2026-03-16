import '../../../core/models/category_model.dart';
import '../../../core/models/session_model.dart';

class ExploreRepository {
  List<CategoryModel> fetchCategories() {
    return [
      // ── Gratuit ───────────────────────────────────────
      CategoryModel(
        id: 'decouverte',
        name: 'Découverte de la méditation',
        emoji: '🧘',
        description:
            'Commence ton voyage vers la pleine conscience. Des séances simples pour découvrir la méditation.',
        isPremium: false,
        isNew: false,
        sessions: [
          const SessionModel(
            id: 'decouverte_1',
            title: 'Ma première méditation',
            description:
                'Une introduction douce pour ceux qui n\'ont jamais médité.',
            durationMinutes: 5,
            audioFile: 'decouverte/decouverte_first.mp3',
            categoryId: 'decouverte',
          ),
          const SessionModel(
            id: 'decouverte_3',
            title: 'Observer sans juger',
            description:
                'Apprends à accueillir tes pensées sans t\'y attacher.',
            durationMinutes: 6,
            audioFile: 'decouverte/decouverte_observe.mp3',
            categoryId: 'decouverte',
          ),
          const SessionModel(
            id: 'decouverte_4',
            title: 'Le moment présent',
            description:
                'Entraîne-toi à revenir ici et maintenant, encore et encore.',
            durationMinutes: 8,
            audioFile: 'decouverte/decouverte_present.mp3',
            categoryId: 'decouverte',
          ),
        ],
      ),

      // ── Premium ───────────────────────────────────────
      CategoryModel(
        id: 'actualite',
        name: 'Actualité & Surcharge mentale',
        emoji: '🌍',
        description:
            'Apprends à décrocher du flux d\'informations. Retrouve la clarté dans un monde qui s\'emballe.',
        isPremium: true,
        isNew: true,
        sessions: [
          const SessionModel(
            id: 'actualite_1',
            title: 'Détox numérique',
            description: 'Déconnecte ton esprit du bruit informationnel.',
            durationMinutes: 8,
            audioFile: 'actualite/actualite_detox.mp3',
            categoryId: 'actualite',
          ),
          const SessionModel(
            id: 'actualite_2',
            title: 'Ancrage face à l\'incertitude',
            description:
                'Trouve la sérénité malgré un monde en constante évolution.',
            durationMinutes: 12,
            audioFile: 'actualite/actualite_grounding.mp3',
            categoryId: 'actualite',
            isPremium: true,
          ),
          const SessionModel(
            id: 'actualite_3',
            title: 'Pause info',
            description: 'Une pause consciente loin des écrans et des titres.',
            durationMinutes: 5,
            audioFile: 'actualite/actualite_pause.mp3',
            categoryId: 'actualite',
          ),
          const SessionModel(
            id: 'actualite_4',
            title: 'Déconnexion consciente',
            description: 'Apprends à poser ton téléphone avec légèreté.',
            durationMinutes: 7,
            audioFile: 'actualite/actualite_disconnect.mp3',
            categoryId: 'actualite',
            isPremium: true,
          ),
          const SessionModel(
            id: 'actualite_5',
            title: 'Recul sur l\'actualité',
            description:
                'Prends de la hauteur sur les événements du monde.',
            durationMinutes: 10,
            audioFile: 'actualite/actualite_perspective.mp3',
            categoryId: 'actualite',
            isPremium: true,
          ),
        ],
      ),
      CategoryModel(
        id: 'stress',
        name: 'Stress & Anxiété',
        emoji: '😤',
        description:
            'Libère la pression accumulée au quotidien. Des séances courtes pour revenir à toi rapidement.',
        isPremium: true,
        isNew: false,
        sessions: [
          const SessionModel(
            id: 'stress_1',
            title: 'Respiration 4-7-8',
            description:
                'Une technique de respiration puissante pour calmer le système nerveux.',
            durationMinutes: 5,
            audioFile: 'stress/stress_breathing_478.mp3',
            categoryId: 'stress',
          ),
          const SessionModel(
            id: 'stress_2',
            title: 'Body scan de détente',
            description: 'Parcours ton corps pour relâcher les tensions.',
            durationMinutes: 15,
            audioFile: 'stress/stress_body_scan.mp3',
            categoryId: 'stress',
            isPremium: true,
          ),
          const SessionModel(
            id: 'stress_3',
            title: 'Relâchement musculaire',
            description:
                'Contracte et relâche chaque groupe musculaire pour libérer le stress physique.',
            durationMinutes: 8,
            audioFile: 'stress/stress_muscle_release.mp3',
            categoryId: 'stress',
          ),
          const SessionModel(
            id: 'stress_4',
            title: 'Ancrage rapide',
            description:
                'Reviens à toi en 3 minutes grâce à une technique d\'ancrage simple.',
            durationMinutes: 3,
            audioFile: 'stress/stress_anchor.mp3',
            categoryId: 'stress',
          ),
          const SessionModel(
            id: 'stress_5',
            title: 'Méditation anti-stress',
            description:
                'Dissolve les tensions mentales et retrouve un état de calme profond.',
            durationMinutes: 10,
            audioFile: 'stress/stress_meditation.mp3',
            categoryId: 'stress',
            isPremium: true,
          ),
        ],
      ),
      CategoryModel(
        id: 'sleep',
        name: 'Sommeil',
        emoji: '🌙',
        description:
            'Prépare ton corps et ton esprit au repos. Endors-toi plus facilement, dors plus profondément.',
        isPremium: true,
        isNew: false,
        sessions: [
          const SessionModel(
            id: 'sleep_1',
            title: 'Détente du soir',
            description:
                'Une méditation douce pour préparer ton endormissement.',
            durationMinutes: 10,
            audioFile: 'sleep/sleep_evening.mp3',
            categoryId: 'sleep',
          ),
          const SessionModel(
            id: 'sleep_2',
            title: 'Visualisation apaisante',
            description: 'Voyage mental dans un lieu calme et sécurisant.',
            durationMinutes: 20,
            audioFile: 'sleep/sleep_visualization.mp3',
            categoryId: 'sleep',
            isPremium: true,
          ),
          const SessionModel(
            id: 'sleep_3',
            title: 'Rituel pré-sommeil',
            description:
                'Un rituel de 7 minutes pour signaler à ton corps qu\'il est temps de dormir.',
            durationMinutes: 7,
            audioFile: 'sleep/sleep_ritual.mp3',
            categoryId: 'sleep',
          ),
          const SessionModel(
            id: 'sleep_4',
            title: 'Respiration du soir',
            description:
                'Une respiration lente et profonde pour ralentir le système nerveux.',
            durationMinutes: 5,
            audioFile: 'sleep/sleep_breathing.mp3',
            categoryId: 'sleep',
          ),
          const SessionModel(
            id: 'sleep_5',
            title: 'Plongée dans le silence',
            description:
                'Laisse les pensées se dissoudre dans un silence bienveillant.',
            durationMinutes: 12,
            audioFile: 'sleep/sleep_silence.mp3',
            categoryId: 'sleep',
            isPremium: true,
          ),
        ],
      ),
      CategoryModel(
        id: 'focus',
        name: 'Focus & Concentration',
        emoji: '🎯',
        description:
            'Entraîne ton attention pour être pleinement présent. Moins de distraction, plus d\'efficacité.',
        isPremium: true,
        isNew: false,
        sessions: [
          const SessionModel(
            id: 'focus_1',
            title: 'Pleine conscience 5 min',
            description: 'Ancre-toi dans le moment présent rapidement.',
            durationMinutes: 5,
            audioFile: 'focus/focus_mindfulness_5.mp3',
            categoryId: 'focus',
          ),
          const SessionModel(
            id: 'focus_2',
            title: 'Méditation pomodoro',
            description:
                'Entre en focus profond avant une session de travail.',
            durationMinutes: 10,
            audioFile: 'focus/focus_pomodoro.mp3',
            categoryId: 'focus',
            isPremium: true,
          ),
          const SessionModel(
            id: 'focus_3',
            title: 'Clarté mentale',
            description:
                'Dégage le brouillard mental et retrouve une pensée claire.',
            durationMinutes: 7,
            audioFile: 'focus/focus_clarity.mp3',
            categoryId: 'focus',
          ),
          const SessionModel(
            id: 'focus_4',
            title: 'Attention au souffle',
            description:
                'Utilise le souffle comme ancre pour entraîner ton attention.',
            durationMinutes: 5,
            audioFile: 'focus/focus_breath.mp3',
            categoryId: 'focus',
          ),
          const SessionModel(
            id: 'focus_5',
            title: 'Focus profond',
            description:
                'Une session longue pour entrer dans un état de concentration totale.',
            durationMinutes: 12,
            audioFile: 'focus/focus_deep.mp3',
            categoryId: 'focus',
            isPremium: true,
          ),
        ],
      ),
      CategoryModel(
        id: 'breathing',
        name: 'Respiration',
        emoji: '🌬️',
        description:
            'Utilise ta respiration comme outil de régulation. Simple, puissant, accessible partout.',
        isPremium: true,
        isNew: false,
        sessions: [
          const SessionModel(
            id: 'breathing_1',
            title: 'Cohérence cardiaque',
            description:
                'Synchronise ta respiration pour équilibrer le système nerveux.',
            durationMinutes: 5,
            audioFile: 'breathing/breathing_coherence.mp3',
            categoryId: 'breathing',
          ),
          const SessionModel(
            id: 'breathing_2',
            title: 'Respiration boîte',
            description:
                'La technique des forces spéciales pour retrouver le calme.',
            durationMinutes: 10,
            audioFile: 'breathing/breathing_box.mp3',
            categoryId: 'breathing',
            isPremium: true,
          ),
          const SessionModel(
            id: 'breathing_3',
            title: 'Respiration alternée',
            description:
                'Équilibre les deux hémisphères cérébraux par la respiration nasale alternée.',
            durationMinutes: 7,
            audioFile: 'breathing/breathing_alternate.mp3',
            categoryId: 'breathing',
          ),
          const SessionModel(
            id: 'breathing_4',
            title: 'Souffle apaisant',
            description:
                'Un rythme respiratoire lent pour calmer l\'agitation intérieure.',
            durationMinutes: 3,
            audioFile: 'breathing/breathing_calm.mp3',
            categoryId: 'breathing',
          ),
          const SessionModel(
            id: 'breathing_5',
            title: 'Expansion thoracique',
            description:
                'Ouvre la cage thoracique et libère les tensions respiratoires.',
            durationMinutes: 8,
            audioFile: 'breathing/breathing_expansion.mp3',
            categoryId: 'breathing',
            isPremium: true,
          ),
        ],
      ),
      CategoryModel(
        id: 'anxiety',
        name: 'Anxiété',
        emoji: '💭',
        description:
            'Accueille et apaise les pensées qui débordent. Reprends le contrôle sur ton mental.',
        isPremium: true,
        isNew: false,
        sessions: [
          const SessionModel(
            id: 'anxiety_1',
            title: 'Technique du 5-4-3-2-1',
            description: 'Reviens dans le présent avec tes 5 sens.',
            durationMinutes: 8,
            audioFile: 'anxiety/anxiety_54321.mp3',
            categoryId: 'anxiety',
          ),
          const SessionModel(
            id: 'anxiety_2',
            title: 'Méditation de l\'arbre',
            description: 'Enracine-toi comme un arbre face à la tempête.',
            durationMinutes: 12,
            audioFile: 'anxiety/anxiety_tree.mp3',
            categoryId: 'anxiety',
            isPremium: true,
          ),
          const SessionModel(
            id: 'anxiety_3',
            title: 'Gestion des pensées',
            description:
                'Observe tes pensées anxieuses sans te laisser emporter.',
            durationMinutes: 7,
            audioFile: 'anxiety/anxiety_thoughts.mp3',
            categoryId: 'anxiety',
          ),
          const SessionModel(
            id: 'anxiety_4',
            title: 'Ancrage d\'urgence',
            description:
                'Une technique rapide pour sortir d\'une crise d\'anxiété.',
            durationMinutes: 3,
            audioFile: 'anxiety/anxiety_emergency.mp3',
            categoryId: 'anxiety',
          ),
          const SessionModel(
            id: 'anxiety_5',
            title: 'Acceptation bienveillante',
            description:
                'Accueille ce qui est avec douceur plutôt que de résister.',
            durationMinutes: 10,
            audioFile: 'anxiety/anxiety_acceptance.mp3',
            categoryId: 'anxiety',
            isPremium: true,
          ),
        ],
      ),
      CategoryModel(
        id: 'confidence',
        name: 'Confiance',
        emoji: '💪',
        description:
            'Renforce ta confiance intérieure jour après jour. Avance avec clarté et assurance.',
        isPremium: true,
        isNew: false,
        sessions: [
          const SessionModel(
            id: 'confidence_1',
            title: 'Affirmations positives',
            description: 'Reprogramme tes croyances limitantes en douceur.',
            durationMinutes: 7,
            audioFile: 'confidence/confidence_affirmations.mp3',
            categoryId: 'confidence',
          ),
          const SessionModel(
            id: 'confidence_2',
            title: 'Visualisation du succès',
            description:
                'Projette-toi dans la version la plus accomplie de toi-même.',
            durationMinutes: 12,
            audioFile: 'confidence/confidence_success.mp3',
            categoryId: 'confidence',
            isPremium: true,
          ),
          const SessionModel(
            id: 'confidence_3',
            title: 'Posture intérieure',
            description:
                'Adopte une posture mentale de force et de sérénité.',
            durationMinutes: 5,
            audioFile: 'confidence/confidence_posture.mp3',
            categoryId: 'confidence',
          ),
          const SessionModel(
            id: 'confidence_4',
            title: 'Discours intérieur positif',
            description:
                'Transforme ta voix intérieure en alliée bienveillante.',
            durationMinutes: 8,
            audioFile: 'confidence/confidence_inner_voice.mp3',
            categoryId: 'confidence',
            isPremium: true,
          ),
          const SessionModel(
            id: 'confidence_5',
            title: 'Renforcement de l\'identité',
            description:
                'Connecte-toi à tes valeurs profondes et ta force intérieure.',
            durationMinutes: 10,
            audioFile: 'confidence/confidence_identity.mp3',
            categoryId: 'confidence',
            isPremium: true,
          ),
        ],
      ),
      CategoryModel(
        id: 'mindfulness',
        name: 'Pleine conscience',
        emoji: '🧘',
        description:
            'Reviens au moment présent. Observe sans juger, ressens sans résister.',
        isPremium: true,
        isNew: false,
        sessions: [
          const SessionModel(
            id: 'mindfulness_1',
            title: 'Scan des sensations',
            description:
                'Explore ton corps avec une attention bienveillante.',
            durationMinutes: 10,
            audioFile: 'mindfulness/mindfulness_scan.mp3',
            categoryId: 'mindfulness',
          ),
          const SessionModel(
            id: 'mindfulness_2',
            title: 'Méditation du miroir',
            description: 'Observe tes pensées sans jugement ni attachement.',
            durationMinutes: 15,
            audioFile: 'mindfulness/mindfulness_mirror.mp3',
            categoryId: 'mindfulness',
            isPremium: true,
          ),
          const SessionModel(
            id: 'mindfulness_3',
            title: 'Observation des pensées',
            description:
                'Deviens le témoin de ton flux mental sans t\'y perdre.',
            durationMinutes: 7,
            audioFile: 'mindfulness/mindfulness_thoughts.mp3',
            categoryId: 'mindfulness',
          ),
          const SessionModel(
            id: 'mindfulness_4',
            title: 'Présence au corps',
            description:
                'Habite pleinement ton corps dans l\'instant présent.',
            durationMinutes: 5,
            audioFile: 'mindfulness/mindfulness_body.mp3',
            categoryId: 'mindfulness',
          ),
          const SessionModel(
            id: 'mindfulness_5',
            title: 'Pleine conscience du son',
            description:
                'Utilise les sons environnants comme ancre de présence.',
            durationMinutes: 8,
            audioFile: 'mindfulness/mindfulness_sound.mp3',
            categoryId: 'mindfulness',
            isPremium: true,
          ),
        ],
      ),
    ];
  }
}
