import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

import '../../app/router.dart';
import '../config/app_constants.dart';
import '../ui/avis_dialog.dart';
import 'storage_providers.dart';
import 'storage_service.dart';
import 'vigie_service.dart';

/// Demande d'avis sur le store, en trois temps :
///
/// 1. Une carte Quieto (voir avis_dialog.dart) pose la question franchement :
///    « Est-ce que Quieto te fait du bien ? ». Elle filtre les mécontents
///    (protège la note moyenne) et permet un design à nous — le popup
///    système, lui, est imposé par l'OS et immodifiable.
/// 2. Sur un « oui » seulement : le popup natif de notation (5 étoiles,
///    SKStoreReviewController sur iOS / In-App Review sur Android). L'OS
///    décide LUI-MÊME de l'afficher ou non (iOS plafonne à ~3 par an,
///    silencieux sinon ; Android ne montre rien hors build Play Store).
/// 3. Sur un « pas vraiment » : la carte demande ce qui coince (raisons à
///    toucher, un mot libre, tout facultatif) et ce retour part dans la
///    boîte aux lettres de la Vigie (Cloud Function `retour`), anonyme.
///    Qui a pris le temps de répondre ne revoit plus jamais la carte.
///
/// Nos propres garde-fous par-dessus ceux de l'OS pour ne jamais harceler :
/// délai minimal entre deux propositions, plafond total.
///
/// Exception : en fin d'onboarding, le popup natif part DIRECTEMENT, sans
/// la carte — voir [solliciterNotationOnboarding].
class ReviewService {
  ReviewService(this._storage, this._vigie);

  final StorageService _storage;
  final VigieService _vigie;

  /// Délai minimal entre deux propositions.
  static const _joursEntreDemandes = 60;

  /// Au-delà, on ne propose plus jamais (qui n'a pas noté en 4 fois ne
  /// notera pas — inutile d'user le quota iOS ou la patience des gens).
  static const _maxDemandes = 4;

  /// Vrai le temps qu'une carte est à l'écran : deux déclencheurs quasi
  /// simultanés ne doivent jamais empiler deux cartes.
  bool _enCours = false;

  /// Propose la carte d'avis si les garde-fous le permettent, puis le popup
  /// natif si la personne répond oui, ou l'envoi de son retour si elle a dit
  /// ce qui coince. [declencheur] documente le moment pour la Vigie
  /// ('seance_terminee', 'etoile_parcours', 'creation_programme').
  Future<void> solliciterAvis(String declencheur) async {
    if (_enCours) return;
    _enCours = true;
    try {
      final nb = _storage.avisNbDemandes;
      // En debug, les garde-fous ne bloquent pas : on doit pouvoir revoir la
      // carte à chaque déclencheur pour tester (le popup système suit
      // toujours hors App Store). En prod, ils protègent la patience des
      // gens.
      if (!kDebugMode && !_gardeFousOk(nb)) return;
      // Le popup système doit pouvoir suivre le « oui » : sinon, ne rien
      // proposer du tout.
      final inAppReview = InAppReview.instance;
      final disponible = await inAppReview.isAvailable();
      debugPrint('[Review] declencheur=$declencheur disponible=$disponible');
      if (!disponible) return;
      // Persisté AVANT l'affichage : si l'app est tuée carte à l'écran,
      // on ne resollicitera quand même pas trop tôt.
      await _storage.enregistreDemandeAvis();
      _vigie.log('avis_propose', {
        'declencheur': declencheur,
        'demande_no': nb + 1,
      });
      // Contexte relu APRÈS les await (lint use_build_context_synchronously).
      final context = rootNavigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      debugPrint('[Review] carte affichée');
      final resultat = await montrerAvisDialog(context);
      debugPrint(
        '[Review] reponse=${resultat.choix.name} '
        'raisons=${resultat.raisons} texte=${resultat.texte.length} car.',
      );
      _vigie.log('avis_reponse', {
        'declencheur': declencheur,
        'reponse': resultat.choix.name,
      });
      if (resultat.choix == AvisChoix.oui) {
        await inAppReview.requestReview();
        return;
      }
      if (!resultat.aRetour) return;
      // Retenu AVANT l'envoi : même si le réseau lâche, la personne ne sera
      // plus jamais resollicitée — elle a fait sa part.
      await _storage.enregistreRetourAvis();
      // En arrière-plan : la feuille est déjà refermée, l'app continue.
      unawaited(_deposerRetour(declencheur, resultat));
    } catch (e, st) {
      // Ne doit JAMAIS gêner l'app : un avis raté est sans gravité.
      debugPrint('[Review] solliciterAvis failed: $e\n$st');
    } finally {
      _enCours = false;
    }
  }

