import Flutter
import HealthKit

/// Canal natif `quieto/sante_mentale` : lit la plus récente évaluation
/// anxiété (GAD-7) et humeur (PHQ-9) de l'app Santé (iOS 18+) et renvoie un
/// NIVEAU grossier (faible/modere/eleve), jamais le score brut ni les
/// réponses. Tout échec (iOS < 18, refus, aucune donnée) → liste vide,
/// silencieusement : le chat Louane ne doit jamais dépendre de cette lecture.
enum SanteMentaleChannel {

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
    let lecture: Set<HKObjectType> =
      [HKScoredAssessmentType(.GAD7), HKScoredAssessmentType(.PHQ9)]
    let ecriture: Set<HKSampleType> = [HKCategoryType(.mindfulSession)]
    store.requestAuthorization(toShare: ecriture, read: lecture) { ok, _ in
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
    store.requestAuthorization(toShare: nil, read: [gad7, phq9]) { _, erreur in
      if erreur != nil {
        completion([])
        return
      }

      let groupe = DispatchGroup()
      let verrou = NSLock()
      var scores: [[String: Any]] = []

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
          verrou.lock()
          scores.append(map)
          verrou.unlock()
        }
        store.execute(requete)
      }

      lire(gad7) { e in
        guard let a = e as? HKGAD7Assessment else { return nil }
        return ["type": "anxiete",
                "niveau": niveau(gad7: a.risk),
                "jours": anciennete(a.startDate)]
      }
      lire(phq9) { e in
        guard let a = e as? HKPHQ9Assessment else { return nil }
        return ["type": "depression",
                "niveau": niveau(phq9: a.risk),
                "jours": anciennete(a.startDate)]
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
