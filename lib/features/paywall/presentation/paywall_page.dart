import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/storage_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/error_placeholder.dart';
import '../paywall_providers.dart';

class PaywallPage extends ConsumerStatefulWidget {
  const PaywallPage({super.key});

  @override
  ConsumerState<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends ConsumerState<PaywallPage> {
  bool _showCloseButton = false;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    // La croix de fermeture apparaît après 3 secondes (ADR-013)
    _closeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showCloseButton = true);
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  void _dismiss() {
    HapticFeedback.lightImpact();
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
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _close,
          ),
        ),
        body: ErrorPlaceholder(
          message: 'Erreur : $e',
          onRetry: () => ref.invalidate(offeringProvider),
        ),
      ),
      data: (offering) {
        if (offering == null) {
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
        }
        return _buildPaywall(offering);
      },
    );
  }

  Widget _buildPaywall(Offering offering) {
    return Scaffold(
      body: Stack(
        children: [
          PaywallView(
            offering: offering,
            onDismiss: () {
              debugPrint('[Paywall] Fermeture manuelle par l\'utilisateur.');
              _close();
            },
            onPurchaseCompleted: (customerInfo, transaction) async {
              // Capturé avant les await : le context peut être démonté après.
              final router = GoRouter.of(context);
              await _onPurchaseSuccess(customerInfo);
              if (!mounted) return;
              await _showPremiumConfirmation();
              if (!mounted) return;
              // Retour à la page d'origine : l'acheteur retrouve la
              // catégorie/séance qu'il consultait, désormais débloquée.
              if (router.canPop()) {
                router.pop();
              } else {
                router.go(AppRoutes.home);
              }
            },
            onRestoreCompleted: (customerInfo) async {
              final router = GoRouter.of(context);
              await _onPurchaseSuccess(customerInfo);
              if (!mounted) return;
              await _showPremiumConfirmation();
              if (!mounted) return;
              if (router.canPop()) {
                router.pop();
              } else {
                router.go(AppRoutes.home);
              }
            },
            onPurchaseError: (error) {
              debugPrint('[Paywall] Erreur d\'achat : $error');
            },
            onRestoreError: (error) {
              debugPrint('[Paywall] Erreur de restauration : $error');
            },
          ),
          // Croix de fermeture (apparaît après 3s, ADR-013)
          Positioned(
            top: MediaQuery.of(context).padding.top + AppConstants.spacingSm,
            right: AppConstants.spacingSm,
            child: AnimatedOpacity(
              opacity: _showCloseButton ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: IgnorePointer(
                ignoring: !_showCloseButton,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    tooltip: 'Fermer',
                    onPressed: _dismiss,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
