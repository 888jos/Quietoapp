import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config/revenue_cat_config.dart';

/// Connexion au compte utilisateur (Firebase Auth).
///
/// L'app reste utilisable sans compte : la connexion est proposée, jamais
/// imposée. Elle sert à savoir qui utilise Quieto et à préparer la
/// sauvegarde de la progression dans le cloud.
///
/// Fournisseurs : Apple (iOS uniquement) et Google (iOS + Android).

/// Utilisateur connecté (null si personne). Réactif : l'UI se met à jour
/// toute seule à la connexion / déconnexion.
final utilisateurProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Résultat d'une tentative de connexion, pour que l'UI sache quoi afficher.
enum AuthResultat { ok, annule, erreur }

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  /// Le bouton Apple ne se montre que sur iPhone/iPad : sur Android le
  /// parcours Apple exige une config web lourde, Google suffit.
  bool get appleDisponible => Platform.isIOS;

  // ── Google ───────────────────────────────────────────

  Future<AuthResultat> connexionGoogle() async {
    try {
      final compte = await GoogleSignIn(scopes: const ['email']).signIn();
      // L'utilisateur a fermé la fenêtre : pas une erreur.
      if (compte == null) return AuthResultat.annule;

      final jetons = await compte.authentication;
      final resultat = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(
          idToken: jetons.idToken,
          accessToken: jetons.accessToken,
        ),
      );
      await _lierRevenueCat(resultat.user);
      return AuthResultat.ok;
    } catch (_) {
      return AuthResultat.erreur;
    }
  }

  // ── Apple ────────────────────────────────────────────

  Future<AuthResultat> connexionApple() async {
    try {
      // Le nonce prouve à Firebase que la réponse d'Apple nous est bien
      // destinée (exigence de sécurité du protocole).
      final brut = _nonceAleatoire();
      final credentialApple = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(brut)).toString(),
      );

      final resultat = await _auth.signInWithCredential(
        OAuthProvider('apple.com').credential(
          idToken: credentialApple.identityToken,
          rawNonce: brut,
          // Depuis firebase_auth 5.2, le code d'autorisation d'Apple est
          // obligatoire en plus du jeton : sans lui, Firebase répond
          // « invalid-credential / Invalid OAuth response from apple.com »
          // (l'erreur vue par le testeur Apple, refus 2.1(a) du 2026-08-05).
          accessToken: credentialApple.authorizationCode,
        ),
      );

      // Apple ne transmet le prénom qu'à la toute première connexion :
      // on le range tout de suite, sinon il est perdu pour toujours.
      final user = resultat.user;
      final prenom = credentialApple.givenName;
      if (user != null &&
          (user.displayName == null || user.displayName!.isEmpty) &&
          prenom != null &&
          prenom.isNotEmpty) {
        await user.updateDisplayName(prenom);
      }
      await _lierRevenueCat(user);
      return AuthResultat.ok;
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint('[Auth] Apple refusé/échoué: ${e.code} ${e.message}');
      return e.code == AuthorizationErrorCode.canceled
          ? AuthResultat.annule
          : AuthResultat.erreur;
    } catch (e) {
      debugPrint('[Auth] connexion Apple échouée: $e');
      return AuthResultat.erreur;
    }
  }

  // ── RevenueCat ───────────────────────────────────────

  /// Relie l'abonnement au compte : dans RevenueCat, la personne apparaît
  /// avec son e-mail et son prénom au lieu d'un code anonyme, et son
  /// abonnement la suit si elle change de téléphone.
  Future<void> _lierRevenueCat(User? user) async {
    if (user == null || !revenueCatDisponible) return;
    try {
      await Purchases.logIn(user.uid);
      final email = user.email;
      if (email != null && email.isNotEmpty) {
        await Purchases.setEmail(email);
      }
      final nom = user.displayName;
      if (nom != null && nom.isNotEmpty) {
        await Purchases.setDisplayName(nom);
      }
    } catch (_) {
      // L'abonnement continue de marcher en anonyme : ne jamais bloquer
      // la connexion pour ça.
    }
  }

  /// Redonne un profil anonyme à RevenueCat. L'abonnement, lui, reste lié
  /// au compte Apple/Google du téléphone : « Restaurer mes achats » ou un
  /// simple relancement le retrouve.
  Future<void> _delierRevenueCat() async {
    if (!revenueCatDisponible) return;
    try {
      if (!await Purchases.isAnonymous) {
        await Purchases.logOut();
      }
    } catch (_) {}
  }

  // ── Déconnexion / suppression ────────────────────────

  Future<void> deconnexion() async {
    // On coupe aussi la session Google, sinon la prochaine connexion
    // reprend le même compte sans jamais montrer le sélecteur.
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _delierRevenueCat();
    await _auth.signOut();
  }

  /// Supprime le compte (exigence App Store dès qu'on propose la création
  /// de compte). Renvoie false si Firebase exige une connexion récente :
  /// l'UI invite alors à se reconnecter puis à réessayer.
  Future<bool> supprimerCompte() async {
    final user = _auth.currentUser;
    if (user == null) return true;
    try {
      await user.delete();
      await _delierRevenueCat();
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') return false;
      rethrow;
    }
  }

  String _nonceAleatoire([int longueur = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(longueur, (_) => chars[random.nextInt(chars.length)])
        .join();
  }
}
