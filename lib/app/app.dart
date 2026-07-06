import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/ambient_music.dart';
import '../core/theme/app_theme.dart';
import '../features/paywall/paywall_providers.dart';
import '../features/player/player_providers.dart';
import 'router.dart';

class QuietoApp extends ConsumerStatefulWidget {
  const QuietoApp({super.key});

  @override
  ConsumerState<QuietoApp> createState() => _QuietoAppState();
}

class _QuietoAppState extends ConsumerState<QuietoApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Préchauffe les offres RevenueCat dès le lancement, pour TOUS les
    // utilisateurs (nouveaux comme abonnés revenant directement à la home).
    // Couplé au retrait d'autoDispose sur offeringProvider, les prix restent
    // ensuite en mémoire : le paywall s'ouvre instantanément, sans roue de
    // chargement pendant l'animation de montée.
    // Best-effort : on avale l'erreur, le paywall la regère via son état error.
    ref.read(offeringProvider.future).catchError((_) => null);
    // Musique de fond de l'app dès le lancement (sauf si une séance est déjà
    // active, ce qui n'arrive jamais au démarrage à froid).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(activeSessionIdProvider) == null) {
        ref.read(ambientMusicProvider).play();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coupe la musique de fond quand l'app part en arrière-plan ou que le
  /// téléphone se verrouille, la reprend au retour (sauf séance en cours,
  /// qui gère son propre audio).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final music = ref.read(ambientMusicProvider);
    switch (state) {
      case AppLifecycleState.resumed:
        if (ref.read(activeSessionIdProvider) == null) music.play();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        music.pause();
      case AppLifecycleState.inactive:
        // Transitoire (centre de contrôle, app switcher…) : on ne coupe pas,
        // « paused » suivra si l'app part vraiment en arrière-plan.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Coupe la musique de fond pendant une séance (mini-player compris),
    // la reprend dès que la séance est fermée.
    ref.listen<String?>(activeSessionIdProvider, (prev, next) {
      final music = ref.read(ambientMusicProvider);
      if (next == null) {
        music.play();
      } else {
        music.pause();
      }
    });
    return MaterialApp.router(
      title: 'Quieto',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
