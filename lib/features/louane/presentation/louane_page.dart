import 'dart:async';
import 'dart:math' show sin, pi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../app/router.dart';
import '../../../core/services/storage_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../louane_providers.dart';
import 'louane_palette.dart';
import 'widgets/louane_avatar.dart';
import 'widgets/louane_sommeil_sheet.dart';
import 'widgets/message_bubble.dart';

/// État de la dictée vocale.
enum _EtatVocal { inactif, ecoute, pause }

/// Page Louane : une conversation à l'écrit, façon WhatsApp.
/// En haut un bandeau « profil ». Au milieu le fil de bulles. En bas, la barre
/// de saisie : champ texte + bouton micro (champ vide → appui = on dicte) qui
/// passe à « envoyer » dès qu'on écrit. Pendant la dictée : annuler · pause ·
/// terminer (façon WhatsApp), avec une vague qui réagit quand on parle. Le
/// vocal est transcrit, déposé dans le champ pour relecture, puis envoyé.
class LouanePage extends ConsumerStatefulWidget {
  const LouanePage({super.key});

  @override
  ConsumerState<LouanePage> createState() => _LouanePageState();
}

class _LouanePageState extends ConsumerState<LouanePage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  // Reconnaissance vocale (dictée).
  final SpeechToText _speech = SpeechToText();
  bool _speechDispo = false;
  _EtatVocal _vocal = _EtatVocal.inactif;
  bool _annuler = false; // session arrêtée pour annulation → ne pas remplir
  String _texteAccumule = ''; // texte figé des segments précédents
  String _texteReconnu = ''; // texte du segment d'écoute en cours
  Timer? _chrono;
  int _secondes = 0;

  // Dernier instant où des mots sont arrivés (= on parle). Sert à animer la
  // vague : récent = on parle → barres hautes ; ancien = silence → barres basses.
  final ValueNotifier<DateTime?> _dernierMot = ValueNotifier(null);

  // Nombre de messages déjà affichés : seuls les messages neufs « POP ».
  int _nbVus = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _versLeBas());
  }

  @override
  void dispose() {
    _chrono?.cancel();
    _speech.stop();
    _dernierMot.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _envoyer() {
    final texte = _controller.text;
    if (texte.trim().isEmpty) return;
    _controller.clear();
    ref.read(louaneChatProvider.notifier).envoyer(texte);
    _versLeBas();
  }

  // ── Vocal (dictée avec pause) ───────────────────────────
  void _demarrerChrono() {
    _chrono?.cancel();
    _chrono = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondes++);
    });
  }

  Future<void> _ecouter() async {
    _texteReconnu = '';
    await _speech.listen(
      onResult: (r) {
        _texteReconnu = r.recognizedWords;
        _dernierMot.value = DateTime.now(); // des mots arrivent → on parle
      },
      listenOptions: SpeechListenOptions(
        localeId: 'fr_FR',
        listenFor: const Duration(seconds: 120),
        pauseFor: const Duration(seconds: 30),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        autoPunctuation: true, // ponctuation auto (virgules, points, ?) comme le clavier
      ),
    );
  }

  Future<void> _demarrerVocal() async {
    if (!_speechDispo) {
      _speechDispo = await _speech.initialize(
        onStatus: _onStatutVocal,
        onError: (_) {
          if (mounted) setState(() => _vocal = _EtatVocal.inactif);
        },
      );
    }
    if (!_speechDispo) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Micro indisponible sur cet appareil.')),
        );
      }
      return;
    }
    HapticFeedback.lightImpact();
    _texteAccumule = '';
    _texteReconnu = '';
    _annuler = false;
    _secondes = 0;
    if (mounted) setState(() => _vocal = _EtatVocal.ecoute);
    _demarrerChrono();
    await _ecouter();
  }

  Future<void> _pauseVocal() async {
    HapticFeedback.lightImpact();
    _chrono?.cancel(); // fige le minuteur
    setState(() => _vocal = _EtatVocal.pause);
    await _speech.stop(); // le statut "done" verra l'état pause → reste en pause
  }

  Future<void> _reprendreVocal() async {
    HapticFeedback.lightImpact();
    setState(() => _vocal = _EtatVocal.ecoute);
    _demarrerChrono();
    await _ecouter();
  }

  void _finaliser() {
    _chrono?.cancel();
    final t = _texteAccumule.trim();
    _texteAccumule = '';
    _texteReconnu = '';
    setState(() {
      _vocal = _EtatVocal.inactif;
      _secondes = 0;
    });
    if (t.isNotEmpty) {
      _controller.text = t;
      _controller.selection = TextSelection.collapsed(offset: t.length);
    }
  }

  Future<void> _terminerVocal() async {
    HapticFeedback.lightImpact();
    if (_vocal == _EtatVocal.pause) {
      _finaliser(); // pas en écoute : on finalise directement
    } else {
      await _speech.stop(); // le statut "done" finalisera
    }
  }

  Future<void> _annulerVocal() async {
    HapticFeedback.lightImpact();
    // On coupe et on revient au champ texte TOUT DE SUITE, sans attendre le
    // retour de la reconnaissance (sur iPhone, cancel() ne rappelle pas
    // toujours le statut → sinon le bouton semblait ne rien faire).
    _annuler = true;
    _chrono?.cancel();
    _texteAccumule = '';
    _texteReconnu = '';
    if (mounted) {
      setState(() {
        _vocal = _EtatVocal.inactif;
        _secondes = 0;
      });
    }
    await _speech.cancel();
  }

  void _onStatutVocal(String status) {
    if (!mounted) return;
    if (status != 'done' && status != 'notListening') return;

    // Annulation : on jette tout.
    if (_annuler) {
      _annuler = false;
      _chrono?.cancel();
      _texteAccumule = '';
      _texteReconnu = '';
      setState(() {
        _vocal = _EtatVocal.inactif;
        _secondes = 0;
      });
      return;
    }

    // On fige le texte de ce segment.
    _texteAccumule = '$_texteAccumule $_texteReconnu'.trim();
    _texteReconnu = '';

    // En pause : on attend reprise / terminer.
    if (_vocal == _EtatVocal.pause) return;

    // Sinon (terminer manuel, ou arrêt auto après silence) : dépose + sort.
    _finaliser();
  }

  void _versLeBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(louaneChatProvider);

    // Mémorise quels messages ont déjà été affichés, pour n'animer (POP) que
    // les nouveaux et ne jamais rejouer l'animation lors des reconstructions.
    if (_nbVus != chat.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nbVus = chat.messages.length;
      });
    }

    // Chaque nouveau message → on redescend en bas du fil. Et si le serveur
    // signale le plafond du jour → la feuille « Louane se repose » glisse.
    ref.listen(louaneChatProvider, (avant, apres) {
      _versLeBas();
      if ((avant?.plafondEvenement ?? 0) < apres.plafondEvenement) {
        montrerLouaneSommeil(context);
      }
    });

    final nbItems = chat.messages.length + (chat.louaneEcrit ? 1 : 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _EnTete(ecrit: chat.louaneEcrit),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                itemCount: nbItems,
                itemBuilder: (context, i) {
                  if (i >= chat.messages.length) return const TypingBubble();
                  final m = chat.messages[i];
                  final bulle = MessageBubble(
                    key: ValueKey(i),
                    message: m,
                    nouveau: i >= _nbVus,
                  );
                  // Bulle de fin des 15 messages → bouton essai gratuit
                  // dessous (masqué si la personne s'est abonnée depuis).
                  if (m.avecBoutonEssai &&
                      !ref.watch(subscriptionProvider)) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [bulle, const _BoutonEssaiGratuit()],
                    );
                  }
                  return bulle;
                },
              ),
            ),
            _BarreSaisie(
              controller: _controller,
              onEnvoyer: _envoyer,
              enregistre: _vocal != _EtatVocal.inactif,
              enPause: _vocal == _EtatVocal.pause,
              secondes: _secondes,
              dernierMot: _dernierMot,
              onMic: _demarrerVocal,
              onPause: _pauseVocal,
              onReprendre: _reprendreVocal,
              onTerminer: _terminerVocal,
              onAnnuler: _annulerVocal,
            ),
          ],
        ),
      ),
    );
  }
}

