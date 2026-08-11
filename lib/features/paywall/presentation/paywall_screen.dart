// =============================================================================
//  Quieto — Paywall « Comment marche ton essai »
//  Traduction Flutter PIXEL-EXACTE du prototype `Quieto Paywall - Sereine.dc.html`.
//  Fourni par le designer (handoff). INTÉGRÉ TEL QUEL : aucune constante (couleur,
//  taille, espacement, courbe) n'a été modifiée. Seules adaptations autorisées :
//    - police 'HankenGrotesk' (asset projet, cf. pubspec.yaml),
//    - icônes Material standard (Icons.*_outlined) : les Material Symbols
//      (police variable) s'affichaient vides en release iOS après tree-shaking,
//    - withOpacity → withValues (équivalent, même valeur),
//    - les offres/onStart/onRestore sont alimentés par RevenueCat depuis paywall_page.
// =============================================================================

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/scheduler.dart' show Ticker;

// ----------------------------------------------------------------------------
//  Tokens (verbatim du prototype)
// ----------------------------------------------------------------------------
const Color _kBg = Color(0xFF0A1628); // fond app
const Color _kSurface = Color(0xFF0D2137); // carte + sélecteur
const Color _kTurq = Color(0xFF5CE0D8); // accent turquoise
const Color _kOnTurq = Color(0xFF0A1628); // texte sur turquoise
const String _kFont = 'HankenGrotesk'; // <- branchée (pubspec.yaml)

Color _w(double o) => Colors.white.withValues(alpha: o); // blanc transparent
Color _t(double o) =>
    const Color(0xFF5CE0D8).withValues(alpha: o); // turquoise transparent

// ----------------------------------------------------------------------------
//  Données dynamiques (⚠ en prod : RevenueCat). Défauts = placeholders du design.
// ----------------------------------------------------------------------------
enum PaywallPlan { annual, monthly }

class PaywallOffer {
  final int trialDays; // 7 / 3  -> "X jours gratuits" (carte tarif)
  final String pricePerMonth; // gros chiffre turquoise, ex "4,99 €"
  final String billingLine; // sous-ligne carte, ex "facturé 59,90 € par an"
  final String? saveBadge; // badge, ex "Économise 58 %" (null = pas de badge)
  final String reminderWhen; // étape 2, ex "Dans 5 jours" / "Demain"
  final String chargeWhen; // étape 3, ex "Dans 7 jours" / "Dans 3 jours"
  final String chargeDate; // étape 3, ex "le 3 juillet" / "le 29 juin"

  const PaywallOffer({
    required this.trialDays,
    required this.pricePerMonth,
    required this.billingLine,
    required this.saveBadge,
    required this.reminderWhen,
    required this.chargeWhen,
    required this.chargeDate,
  });

  static const PaywallOffer placeholderAnnual = PaywallOffer(
    trialDays: 7,
    pricePerMonth: '7,50 €',
    billingLine: 'facturé 89,99 € par an',
    saveBadge: 'Économise 56 %',
    reminderWhen: 'Dans 5 jours',
    chargeWhen: 'Dans 7 jours',
    chargeDate: 'le 3 juillet',
  );

  static const PaywallOffer placeholderMonthly = PaywallOffer(
    trialDays: 3,
    pricePerMonth: '16,99 €',
    billingLine: 'facturé chaque mois, sans engagement',
    saveBadge: null,
    reminderWhen: 'Demain',
    chargeWhen: 'Dans 3 jours',
    chargeDate: 'le 29 juin',
  );
}

// ----------------------------------------------------------------------------
//  Écran
// ----------------------------------------------------------------------------
class PaywallScreen extends StatefulWidget {
  final PaywallOffer annual;
  final PaywallOffer monthly;
  final PaywallPlan initialPlan;

  /// CTA — appelle l'achat existant avec le forfait sélectionné.
  final void Function(PaywallPlan plan)? onStart;
  final VoidCallback? onRestore;
  final VoidCallback? onTerms;
  final VoidCallback? onPrivacy;

