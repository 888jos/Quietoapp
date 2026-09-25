import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HapticFeedback, LengthLimitingTextInputFormatter;
import '../../features/louane/presentation/widgets/louane_avatar.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'starry_background.dart';

/// Ce que la personne a répondu à la première question de la carte.
enum AvisChoix { oui, non, ignore }

/// Les raisons proposées à qui répond « Pas vraiment ». Les CLÉS (jamais les
/// libellés) partent au serveur, qui n'accepte que celles-ci : à garder
/// synchro avec RAISONS_RETOUR dans le backend (index.js).
const raisonsRetour = <String, String>{
  'louane': 'Louane',
  'seances': 'Les séances',
  'prix': 'Le prix',
  'bugs': 'Ça bugue',
  'pas_pour_moi': 'Pas mon truc',
};

/// Longueur max du mot écrit (le serveur coupe à la même valeur).
const retourTexteMax = 1000;

/// Ce que la carte a recueilli : le choix, puis — sur « Pas vraiment » —
/// les raisons cochées et le mot écrit. Rempli par la feuille au moment où
/// la personne VALIDE (Continuer, Envoyer, Passer) : une feuille balayée en
/// cours de route ne fait rien partir, sauf le choix déjà exprimé.
class AvisResultat {
  AvisChoix choix = AvisChoix.ignore;
  final Set<String> raisons = {};
  String texte = '';

  /// Vrai dès qu'il y a quelque chose à déposer dans la boîte aux lettres.
  bool get aRetour => raisons.isNotEmpty || texte.isNotEmpty;
}

/// La carte d'avis, dans le langage des feuilles de Louane (même dégradé
/// nocturne, même montée douce que le disclaimer). Une seule feuille dont le
/// contenu se transforme, comme si Louane continuait de parler :
///
/// 1. « Est-ce que Quieto te fait du bien ? » — « Oui, beaucoup » referme la
///    feuille et le ReviewService enchaîne sur le popup système 5 étoiles
///    (dont le texte et l'apparence sont imposés par l'OS, immodifiables).
/// 2. Sur « Pas vraiment » : « Qu'est-ce qui coince ? », des raisons à
///    toucher, plusieurs possibles — il en faut au moins une pour continuer.
/// 3. « Tu veux m'en dire plus ? », un mot libre, à envoyer. Seule issue
///    sans écrire : une petite croix en haut à gauche (les raisons déjà
///    validées partent quand même, pas le brouillon).
/// 4. Merci, et la feuille se referme seule.
///
/// Pas de bouton « Passer » (décision de Paul, 07/09/2026) : on veut des
/// réponses, et la feuille reste balayable pour qui n'en veut vraiment pas.
///
/// Aucune IA là-dedans : des questions fixes, écrites par nous. Louane n'est
/// que l'habillage. Le résultat part ensuite (ReviewService) dans la boîte
/// aux lettres de la Vigie, anonyme (id d'installation aléatoire).
Future<AvisResultat> montrerAvisDialog(BuildContext context) async {
  final resultat = AvisResultat();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xCC050B14),
    sheetAnimationStyle: AnimationStyle(
      duration: const Duration(milliseconds: 600),
      reverseDuration: const Duration(milliseconds: 350),
    ),
    builder: (context) => _FeuilleAvis(resultat: resultat),
  );
  return resultat;
}

enum _Etape { question, raisons, texte, merci }

class _FeuilleAvis extends StatefulWidget {
  const _FeuilleAvis({required this.resultat});

  final AvisResultat resultat;

  @override
  State<_FeuilleAvis> createState() => _FeuilleAvisState();
}

class _FeuilleAvisState extends State<_FeuilleAvis> {
  _Etape _etape = _Etape.question;

  /// Raisons touchées, en attente d'une validation.
  final Set<String> _choisies = {};
  final _controleur = TextEditingController();
  Timer? _fermeture;

  /// Vrai dès qu'on a demandé la fermeture : jamais deux pop pour une feuille.
  bool _ferme = false;

  AvisResultat get _r => widget.resultat;

  @override
  void dispose() {
    _fermeture?.cancel();
    _controleur.dispose();
    super.dispose();
  }

  void _va(_Etape etape) => setState(() => _etape = etape);