// ── En-tête « profil » (façon WhatsApp) ───────────────────
class _EnTete extends StatelessWidget {
  final bool ecrit;

  const _EnTete({required this.ecrit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.accentDim, width: 1),
        ),
      ),
      child: Row(
        children: [
          LouaneAvatar(size: 44, parle: ecrit),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Louane', style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: LouanePalette.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ecrit ? 'écrit…' : 'en ligne',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bouton « essai gratuit » sous la bulle de fin des 15 ──
/// Un vrai bouton d'action : centré, généreux, avec un halo turquoise
/// STATIQUE (une lueur animée scintille sur iOS, cf. feuille sommeil).
class _BoutonEssaiGratuit extends StatelessWidget {
  const _BoutonEssaiGratuit();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF86ECE4), LouanePalette.accent],
          ),
          boxShadow: [
            BoxShadow(
              color: LouanePalette.accent.withValues(alpha: 0.45),
              blurRadius: 22,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => context.push(AppRoutes.paywallSlide),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 16),
              child: Text(
                'Commencer mon essai gratuit',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.background,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Barre de saisie ───────────────────────────────────────
class _BarreSaisie extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onEnvoyer;
  final bool enregistre;
  final bool enPause;
  final int secondes;
  final ValueNotifier<DateTime?> dernierMot;
  final VoidCallback onMic;
  final VoidCallback onPause;
  final VoidCallback onReprendre;
  final VoidCallback onTerminer;
  final VoidCallback onAnnuler;

  const _BarreSaisie({
    required this.controller,
    required this.onEnvoyer,
    required this.enregistre,
    required this.enPause,
    required this.secondes,
    required this.dernierMot,
    required this.onMic,
    required this.onPause,
    required this.onReprendre,
    required this.onTerminer,
    required this.onAnnuler,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.accentDim, width: 1)),
      ),
      child: enregistre
          ? _BandeauEnregistrement(
              enPause: enPause,
              secondes: secondes,
              dernierMot: dernierMot,
              onAnnuler: onAnnuler,
              onPause: onPause,
              onReprendre: onReprendre,
              onTerminer: onTerminer,
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppTextStyles.bodyLarge,
                    onSubmitted: (_) => onEnvoyer(),
                    decoration: InputDecoration(
                      hintText: 'Dis ce que tu as sur le cœur…',
                      hintStyle: AppTextStyles.bodyMedium,
                      filled: true,
                      fillColor: AppColors.cardSurface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final aTexte = value.text.trim().isNotEmpty;
                    return _BoutonAction(
                      aTexte: aTexte,
                      onTap: aTexte ? onEnvoyer : onMic,
                    );
                  },
                ),
              ],
            ),
    );
  }
}

