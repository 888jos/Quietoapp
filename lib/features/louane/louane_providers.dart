import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/louane_message.dart';
import 'data/louane_repository.dart';

final louaneRepositoryProvider = Provider<LouaneRepository>(
  (_) => LouaneRepository(),
);

/// État de la conversation : la liste des messages + si Louane est en train
/// d'écrire (pour afficher l'indicateur "…").
class LouaneChatState {
  final List<LouaneMessage> messages;
  final bool louaneEcrit;

  const LouaneChatState({
    this.messages = const [],
    this.louaneEcrit = false,
  });

  LouaneChatState copyWith({
    List<LouaneMessage>? messages,
    bool? louaneEcrit,
  }) {
    return LouaneChatState(
      messages: messages ?? this.messages,
      louaneEcrit: louaneEcrit ?? this.louaneEcrit,
    );
  }
}

class LouaneChatNotifier extends StateNotifier<LouaneChatState> {
  final LouaneRepository _repo;

  LouaneChatNotifier(this._repo)
      : super(const LouaneChatState(messages: [
          LouaneMessage(
            auteur: AuteurMessage.louane,
            texte: "Coucou, moi c'est Louane 🌸 Je suis là, rien que pour "
                "toi. Comment tu te sens, en ce moment ?",
          ),
        ]));

  Future<void> envoyer(String texte) async {
    final t = texte.trim();
    if (t.isEmpty || state.louaneEcrit) return;

    final avecUser = [
      ...state.messages,
      LouaneMessage(auteur: AuteurMessage.user, texte: t),
    ];
    state = state.copyWith(messages: avecUser, louaneEcrit: true);

    try {
      final reponse = await _repo.envoyer(t, _historiquePourApi(avecUser));
      state = state.copyWith(
        messages: [
          ...state.messages,
          LouaneMessage(auteur: AuteurMessage.louane, texte: reponse),
        ],
        louaneEcrit: false,
      );
    } catch (_) {
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
  (ref) => LouaneChatNotifier(ref.watch(louaneRepositoryProvider)),
);
