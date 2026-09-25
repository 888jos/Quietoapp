import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_constants.dart';
import '../../../../core/services/acces_entreprise.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/storage_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/ui/app_button.dart';
import '../../../../core/ui/boutons_connexion.dart';

/// Ouvre la feuille « Accès offert par mon entreprise » (B2B, 23/09/2026).
///
/// Parcours : connexion Apple/Google si besoin (l'accès doit suivre la
/// personne sur un autre téléphone) → code reçu de la RH → « Premium offert
/// par ACME » → Activer → c'est fait. Libellé volontairement « accès offert
/// par l'entreprise », jamais « code promo » (règle Apple 3.1.1).
void ouvrirAccesEntreprise(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    // Au-dessus de la barre de navigation flottante (sinon elle masque les
    // boutons du bas de la feuille).
    useRootNavigator: true,
    isScrollControlled: true,
    // Fond de nuit (plus sombre que les cartes) et coins arrondis qui
    // découpent aussi la gouache du haut.
    backgroundColor: AppColors.background,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _AccesEntrepriseSheet(),
  );
}

// Habillage (24/09/2026, demande de Paul : « plus joli, pas l'ancien ») :
// gouache en tête, titre en Cormorant crème comme la salutation de la Home,
// surtitre turquoise, pas d'emoji. La structure ne change pas.
const _creme = Color(0xFFF5E3C8);
const _aube = Color(0xFFE8A38C);
const _styleTitre = TextStyle(
  fontFamily: 'CormorantGaramond',
  fontSize: 30,
  fontVariations: [FontVariation('wght', 600)],
  color: _creme,
  height: 1.1,
);
final _styleSurtitre = AppTextStyles.caption.copyWith(
  color: AppColors.accent,
  fontWeight: FontWeight.w600,
  letterSpacing: 1.6,
);

/// La gouache en haut de la feuille, fondue dans la nuit vers le bas, avec
/// la poignée de la feuille par-dessus. Plus basse quand le clavier est
/// ouvert (petits écrans).
class _EnteteGouache extends StatelessWidget {
  final String image;
  const _EnteteGouache({required this.image});

  @override
  Widget build(BuildContext context) {
    final clavier = MediaQuery.of(context).viewInsets.bottom > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: AppConstants.animFast),
      height: clavier ? 84 : 150,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Image.asset(
              image,
              key: ValueKey(image),
              fit: BoxFit.cover,
              alignment: const Alignment(0.3, 0.2),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x000A1628), Color(0x660A1628), AppColors.background],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Etape { code, confirmation, active }

class _AccesEntrepriseSheet extends ConsumerStatefulWidget {
  const _AccesEntrepriseSheet();

  @override
  ConsumerState<_AccesEntrepriseSheet> createState() =>
      _AccesEntrepriseSheetState();
}

