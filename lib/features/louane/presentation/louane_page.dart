import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../louane_providers.dart';
import 'louane_palette.dart';
import 'widgets/louane_personnage.dart';
import 'widgets/message_bubble.dart';

enum ModeLouane { ecrit, oral }

class LouanePage extends ConsumerStatefulWidget {
  const LouanePage({super.key});

  @override
  ConsumerState<LouanePage> createState() => _LouanePageState();
}

class _LouanePageState extends ConsumerState<LouanePage>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _speechDispo = false;
  bool _ecoute = false; // micro en écoute
  bool _louaneParle = false; // TTS en cours
  String _texteReconnu = '';

  ModeLouane _mode = ModeLouane.ecrit;

  // Bascule écrit ↔ oral (0 = écrit, 1 = oral) : un seul personnage glisse du
  // haut vers le centre en grandissant, pendant que le contenu écrit descend
  // et s'efface, et que le ciel étoilé apparaît.
  late final AnimationController _modeAnim;

  @override
  void initState() {
    super.initState();
    _modeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _initSpeech();
    _initTts();
    WidgetsBinding.instance.addPostFrameCallback((_) => _versLeBas());
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _modeAnim.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Init voix ───────────────────────────────────────────
  Future<void> _initSpeech() async {
    try {
      _speechDispo = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: (_) {
          if (mounted) setState(() => _ecoute = false);
        },
      );
    } catch (_) {
      _speechDispo = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _initTts() async {
    try {
      if (Platform.isIOS) {
        await _tts.setSharedInstance(true);
      }
      await _tts.setLanguage('fr-FR');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _louaneParle = false);
      });
      _tts.setCancelHandler(() {
        if (mounted) setState(() => _louaneParle = false);
      });
    } catch (_) {}
  }

  // ── Écoute micro ────────────────────────────────────────
  void _onSpeechStatus(String status) {
    if (!mounted) return;
    if (status == 'done' || status == 'notListening') {
      final etaitEcoute = _ecoute;
      setState(() => _ecoute = false);
      // En mode oral : on envoie automatiquement ce qui a été dit.
      if (etaitEcoute && _mode == ModeLouane.oral) {
        final t = _texteReconnu.trim();
        _texteReconnu = '';
        if (t.isNotEmpty) {
          ref.read(louaneChatProvider.notifier).envoyer(t);
        }
      }
    }
  }

  Future<void> _demarreEcouteOrale() async {
    if (_louaneParle) {
      await _tts.stop();
      if (mounted) setState(() => _louaneParle = false);
    }
    if (!_speechDispo) {
      _speechDispo = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: (_) {
          if (mounted) setState(() => _ecoute = false);
        },
      );
    }
    if (!_speechDispo || !mounted) return;
    _texteReconnu = '';
    setState(() => _ecoute = true);
    try {
      await _speech.listen(
        onResult: (r) => _texteReconnu = r.recognizedWords,
        listenOptions: SpeechListenOptions(
          localeId: 'fr_FR',
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _ecoute = false);
    }
  }

  Future<void> _toggleMicroOral() async {
    if (_ecoute) {
      await _speech.stop(); // le status handler enverra le texte
      return;
    }
    await _demarreEcouteOrale();
  }

  // ── Louane parle (TTS) ──────────────────────────────────
  Future<void> _parler(String texte) async {
    final t = _sansEmoji(texte).trim();
    if (t.isEmpty) return;
    if (mounted) setState(() => _louaneParle = true);
    await _tts.stop();
    await _tts.speak(t);
  }

  String _sansEmoji(String s) => s.replaceAll(
        RegExp(
          r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2190}-\u{21FF}\u{2B00}-\u{2BFF}️]',
          unicode: true,
        ),
        '',
      );

  // ── Mode ────────────────────────────────────────────────
  void _changerMode(ModeLouane m) {
    if (m == _mode) return;
    _speech.stop();
    _tts.stop();
    setState(() {
      _mode = m;
      _ecoute = false;
      _louaneParle = false;
    });
    // Glisse en douceur vers le nouveau mode (le personnage se déplace).
    if (m == ModeLouane.oral) {
      _modeAnim.forward();
    } else {
      _modeAnim.reverse();
    }
  }

  void _passerEnOral() => _changerMode(ModeLouane.oral);

  // ── Envoi écrit ─────────────────────────────────────────
  void _envoyer() {
    final texte = _controller.text;
    if (texte.trim().isEmpty) return;
    _controller.clear();
    ref.read(louaneChatProvider.notifier).envoyer(texte);
    _versLeBas();
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

    // Nouveau message de Louane → en mode oral, elle le dit à voix haute.
    ref.listen(louaneChatProvider, (prev, next) {
      _versLeBas();
      if (_mode != ModeLouane.oral) return;
      final avant = prev?.messages.length ?? 0;
      if (next.messages.length > avant && next.messages.last.estLouane) {
        _parler(next.messages.last.texte);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _SelecteurMode(mode: _mode, onChange: _changerMode),
            Expanded(child: _corps(chat)),
          ],
        ),
      ),
    );
  }

  // ── Corps : écrit ↔ oral en un seul mouvement continu ─────
  Widget _corps(LouaneChatState chat) {
    final estOral = _mode == ModeLouane.oral;
    final clavier = MediaQuery.of(context).viewInsets.bottom > 0;
    return AnimatedBuilder(
      animation: _modeAnim,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(_modeAnim.value);
        return LayoutBuilder(
          builder: (context, c) {
            final h = c.maxHeight;
            // Centre vertical du personnage : en haut (écrit) → centre (oral).
            final yEcrit = clavier ? 66.0 : 110.0;
            final yOral = h * 0.40;
            final yC = yEcrit + (yOral - yEcrit) * t;
            // Taille : grandit un peu en arrivant au centre.
            final scEcrit = clavier ? 0.5 : 1.0;
            final scale = scEcrit + (1.25 - scEcrit) * t;
            return Stack(
              children: [
                // 1. Ciel étoilé plein écran (apparaît en mode oral).
                if (t > 0.001)
                  Positioned.fill(
                    child: Opacity(opacity: t, child: const CielEtoileFond()),
                  ),
                // 2. Conversation écrite : glisse vers le bas en s'effaçant.
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: estOral,
                    child: Opacity(
                      opacity: (1 - t).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, t * 90),
                        child: _contenuEcrit(chat, clavier),
                      ),
                    ),
                  ),
                ),
                // 3. Le personnage : UN SEUL élément qui glisse et grandit.
                Positioned(
                  top: yC - 95,
                  left: 0,
                  right: 0,
                  height: 190,
                  child: Transform.scale(
                    scale: scale,
                    child: LouanePersonnage(
                      parle: estOral ? _louaneParle : chat.louaneEcrit,
                      ecoute: estOral ? _ecoute : false,
                      sansCiel: true,
                    ),
                  ),
                ),
                // 4. Bouton micro (mode oral) : apparaît en bas.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 28,
                  child: IgnorePointer(
                    ignoring: !estOral,
                    child: Opacity(
                      opacity: t,
                      child: Center(
                        child: _GrosBoutonMicro(
                          actif: _ecoute,
                          onTap: _toggleMicroOral,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Conversation écrite (sans le personnage, qui flotte au-dessus).
  Widget _contenuEcrit(LouaneChatState chat, bool clavier) {
    final nbItems = chat.messages.length + (chat.louaneEcrit ? 1 : 0);
    final espaceHaut = clavier ? 120.0 : 210.0; // réserve la place du personnage
    return Column(
      children: [
        SizedBox(height: espaceHaut),
        const Divider(height: 1, color: AppColors.accentDim),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: nbItems,
            itemBuilder: (context, i) {
              if (i >= chat.messages.length) return const TypingBubble();
              return MessageBubble(message: chat.messages[i]);
            },
          ),
        ),
        _BarreSaisie(
          controller: _controller,
          onEnvoyer: _envoyer,
          onMic: _passerEnOral,
        ),
      ],
    );
  }
}

// ── Sélecteur Écrit / Oral ────────────────────────────────
class _SelecteurMode extends StatelessWidget {
  final ModeLouane mode;
  final ValueChanged<ModeLouane> onChange;

  const _SelecteurMode({required this.mode, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            _pill('À l\'écrit', ModeLouane.ecrit),
            _pill('À l\'oral', ModeLouane.oral),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, ModeLouane m) {
    final actif = mode == m;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChange(m),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: actif ? LouanePalette.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelLarge.copyWith(
              color: actif ? AppColors.background : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Barre de saisie (écrit) ───────────────────────────────
class _BarreSaisie extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onEnvoyer;
  final VoidCallback onMic;

  const _BarreSaisie({
    required this.controller,
    required this.onEnvoyer,
    required this.onMic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.accentDim, width: 1)),
      ),
      child: Row(
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
              if (aTexte) {
                return _BoutonRond(
                  icon: Icons.arrow_upward_rounded,
                  couleur: LouanePalette.accent,
                  iconColor: AppColors.background,
                  onTap: onEnvoyer,
                );
              }
              return _BoutonRond(
                icon: Icons.mic_none_rounded,
                couleur: AppColors.cardSurface,
                iconColor: AppColors.textMuted,
                onTap: onMic,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BoutonRond extends StatelessWidget {
  final IconData icon;
  final Color couleur;
  final Color iconColor;
  final VoidCallback onTap;

  const _BoutonRond({
    required this.icon,
    required this.couleur,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor),
      ),
    );
  }
}

// ── Gros bouton micro (oral) ──────────────────────────────
class _GrosBoutonMicro extends StatefulWidget {
  final bool actif;
  final VoidCallback onTap;

  const _GrosBoutonMicro({required this.actif, required this.onTap});

  @override
  State<_GrosBoutonMicro> createState() => _GrosBoutonMicroState();
}

class _GrosBoutonMicroState extends State<_GrosBoutonMicro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final couleur = widget.actif ? AppColors.error : LouanePalette.accent;
          final glow = widget.actif ? (0.35 + 0.4 * _c.value) : 0.25;
          return Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: couleur,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: couleur.withValues(alpha: glow),
                  blurRadius: 24,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Icon(
              widget.actif ? Icons.mic : Icons.mic_none_rounded,
              color: Colors.white,
              size: 32,
            ),
          );
        },
      ),
    );
  }
}
