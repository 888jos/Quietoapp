import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/ambient_music.dart';
import '../core/services/storage_providers.dart';
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
  /// Dernière route notée par le greffier (évite les doublons quand le
  /// routeur notifie sans changement de page).
  String _derniereRoute = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Greffier d'écrans (Vigie) : note automatiquement CHAQUE changement de
    // page, y compris les pages futures — rien à ajouter quand une page naît,
    // rien à retirer quand une page disparaît. On enregistre le MOTIF de la
    // route ('/player/:sessionId'), jamais les valeurs : zéro donnée sensible.
    appRouter.routerDelegate.addListener(_surChangementDeRoute);
    // Préchauffe les offres RevenueCat dès le lancement, pour TOUS les
    // utilisateurs (nouveaux comme abonnés revenant directement à la home).
    // Couplé au retrait d'autoDispose sur offeringProvider, les prix restent
    // ensuite en mémoire : le paywall s'ouvre instantanément, sans roue de
    // chargement pendant l'animation de montée.
    // Best-effort : on avale l'erreur, le paywall la regère via son état error.
    ref.read(offeringProvider.future).catchError((_) => null);
    // Fait glisser la fenêtre des rappels quotidiens programmés (30 jours
    // d'avance, textes qui tournent : pas de notification répétitive, il faut
    // reprogrammer régulièrement). skipToday si la séance du jour est déjà
    // faite, pour rester fidèle au « jamais redondant ».
    final storage = ref.read(storageServiceProvider);
    final reminderHour = storage.reminderHour;
    final reminderMinute = storage.reminderMinute;
    if (storage.notificationsEnabled &&
        reminderHour != null &&
        reminderMinute != null) {
      final last = storage.loadProgress().lastSessionDate;
      final now = DateTime.now();
      final doneToday = last != null &&
          last.year == now.year &&
          last.month == now.month &&
          last.day == now.day;
      ref.read(notificationServiceProvider).scheduleDailyReminder(
            hour: reminderHour,
            minute: reminderMinute,
            skipToday: doneToday,
          );
    }
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
    appRouter.routerDelegate.removeListener(_surChangementDeRoute);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _surChangementDeRoute() {
    final conf = appRouter.routerDelegate.currentConfiguration;
    final route = conf.fullPath.isEmpty ? conf.uri.path : conf.fullPath;
    if (route == _derniereRoute) return;
    _derniereRoute = route;
    ref.read(vigieProvider).log('ecran', {'nom': route});
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
        // Vigie : note l'écran où la personne était (départ vs blocage) et
        // pousse le lot avant qu'iOS/Android ne gèlent le process.
        ref.read(vigieProvider).logFond();
      case AppLifecycleState.inactive:
        // Transitoire (centre de contrôle, app switcher…) : on ne coupe pas,
        // « paused » suivra si l'app part vraiment en arrière-plan.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Séance ARRÊTÉE au bouton stop → curseur et musique reviennent au
    // volume d'avant (sauf réglage fait pendant la séance, qui fait foi).
    // La COUPURE en début de séance, elle, vit dans playerProvider :
    // relancer la même séance ne change pas l'id, ce listener ne tirerait
    // pas. Une séance qui va au bout ne passe jamais à null : la musique
    // reste dans l'état choisi jusqu'au prochain lancement.
    ref.listen<String?>(activeSessionIdProvider, (prev, next) {
      if (next == null) {
        ref.read(ambientLevelProvider.notifier).sessionStopped();
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
