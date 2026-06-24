import 'dart:io' show Platform;

// Clé iOS (commence par appl_) et clé Android (commence par goog_).
// Elles sont injectées via --dart-define-from-file=.env.json.
const String _revenueCatKeyIos = String.fromEnvironment('REVENUE_CAT_KEY');
const String _revenueCatKeyAndroid =
    String.fromEnvironment('REVENUE_CAT_KEY_ANDROID');

/// Renvoie la bonne clé RevenueCat selon la plateforme.
String get revenueCatApiKey =>
    Platform.isAndroid ? _revenueCatKeyAndroid : _revenueCatKeyIos;