  /// Referme la feuille — une seule fois, et seulement si elle est encore
  /// là. Si la personne l'a balayée (ou touché le voile) juste avant la
  /// fermeture automatique du merci, la route est déjà dépilée mais le widget
  /// vit encore le temps de l'animation de sortie : un pop de plus
  /// dépilerait la PAGE du dessous, et go_router planterait (« plus de page
  /// à montrer », écran noir — vu sur le simulateur le 07/09/2026).
  void _fermer() {
    if (!mounted || _ferme) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isActive) return;
    _ferme = true;
    Navigator.of(context).pop();
  }

  void _oui() {
    HapticFeedback.mediumImpact();
    _r.choix = AvisChoix.oui;
    _fermer();
  }

  void _pasVraiment() {
    HapticFeedback.selectionClick();
    _r.choix = AvisChoix.non;
    _va(_Etape.raisons);
  }

  void _basculeRaison(String cle) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_choisies.remove(cle)) _choisies.add(cle);
    });
  }

  void _continuer() {
    HapticFeedback.selectionClick();
    _va(_Etape.texte);
  }

  /// Fin de parcours. « Envoyer » : le mot part avec les raisons, puis
  /// merci et la feuille se referme seule. La croix : on garde les raisons
  /// déjà validées à l'étape d'avant, pas le brouillon, et la feuille se
  /// referme tout de suite, sans cérémonie.
  void _valider({required bool avecTexte}) {
    _r.raisons
      ..clear()
      ..addAll(_choisies);
    _r.texte = avecTexte ? _controleur.text.trim() : '';
    FocusManager.instance.primaryFocus?.unfocus();
    if (!avecTexte || !_r.aRetour) {
      _fermer();
      return;
    }
    HapticFeedback.mediumImpact();
    _va(_Etape.merci);
    _fermeture = Timer(const Duration(milliseconds: 1600), _fermer);
  }

  Widget _contenu() => switch (_etape) {
    _Etape.question => _EtapeQuestion(onOui: _oui, onNon: _pasVraiment),
    _Etape.raisons => _EtapeRaisons(
      choisies: _choisies,
      onBascule: _basculeRaison,
      onContinuer: _continuer,
    ),
    _Etape.texte => _EtapeTexte(
      controleur: _controleur,
      onEnvoyer: () => _valider(avecTexte: true),
    ),
    _Etape.merci => const _EtapeMerci(),
  };

  @override
  Widget build(BuildContext context) {
    final basSafe = MediaQuery.viewPaddingOf(context).bottom;
    // Le clavier (étape du mot) pousse la feuille vers le haut.
    final clavier = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: clavier),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E1F38), AppColors.background],
          ),
        ),
        child: Stack(
          // passthrough : le contenu reçoit la largeur pleine de la feuille.
          // Sinon il se serre à la largeur de son texte (le « Merci » n'a
          // pas de pilule pleine largeur) et tout glisse à gauche.
          fit: StackFit.passthrough,
          children: [
            // Le ciel de Quieto, qui scintille doucement derrière le contenu.
            const Positioned.fill(child: StarryBackground()),
            SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(28, 36, 28, 24 + basSafe),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Louane dans un halo turquoise, comme quand elle compose.
                    // Elle reste en place d'une étape à l'autre : c'est elle
                    // qui « continue de parler ».
                    Container(
                      width: 132,
                      height: 132,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Color(0x335CE0D8), Colors.transparent],
                        ),
                      ),
                      child: const LouaneAvatar(size: 84, parle: true),
                    ),
                    const SizedBox(height: 20),
                    // La feuille garde sa place, seul son contenu change :
                    // fondu + légère montée, et la hauteur suit en douceur.
                    AnimatedSize(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 0.06),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        layoutBuilder: (courant, precedents) => Stack(
                          alignment: Alignment.topCenter,
                          children: [...precedents, ?courant],
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(_etape),
                          child: _contenu(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // La petite croix, seulement à l'étape du mot : pour qui ne veut
            // pas écrire. Discrète, en haut à gauche.
            Positioned(
              top: 14,
              left: 14,
              child: IgnorePointer(
                ignoring: _etape != _Etape.texte,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: _etape == _Etape.texte ? 1 : 0,
                  child: _Croix(onTap: () => _valider(avecTexte: false)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Croix extends StatelessWidget {
  const _Croix({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Fermer',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          child: Icon(
            Icons.close_rounded,
            size: 20,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

// ── Étape 1 : la question franche ────────────────────────────────

class _EtapeQuestion extends StatelessWidget {
  const _EtapeQuestion({required this.onOui, required this.onNon});

  final VoidCallback onOui;
  final VoidCallback onNon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Titre('Est-ce que Quieto\nte fait du bien ?'),
        const SizedBox(height: 32),
        _Pilule(label: 'Oui, beaucoup', onTap: onOui),
        const SizedBox(height: 8),
        _Lien(label: 'Pas vraiment', onTap: onNon),
      ],
    );
  }
}

// ── Étape 2 : ce qui coince ──────────────────────────────────────

class _EtapeRaisons extends StatelessWidget {
  const _EtapeRaisons({
    required this.choisies,
    required this.onBascule,
    required this.onContinuer,
  });

  final Set<String> choisies;
  final ValueChanged<String> onBascule;
  final VoidCallback onContinuer;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Titre("Qu'est-ce qui coince ?", uneLigne: true),
        const SizedBox(height: 8),
        const _SousTitre('Plusieurs réponses possibles.'),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (final raison in raisonsRetour.entries)
              _Raison(
                label: raison.value,
                choisie: choisies.contains(raison.key),
                onTap: () => onBascule(raison.key),
              ),
          ],
        ),
        const SizedBox(height: 28),
        // Il faut au moins une raison pour continuer : on veut des réponses.
        _Pilule(
          label: 'Continuer',
          actif: choisies.isNotEmpty,
          onTap: onContinuer,
        ),
      ],
    );
  }
}