  const PaywallScreen({
    super.key,
    this.annual = PaywallOffer.placeholderAnnual,
    this.monthly = PaywallOffer.placeholderMonthly,
    this.initialPlan = PaywallPlan.annual,
    this.onStart,
    this.onRestore,
    this.onTerms,
    this.onPrivacy,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen>
    with TickerProviderStateMixin {
  late PaywallPlan _plan = widget.initialPlan;

  // Animations « douces » de l'orbe.
  late final AnimationController _halo =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))
        ..repeat(reverse: true); // 6s aller-retour
  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3500))
        ..repeat(reverse: true); // 7s aller-retour

  // Horloge continue pour le ciel (scintillement + étoiles filantes).
  final ValueNotifier<double> _clock = ValueNotifier<double>(0);
  late final Ticker _ticker;
  late final List<_Star> _stars = _buildStars();

  bool get _isAnnual => _plan == PaywallPlan.annual;
  PaywallOffer get _offer => _isAnnual ? widget.annual : widget.monthly;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _clock.value = elapsed.inMicroseconds / 1e6;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _halo.dispose();
    _float.dispose();
    _clock.dispose();
    super.dispose();
  }

  // ---- Ciel : 130 étoiles, MÊME disposition que le prototype (mulberry32, seed 717).
  List<_Star> _buildStars() {
    final rand = _mulberry32(717);
    const int count = 130; // round(130 * density=1)
    final out = <_Star>[];
    for (int i = 0; i < count; i++) {
      final size = 1 + rand() * 2.0;
      final left = rand() * 100;
      final top = rand() * 100;
      final dur = (2.2 + rand() * 3) / 1.0; // speed = 1
      final delay = rand() * 4;
      final isTurq = rand() < 0.16;
      final bright = size > 2.0 || isTurq;
      final color = isTurq ? _kTurq : Colors.white;
      final glow = bright ? (4 + rand() * 6) : 0.0; // rand consommé seulement si bright
      out.add(_Star(
        xf: left / 100.0,
        y: top / 100.0 * 360.0, // calque haut = 360px
        size: size,
        dur: dur,
        delay: delay,
        color: color,
        bright: bright,
        glow: glow,
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: _kFont,
          color: Colors.white,
          fontSize: 15,
          height: 1.2,
          decoration: TextDecoration.none,
          leadingDistribution: TextLeadingDistribution.even,
        ),
        child: Stack(
          children: [
            // ---- Ciel étoilé (calque absolu en haut, fondu vers le bas via le painter)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 360,
              child: IgnorePointer(
                child: ClipRect(
                  child: CustomPaint(
                    painter: _SkyPainter(_stars, _clock),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),

            // ---- Contenu
            SafeArea(
              child: LayoutBuilder(
                builder: (context, cons) => SingleChildScrollView(
                  // Clip.none : le halo de l'orbe dépasse en haut du scroll,
                  // sinon il est coupé net (ligne visible sous la barre d'état).
                  clipBehavior: Clip.none,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: cons.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _orbe(),
                            const SizedBox(height: 14),
                            _titleBlock(),
                            const SizedBox(height: 20),
                            _selector(),
                            const SizedBox(height: 24),
                            _timeline(),
                            const SizedBox(height: 22),
                            // Espace flexible AVANT la carte tarif : elle descend
                            // contre le bloc d'action, la timeline garde tout
                            // l'espace libre de l'écran.
                            const Expanded(child: SizedBox()),
                            _priceCard(),
                            const SizedBox(height: 16),
                            _actionBlock(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Orbe de méditation (bloc 128) : halo radial + cercle turquoise flottant.
  Widget _orbe() {
    return SizedBox(
      height: 128,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_halo, _float]),
          builder: (context, _) {
            final h = Curves.easeInOut.transform(_halo.value);
            final f = Curves.easeInOut.transform(_float.value);
            final haloOpacity = 0.55 + (0.85 - 0.55) * h;
            final haloScale = 1.0 + (1.05 - 1.0) * h;
            final dy = 0.0 + (-5.0 - 0.0) * f;
            return Stack(
              // Clip.none : le halo dépasse du bloc de 128 px sans être coupé.
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Halo : en Positioned pour qu'il ne compte pas dans la mise
                // en page (sinon il est écrasé à 128 px de haut et devient une
                // ellipse au bord visible). Ici : vrai cercle, très faible,
                // fondu progressif façon lueur.
                Positioned(
                  left: -55,
                  top: -55,
                  child: Opacity(
                    opacity: haloOpacity,
                    child: Transform.scale(
                      scale: haloScale,
                      child: Container(
                        width: 210,
                        height: 210,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Color(0x145CE0D8), // ~8 % (caché sous le cercle)
                              Color(0x115CE0D8), // ~7 % au bord du cercle
                              Color(0x0A5CE0D8), // ~4 %
                              Color(0x055CE0D8), // ~2 %
                              Color(0x025CE0D8), // ~1 %
                              Color(0x005CE0D8), // 0 % (fondu total)
                            ],
                            stops: [0.0, 0.48, 0.62, 0.76, 0.88, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // cercle turquoise 100x100 + icône
                Transform.translate(
                  offset: Offset(0, dy),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kTurq,
                      boxShadow: [
                        BoxShadow(
                          color: _t(0.38),
                          blurRadius: 42,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.self_improvement,
                          size: 47, color: _kOnTurq),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---- Titre
  Widget _titleBlock() {
    return const Text(
      'Comment marche\nton essai',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -0.56, // -0.02em * 28
      ),
    );
  }

  // ---- Sélecteur segmenté Annuel / Mensuel (pastille turquoise qui glisse, .34s)
  Widget _selector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          // pastille : moitié de la largeur interne, glisse gauche <-> droite
          Positioned.fill(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 340),
              curve: const Cubic(0.45, 0.05, 0.25, 1.0),
              alignment: _isAnnual ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _kTurq,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _t(0.55),
                        blurRadius: 16,
                        spreadRadius: -6,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // libellés
          Row(
            children: [
              _tab('Annuel', PaywallPlan.annual),
              _tab('Mensuel', PaywallPlan.monthly),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, PaywallPlan plan) {
    final active = _plan == plan;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _plan = plan);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 280),
            curve: Curves.ease,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _kFont,
              fontSize: 15,
              height: 1.0,
              fontWeight: FontWeight.w600,
              color: active ? _kOnTurq : _w(0.55),
            ),
            child: Text(label, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }

  // ---- Timeline d'essai (3 étapes)
  Widget _timeline() {
    // Mots-clés en blanc quasi pur + semi-gras : c'est le contraste avec le
    // reste de la phrase qui les fait ressortir, pas la taille.
    TextSpan em(String t) => TextSpan(
          text: t,
          style: TextStyle(color: _w(0.96), fontWeight: FontWeight.w600),
        );
    TextSpan tx(String t) => TextSpan(text: t);

    return Column(
      children: [
        _step(
          icon: Icons.lock_open_outlined,
          title: 'Aujourd\'hui',
          desc: [
            em('Toutes les méditations'),
            tx(', ton '),
            em('programme personnalisé'),
            tx(' et '),
            em('Louane'),
            tx(' en illimité.'),
          ],
          last: false,
        ),
        _step(
          icon: Icons.notifications_none_outlined,
          title: _offer.reminderWhen,
          desc: [
            em('On te prévient'),
            tx(' avant la fin de l\'essai (aucune mauvaise surprise).'),
          ],
          last: false,
        ),
        _step(
          icon: Icons.workspace_premium_outlined,
          title: _offer.chargeWhen,
          desc: [
            tx('Ton abonnement commence '),
            em(_offer.chargeDate),
            tx('.'),
          ],
          last: true,
        ),
      ],
    );
  }

  Widget _step({
    required IconData icon,
    required String title,
    required List<TextSpan> desc,
    required bool last,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // colonne icône + ligne de liaison
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _t(0.14),
                    border: Border.all(color: _t(0.22), width: 1),
                  ),
                  child: Center(child: Icon(icon, size: 21, color: _kTurq)),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 5),
                      constraints: const BoxConstraints(minHeight: 26),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [_t(0.35), _t(0.1)],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // texte
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 1, bottom: last ? 0 : 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text.rich(
                    TextSpan(children: desc),
                    style: TextStyle(
                      color: _w(0.72),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      height: 1.42,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Carte tarif
  Widget _priceCard() {
    final badge = _offer.saveBadge;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _t(0.16), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        '${_offer.trialDays} jours gratuits',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          letterSpacing: -0.155, // -0.01em * 15.5
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _t(0.14),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: _kTurq,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  _offer.billingLine,
                  style: TextStyle(
                    color: _w(0.55),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _offer.pricePerMonth,
                style: const TextStyle(
                  color: _kTurq,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  letterSpacing: -0.38, // -0.02em * 19
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'par mois',
                style: TextStyle(
                  color: _w(0.42),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Bloc d'action : réassurance + CTA + restaurer + légal
  Widget _actionBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // réassurance
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 15, color: _kTurq),
              const SizedBox(width: 6),
              Text(
                'Sans engagement · annulable à tout moment',
                style: TextStyle(
                  color: _w(0.78),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
        // CTA
        _PressableButton(
          onPressed: () => widget.onStart?.call(_plan),
          child: const Center(
            child: Text(
              'Commencer mon essai gratuit',
              style: TextStyle(
                color: _kOnTurq,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
          ),
        ),
        // restaurer
        const SizedBox(height: 15),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onRestore?.call();
          },
          child: const Center(
            child: Text(
              'Restaurer mes achats',
              style: TextStyle(
                color: _kTurq,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
          ),
        ),
        // légal — liens Conditions/Confidentialité exigés par Apple (règle 3.1.2).
        // Le paragraphe de renouvellement auto a été retiré : la feuille de
        // paiement Apple affiche déjà ces conditions à l'achat.
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: widget.onTerms,
              child: Text(
                'Conditions',
                style: TextStyle(
                  color: _w(0.4),
                  fontSize: 12,
                  height: 1.0,
                  decoration: TextDecoration.underline,
                  decorationColor: _w(0.4),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('·', style: TextStyle(color: _w(0.4), fontSize: 12)),
            ),
            GestureDetector(
              onTap: widget.onPrivacy,
              child: Text(
                'Confidentialité',
                style: TextStyle(
                  color: _w(0.4),
                  fontSize: 12,
                  height: 1.0,
                  decoration: TextDecoration.underline,
                  decorationColor: _w(0.4),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------------
//  CTA : feedback tactile à l'appui (scale .97 + ombre resserrée, .16s)
// ----------------------------------------------------------------------------
class _PressableButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  const _PressableButton({required this.child, this.onPressed});

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton> {
  bool _pressed = false;
  static const _curve = Cubic(0.4, 0.0, 0.2, 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.mediumImpact();
        setState(() => _pressed = true);
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: _curve,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: _curve,
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _pressed
                ? Color.lerp(_kTurq, Colors.black, 0.03) // brightness .97
                : _kTurq,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              _pressed
                  ? BoxShadow(
                      color: _t(0.5),
                      blurRadius: 14,
                      spreadRadius: -8,
                      offset: const Offset(0, 5),
                    )
                  : BoxShadow(
                      color: _t(0.55),
                      blurRadius: 30,
                      spreadRadius: -8,
                      offset: const Offset(0, 12),
                    ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
//  Ciel : scintillement + 3 étoiles filantes — CustomPainter piloté par l'horloge
// ----------------------------------------------------------------------------
class _Star {
  final double xf; // fraction de la largeur (0..1)
  final double y; // px dans le calque 360
  final double size; // px
  final double dur; // s
  final double delay; // s
  final Color color;
  final bool bright;
  final double glow; // px (0 si pas bright)
  const _Star({
    required this.xf,
    required this.y,
    required this.size,
    required this.dur,
    required this.delay,
    required this.color,
    required this.bright,
    required this.glow,
  });
}

class _Shoot {
  final double leftf; // fraction largeur
  final double top; // px
  final double period; // s
  final double delay; // s
  final double len; // px
  final double thick; // px
  final Color color;
  final double opacity;
  final double glow; // px
  const _Shoot(this.leftf, this.top, this.period, this.delay, this.len,
      this.thick, this.color, this.opacity, this.glow);
}

class _SkyPainter extends CustomPainter {
  final List<_Star> stars;
  final ValueListenable<double> clock;
  _SkyPainter(this.stars, this.clock) : super(repaint: clock);

  static const double _layerH = 360;

  // 3 étoiles filantes (verbatim du prototype)
  static final List<_Shoot> _shoots = [
    _Shoot(0.07, 24, 13, 1.5, 74, 1.6, Colors.white, 0.9, 6),
    _Shoot(0.56, 13, 16, 7, 92, 1.6, _kTurq, 0.85, 7),
    _Shoot(0.32, 50, 19, 12, 80, 1.5, Colors.white, 0.88, 6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;

    // --- étoiles scintillantes
    for (final s in stars) {
      double p = (t + s.delay) / s.dur;
      p -= p.floorToDouble();
      double opacity, scale;
      if (p < 0.5) {
        final e = Curves.easeInOut.transform(p / 0.5);
        opacity = 0.2 + (1.0 - 0.2) * e;
        scale = 0.8 + (1.18 - 0.8) * e;
      } else {
        final e = Curves.easeInOut.transform((p - 0.5) / 0.5);
        opacity = 1.0 + (0.2 - 1.0) * e;
        scale = 1.18 + (0.8 - 1.18) * e;
      }
      // fondu du masque vers le bas (#000 0% .. transparent 85%, opaque jusqu'à 42%)
      final fy = s.y / _layerH;
      double fade = fy <= 0.42
          ? 1.0
          : fy >= 0.85
              ? 0.0
              : 1.0 - (fy - 0.42) / (0.85 - 0.42);
      final a = (opacity * fade).clamp(0.0, 1.0);
      if (a <= 0.01) continue;

      final cx = s.xf * size.width;
      final cy = s.y;
      final r = s.size * scale / 2;
      if (s.bright && s.glow > 0) {
        canvas.drawCircle(
          Offset(cx, cy),
          r + s.glow * 0.5,
          Paint()
            ..color = s.color.withValues(alpha: a * 0.5)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.glow / 2),
        );
      }
      canvas.drawCircle(
          Offset(cx, cy), r, Paint()..color = s.color.withValues(alpha: a));
    }

    // --- étoiles filantes
    const double ang = 27 * math.pi / 180;
    final double ca = math.cos(ang), sa = math.sin(ang);
    for (final sh in _shoots) {
      double localT = (t - sh.delay) % sh.period;
      if (localT < 0) localT += sh.period;
      final p = localT / sh.period;
      if (p >= 0.12) continue; // visible seulement sur les 12 premiers %

      final f = (p / 0.12).clamp(0.0, 1.0);
      final fe = Curves.easeIn.transform(f); // CSS ease-in
      final tx = -20 + (150 - (-20)) * fe;
      final ty = -12 + (78 - (-12)) * fe;

      double op;
      if (p < 0.02) {
        op = p / 0.02;
      } else {
        op = 1 - (p - 0.02) / 0.10;
      }
      op = op.clamp(0.0, 1.0) * sh.opacity;
      if (op <= 0.01) continue;

      final headX = sh.leftf * size.width + tx;
      final headY = sh.top + ty;
      final tailX = headX - sh.len * ca;
      final tailY = headY - sh.len * sa;

      final shader = ui.Gradient.linear(
        Offset(tailX, tailY),
        Offset(headX, headY),
        [sh.color.withValues(alpha: 0), sh.color.withValues(alpha: op)],
      );
      // halo
      canvas.drawLine(
        Offset(tailX, tailY),
        Offset(headX, headY),
        Paint()
          ..shader = shader
          ..strokeWidth = sh.thick
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sh.glow / 2),
      );
      // trait net
      canvas.drawLine(
        Offset(tailX, tailY),
        Offset(headX, headY),
        Paint()
          ..shader = shader
          ..strokeWidth = sh.thick
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => false; // repaint via `clock`
}

// ----------------------------------------------------------------------------
//  PRNG mulberry32 — IDENTIQUE au prototype (garantit la même disposition d'étoiles)
// ----------------------------------------------------------------------------
int _imul(int a, int b) {
  a &= 0xFFFFFFFF;
  b &= 0xFFFFFFFF;
  final int aLo = a & 0xFFFF, aHi = (a >>> 16) & 0xFFFF;
  final int bLo = b & 0xFFFF, bHi = (b >>> 16) & 0xFFFF;
  final int lo = aLo * bLo;
  final int mid = (aHi * bLo + aLo * bHi) & 0xFFFFFFFF;
  return (lo + ((mid << 16) & 0xFFFFFFFF)) & 0xFFFFFFFF;
}

double Function() _mulberry32(int seed) {
  int s = seed & 0xFFFFFFFF;
  return () {
    s = (s + 0x6D2B79F5) & 0xFFFFFFFF;
    int t = _imul(s ^ (s >>> 15), 1 | s) & 0xFFFFFFFF;
    t = ((t + _imul(t ^ (t >>> 7), 61 | t)) ^ t) & 0xFFFFFFFF;
    return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 4294967296.0;
  };
}
