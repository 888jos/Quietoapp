import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/storage_providers.dart';
import 'data/louane_message.dart';
import 'data/louane_repository.dart';

final louaneRepositoryProvider = Provider<LouaneRepository>(
  // subscriptionProvider est LU (read) et non observé (watch) : un achat en
  // pleine conversation ne doit pas reconstruire le repo → ce qui remettrait
  // la conversation à zéro via louaneChatProvider.
  (ref) => LouaneRepository(
    ref.watch(storageServiceProvider),
    () => ref.read(subscriptionProvider),
  ),
);

/// État de la conversation : la liste des messages + si Louane est en train
/// d'écrire (pour afficher l'indicateur "…"). [plafondEvenement] s'incrémente
/// chaque fois que le serveur signale le plafond du jour — la page l'écoute
/// pour faire glisser la feuille « Louane se repose ».
class LouaneChatState {
  final List<LouaneMessage> messages;
  final bool louaneEcrit;
  final int plafondEvenement;

  const LouaneChatState({
    this.messages = const [],
    this.louaneEcrit = false,
    this.plafondEvenement = 0,
  });

  LouaneChatState copyWith({
    List<LouaneMessage>? messages,
    bool? louaneEcrit,
    int? plafondEvenement,
  }) {
    return LouaneChatState(
      messages: messages ?? this.messages,
      louaneEcrit: louaneEcrit ?? this.louaneEcrit,
      plafondEvenement: plafondEvenement ?? this.plafondEvenement,
    );
  }
}

class LouaneChatNotifier extends StateNotifier<LouaneChatState> {
  final LouaneRepository _repo;
  final bool Function() _estAbonne;

  LouaneChatNotifier(this._repo, this._estAbonne)
      : super(const LouaneChatState(messages: [
          LouaneMessage(
            auteur: AuteurMessage.louane,
            texte: "Coucou, moi c'est Louane 🌸 Je suis là, rien que pour "
                "toi. Comment tu te sens, en ce moment ?",
          ),
        ]));

  /// Fin des 15 messages découverte — le mot de Louane validé (en attendant
  /// le vrai écran d'abonnement, branché avec StoreKit plus tard).
  static const _motPaywall =
      "J'ai adoré faire ta connaissance. Pour qu'on continue à se parler "
      "tous les jours, il y a Quieto Premium, et tu peux l'essayer 7 jours "
      "gratuitement. Je t'attends 🤍";

  /// Frein anti-spam : au-delà de [_maxRefusVerifies] refus (paywall/plafond)
  /// d'affilée, on cesse d'appeler le serveur — même le Veilleur (0,08 ¢/msg)
  /// ne doit pas tourner en boucle pour quelqu'un qui force. L'éthique reste
  /// couverte : le 3114 est écrit en toutes lettres dans la réponse locale.
  static const _maxRefusVerifies = 5;
  int _refusDeSuite = 0;
  bool _refusSousAbonne = false; // statut abonné au moment du dernier refus

  static const _motStop =
      "Je dois vraiment te laisser pour aujourd'hui 🤍 Et surtout, si tu "
      "traverses un moment difficile, le 3114 est là pour toi, 24h/24 et "
      "gratuitement.";

  Future<void> envoyer(String texte) async {
    final t = texte.trim();
    if (t.isEmpty || state.louaneEcrit) return;

    final avecUser = [
      ...state.messages,
      LouaneMessage(auteur: AuteurMessage.user, texte: t),
    ];
    state = state.copyWith(messages: avecUser, louaneEcrit: true);

    // Le statut d'abonnement a changé depuis le dernier refus (la personne
    // vient de s'abonner, par exemple) → on relâche le frein : le serveur
    // retranchera les vraies limites lui-même.
    if (_refusDeSuite > 0 && _estAbonne() != _refusSousAbonne) {
      _refusDeSuite = 0;
    }

    // Frein anti-spam : trop de refus d'affilée → réponse locale, zéro appel
    // serveur, zéro coût. Le 3114 reste écrit noir sur blanc.
    if (_refusDeSuite >= _maxRefusVerifies) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          const LouaneMessage(auteur: AuteurMessage.louane, texte: _motStop),
        ],
        louaneEcrit: false,
      );
      return;
    }

    try {
      final reponse = await _repo.envoyer(t, _historiquePourApi(avecUser));

      // Plafond du jour atteint : pas de réponse, Louane dort — on prévient
      // la page (feuille qui glisse) sans rien ajouter au fil.
      if (reponse.plafond && reponse.texte.isEmpty) {
        _refusDeSuite++;
        _refusSousAbonne = _estAbonne();
        state = state.copyWith(
          louaneEcrit: false,
          plafondEvenement: state.plafondEvenement + 1,
        );
        return;
      }

      // Messages découverte épuisés : Louane le dit avec ses mots, et la
      // page affiche le bouton « essai gratuit » sous la bulle.
      if (reponse.paywall && reponse.texte.isEmpty) {
        _refusDeSuite++;
        _refusSousAbonne = _estAbonne();
        state = state.copyWith(
          messages: [
            ...state.messages,
            const LouaneMessage(
              auteur: AuteurMessage.louane,
              texte: _motPaywall,
              avecBoutonEssai: true,
            ),
          ],
          louaneEcrit: false,
        );
        return;
      }

      // Vraie réponse de Louane (ou message de sécurité du Veilleur).
      _refusDeSuite = 0;
      state = state.copyWith(
        messages: [
          ...state.messages,
          LouaneMessage(auteur: AuteurMessage.louane, texte: reponse.texte),
        ],
        louaneEcrit: false,
      );
    } catch (e) {
      // L'erreur reste visible en console — le message doux, lui, à l'écran.
      debugPrint('[Louane] envoi échoué : $e');
      state = state.copyWith(
        messages: [
          ...state.messages,
          const LouaneMessage(
            auteur: AuteurMessage.louane,
            texte: "Je n'arrive pas à te répondre là, tout de suite… "
                "On réessaie dans un instant ?",
          ),
        ],
        louaneEcrit: false,
      );
    }
  }

  /// Transforme la conversation au format attendu par l'API (rôles
  /// user/assistant). On retire le dernier message (envoyé séparément) et tout
  /// message "assistant" en tête (ex: le mot d'accueil), car l'API exige que
  /// la conversation commence par un message "user".
  List<Map<String, String>> _historiquePourApi(List<LouaneMessage> tous) {
    final precedents = tous.sublist(0, tous.length - 1);
    final mapped = precedents
        .map((m) => {
              'role': m.estLouane ? 'assistant' : 'user',
              'content': m.texte,
            })
        .toList();
    while (mapped.isNotEmpty && mapped.first['role'] == 'assistant') {
      mapped.removeAt(0);
    }
    return mapped;
  }
}

final louaneChatProvider =
    StateNotifierProvider<LouaneChatNotifier, LouaneChatState>(
  (ref) => LouaneChatNotifier(
    ref.watch(louaneRepositoryProvider),
    () => ref.read(subscriptionProvider),
  ),
);
