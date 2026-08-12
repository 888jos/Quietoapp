import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/storage_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/error_placeholder.dart';
import '../paywall_providers.dart';
import 'paywall_screen.dart';

/// INTERRUPTEUR DE SECOURS — mets `false` pour revenir INSTANTANÉMENT à
/// l'ancien paywall natif RevenueCat si le nouveau (100 % Flutter) pose souci.
/// Aucune autre modif : on recompile et l'ancien écran revient tel quel.
const bool kUsePaywallFlutter = true;

class PaywallPage extends ConsumerStatefulWidget {
  const PaywallPage({super.key});

  @override
  ConsumerState<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends ConsumerState<PaywallPage> {
  // ValueNotifier (et non un bool + setState) : quand la croix apparaît à 3s,
  // seul le petit bouton se reconstruit via ValueListenableBuilder — le gros
  // PaywallView natif n'est PAS repeint (évite un à-coup).
  final ValueNotifier<bool> _showCloseButton = ValueNotifier(false);
  Timer? _closeTimer;

  bool _busy = false; // achat / restauration en cours
  bool _autoClosed = false; // évite de refermer 2× quand aucune offre n'existe
  bool _erreurTracee = false; // une seule trace Vigie par ouverture en erreur

  // Vigie : surface d'origine (onboarding, louane, categorie, profil, seance)
  // + heure d'ouverture → durée passée sur le paywall, et taux de conversion
  // par surface. Aucun événement « achat » ici n'est deviné : chacun suit un
  // vrai retour RevenueCat.
  String _vigieSource = 'onboarding';
  late final DateTime _vigieOuvertA;
  bool _vigieAchete = false;

  int get _vigieDureeS => DateTime.now().difference(_vigieOuvertA).inSeconds;

  static const _urlConfidentialite =
      'https://www.notion.so/Politique-de-Confidentialit-31de9e37b4a88093b560e0636712146e';
  static const _urlConditions =
      'https://www.notion.so/Terms-31de9e37b4a88085a949e24158d042e9';

  // Le paywall natif (PaywallView) est LOURD à monter : s'il s'instancie pendant
  // l'animation de montée, la transition saccade. On attend donc que la montée
  // soit FINIE avant de le monter — la montée reste 100 % fluide (écran léger),
  // puis le vrai paywall apparaît en fondu doux sur un écran déjà immobile.
  bool _pretPourLeNatif = false;
  Animation<double>? _transitionRoute;

  @override
  void initState() {
    super.initState();
    // Le préchargement fait au lancement peut avoir échoué : à froid, le
    // réseau/le store ne sont pas toujours prêts, et cet échec resterait en
    // cache TOUTE la session (offeringProvider n'a pas d'autoDispose). C'était
    // le bug « abonnements indisponibles » de la 1.0.14 (36 % des ouvertures).
    // Donc à CHAQUE ouverture : si le cache n'a pas une offre achetable, on
    // recharge — la personne navigue, le réseau est disponible maintenant.
    final offres = ref.read(offeringProvider);
    final achetable =
        offres.valueOrNull?.availablePackages.isNotEmpty ?? false;
    if (!offres.isLoading && !achetable) {
      // Pas `ref.invalidate` ici : dans initState il fait crasher la page
      // (il écoute le ProviderScope, interdit avant la fin d'initState).
      ProviderScope.containerOf(context, listen: false)
          .invalidate(offeringProvider);
    }
    // La croix de fermeture apparaît après 3 secondes (ADR-013)
    _closeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _showCloseButton.value = true;
    });
    _vigieOuvertA = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final q = GoRouterState.of(context).uri.queryParameters;
      _vigieSource = q['src'] ?? (q['from'] == 'premium' ? 'premium' : 'onboarding');
      ref.read(vigieProvider).log('paywall_affiche', {'source': _vigieSource});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Suit l'animation d'arrivée de la route : on ne monte le paywall natif
    // qu'une fois la transition terminée (status == completed).
    final anim = ModalRoute.of(context)?.animation;
    if (identical(anim, _transitionRoute)) return;
    _transitionRoute?.removeStatusListener(_onTransition);
    _transitionRoute = anim;
    if (anim == null || anim.isCompleted) {
      _pretPourLeNatif = true; // pas de transition (ou déjà finie) → direct
    } else {
      anim.addStatusListener(_onTransition);
    }
  }

  void _onTransition(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted && !_pretPourLeNatif) {
      setState(() => _pretPourLeNatif = true);
    }
  }

  @override
  void dispose() {
    _transitionRoute?.removeStatusListener(_onTransition);
    _closeTimer?.cancel();
    _showCloseButton.dispose();
    super.dispose();
  }

  void _dismiss() {
    HapticFeedback.lightImpact();
    // Vigie : fermeture par la croix = un refus, avec le temps passé dessus.
    ref.read(vigieProvider).log('paywall_ferme', {
      'source': _vigieSource,
      'apres_s': _vigieDureeS,
    });
    _close();
  }

  /// Ferme le paywall en revenant à la page d'origine (catégorie, séance,
  /// profil…) avec l'animation de descente. Cas onboarding : le paywall a été
  /// ouvert via `context.go` (pile vide, canPop = false) → fallback home.
  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _onPurchaseSuccess(CustomerInfo customerInfo) async {
    final isPremium = customerInfo.entitlements.active
        .containsKey(AppConstants.entitlementPremium);
    debugPrint('[Paywall] Achat réussi — isPremium: $isPremium');
    try {
      await ref.read(storageServiceProvider).setIsPremium(isPremium);
    } catch (e) {
      debugPrint('[Paywall] setIsPremium a échoué (non-bloquant) : $e');
    }
    // Pas besoin d'invalider subscriptionProvider : depuis sa conversion
    // en StateNotifierProvider qui écoute Purchases.addCustomerInfoUpdateListener,
    // le state est déjà mis à jour automatiquement par le listener RC quand
    // l'achat se conclut.
  }

  /// Flux commun après un achat/restauration réussi : marque premium, montre la
  /// confirmation, puis revient à la page d'origine. Utilisé par le paywall
  /// Flutter ET le paywall natif → mêmes étapes, rien ne change côté paiement.
  Future<void> _finaliserAchat(CustomerInfo info) async {
    final router = GoRouter.of(context); // capturé avant les await
    if (!_vigieAchete) {
      _vigieAchete = true;
      ref.read(vigieProvider).log('achat_reussi', {
        'source': _vigieSource,
        'apres_s': _vigieDureeS,
      });
      // L'achat est LE moment clé : on pousse tout de suite, sans attendre.
      ref.read(vigieProvider).flush();
    }
    await _onPurchaseSuccess(info);
    if (!mounted) return;
    await _showPremiumConfirmation();
    if (!mounted) return;
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(AppRoutes.home);
    }
  }

  // ── Branchement du paywall design (PaywallScreen) ───────

  /// Achat depuis le CTA du nouveau paywall (forfait sélectionné).
  Future<void> _onStart(Package? pkg) async {
    if (pkg == null) {
      _snack('Offre indisponible. Réessaie dans un instant.');
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    final plan = pkg.packageType == PackageType.annual ? 'annuel' : 'mensuel';
    ref.read(vigieProvider).log('achat_tente', {
      'source': _vigieSource,
      'plan': plan,
    });
    try {
      final result = await Purchases.purchase(PurchaseParams.package(pkg));
      if (!mounted) return;
      await _finaliserAchat(result.customerInfo);
    } on PlatformException catch (e) {
      // Annulation utilisateur → silencieux (pas une erreur).
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError) {
        ref.read(vigieProvider).log('achat_erreur', {'plan': plan});
        _snack('L\'achat n\'a pas pu aboutir. Réessaie dans un instant.');
      } else {
        ref.read(vigieProvider).log('achat_annule', {'plan': plan});
      }
    } catch (_) {
      ref.read(vigieProvider).log('achat_erreur', {'plan': plan});
      _snack('Une erreur est survenue. Réessaie dans un instant.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Restauration depuis « Restaurer mes achats ».
  Future<void> _onRestore() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final info = await Purchases.restorePurchases();
      if (!mounted) return;
      final premium = info.entitlements.active
          .containsKey(AppConstants.entitlementPremium);
      if (premium) {
        await _finaliserAchat(info);
      } else {
        _snack('Aucun abonnement à restaurer sur ce compte.');
      }
    } on PlatformException catch (_) {
      _snack('La restauration a échoué. Réessaie dans un instant.');
    } catch (_) {
      _snack('Une erreur est survenue. Réessaie dans un instant.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ouvrirLien(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _snack(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.cardSurface,
        margin: const EdgeInsets.all(AppConstants.spacingMd),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg)),
        content: Text(texte, style: const TextStyle(color: Colors.white)),
      ));
  }

  /// Construit l'offre affichée (prix, dates, essai) à partir d'un package RC.
  PaywallOffer _buildOffer(Package p, {required bool annuel, int? savePct}) {
    final sp = p.storeProduct;
    final trial = _trialDays(sp);
    final reminder = trial - 2;
    // Prix RÉELS RevenueCat, localisés automatiquement selon le pays du compte
    // (€, $, £…). Exigé par Apple (règle 3.1.2) : le prix affiché doit être
    // exactement le prix facturé, dans la devise de l'utilisateur.
    return PaywallOffer(
      trialDays: trial,
      pricePerMonth:
          annuel ? (sp.pricePerMonthString ?? sp.priceString) : sp.priceString,
      billingLine: annuel
          ? 'facturé ${sp.priceString} par an'
          : 'facturé chaque mois, sans engagement',
      saveBadge: (annuel && savePct != null) ? 'Économise $savePct %' : null,
      reminderWhen: reminder <= 1 ? 'Demain' : 'Dans $reminder jours',
      chargeWhen: 'Dans $trial jours',
      chargeDate: _chargeDate(trial),
    );
  }

  int _trialDays(StoreProduct p) {
    final intro = p.introductoryPrice;
    if (intro == null || intro.price != 0) return 0;
    final n = intro.periodNumberOfUnits;
    return switch (intro.periodUnit) {
      PeriodUnit.day => n,
      PeriodUnit.week => n * 7,
      PeriodUnit.month => n * 30,
      PeriodUnit.year => n * 365,
      _ => n,
    };
  }

  /// Les placeholders du design embarquent des dates d'exemple (« le 3 juillet »).
  /// Quand ils servent (debug sans produits, package manquant côté RC), on
  /// recalcule les dates à partir d'aujourd'hui : une date fausse ne doit
  /// JAMAIS s'afficher, seuls les prix d'exemple restent.
  PaywallOffer _placeholderAvecVraiesDates(PaywallOffer p) {
    final reminder = p.trialDays - 2;
    return PaywallOffer(
      trialDays: p.trialDays,
      pricePerMonth: p.pricePerMonth,
      billingLine: p.billingLine,
      saveBadge: p.saveBadge,
      reminderWhen: reminder <= 1 ? 'Demain' : 'Dans $reminder jours',
      chargeWhen: 'Dans ${p.trialDays} jours',
      chargeDate: _chargeDate(p.trialDays),
    );
  }

  String _chargeDate(int trial) {
    const mois = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
      'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    final d = DateTime.now().add(Duration(days: trial));
    return 'le ${d.day} ${mois[d.month - 1]}';
  }

  /// Alerte native iOS de confirmation (façon Calm). S'affiche par-dessus le
  /// paywall, non annulable au tap extérieur : l'utilisateur doit taper
  /// « Parfait ».
  Future<void> _showPremiumConfirmation() {
    return showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Félicitations !'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
              'Vous bénéficiez désormais de ${AppConstants.appName} Premium'),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Parfait'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offeringAsync = ref.watch(offeringProvider);

    return offeringAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) {
        // Panne de chargement (réseau…) : jusqu'ici invisible dans la Vigie —
        // seule l'offre vide était tracée. Une trace par ouverture.
        if (!_erreurTracee) {
          _erreurTracee = true;
          ref.read(vigieProvider).log('paywall_erreur_chargement', {
            'source': _vigieSource,
          });
        }
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: _close,
            ),
          ),
          body: ErrorPlaceholder(
            message: 'Aucun abonnement disponible pour le moment.',
            onRetry: () => ref.invalidate(offeringProvider),
          ),
        );
      },
      data: (offering) {
        // Aucun produit sur cette plateforme (Android tant que Play + RC ne
        // sont pas branchés) : en DEBUG on affiche quand même le paywall
        // Flutter avec ses prix d'exemple pour valider le design ; en release
        // on referme sans bloquer l'utilisateur.
        if (offering == null && !(kDebugMode && kUsePaywallFlutter)) {
          return _fermerSansPaywall();
        }
        return _buildPaywall(offering);
      },
    );
  }

  /// Aucun abonnement à vendre : offre RevenueCat nulle (produits App Store
  /// pas récupérables : en attente de validation, agrément expiré, offre
  /// vide…). On ne referme PLUS en silence : du 24 au 25 juillet 2026, une
  /// offre cassée (renommage « Abonnement » → « Abonnement 2 » au changement
  /// de prix) a fait se refermer le paywall instantanément pour TOUS les
  /// utilisateurs — impossible de payer, zéro signal. Maintenant : trace
  /// Vigie + écran d'erreur avec réessai, comme pour une panne réseau.
  Widget _fermerSansPaywall() {
    if (!_autoClosed) {
      _autoClosed = true;
      // Une seule trace par ouverture (le build peut repasser ici).
      ref.read(vigieProvider).log('paywall_offre_vide', {
        'source': _vigieSource,
      });
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: _close,
        ),
      ),
      body: ErrorPlaceholder(
        message: 'Les abonnements ne sont pas disponibles pour le moment. '
            'Réessaie dans un instant.',
        onRetry: () => ref.invalidate(offeringProvider),
      ),
    );
  }

  Widget _buildPaywall(Offering? offering) {
    // Secours : ancien paywall natif RevenueCat (mettre kUsePaywallFlutter=false).
    if (!kUsePaywallFlutter) {
      if (offering == null) return _fermerSansPaywall();
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            Positioned.fill(child: _vueNativeDifferee(offering)),
            _boutonFermeture(),
          ],
        ),
      );
    }

    // Nouveau paywall design (PaywallScreen) alimenté par RevenueCat.
    // offering null (debug sans produits) : prix d'exemple, achat impossible.
    Package? annuel, mensuel;
    for (final p in offering?.availablePackages ?? const <Package>[]) {
      if (p.packageType == PackageType.annual) annuel = p;
      if (p.packageType == PackageType.monthly) mensuel = p;
    }
    // Release : offre présente mais AUCUN forfait annuel/mensuel résolu →
    // le paywall montrerait les prix d'exemple avec un CTA mort (_onStart
    // reçoit null). Mieux vaut l'écran « indisponible » avec réessai — et la
    // trace paywall_offre_vide, sinon ce cas est invisible dans la Vigie.
    if (!kDebugMode && annuel == null && mensuel == null) {
      return _fermerSansPaywall();
    }
    int? savePct;
    if (annuel != null &&
        mensuel != null &&
        mensuel.storeProduct.price > 0) {
      savePct = ((1 - annuel.storeProduct.price / (mensuel.storeProduct.price * 12)) *
              100)
          .round();
    }
    final offreAnnuel = annuel != null
        ? _buildOffer(annuel, annuel: true, savePct: savePct)
        : _placeholderAvecVraiesDates(PaywallOffer.placeholderAnnual);
    final offreMensuel = mensuel != null
        ? _buildOffer(mensuel, annuel: false)
        : _placeholderAvecVraiesDates(PaywallOffer.placeholderMonthly);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: PaywallScreen(
              annual: offreAnnuel,
              monthly: offreMensuel,
              onStart: (plan) => _onStart(
                  plan == PaywallPlan.annual ? annuel : mensuel),
              onRestore: _onRestore,
              onTerms: () => _ouvrirLien(_urlConditions),
              onPrivacy: () => _ouvrirLien(_urlConfidentialite),
            ),
          ),
          // Voile + spinner pendant un achat/restauration (anti double-tap).
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent)),
              ),
            ),
          _boutonFermeture(),
        ],
      ),
    );
  }

  /// Paywall natif (secours) : on monte un écran léger pendant la montée, puis
  /// la vue native apparaît en fondu une fois l'écran immobile.
  Widget _vueNativeDifferee(Offering offering) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: _pretPourLeNatif
          ? _vueNative(offering)
          : ColoredBox(
              key: const ValueKey('paywall-placeholder'),
              color: AppColors.background,
            ),
    );
  }

  /// Croix de fermeture (apparaît après 3s, ADR-013). ValueListenableBuilder :
  /// seul ce bouton se reconstruit au bout de 3s, jamais le contenu du paywall.
  Widget _boutonFermeture() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + AppConstants.spacingSm,
      right: AppConstants.spacingSm,
      child: ValueListenableBuilder<bool>(
        valueListenable: _showCloseButton,
        builder: (context, show, child) => AnimatedOpacity(
          opacity: show ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: IgnorePointer(ignoring: !show, child: child),
        ),
        child: IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: Colors.white.withValues(alpha: 0.85),
            size: 24,
          ),
          style: IconButton.styleFrom(
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.white.withValues(alpha: 0.08),
          ),
          tooltip: 'Fermer',
          onPressed: _dismiss,
        ),
      ),
    );
  }

  /// Le paywall natif RevenueCat. Monté seulement une fois la montée terminée
  /// (voir [_pretPourLeNatif]) : la transition reste lisse, et cette vue apparaît
  /// ensuite en fondu via l'AnimatedSwitcher.
  Widget _vueNative(Offering offering) {
    return KeyedSubtree(
      key: const ValueKey('paywall-natif'),
      child: PaywallView(
        offering: offering,
        onDismiss: () {
          debugPrint('[Paywall] Fermeture manuelle par l\'utilisateur.');
          _close();
        },
        onPurchaseCompleted: (customerInfo, transaction) =>
            _finaliserAchat(customerInfo),
        onRestoreCompleted: (customerInfo) => _finaliserAchat(customerInfo),
        onPurchaseError: (error) {
          debugPrint('[Paywall] Erreur d\'achat : $error');
        },
        onRestoreError: (error) {
          debugPrint('[Paywall] Erreur de restauration : $error');
        },
      ),
    );
  }
}