class _Raison extends StatelessWidget {
  const _Raison({
    required this.label,
    required this.choisie,
    required this.onTap,
  });

  final String label;
  final bool choisie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: choisie
              ? AppColors.accentDim
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: choisie
                ? AppColors.accent
                : Colors.white.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: choisie ? AppColors.accent : AppColors.textPrimary,
            fontWeight: choisie ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Étape 3 : un mot, si la personne veut ────────────────────────

class _EtapeTexte extends StatelessWidget {
  const _EtapeTexte({required this.controleur, required this.onEnvoyer});

  final TextEditingController controleur;
  final VoidCallback onEnvoyer;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Titre("Tu m'en dis plus ?", uneLigne: true),
        const SizedBox(height: 8),
        const _SousTitre(
          "Ce que tu écris arrive tel quel à l'équipe de Quieto, "
          'sans ton nom.',
        ),
        const SizedBox(height: 20),
        // Même voile bleu nuit que la pilule du chat de Louane.
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF122036).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: TextField(
            controller: controleur,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            // Le serveur coupe à la même longueur : on borne ici, sans
            // compteur à l'écran.
            inputFormatters: [LengthLimitingTextInputFormatter(retourTexteMax)],
            textCapitalization: TextCapitalization.sentences,
            style: AppTextStyles.bodyLarge,
            cursorColor: AppColors.accent,
            decoration: InputDecoration(
              hintText: "Ce qui manque, ce qui t'a gêné…",
              hintStyle: AppTextStyles.bodyMedium,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // « Envoyer » ne s'allume qu'avec un mot écrit. Sans mot : la croix.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controleur,
          builder: (context, valeur, _) => _Pilule(
            label: 'Envoyer',
            actif: valeur.text.trim().isNotEmpty,
            onTap: onEnvoyer,
          ),
        ),
      ],
    );
  }
}

// ── Étape 4 : merci ──────────────────────────────────────────────

class _EtapeMerci extends StatelessWidget {
  const _EtapeMerci();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Titre("Merci, c'est noté.", uneLigne: true),
          SizedBox(height: 8),
          _SousTitre("Ça m'aide à faire mieux."),
        ],
      ),
    );
  }
}

// ── Briques communes ─────────────────────────────────────────────

/// Le titre porte la feuille à lui seul : grand mais en graisse normale,
/// dans la police de l'app. Le « ? » est collé au mot par une espace
/// insécable (jamais un « ? » orphelin sur sa ligne — vu par Paul le
/// 07/09/2026). Un titre [uneLigne] se réduit un peu plutôt que de se
/// couper sur les petits écrans.
class _Titre extends StatelessWidget {
  const _Titre(this.texte, {this.uneLigne = false});

  final String texte;
  final bool uneLigne;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.displayLarge.copyWith(
      fontWeight: FontWeight.w400,
    );
    if (!uneLigne) {
      return Text(texte, style: style, textAlign: TextAlign.center);
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(texte, style: style, maxLines: 1, softWrap: false),
    );
  }
}

class _SousTitre extends StatelessWidget {
  const _SousTitre(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Text(
      texte,
      style: AppTextStyles.bodyMedium,
      textAlign: TextAlign.center,
    );
  }
}

/// Pilule lumineuse, même langage que « Crée-moi mon programme » (dégradé +
/// halo turquoise). Éteinte (translucide, inerte) quand [actif] est faux.
class _Pilule extends StatelessWidget {
  const _Pilule({required this.label, required this.onTap, this.actif = true});

  final String label;
  final VoidCallback onTap;
  final bool actif;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: actif ? 1 : 0.35,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF86ECE4), AppColors.accent],
          ),
          boxShadow: [
            if (actif)
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.45),
                blurRadius: 22,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: actif ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                label,
                textAlign: TextAlign.center,
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

class _Lien extends StatelessWidget {
  const _Lien({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
      ),
    );
  }
}
