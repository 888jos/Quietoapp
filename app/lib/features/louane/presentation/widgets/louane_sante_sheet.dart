import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/health_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/ui/apple_health_icon.dart';
import '../louane_palette.dart';

/// Feuille « Ce que Louane voit » (bouton Apple Santé de l'en-tête du chat,
/// choix de Paul 12/09) : les signaux Santé qu'elle lit, en clair, le dernier
/// questionnaire et sa date, et de quoi connecter ou rouvrir l'accès.
///
/// [onConnexion] : la personne tape « Connecter Apple Santé » depuis la
/// feuille (Vigie : `louane_sante_connexion`).
Future<void> montrerLouaneSante(
  BuildContext context, {
  VoidCallback? onConnexion,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // Navigateur racine : au-dessus de la pilule de nav de HomeShell.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xCC050B14),
    builder: (context) => _FeuilleSante(onConnexion: onConnexion),
  );
}

class _FeuilleSante extends StatefulWidget {
  final VoidCallback? onConnexion;
  const _FeuilleSante({this.onConnexion});

  @override
  State<_FeuilleSante> createState() => _FeuilleSanteState();
}

class _FeuilleSanteState extends State<_FeuilleSante> {
  /// 'autorise' / 'refuse' / 'jamais' (écriture Pleine conscience, le seul
  /// statut que HealthKit révèle), '' hors iPhone.
  String _etat = '';
  List<SignalSanteAffiche> _signaux = const [];
  bool _chargement = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final etat = await HealthService.instance.etatConnexion();
    await HealthService.instance.resumeSanteMentale();
    if (!mounted) return;
    setState(() {
      _etat = etat;
      _signaux = HealthService.instance.signaux;
      _chargement = false;
    });
  }

  /// Connecter (feuille système) ou relire : même geste, la lecture suit.
  Future<void> _connecter() async {
    if (_busy) return;
    widget.onConnexion?.call();
    setState(() => _busy = true);
    await HealthService.instance.reconnecter();
    if (!mounted) return;
    await _charger();
    if (mounted) setState(() => _busy = false);
  }

  /// Après un refus, seule l'app Santé permet de rouvrir l'accès.
  Future<void> _ouvrirSante() async {
    try {
      await launchUrl(
        Uri.parse('x-apple-health://'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final basSafe = MediaQuery.viewPaddingOf(context).bottom;
    final iphone = HealthService.instance.disponible;
    // Mise en page voulue par Paul (12/09) : grand logo, grand titre, UNE
    // bulle d'explication en deux ou trois lignes, la liste de ce qu'elle
    // voit s'il y a quelque chose, et un seul grand bouton centré en bas.
    // Rien d'autre : ni sous-titre, ni texte sous le bouton.
    return Container(
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
      padding: EdgeInsets.fromLTRB(24, 14, 24, 22 + basSafe),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Center(child: AppleHealthIcon(size: 64)),
            const SizedBox(height: 18),
            Text(
              'Louane et Apple Santé',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 18),
            _Encart(texte: _explication(iphone)),
            if (!_chargement && _signaux.isNotEmpty) ...[
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Ce qu\'elle voit en ce moment',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              _ListeSignaux(signaux: _signaux),
            ],
            const SizedBox(height: 26),
            if (iphone) _bouton(),
          ],
        ),
      ),
    );
  }

  /// Deux ou trois lignes, simples, sur ce que Louane fait concrètement
  /// avec Santé — et, après un refus, comment rouvrir l'accès.
  String _explication(bool iphone) {
    if (!iphone) {
      return "Apple Santé n'existe que sur iPhone. Ici, Louane s'appuie "
          'seulement sur ce que tu lui racontes.';
    }
    if (_etat == 'refuse') {
      return "Quieto n'a pas accès à Santé pour l'instant. Pour rouvrir "
          "l'accès : app Santé, Partage, Apps et services, Quieto.";
    }
    return 'Louane lit tes questionnaires de bien-être, ton état d\'esprit '
        'et ton sommeil dans Santé, pour adapter ses réponses et ton '
        'programme. Rien n\'est enregistré sur nos serveurs.';
  }

  /// Un seul bouton, grand et centré : connecter (feuille système) tant que
  /// l'accès n'a jamais été demandé, ouvrir l'app Santé ensuite.
  Widget _bouton() {
    final jamais = _etat == 'jamais' || _etat == '';
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: _busy ? null : (jamais ? _connecter : _ouvrirSante),
        style: FilledButton.styleFrom(
          backgroundColor: LouanePalette.accent,
          foregroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: AppTextStyles.bodyLarge.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(
          jamais
              ? (_busy ? 'Connexion…' : 'Connecter Apple Santé')
              : "Ouvrir l'app Santé",
        ),
      ),
    );
  }
}

/// La liste des signaux : une ligne par signal, titre à gauche, valeur en
/// dessous en turquoise doux, séparées par un trait fin.
class _ListeSignaux extends StatelessWidget {
  final List<SignalSanteAffiche> signaux;
  const _ListeSignaux({required this.signaux});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < signaux.length; i++)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                border: i == signaux.length - 1
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signaux[i].titre,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    signaux[i].valeur,
                    style: AppTextStyles.caption.copyWith(
                      color: LouanePalette.accent.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Encart extends StatelessWidget {
  final String texte;
  const _Encart({required this.texte});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: LouanePalette.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        texte,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
          height: 1.5,
        ),
      ),
    );
  }
}
