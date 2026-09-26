import 'dart:io' show Platform;

// Clé iOS (commence par appl_) et clé Android (commence par goog_).
// Elles sont injectées via --dart-define-from-file=.env.json.
const String _revenueCatKeyIos = String.fromEnvironment('REVENUE_CAT_KEY');
const String _revenueCatKeyAndroid =
    String.fromEnvironment('REVENUE_CAT_KEY_ANDROID');

/// Renvoie la bonne clé RevenueCat selon la plateforme.
String get revenueCatApiKey =>
    Platform.isAndroid ? _revenueCatKeyAndroid : _revenueCatKeyIos;

/// true si la clé est présente dans le build. Si elle manque (build fait
/// sans --dart-define-from-file), AUCUN appel à Purchases ne doit partir :
/// le SDK natif s'écrase avec un fatalError au lieu de renvoyer une erreur
/// rattrapable (crash écran noir au lancement, vécu sur la 1.0.7 build 9).
bool get revenueCatDisponible => revenueCatApiKey.isNotEmpty;
