import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'core/config/revenue_cat_config.dart';
import 'core/services/storage_service.dart';
import 'core/services/storage_providers.dart';
import 'features/player/data/audio_handler.dart';
import 'features/player/player_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService(prefs);

  if (revenueCatApiKey.isEmpty) {
    debugPrint(
        '[Main] ⚠️ REVENUE_CAT_KEY est vide. Lance avec --dart-define-from-file=.env.json '
        '(ou utilise les configs VS Code dans .vscode/launch.json). '
        'Le paywall ne pourra pas se charger.');
  } else {
    try {
      await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(PurchasesConfiguration(revenueCatApiKey));
      debugPrint('[Main] RevenueCat configuré avec succès');
    } catch (e) {
      debugPrint('[Main] ERREUR configuration RevenueCat : $e');
    }

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final isPremium =
          customerInfo.entitlements.active.containsKey('premium');
      await storageService.setIsPremium(isPremium);
      debugPrint('[Main] isPremium: $isPremium');
    } catch (e) {
      debugPrint('[Main] getCustomerInfo failed (non-bloquant) : $e');
    }
  }

  final audioHandler = await AudioService.init(
    builder: () => QuietoAudioHandler(storage: storageService),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.quieto.audio',
      androidNotificationChannelName: 'Quieto',
      androidNotificationOngoing: true,
    ),
  );

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
