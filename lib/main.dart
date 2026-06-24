import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/app.dart';
import 'firebase_options.dart';
import 'core/config/app_constants.dart';
import 'core/config/revenue_cat_config.dart';
import 'core/services/storage_service.dart';
import 'core/services/storage_providers.dart';
import 'features/player/data/audio_handler.dart';
import 'features/player/player_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService(prefs);

  if (revenueCatApiKey.isEmpty) {
    debugPrint(
        '[Main] ⚠️ REVENUE_CAT_KEY est vide. Lance avec --dart-define-from-file=.env.json '
        '(ou utilise les configs VS Code dans .vscode/launch.json). '
        'Le paywall ne pourra pas se charger.');
  } else {
    // Les appels RevenueCat sont bornés par un timeout : sur simulateur, le
    // réseau peut traîner, et on ne veut SURTOUT pas qu'ils bloquent l'écran
    // de démarrage. En cas d'échec/timeout, on continue quand même.
    try {
      await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(PurchasesConfiguration(revenueCatApiKey))
          .timeout(const Duration(seconds: 6));
      debugPrint('[Main] RevenueCat configuré avec succès');
    } catch (e) {
      debugPrint('[Main] ERREUR configuration RevenueCat : $e');
    }

    try {
      final customerInfo =
          await Purchases.getCustomerInfo().timeout(const Duration(seconds: 6));
      final isPremium = customerInfo.entitlements.active
          .containsKey(AppConstants.entitlementPremium);
      await storageService.setIsPremium(isPremium);
      debugPrint('[Main] isPremium: $isPremium');
    } catch (e) {
      debugPrint('[Main] getCustomerInfo failed (non-bloquant) : $e');
    }
  }

  // AudioService.init peut se bloquer indéfiniment sur simulateur (et ne peut
  // être appelé qu'UNE fois par process → un hot restart le fait freezer).
  // On le borne par un timeout : en cas d'échec, on retombe sur un handler
  // simple. La lecture audio fonctionne toujours ; seules les commandes
  // système (écran verrouillé / notification) sont indisponibles. L'app ne
  // reste JAMAIS bloquée sur un écran blanc au démarrage.
  QuietoAudioHandler audioHandler;
  try {
    audioHandler = await AudioService.init(
      builder: () => QuietoAudioHandler(storage: storageService),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.quieto.audio',
        androidNotificationChannelName: 'Quieto',
        androidNotificationOngoing: true,
      ),
    ).timeout(const Duration(seconds: 6));
  } catch (e) {
    debugPrint('[Main] AudioService.init échec/timeout, fallback handler : $e');
    audioHandler = QuietoAudioHandler(storage: storageService);
  }

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const QuietoApp(),
    ),
  );
}
