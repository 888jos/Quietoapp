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
            audioFile: 'decouverte/0-premiere-séance.mp3',
            categoryId: 'decouverte',
          ),
          const SessionModel(
            id: 'decouverte_2',
            title: 'Observer sans juger',
            description:
                'Apprends à accueillir tes pensées sans t\'y attacher.',
            durationMinutes: 6,
            audioFile: 'decouverte/1-deuxième-séance.mp3',
            categoryId: 'decouverte',
          ),
          const SessionModel(
            id: 'decouverte_3',
            title: 'Le moment présent',
            description:
                'Entraîne-toi à revenir ici et maintenant, encore et encore.',
            durationMinutes: 8,
            audioFile: 'decouverte/2-troisième-séance.mp3',
            categoryId: 'decouverte',
          ),
        ],
      ),

      // ── Premium ───────────────────────────────────────
      CategoryModel(
        id: 'actualite',
        name: 'Actualité & Surcharge mentale',
        emoji: '📰',
        description:
            'Apprends à décrocher du flux d\'informations. Retrouve la clarté dans un monde qui s\'emballe.',
        isPremium: true,
        isNew: true,
        sessions: [
          const SessionModel(
            id: 'actualite_1',
            title: 'Quand le monde brûle',
            description: 'Déconnecte ton esprit du bruit informationnel.',
            durationMinutes: 8,
            audioFile: 'actualite/4-quand-le-monde-brule.mp3',
            categoryId: 'actualite',
          ),
          const SessionModel(
            id: 'actualite_2',
            title: 'La guerre en bruit de fond',
            description:
                'Trouve la sérénité malgré un monde en constante évolution.',
            durationMinutes: 12,
            audioFile: 'actualite/3-la-guerre-en-bruit-de-fond.mp3',
            categoryId: 'actualite',
            isPremium: true,
          ),
          const SessionModel(
            id: 'actualite_3',
            title: 'Débrancher quand tout crie',
            description: 'Une pause consciente loin des écrans et des titres.',
            durationMinutes: 5,
            audioFile: 'actualite/2-débrancher-quand-tout-crie.mp3',
            categoryId: 'actualite',
          ),
          const SessionModel(
            id: 'actualite_4',
            title: 'Recul sur l\'actualité',
            description: 'Apprends à poser ton téléphone avec légèreté.',
            durationMinutes: 7,
            audioFile: 'actualite/1-recul-sur-lactualité.mp3',
            categoryId: 'actualite',
            isPremium: true,
          ),
          const SessionModel(
            id: 'actualite_5',
            title: 'Pause info',
            description:
                'Prends de la hauteur sur les événements du monde.',
            durationMinutes: 10,
            audioFile: 'actualite/0-pause-info.mp3',
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
            title: 'Quand le stress prend le dessus',
            description:
                'Une technique de respiration puissante pour calmer le système nerveux.',
            durationMinutes: 5,
            audioFile: 'stress/0-quand-le-stress-prend-le-dessu.mp3',
            categoryId: 'stress',
          ),
          const SessionModel(
            id: 'stress_2',
            title: 'Respiration 4-7-8',
            description: 'Parcours ton corps pour relâcher les tensions.',
            durationMinutes: 15,
            audioFile: 'stress/1-4-7-8.mp3',
            categoryId: 'stress',
            isPremium: true,
          ),
          const SessionModel(
            id: 'stress_3',
            title: 'Relâche',
            description:
                'Contracte et relâche chaque groupe musculaire pour libérer le stress physique.',
            durationMinutes: 8,
            audioFile: 'stress/2-relache.mp3',
            categoryId: 'stress',
          ),
          const SessionModel(
            id: 'stress_4',
            title: 'Ancrage',
            description:
                'Reviens à toi en 3 minutes grâce à une technique d\'ancrage simple.',
            durationMinutes: 3,
            audioFile: 'stress/3-ancrage.mp3',
            categoryId: 'stress',
          ),
          const SessionModel(
            id: 'stress_5',
            title: 'Le voyageur qui s\'arrête',
            description:
                'Dissolve les tensions mentales et retrouve un état de calme profond.',
            durationMinutes: 10,
            audioFile: 'stress/4-le-voyageur-qui-sarrête.mp3',
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
            audioFile: 'sleep/3-détente-du-soir.mp3',
            categoryId: 'sleep',
          ),
          const SessionModel(
            id: 'sleep_2',
            title: 'Visualisation apaisante',
            description: 'Voyage mental dans un lieu calme et sécurisant.',
            durationMinutes: 20,
            audioFile: 'sleep/2-visualisation-apaisante.mp3',
            categoryId: 'sleep',
            isPremium: true,
          ),
          const SessionModel(
            id: 'sleep_3',
            title: 'Rituel pré-sommeil',
            description:
                'Un rituel de 7 minutes pour signaler à ton corps qu\'il est temps de dormir.',
            durationMinutes: 7,
            audioFile: 'sleep/1-rituel-pré-sommeil.mp3',
            categoryId: 'sleep',
          ),
          const SessionModel(
            id: 'sleep_4',
            title: 'Entre deux mondes',
            description:
                'Une respiration lente et profonde pour ralentir le système nerveux.',
            durationMinutes: 5,
            audioFile: 'sleep/0-entre-deux-mondes.mp3',
            categoryId: 'sleep',
          ),
          const SessionModel(
            id: 'sleep_5',
            title: 'Plongée dans le silence',
            description:
                'Laisse les pensées se dissoudre dans un silence bienveillant.',
            durationMinutes: 12,
            audioFile: 'sleep/4-plongée-dans-le-silence.mp3',
            categoryId: 'sleep',
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
            audioFile: 'breathing/3-cohérence-cardiaque.mp3',
            categoryId: 'breathing',
          ),
          const SessionModel(
            id: 'breathing_2',
            title: 'Respiration alternée',
            description:
                'Équilibre les deux hémisphères cérébraux par la respiration nasale alternée.',
            durationMinutes: 7,
            audioFile: 'breathing/2-respiration-alternée.mp3',
            categoryId: 'breathing',
            isPremium: true,
          ),
          const SessionModel(
            id: 'breathing_3',
            title: 'Souffle apaisant',
            description:
                'Un rythme respiratoire lent pour calmer l\'agitation intérieure.',
            durationMinutes: 3,
            audioFile: 'breathing/1-souffle-apaisant.mp3',
            categoryId: 'breathing',
          ),
          const SessionModel(
            id: 'breathing_4',
            title: 'Expansion thoracique',
            description:
                'Ouvre la cage thoracique et libère les tensions respiratoires.',
            durationMinutes: 8,
            audioFile: 'breathing/0-expansion-thoracique.mp3',
            categoryId: 'breathing',
            isPremium: true,
          ),
        ],
      ),
      CategoryModel(
        id: 'emotion',
        name: 'Émotions',
        emoji: '💛',
        description:
            'Explore et apprivoise tes émotions. Accueille ce que tu ressens avec douceur et bienveillance.',
        isPremium: true,
        isNew: false,
        sessions: [
          const SessionModel(
            id: 'emotion_1',
            title: 'Apprendre à s\'aimer',
            description:
                'Pose un regard doux et bienveillant sur toi-même.',
            durationMinutes: 8,
            audioFile: 'Emotion/0-lamour.mp3',
            categoryId: 'emotion',
          ),
          const SessionModel(
            id: 'emotion_2',
            title: 'Joie et énergie',
            description:
                'Reconnecte-toi à ta joie naturelle et à ta vitalité.',
            durationMinutes: 7,
            audioFile: 'Emotion/3-joie-et-énergie.mp3',
            categoryId: 'emotion',
            isPremium: true,
          ),
          const SessionModel(
            id: 'emotion_3',
            title: 'De l\'anxiété au sourire',
            description:
                'Transforme doucement l\'anxiété en légèreté et sérénité.',
            durationMinutes: 10,
            audioFile: 'Emotion/2-de-lanxiété-au-sourire.mp3',
            categoryId: 'emotion',
            isPremium: true,
          ),
          const SessionModel(
            id: 'emotion_4',
            title: 'Peur et courage',
            description:
                'Accueille ta peur et découvre le courage qui se cache derrière.',
            durationMinutes: 9,
            audioFile: 'Emotion/1-peur-et-courage.mp3',
            categoryId: 'emotion',
          ),
          const SessionModel(
            id: 'emotion_5',
            title: 'L\'amour',
            description:
                'Cultive l\'amour inconditionnel envers toi-même et les autres.',
            durationMinutes: 12,
            audioFile: 'Emotion/4-apprendre-à-saimer.mp3',
            categoryId: 'emotion',
            isPremium: true,
          ),
        ],
      ),
    ];
  }
}
