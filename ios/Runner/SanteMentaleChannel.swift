import Flutter
import HealthKit

/// Canal natif `quieto/sante_mentale` : lit les signaux bien-être de l'app
/// Santé (iOS 18+). Les questionnaires en détail, le reste en niveau grossier :
/// - évaluations anxiété (GAD-7) et humeur (PHQ-9) → niveau faible/modere/eleve,
///   ET (décision Paul 11/09/2026) le score, les réponses question par question
///   (0-3 ; 4 = « préfère ne pas répondre », 9e question du PHQ-9 seulement)
///   et l'horodatage — deux échantillons à la même heure = le questionnaire
///   complet de bien-être mental (Santé enchaîne les deux en un passage) ;
/// - état d'esprit consigné (7 derniers jours) → agreable/neutre/desagreable ;
/// - sommeil de la dernière nuit → court/correct/bon (+ heures arrondies) ;
/// - lumière du jour → minutes/jour en moyenne sur 7 jours.
/// Tout échec (iOS < 18, refus, aucune donnée) → liste vide,
/// silencieusement : le chat Louane ne doit jamais dépendre de cette lecture.
enum SanteMentaleChannel {

  /// Les types LUS : tout le pan santé mentale + le sommeil (décision Paul
  /// 14/08/2026). Chaque type doit être réellement exploité dans le résumé
  /// ci-dessous (exigence App Review sur les données santé).
  @available(iOS 18.0, *)
  private static func typesLecture() -> Set<HKObjectType> {
    var lecture: Set<HKObjectType> = [
      HKScoredAssessmentType(.GAD7),
      HKScoredAssessmentType(.PHQ9),
      HKSampleType.stateOfMindType(),
    ]
    if let sommeil = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
      lecture.insert(sommeil)
    }
    if let lumiere = HKObjectType.quantityType(forIdentifier: .timeInDaylight) {
      lecture.insert(lumiere)
    }
    return lecture
  }

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "quieto/sante_mentale", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "derniersScores":
        guard #available(iOS 18.0, *), HKHealthStore.isHealthDataAvailable() else {
          result([[String: Any]]())
          return
        }
        derniersScores { scores in
          DispatchQueue.main.async { result(scores) }
        }
      case "etatEcriture":
        // Statut de l'ÉCRITURE Pleine conscience : le seul que HealthKit
        // accepte de révéler (les refus de lecture restent invisibles).
        // Sert à la carte « Apple Santé » du profil.
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKObjectType.categoryType(forIdentifier: .mindfulSession)
        else {
          result("")
          return
        }
        switch HKHealthStore().authorizationStatus(for: type) {
        case .sharingAuthorized: result("autorise")
        case .sharingDenied: result("refuse")
        default: result("jamais")
        }
      case "demanderAutorisation":
        // UNE seule feuille système : écriture Pleine conscience + lecture
        // des deux évaluations. false sous iOS < 18 → le Dart retombe sur le
        // plugin `health` (écriture seule).
        guard #available(iOS 18.0, *), HKHealthStore.isHealthDataAvailable() else {
          result(false)
          return
        }
        demanderAutorisation { ok in
          DispatchQueue.main.async { result(ok) }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @available(iOS 18.0, *)
  private static func demanderAutorisation(completion: @escaping (Bool) -> Void) {
    let store = HKHealthStore()
    let ecriture: Set<HKSampleType> = [HKCategoryType(.mindfulSession)]
    store.requestAuthorization(toShare: ecriture, read: typesLecture()) { ok, _ in
      // ok = la feuille a été traitée, PAS « lecture accordée » : les refus
      // de lecture sont invisibles par design HealthKit.
      completion(ok)
    }
  }

  @available(iOS 18.0, *)
  private static func derniersScores(completion: @escaping ([[String: Any]]) -> Void) {
    let store = HKHealthStore()
    let gad7 = HKScoredAssessmentType(.GAD7)
    let phq9 = HKScoredAssessmentType(.PHQ9)
    // Idempotent : la feuille système ne sort que si ces types n'ont jamais
    // été proposés. Déjà répondu → aucune UI, les requêtes suivent.
    store.requestAuthorization(toShare: nil, read: typesLecture()) { _, erreur in
      if erreur != nil {
        completion([])
        return
      }

      let groupe = DispatchGroup()
      let verrou = NSLock()
      var scores: [[String: Any]] = []
      func ajouter(_ map: [String: Any]) {
        verrou.lock()
        scores.append(map)
        verrou.unlock()
      }

      func lire(_ type: HKScoredAssessmentType,
                _ convertir: @escaping (HKSample) -> [String: Any]?) {
        groupe.enter()
        let requete = HKSampleQuery(
          sampleType: type, predicate: nil, limit: 1,
          sortDescriptors: [NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { _, echantillons, _ in
          defer { groupe.leave() }
          guard let e = echantillons?.first, let map = convertir(e) else { return }
          ajouter(map)
        }
        store.execute(requete)
      }

      lire(gad7) { e in
        guard let a = e as? HKGAD7Assessment else { return nil }
        return ["type": "anxiete",
                "niveau": niveau(gad7: a.risk),
                "score": a.score,
                "reponses": a.answers.map { $0.rawValue },
                "horodatage": a.startDate.timeIntervalSince1970,
                "jours": anciennete(a.startDate)]
      }
      lire(phq9) { e in
        guard let a = e as? HKPHQ9Assessment else { return nil }
        return ["type": "depression",
                "niveau": niveau(phq9: a.risk),
                "score": a.score,
                "reponses": a.answers.map { $0.rawValue },
                "horodatage": a.startDate.timeIntervalSince1970,
                "jours": anciennete(a.startDate)]
      }

      // État d'esprit : moyenne de valence des consignations des 7 derniers
      // jours → un mot, jamais les émotions détaillées.
      groupe.enter()
      let depuis7j = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
      let predEsprit = HKQuery.predicateForSamples(withStart: depuis7j, end: nil)
      let requeteEsprit = HKSampleQuery(
        sampleType: HKSampleType.stateOfMindType(), predicate: predEsprit,
        limit: HKObjectQueryNoLimit, sortDescriptors: nil
      ) { _, echantillons, _ in
        defer { groupe.leave() }
        let humeurs = (echantillons as? [HKStateOfMind]) ?? []
        guard !humeurs.isEmpty else { return }
        let moyenne = humeurs.map(\.valence).reduce(0, +) / Double(humeurs.count)
        let ressenti = moyenne > 0.15 ? "agreable"
          : (moyenne < -0.15 ? "desagreable" : "neutre")
        let dernier = humeurs.map(\.startDate).max() ?? Date()
        ajouter(["type": "etat_esprit", "niveau": ressenti,
                 "nb": humeurs.count, "jours": anciennete(dernier)])
      }
      store.execute(requeteEsprit)

      // Sommeil : total dormi sur les ~32 dernières heures (la dernière
      // nuit, peu importe l'heure du coucher) → heures arrondies + niveau.
      if let typeSommeil = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
        groupe.enter()
        let predSommeil = HKQuery.predicateForSamples(
          withStart: Date().addingTimeInterval(-32 * 3600), end: nil)
        let requeteSommeil = HKSampleQuery(
          sampleType: typeSommeil, predicate: predSommeil,
          limit: HKObjectQueryNoLimit, sortDescriptors: nil
        ) { _, echantillons, _ in
          defer { groupe.leave() }
          let dodo = ((echantillons as? [HKCategorySample]) ?? []).filter { e in
            switch HKCategoryValueSleepAnalysis(rawValue: e.value) {
            case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM:
              return true
            default:
              return false
            }
          }
          guard !dodo.isEmpty else { return }
          let heures = dodo.reduce(0.0) {
            $0 + $1.endDate.timeIntervalSince($1.startDate)
          } / 3600
          guard heures > 1 else { return } // bruit de capteur
          let qualite = heures < 6 ? "court" : (heures < 7.5 ? "correct" : "bon")
          ajouter(["type": "sommeil", "niveau": qualite,
                   "heures": (heures * 10).rounded() / 10, "jours": 0])
        }
        store.execute(requeteSommeil)
      }

      // Lumière du jour : minutes/jour en moyenne sur 7 jours.
      if let typeLumiere = HKObjectType.quantityType(forIdentifier: .timeInDaylight) {
        groupe.enter()
        let predLumiere = HKQuery.predicateForSamples(withStart: depuis7j, end: nil)
        let requeteLumiere = HKStatisticsQuery(
          quantityType: typeLumiere, quantitySamplePredicate: predLumiere,
          options: .cumulativeSum
        ) { _, stats, _ in
          defer { groupe.leave() }
          guard let somme = stats?.sumQuantity()?.doubleValue(for: .minute()),
                somme > 0 else { return }
          ajouter(["type": "lumiere",
                   "minutesParJour": Int((somme / 7).rounded()), "jours": 0])
        }
        store.execute(requeteLumiere)
      }

      groupe.notify(queue: .main) { completion(scores) }
    }
  }

  private static func anciennete(_ date: Date) -> Int {
    max(0, Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0)
  }

  @available(iOS 18.0, *)
  private static func niveau(gad7 risque: HKGAD7Assessment.Risk) -> String {
    switch risque {
    case .noneToMinimal: return "faible"
    case .mild, .moderate: return "modere"
    case .severe: return "eleve"
    @unknown default: return "modere"
    }
  }

  @available(iOS 18.0, *)
  private static func niveau(phq9 risque: HKPHQ9Assessment.Risk) -> String {
    switch risque {
    case .noneToMinimal: return "faible"
    case .mild, .moderate: return "modere"
    case .moderatelySevere, .severe: return "eleve"
    @unknown default: return "modere"
    }
  }
}
