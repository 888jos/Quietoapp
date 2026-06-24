import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../features/paywall/paywall_providers.dart';
import 'router.dart';

class QuietoApp extends ConsumerStatefulWidget {
  const QuietoApp({super.key});

  @override
  ConsumerState<QuietoApp> createState() => _QuietoAppState();
}

class _QuietoAppState extends ConsumerState<QuietoApp> {
  @override
  void initState() {
    super.initState();
    // Préchauffe les offres RevenueCat dès le lancement, pour TOUS les
    // utilisateurs (nouveaux comme abonnés revenant directement à la home).
    // Couplé au retrait d'autoDispose sur offeringProvider, les prix restent
    // ensuite en mémoire : le paywall s'ouvre instantanément, sans roue de
    // chargement pendant l'animation de montée.
    // Best-effort : on avale l'erreur, le paywall la regère via son état error.
    ref.read(offeringProvider.future).catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Quieto',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
