import '../../../core/models/category_model.dart';
import '../../../core/models/session_model.dart';

class ExploreRepository {
  List<CategoryModel> fetchCategories() {
    return [
      // ── Express (différenciation Quieto vs Petit BamBou) ──
      CategoryModel(
        id: 'express',
        name: 'Une minute pour toi',
        emoji: '⚡',
        description:
            'Des micro-méditations pour les vrais moments de ta journée.',
        isPremium: false,
        isNew: true,
        sessions: [
          const SessionModel(
            id: 'express_1',
            title: 'Avant un appel difficile',
            description:
                'Un ancrage rapide pour arriver centré et calme à ton prochain appel.',
            durationMinutes: 1,
            audioFile: 'express-avant-un-appel-difficile.mp3',
            categoryId: 'express',
            imageFile: 'sessions/express/express_1.png',
          ),
          const SessionModel(
            id: 'express_2',
            title: 'Transports bondés',
            description:
                'Trouve ton calme intérieur même au milieu de la foule.',
            durationMinutes: 2,
            audioFile: 'express-transports-bondes.mp3',
            categoryId: 'express',
            imageFile: 'sessions/express/express_2.png',
          ),
          const SessionModel(
            id: 'express_3',
            title: 'Petit déjeuner',
            description:
                'Une minute de gratitude pour bien commencer ta journée.',
            durationMinutes: 2,
            audioFile: 'express-petit-dejeuner.mp3',
            categoryId: 'express',
            imageFile: 'sessions/express/express_3.png',
          ),
          const SessionModel(
            id: 'express_4',
            title: 'Juste avant de dormir',
            description:
                'Relâche les tensions de la journée en 3 minutes pour mieux t\'endormir.',
            durationMinutes: 3,
            audioFile: 'express-juste-avant-de-dormir.mp3',
            categoryId: 'express',
            imageFile: 'sessions/express/express_4.png',
          ),
          const SessionModel(
            id: 'express_5',
            title: 'Coup de stress au boulot',
            description:
                'Quand la pression monte, reprends le contrôle en 90 secondes.',
            durationMinutes: 2,
            audioFile: 'express-coup-de-stress-au-boulot.mp3',
            categoryId: 'express',
            isPremium: true,
            imageFile: 'sessions/express/express_5.png',
          ),
          const SessionModel(
            id: 'express_6',
            title: 'Après une dispute',
            description:
                'Reconnecte-toi à toi-même quand l\'émotion a pris le dessus.',
            durationMinutes: 2,
            audioFile: 'express-apres-une-dispute.mp3',
            categoryId: 'express',
            isPremium: true,
            imageFile: 'sessions/express/express_6.png',
          ),
          const SessionModel(
            id: 'express_7',
            title: 'Réveil en panique',
            description:
                'Calme ton cœur quand tu te réveilles avec l\'angoisse au ventre.',
            durationMinutes: 1,
            audioFile: 'express-reveil-en-panique.mp3',
            categoryId: 'express',
            isPremium: true,
            imageFile: 'sessions/express/express_7.png',
          ),
          const SessionModel(
            id: 'express_8',
            title: 'Avant une présentation',
            description:
                'Calme le trac avant de prendre la parole en public, en présentation ou en examen.',
            durationMinutes: 2,
            audioFile: 'express-avant-une-presentation.mp3',
            categoryId: 'express',
            isPremium: true,
            imageFile: 'sessions/express/express_8.png',
          ),
        ],
      ),

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
            audioFile: '01-decouverte-premiere-meditation.mp3',
            categoryId: 'decouverte',
            imageFile: 'sessions/decouverte/decouverte_1.png',
          ),
          const SessionModel(
            id: 'decouverte_2',
            title: 'Observer sans juger',
            description:
                'Apprends à accueillir tes pensées sans t\'y attacher.',
            durationMinutes: 6,
            audioFile: '02-decouverte-observer-sans-juger.mp3',
            categoryId: 'decouverte',
            imageFile: 'sessions/decouverte/decouverte_2.png',
          ),
          const SessionModel(
            id: 'decouverte_3',
            title: 'Le moment présent',
            description:
                'Entraîne-toi à revenir ici et maintenant, encore et encore.',
            durationMinutes: 8,
            audioFile: '03-decouverte-moment-present.mp3',
            categoryId: 'decouverte',
            imageFile: 'sessions/decouverte/decouverte_3.png',
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
            audioFile: '23-actualite-quand-le-monde-brule.mp3',
            categoryId: 'actualite',
            imageFile: 'sessions/actualite/actualite_1.png',
          ),
          const SessionModel(
            id: 'actualite_2',
            title: 'La guerre en bruit de fond',
            description:
                'Trouve la sérénité malgré un monde en constante évolution.',
            durationMinutes: 12,
            audioFile: '24-actualite-la-guerre-en-bruit-de-fond.mp3',
            categoryId: 'actualite',
            isPremium: true,
            imageFile: 'sessions/actualite/actualite_2.png',
          ),
          const SessionModel(
            id: 'actualite_3',
            title: 'Débrancher quand tout crie',
            description: 'Une pause consciente loin des écrans et des titres.',
            durationMinutes: 5,
            audioFile: '25-actualite-debrancher-quand-tout-crie.mp3',
            categoryId: 'actualite',
            imageFile: 'sessions/actualite/actualite_3.png',
          ),
          const SessionModel(
            id: 'actualite_4',
            title: 'Recul sur l\'actualité',
            description: 'Apprends à poser ton téléphone avec légèreté.',
            durationMinutes: 7,
            audioFile: '26-actualite-recul-sur-lactualite.mp3',
            categoryId: 'actualite',
            isPremium: true,
            imageFile: 'sessions/actualite/actualite_4.png',
          ),
          const SessionModel(
            id: 'actualite_5',
            title: 'Pause info',
            description:
                'Prends de la hauteur sur les événements du monde.',
            durationMinutes: 10,
            audioFile: '27-actualite-pause-info.mp3',
            categoryId: 'actualite',
            isPremium: true,
            imageFile: 'sessions/actualite/actualite_5.png',
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
            audioFile: '08-stress-quand-le-stress-prend-le-dessus.mp3',
            categoryId: 'stress',
            imageFile: 'sessions/stress/stress_1.png',
          ),
          const SessionModel(
            id: 'stress_2',
            title: 'Respiration 4-7-8',
            description: 'Parcours ton corps pour relâcher les tensions.',
            durationMinutes: 15,
            audioFile: '09-stress-respiration-4-7-8.mp3',
            categoryId: 'stress',
            isPremium: true,
            imageFile: 'sessions/stress/stress_2.png',
          ),
          const SessionModel(
            id: 'stress_3',
            title: 'Relâche',
            description:
                'Contracte et relâche chaque groupe musculaire pour libérer le stress physique.',
            durationMinutes: 8,
            audioFile: '10-stress-relache.mp3',
            categoryId: 'stress',
            imageFile: 'sessions/stress/stress_3.png',
          ),
          const SessionModel(
            id: 'stress_4',
            title: 'Ancrage',
            description:
                'Reviens à toi en 3 minutes grâce à une technique d\'ancrage simple.',
            durationMinutes: 3,
            audioFile: '11-stress-ancrage.mp3',
            categoryId: 'stress',
            imageFile: 'sessions/stress/stress_4.png',
          ),
          const SessionModel(
            id: 'stress_5',
            title: 'Le voyageur qui s\'arrête',
            description:
                'Dissolve les tensions mentales et retrouve un état de calme profond.',
            durationMinutes: 10,
            audioFile: '12-stress-le-voyageur-qui-sarrete.mp3',
            categoryId: 'stress',
            isPremium: true,
            imageFile: 'sessions/stress/stress_5.png',
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
            audioFile: '13-sommeil-detente-du-soir.mp3',
            categoryId: 'sleep',
            imageFile: 'sessions/sleep/sleep_1.png',
          ),
          const SessionModel(
            id: 'sleep_2',
            title: 'Visualisation apaisante',
            description: 'Voyage mental dans un lieu calme et sécurisant.',
            durationMinutes: 20,
            audioFile: '14-sommeil-visualisation-apaisante.mp3',
            categoryId: 'sleep',
            isPremium: true,
            imageFile: 'sessions/sleep/sleep_2.png',
          ),
          const SessionModel(
            id: 'sleep_3',
            title: 'Rituel pré-sommeil',
            description:
                'Un rituel de 7 minutes pour signaler à ton corps qu\'il est temps de dormir.',
            durationMinutes: 7,
            audioFile: '15-sommeil-rituel-pre-sommeil.mp3',
            categoryId: 'sleep',
            imageFile: 'sessions/sleep/sleep_3.png',
          ),
          const SessionModel(
            id: 'sleep_4',
            title: 'Entre deux mondes',
            description:
                'Une respiration lente et profonde pour ralentir le système nerveux.',
            durationMinutes: 5,
            audioFile: '16-sommeil-entre-deux-mondes.mp3',
            categoryId: 'sleep',
            imageFile: 'sessions/sleep/sleep_4.png',
          ),
          const SessionModel(
            id: 'sleep_5',
            title: 'Plongée dans le silence',
            description:
                'Laisse les pensées se dissoudre dans un silence bienveillant.',
            durationMinutes: 12,
            audioFile: '17-sommeil-plongee-dans-le-silence.mp3',
            categoryId: 'sleep',
            isPremium: true,
            imageFile: 'sessions/sleep/sleep_5.png',
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
            audioFile: '04-respiration-coherence-cardiaque.mp3',
            categoryId: 'breathing',
            imageFile: 'sessions/breathing/breathing_1.png',
          ),
          const SessionModel(
            id: 'breathing_2',
            title: 'Respiration alternée',
            description:
                'Équilibre les deux hémisphères cérébraux par la respiration nasale alternée.',
            durationMinutes: 7,
            audioFile: '05-respiration-respiration-alternee.mp3',
            categoryId: 'breathing',
            isPremium: true,
            imageFile: 'sessions/breathing/breathing_2.png',
          ),
          const SessionModel(
            id: 'breathing_3',
            title: 'Souffle apaisant',
            description:
                'Un rythme respiratoire lent pour calmer l\'agitation intérieure.',
            durationMinutes: 3,
            audioFile: '06-respiration-souffle-apaisant.mp3',
            categoryId: 'breathing',
            imageFile: 'sessions/breathing/breathing_3.png',
          ),
          const SessionModel(
            id: 'breathing_4',
            title: 'Expansion thoracique',
            description:
                'Ouvre la cage thoracique et libère les tensions respiratoires.',
            durationMinutes: 8,
            audioFile: '07-respiration-expansion-thoracique.mp3',
            categoryId: 'breathing',
            isPremium: true,
            imageFile: 'sessions/breathing/breathing_4.png',
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
            audioFile: '18-emotion-apprendre-a-saimer.mp3',
            categoryId: 'emotion',
            imageFile: 'sessions/emotion/emotion_1.png',
          ),
          const SessionModel(
            id: 'emotion_2',
            title: 'Joie et énergie',
            description:
                'Reconnecte-toi à ta joie naturelle et à ta vitalité.',
            durationMinutes: 7,
            audioFile: '19-emotion-joie-et-energie.mp3',
            categoryId: 'emotion',
            isPremium: true,
            imageFile: 'sessions/emotion/emotion_2.png',
          ),
          const SessionModel(
            id: 'emotion_3',
            title: 'De l\'anxiété au sourire',
            description:
                'Transforme doucement l\'anxiété en légèreté et sérénité.',
            durationMinutes: 10,
            audioFile: '20-emotion-de-lanxiete-au-sourire.mp3',
            categoryId: 'emotion',
            isPremium: true,
            imageFile: 'sessions/emotion/emotion_3.png',
          ),
          const SessionModel(
            id: 'emotion_4',
            title: 'Peur et courage',
            description:
                'Accueille ta peur et découvre le courage qui se cache derrière.',
            durationMinutes: 9,
            audioFile: '21-emotion-peur-et-courage.mp3',
            categoryId: 'emotion',
            imageFile: 'sessions/emotion/emotion_4.png',
          ),
          const SessionModel(
            id: 'emotion_5',
            title: 'L\'amour',
            description:
                'Cultive l\'amour inconditionnel envers toi-même et les autres.',
            durationMinutes: 12,
            audioFile: '22-emotion-lamour.mp3',
            categoryId: 'emotion',
            isPremium: true,
            imageFile: 'sessions/emotion/emotion_5.png',
          ),
        ],
      ),
    ];
  }
}
