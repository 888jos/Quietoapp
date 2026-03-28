import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/storage_providers.dart';

class PaywallPage extends ConsumerStatefulWidget {
  const PaywallPage({super.key});

  @override
  ConsumerState<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends ConsumerState<PaywallPage> {
  Offering? _offering;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOffering();
  }

  Future<void> _loadOffering() async {
    try {
      debugPrint('[Paywall] Chargement des offerings...');
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;

      if (current == null) {
        debugPrint('[Paywall] Aucun offering courant trouvé.');
        debugPrint('[Paywall] Offerings disponibles : ${offerings.all.keys.toList()}');
        setState(() {
          _error = 'Aucun abonnement disponible pour le moment.';
          _loading = false;
        });
      } else {
        debugPrint('[Paywall] Offering trouvé : ${current.identifier}');
        debugPrint('[Paywall] Packages : ${current.availablePackages.map((p) => p.identifier).toList()}');
        setState(() {
          _offering = current;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[Paywall] Erreur lors du chargement : $e');
      setState(() {
        _error = 'Erreur : $e';
        _loading = false;
      });
    }
  }

  Future<void> _onPurchaseSuccess(CustomerInfo customerInfo) async {
    final isPremium = customerInfo.entitlements.active
        .containsKey(AppConstants.entitlementPremium);
    debugPrint('[Paywall] Achat réussi — isPremium: $isPremium');
    await ref.read(storageServiceProvider).setIsPremium(isPremium);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _offering == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.go(AppRoutes.home),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error ?? 'Aucun abonnement disponible.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: PaywallView(
        offering: _offering,
        onDismiss: () {
          debugPrint('[Paywall] Fermeture manuelle par l\'utilisateur.');
          context.go(AppRoutes.home);
        },
        onPurchaseCompleted: (customerInfo, transaction) async {
          final router = GoRouter.of(context);
          await _onPurchaseSuccess(customerInfo);
          if (!mounted) return;
          router.go(AppRoutes.home);
        },
        onRestoreCompleted: (customerInfo) async {
          final router = GoRouter.of(context);
          await _onPurchaseSuccess(customerInfo);
          if (!mounted) return;
          router.go(AppRoutes.home);
        },
        onPurchaseError: (error) {
          debugPrint('[Paywall] Erreur d\'achat : $error');
        },
      ),
    );
  }
}
