import Flutter
import UIKit

/// Vue native « quieto/verre » : le VERRE d'Apple (Liquid Glass, iOS 26) posé
/// sous la barre de saisie du chat — demande de Paul, 22/09/2026 : « l'effet
/// glace d'Apple, exactement comme dans l'app Claude ». Flutter dessine le
/// champ et les boutons par-dessus ; cette vue ne fait que le fond : le fil
/// se voit au travers, déformé et flouté, avec le reflet sur les bords.
/// Avant iOS 26 : le flou système le plus fin. Ne prend jamais le toucher.
///
/// Réglages depuis Dart (creationParams) : `rayon` (coins, 28 par défaut),
/// `clair` (true = verre sans teinte, comme Claude ; false = teinté bleu nuit).
final class VerreFactory: NSObject, FlutterPlatformViewFactory {
  static let identifiant = "quieto/verre"
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
              arguments args: Any?) -> FlutterPlatformView {
    return VerreVue(frame: frame, args: args as? [String: Any])
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

final class VerreVue: NSObject, FlutterPlatformView {
  private let conteneur: UIView

  init(frame: CGRect, args: [String: Any]?) {
    let rayon = CGFloat((args?["rayon"] as? Double) ?? 28)
    let clair = (args?["clair"] as? Bool) ?? true
    conteneur = UIView(frame: frame)
    conteneur.backgroundColor = .clear
    conteneur.isUserInteractionEnabled = false
    // L'app est sombre quel que soit le réglage du téléphone : le verre
    // aussi (en mode clair, il sortait blanchâtre et illisible sur la barre
    // de navigation, vu le 22/09 sur simulateur).
    conteneur.overrideUserInterfaceStyle = .dark

    let effet: UIVisualEffect
    if #available(iOS 26.0, *) {
      let verre = UIGlassEffect(style: .regular)
      verre.isInteractive = false
      if !clair {
        verre.tintColor = UIColor(red: 0.07, green: 0.13, blue: 0.21, alpha: 0.55)
      }
      effet = verre
    } else {
      effet = UIBlurEffect(style: .systemUltraThinMaterialDark)
    }
    let vue = UIVisualEffectView(effect: effet)
    vue.frame = conteneur.bounds
    vue.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    vue.isUserInteractionEnabled = false
    vue.overrideUserInterfaceStyle = .dark
    // Les coins : le verre suit le rayon de la couche (reflet compris).
    vue.layer.cornerRadius = rayon
    vue.layer.cornerCurve = .continuous
    vue.clipsToBounds = true
    conteneur.addSubview(vue)
    super.init()
  }

  func view() -> UIView { conteneur }
}