class _AccesEntrepriseSheetState extends ConsumerState<_AccesEntrepriseSheet> {
  final _code = TextEditingController();
  _Etape _etape = _Etape.code;
  bool _chargement = false;
  bool _connexionEnCours = false;
  String? _erreur;
  String _nom = '';
  // URL de gestion de l'abonnement personnel encore actif (App Store /
  // Play), null s'il n'y en a pas.
  String? _gererAbonnementPerso;
  bool _aboPersoActif = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verifier() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    final vigie = ref.read(vigieProvider);
    try {
      final nom = await AccesEntreprise.apercu(code);
      final perso = await AccesEntreprise.abonnementPersonnelActif();
      vigie.log('entreprise_code', {'resultat': 'ok'});
      if (!mounted) return;
      setState(() {
        _nom = nom;
        _aboPersoActif = perso != null;
        _gererAbonnementPerso = perso?.managementURL;
        _etape = _Etape.confirmation;
      });
    } on AccesEntrepriseErreur catch (e) {
      vigie.log('entreprise_code', {'resultat': e.raison});
      if (mounted) setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _activer() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    final vigie = ref.read(vigieProvider);
    try {
      final nom = await AccesEntreprise.activer(_code.text.trim());
      vigie.log('entreprise_activee', {'abo_perso': _aboPersoActif});
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _nom = nom;
        _etape = _Etape.active;
      });
    } on AccesEntrepriseErreur catch (e) {
      vigie.log('entreprise_activation_echec', {'raison': e.raison});
      if (mounted) setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _connexion({required bool apple}) async {
    final auth = ref.read(authServiceProvider);
    setState(() {
      _connexionEnCours = true;
      _erreur = null;
    });
    final resultat =
        apple ? await auth.connexionApple() : await auth.connexionGoogle();
    if (!mounted) return;
    setState(() {
      _connexionEnCours = false;
      if (resultat == AuthResultat.erreur) {
        _erreur =
            'La connexion n\'a pas fonctionné. Réessaie dans un instant.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final compte = ref.watch(utilisateurProvider).value;
    // Une gouache par moment : le bureau pour entrer le code, la
    // méditation au bord de l'eau pour l'offre, la pleine lune une fois
    // activé.
    final image = switch (_etape) {
      _Etape.code => 'assets/images/categories/express.webp',
      _Etape.confirmation => 'assets/images/categories/decouverte.webp',
      _Etape.active => 'assets/images/categories/sleep.webp',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EnteteGouache(image: image),
        Padding(
          padding: EdgeInsets.only(
            left: AppConstants.spacingLg,
            right: AppConstants.spacingLg,
            top: 4,
            bottom: MediaQuery.of(context).viewInsets.bottom +
                AppConstants.spacingLg,
          ),
          child: SafeArea(
            top: false,
            child: AnimatedSize(
              duration: const Duration(milliseconds: AppConstants.animFast),
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: switch (_etape) {
                  _Etape.code when compte == null => _connexionRequise(),
                  _Etape.code => _saisieCode(),
                  _Etape.confirmation => _confirmation(),
                  _Etape.active => _activee(),
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Surtitre turquoise + titre en Cormorant crème.
  List<Widget> _entete(String surtitre, String titre) => [
        Text(surtitre.toUpperCase(), style: _styleSurtitre),
        const SizedBox(height: 6),
        Text(titre, style: _styleTitre),
        const SizedBox(height: AppConstants.spacingSm + 2),
      ];

  TextStyle get _styleCorps => AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textPrimary.withValues(alpha: 0.74),
        height: 1.45,
      );

  List<Widget> _connexionRequise() {
    final auth = ref.read(authServiceProvider);
    return [
      ..._entete('Accès entreprise', 'Offert par ton entreprise'),
      Text(
        'Ton employeur t\'offre Quieto ? Connecte-toi d\'abord : ton accès '
        'te suivra si tu changes de téléphone.',
        style: _styleCorps,
      ),
      const SizedBox(height: AppConstants.spacingLg),
      if (auth.appleDisponible) ...[
        BoutonConnexionApple(
          isLoading: _connexionEnCours,
          onTap: _connexionEnCours ? null : () => _connexion(apple: true),
        ),
        const SizedBox(height: AppConstants.spacingSm),
      ],
      BoutonConnexionGoogle(
        isLoading: _connexionEnCours,
        onTap: _connexionEnCours ? null : () => _connexion(apple: false),
      ),
      ..._ligneErreur(),
      const SizedBox(height: AppConstants.spacingSm),
    ];
  }

  List<Widget> _saisieCode() {
    return [
      ..._entete('Accès entreprise', 'Ton code entreprise'),
      Text(
        'Entre le code transmis par ton entreprise.',
        style: _styleCorps,
      ),
      const SizedBox(height: AppConstants.spacingMd),
      TextField(
        controller: _code,
        autofocus: true,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _chargement ? null : _verifier(),
        onChanged: (_) {
          if (_erreur != null) setState(() => _erreur = null);
        },
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyLarge.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.5,
          color: _creme,
        ),
        cursorColor: AppColors.accent,
        decoration: InputDecoration(
          hintText: 'ACME-7K2P',
          hintStyle: AppTextStyles.bodyLarge.copyWith(
            fontSize: 20,
            letterSpacing: 2.5,
            color: AppColors.textPrimary.withValues(alpha: 0.22),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: _creme.withValues(alpha: 0.14)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
          ),
          filled: true,
          fillColor: AppColors.cardSurface,
        ),
      ),
      ..._ligneErreur(),
      const SizedBox(height: AppConstants.spacingMd),
      AppButton(
        label: 'Continuer',
        onTap: _chargement ? null : _verifier,
        isLoading: _chargement,
      ),
      const SizedBox(height: AppConstants.spacingSm),
    ];
  }

  List<Widget> _confirmation() {
    return [
      ..._entete('Accès offert', 'Premium offert par $_nom'),
      Text(
        'Louane et toutes les séances, sans limite. Ton entreprise ne voit '
        'rien de ce que tu fais dans Quieto.',
        style: _styleCorps,
      ),
      // Seulement si la personne paie déjà un abonnement Quieto à elle :
      // sinon cet encadré n'existe pas et « Activer » suit le texte.
      if (_aboPersoActif) ...[
        const SizedBox(height: AppConstants.spacingMd),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          decoration: BoxDecoration(
            color: _aube.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _aube.withValues(alpha: 0.28)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.info_outline_rounded, color: _aube, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu as aussi un abonnement Quieto personnel. Il '
                      'continuera d\'être prélevé : pense à le résilier.',
                      style: _styleCorps.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.86),
                      ),
                    ),
                    if (_gererAbonnementPerso != null) ...[
                      const SizedBox(height: AppConstants.spacingSm),
                      GestureDetector(
                        onTap: () async {
                          try {
                            await launchUrl(Uri.parse(_gererAbonnementPerso!),
                                mode: LaunchMode.externalApplication);
                          } catch (_) {}
                        },
                        child: Text(
                          'Gérer mon abonnement  →',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: _aube,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      ..._ligneErreur(),
      const SizedBox(height: AppConstants.spacingLg),
      AppButton(
        label: 'Activer',
        onTap: _chargement ? null : _activer,
        isLoading: _chargement,
      ),
      const SizedBox(height: AppConstants.spacingSm),
      AppButton(
        label: 'Changer de code',
        variant: AppButtonVariant.ghost,
        onTap: _chargement
            ? null
            : () => setState(() {
                  _erreur = null;
                  _etape = _Etape.code;
                }),
      ),
    ];
  }

  List<Widget> _activee() {
    return [
      ..._entete('C\'est activé', 'Bienvenue dans Quieto Premium'),
      Text(
        'Premium t\'est offert par $_nom. Prends soin de toi.',
        style: _styleCorps,
      ),
      const SizedBox(height: AppConstants.spacingLg),
      AppButton(
        label: 'Fermer',
        onTap: () => Navigator.of(context).pop(),
      ),
      const SizedBox(height: AppConstants.spacingSm),
    ];
  }

  List<Widget> _ligneErreur() {
    if (_erreur == null) return const [];
    return [
      const SizedBox(height: AppConstants.spacingSm),
      Text(
        _erreur!,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
      ),
    ];
  }
}
