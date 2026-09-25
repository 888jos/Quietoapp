import 'dart:async' show unawaited;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'app/app.dart';
import 'firebase_options.dart';
import 'core/config/app_constants.dart';
import 'core/config/revenue_cat_config.dart';
import 'core/services/abonnement_serveur.dart';
import 'core/services/acces_entreprise.dart';
import 'core/services/storage_service.dart';
import 'core/services/storage_providers.dart';
import 'core/services/vigie_service.dart';
import 'features/player/data/audio_handler.dart';
import 'features/player/player_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // L'app est pensée pour le portrait uniquement : on bloque la rotation.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Fonctions LOCALES (debug seulement) : pour tester une nouvelle Louane sur
  // le simulateur AVANT de la déployer. Lancer l'émulateur dans
  // quieto-backend (`firebase emulators:start --only functions --project
  // quieto-06`), puis :
  //   flutter run --dart-define-from-file=.env.json --dart-define=FONCTIONS_LOCALES=true
  // Sur un VRAI iPhone, 127.0.0.1 est le téléphone lui-même : passer l'IP
  // du Mac sur le Wi-Fi (`ipconfig getifaddr en0`) et ouvrir l'émulateur au
  // réseau (`emulators.functions.host` = 0.0.0.0 dans firebase.json) :
  //   … --dart-define=FONCTIONS_HOTE=192.168.1.117
  // Sans ce define (et toujours en release), l'app parle à la prod.
  const fonctionsLocales = bool.fromEnvironment('FONCTIONS_LOCALES');
  const fonctionsHote =
      String.fromEnvironment('FONCTIONS_HOTE', defaultValue: '127.0.0.1');
  if (kDebugMode && fonctionsLocales) {
    FirebaseFunctions.instance.useFunctionsEmulator(fonctionsHote, 5001);
    debugPrint('[Main] Cloud Functions → émulateur local $fonctionsHote:5001');
  }

  // App Check : prouve à Firebase que l'appel vient bien de NOTRE vraie app,
  // pas d'un script qui voudrait cramer les crédits Claude.
  // - En dev (debug) : provider "debug" → un jeton à coller dans la console.
  // - En prod (release) : App Attest (iOS) / Play Integrity (Android).
  // On le borne par un timeout : s'il échoue, l'app démarre quand même.
  try {
    await FirebaseAppCheck.instance.activate(
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestProvider(),
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    ).timeout(const Duration(seconds: 6));
    debugPrint('[Main] App Check activé (${kDebugMode ? "debug" : "prod"})');
  } catch (e) {
    debugPrint('[Main] App Check activation échec (non-bloquant) : $e');
  }

  // Test « nouvel utilisateur » sur un vrai iPhone : le trousseau survit à la
  // désinstallation (compte anonyme Firebase, coffre chiffré), donc une simple
  // réinstallation ne repart PAS de zéro. En debug seulement, avec
  // `--dart-define=NOUVEL_UTILISATEUR=true`, on efface tout UNE fois par
  // installation (marqueur dans les préférences, lui-même effacé à la
  // désinstallation). Sans effet sur les builds normaux.
  const nouvelUtilisateur = bool.fromEnvironment('NOUVEL_UTILISATEUR');
  if (kDebugMode && nouvelUtilisateur) {
    final prefsInit = await SharedPreferences.getInstance();
    if (!prefsInit.containsKey('nouvel_utilisateur_fait')) {
      try {
        await FirebaseAuth.instance.signOut();
        await StorageService(prefsInit).clearAll();
        await prefsInit.setBool('nouvel_utilisateur_fait', true);
        debugPrint('[Main] NOUVEL_UTILISATEUR : trousseau et préférences effacés');
      } catch (e) {
        debugPrint('[Main] NOUVEL_UTILISATEUR : effacement échoué : $e');
      }
    }
  }

  // Identité Firebase pour TOUT LE MONDE (audit sécurité du 02/09/2026) :
  // sans compte Apple/Google, une connexion ANONYME donne au serveur un
  // identifiant stable et vérifiable (quotas, abonnement, accès aux MP3).
  // Invisible pour la personne ; elle devient un vrai compte à la connexion
  // (linkWithCredential dans auth_service.dart). Bornée : l'app démarre
  // quand même si le réseau traîne ou si la connexion anonyme est refusée.
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance
          .signInAnonymously()
          .timeout(const Duration(seconds: 6));
      debugPrint('[Main] connexion anonyme Firebase OK');
    }
  } catch (e) {
    debugPrint('[Main] connexion anonyme Firebase échouée (non-bloquant) : $e');
  }

  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService(prefs);
  // Fiche mémoire de Louane, réponses d'onboarding et prénom vivent dans le
  // coffre chiffré : on les charge une fois en mémoire avant tout affichage.
  await storageService.chargerCoffre();

  // Vigie (mesure d'usage interne, anonyme) : un événement d'ouverture par
  // lancement, avec l'état de départ (permet funnel + rétention).
  final vigie = VigieService(prefs);
  vigie.log('app_ouverte', {
    'onboarding_fait': storageService.isOnboardingDone,
    'premium': storageService.isPremium,
    'messages_louane_total': storageService.louaneCompteurTotal,
  });

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
      // Journal RevenueCat verbeux en debug seulement : en release, il
      // laissait l'identifiant, les produits et les droits dans les logs
      // du téléphone (audit du 02/09/2026).
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);
      await Purchases.configure(PurchasesConfiguration(revenueCatApiKey))
          .timeout(const Duration(seconds: 6));
      // RevenueCat parle le même identifiant que Firebase (compte anonyme
      // compris) : c'est ce qui permet au serveur de vérifier l'abonnement
      // sans rien croire de ce que l'app raconte. Un ancien profil
      // RevenueCat anonyme est fusionné dans ce compte (les achats suivent).
      final uidFirebase = FirebaseAuth.instance.currentUser?.uid;
      if (uidFirebase != null) {
        await Purchases.logIn(uidFirebase).timeout(const Duration(seconds: 6));
      }
      // Étiquette Vigie sur le profil RevenueCat : le webhook (backend) s'en
      // sert pour relier l'issue d'un essai — convertie ou annulée des jours
      // plus tard chez Apple/Google, app fermée — au parcours anonyme de
      // vigie_events. Posée à chaque lancement : se répare toute seule.
      await Purchases.setAttributes({'vigie': vigie.id});
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
    // Nom de l'entreprise qui offre Premium (accès B2B), pour le profil.
    await AccesEntreprise.charger();
    // Le serveur pose le claim `premium` (accès aux MP3 premium) — en fond,
    // jamais bloquant pour le démarrage.
    unawaited(synchroniserAbonnementServeur());
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
        vigieProvider.overrideWithValue(vigie),
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const QuietoApp(),
    ),
  );
}