/// Le bouton à droite : micro (champ vide) ↔ envoyer (dès qu'on écrit).
class _BoutonAction extends StatelessWidget {
  final bool aTexte;
  final VoidCallback onTap;

  const _BoutonAction({required this.aTexte, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Container(
          key: ValueKey(aTexte),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: aTexte ? LouanePalette.accent : AppColors.cardSurface,
            shape: BoxShape.circle,
          ),
          child: Icon(
            aTexte ? Icons.arrow_upward_rounded : Icons.mic_none_rounded,
            color: aTexte ? AppColors.background : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Pendant la dictée (2 lignes façon WhatsApp) :
/// haut = point rouge + vague (barres blanches réactives) + minuteur ;
/// bas  = 🗑️ annuler · ⏸️/🎙️ pause-reprendre · ✓ terminer.
class _BandeauEnregistrement extends StatelessWidget {
  final bool enPause;
  final int secondes;
  final ValueNotifier<DateTime?> dernierMot;
  final VoidCallback onAnnuler;
  final VoidCallback onPause;
  final VoidCallback onReprendre;
  final VoidCallback onTerminer;

  const _BandeauEnregistrement({
    required this.enPause,
    required this.secondes,
    required this.dernierMot,
    required this.onAnnuler,
    required this.onPause,
    required this.onReprendre,
    required this.onTerminer,
  });

  String get _minutage {
    final m = secondes ~/ 60;
    final s = (secondes % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ligne 1 : point + vague + minuteur.
        SizedBox(
          height: 34,
          child: Row(
            children: [
              const SizedBox(width: 4),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: enPause ? AppColors.textMuted : AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Ondes(actif: !enPause, dernierMot: dernierMot),
              ),
              const SizedBox(width: 12),
              Text(
                _minutage,
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Ligne 2 : annuler · pause/reprendre · terminer.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _PetitBouton(
              icon: Icons.delete_outline_rounded,
              taille: 46,
              couleur: AppColors.cardSurface,
              iconColor: AppColors.error,
              onTap: onAnnuler,
            ),
            _PetitBouton(
              icon: enPause ? Icons.mic_rounded : Icons.pause_rounded,
              taille: 54,
              couleur: AppColors.error,
              iconColor: Colors.white,
              onTap: enPause ? onReprendre : onPause,
            ),
            _PetitBouton(
              icon: Icons.check_rounded,
              taille: 46,
              couleur: LouanePalette.accent,
              iconColor: AppColors.background,
              onTap: onTerminer,
            ),
          ],
        ),
      ],
    );
  }
}

class _PetitBouton extends StatelessWidget {
  final IconData icon;
  final double taille;
  final Color couleur;
  final Color iconColor;
  final VoidCallback onTap;

  const _PetitBouton({
    required this.icon,
    required this.taille,
    required this.couleur,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: taille,
        height: taille,
        decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: taille * 0.46),
      ),
    );
  }
}

/// Vague de barres blanches qui remplit la largeur, ondule en continu, et
/// monte quand on parle (détecté via [dernierMot]) / s'aplatit en pause.
class _Ondes extends StatefulWidget {
  final bool actif;
  final ValueNotifier<DateTime?> dernierMot;

  const _Ondes({required this.actif, required this.dernierMot});

  @override
  State<_Ondes> createState() => _OndesState();
}

class _OndesState extends State<_Ondes> with SingleTickerProviderStateMixin {
  late final AnimationController _flow;
  double _intensite = 0; // 0 (silence/pause) → 1 (on parle), lissé

  @override
  void initState() {
    super.initState();
    _flow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flow,
      builder: (context, _) {
        final dm = widget.dernierMot.value;
        final parleRecemment = widget.actif &&
            dm != null &&
            DateTime.now().difference(dm).inMilliseconds < 380;
        // Cible : haut si on parle, bas si silence, ~0 si pause/inactif.
        final cible = !widget.actif ? 0.0 : (parleRecemment ? 1.0 : 0.2);
        _intensite += (cible - _intensite) * 0.16; // lissage
        return CustomPaint(
          size: const Size(double.infinity, 30),
          painter: _OndesPainter(phase: _flow.value, intensite: _intensite),
        );
      },
    );
  }
}

class _OndesPainter extends CustomPainter {
  final double phase; // 0 → 1 (déplacement de l'onde)
  final double intensite; // 0 → 1

  _OndesPainter({required this.phase, required this.intensite});

  @override
  void paint(Canvas canvas, Size size) {
    const n = 36;
    final gap = size.width / n;
    final paint = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..strokeWidth = gap * 0.5;
    final cy = size.height / 2;
    for (var i = 0; i < n; i++) {
      final x = gap * (i + 0.5);
      // Onde qui se déplace + petite enveloppe (centre un peu plus haut).
      final onde = (sin(phase * 2 * pi + i * 0.55) + 1) / 2; // 0 → 1
      final enveloppe =
          0.6 + 0.4 * (1 - ((i - (n - 1) / 2).abs() / ((n - 1) / 2)));
      final frac = (0.1 + 0.9 * intensite) * (0.35 + 0.65 * onde) * enveloppe;
      final h = size.height * frac.clamp(0.0, 1.0);
      canvas.drawLine(Offset(x, cy - h / 2), Offset(x, cy + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_OndesPainter old) =>
      old.phase != phase || old.intensite != intensite;
}