  /// Fin d'onboarding, au moment de passer au mur d'abonnement : le popup
  /// natif de notation DIRECTEMENT, sans la carte (demande de Paul,
  /// 11/09/2026). La personne n'a fait qu'une respiration : « est-ce que
  /// Quieto te fait du bien ? » et ses raisons (Louane, les séances, le
  /// prix…) n'auraient aucun sens. Un peu culotté, mais c'est LE moment :
  /// elle sort du mur d'avis 4,9 ★ et n'a pas encore vu le prix. L'OS garde
  /// la main (iOS ne montre rien s'il juge que non, ~3 fois par an au plus).
  /// Compte comme une sollicitation : la carte ne reviendra pas avant 60
  /// jours, et jamais si la personne a déjà été entendue.
  ///
  /// Renvoie vrai si le popup a bien été demandé à l'OS — StoreKit met
  /// ensuite ~1 s à l'afficher, l'appelant peut caler sa transition dessus.
  Future<bool> solliciterNotationOnboarding() async {
    if (_enCours) return false;
    _enCours = true;
    try {
      final nb = _storage.avisNbDemandes;
      if (!kDebugMode && !_gardeFousOk(nb)) return false;
      final inAppReview = InAppReview.instance;
      final disponible = await inAppReview.isAvailable();
      debugPrint('[Review] onboarding_paywall disponible=$disponible');
      if (!disponible) return false;
      await _storage.enregistreDemandeAvis();
      // Événement DISTINCT d'avis_propose : pas de carte ici, donc jamais
      // d'avis_reponse derrière — l'entonnoir de la carte (dashboard) ne doit
      // pas compter ces popups comme des cartes vues.
      _vigie.log('avis_natif', {
        'declencheur': 'onboarding_paywall',
        'demande_no': nb + 1,
      });
      debugPrint('[Review] popup natif demandé (onboarding)');
      await inAppReview.requestReview();
      return true;
    } catch (e, st) {
      // Ne doit JAMAIS gêner l'app : un avis raté est sans gravité.
      debugPrint('[Review] solliciterNotationOnboarding failed: $e\n$st');
      return false;
    } finally {
      _enCours = false;
    }
  }

  /// Nos garde-fous (ignorés en debug, pour retester à volonté) : jamais
  /// après un retour donné — qui a dit ce qui n'allait pas a été entendu —,
  /// plafond à vie, délai minimal entre deux propositions.
  bool _gardeFousOk(int nb) {
    if (_storage.avisRetourDonne) return false;
    if (nb >= _maxDemandes) return false;
    final derniere = _storage.avisDerniereDemande;
    if (derniere != null &&
        DateTime.now().difference(derniere).inDays < _joursEntreDemandes) {
      return false;
    }
    return true;
  }

  /// Dépose le retour dans la boîte aux lettres (Cloud Function `retour`).
  /// Trois tentatives espacées, puis on renonce : un mot sincère mérite
  /// mieux qu'un seul essai sur un réseau qui hoquette, mais pas une file
  /// d'attente persistante. La Vigie note l'issue — jamais le texte (seul
  /// le serveur `retour` le reçoit, la Vigie reste sans texte libre).
  Future<void> _deposerRetour(String declencheur, AvisResultat r) async {
    var envoye = false;
    for (final attente in const [0, 5, 20]) {
      if (attente > 0) await Future<void>.delayed(Duration(seconds: attente));
      try {
        await FirebaseFunctions.instance
            .httpsCallable('retour')
            .call({
              'vigie': _vigie.id,
              'session': _vigie.session,
              'version': AppConstants.appVersion,
              'os': Platform.operatingSystem,
              'declencheur': declencheur,
              'raisons': r.raisons.toList(),
              'texte': r.texte,
            })
            .timeout(const Duration(seconds: 15));
        envoye = true;
        break;
      } catch (e) {
        debugPrint('[Review] dépôt du retour raté (attente ${attente}s) : $e');
      }
    }
    _vigie.log('avis_retour', {
      'declencheur': declencheur,
      'raisons': (r.raisons.toList()..sort()).join('|'),
      'nb_raisons': r.raisons.length,
      'texte_car': r.texte.length,
      'envoye': envoye,
    });
  }
}

final reviewServiceProvider = Provider<ReviewService>((ref) {
  return ReviewService(
    ref.watch(storageServiceProvider),
    ref.watch(vigieProvider),
  );
});
