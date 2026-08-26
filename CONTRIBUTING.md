# Contributing — Quieto

## Prérequis

- Flutter 3.41+
- Dart 3.11+
- Xcode 16+ (iOS)
- Android Studio / SDK (Android)

## Setup

```bash
git clone https://github.com/agencymape-coder/Quieto.git
cd Quieto
flutter pub get
flutter run --dart-define-from-file=.env.json
```

⚠️ `.env.json` (clés RevenueCat, non versionné) est obligatoire — sans le flag, les achats ne fonctionnent pas (voir `CONFIG.md`). (maj 12/08/2026)

## Conventions de code

### Nommage
- **Fichiers** : `snake_case.dart`
- **Classes** : `PascalCase`
- **Variables / fonctions** : `camelCase`
- **Constantes** : `camelCase` (Dart convention)
- **Privé** : préfixe `_`

### Structure d'une feature

```
features/ma_feature/
  presentation/
    ma_feature_page.dart     # Page principale
    widgets/                 # Widgets privés à la feature
  data/
    ma_feature_repository.dart
  ma_feature_providers.dart
```

### Règles absolues

1. **Pas de couleur hardcodée** — toujours `AppColors.xxx`
2. **Pas de style hardcodé** — toujours `AppTextStyles.xxx`
3. **Pas de valeur magique** — toujours `AppConstants.xxx`
4. **Pas de logique dans les widgets** — passer par un provider/notifier
5. **Pas de navigation directe** — utiliser `AppRoutes.xxx` avec le bon appel selon le contexte :
   - `context.go()` pour remplacer la stack (redirections)
   - `context.push()` pour empiler avec retour possible (pages detail, player, paywall)
   - `shell.goBranch(index)` pour changer de tab dans la navbar
   - Avant toute nouvelle route, consulter la table de décision dans `ARCHITECTURE.md` (section Navigation)
6. **Try-catch obligatoire** sur tout appel async

### Exemple de widget correct

```dart
class MyWidget extends ConsumerWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(myProvider);
    return Text(data, style: AppTextStyles.bodyLarge);
  }
}
```

Utiliser `ConsumerStatefulWidget` uniquement si le widget a besoin d'un `AnimationController`, d'un `Timer`, ou d'un `initState`/`dispose`. Dans ce cas, disposer les ressources proprement :

```dart
class MyAnimatedWidget extends ConsumerStatefulWidget {
  const MyAnimatedWidget({super.key});

  @override
  ConsumerState<MyAnimatedWidget> createState() => _MyAnimatedWidgetState();
}

class _MyAnimatedWidgetState extends ConsumerState<MyAnimatedWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _controller, child: ...);
  }
}
```

## Branches (maj 12/08/2026)

- `main` — production stable
- `feat/xxx` — nouvelle feature (ex. réels : `feat/paywall-flutter`, `feat/vigie-conversion`)
- `hotfix/xxx` / `fix/xxx` — correction de bug

(Il n'y a pas de branche `develop` : les features partent de `main` et y reviennent.)

## Commit convention

```
feat: description courte
fix: correction du bug XYZ
refactor: restructuration de player_providers
chore: mise à jour des dépendances
```

## Dev : bypasser le paywall (maj 26/08/2026)

**Il n'existe plus AUCUN moyen de forcer le premium dans l'app.** Historique : l'ancienne constante `_devUnlockPremium` a disparu, l'interrupteur `devForcerPremium` du profil a été retiré le 17/08 (commit `f9ab2e9`), et la carte provisoire « Premium forcé (dev) » + flag `premium_force_dev` remise le temps du chantier visuel a été retirée le 26/08 avec tous les autres outils de dev (commit `9e82c22` : boutons profil animation/avancer d'un jour/refaire l'onboarding, flèches dev d'onboarding, mode `?demo=1` de la création de programme, `avancerJourDev()`). Pour tester l'abonnement : sandbox RevenueCat. Si un nouvel outil de dev provisoire s'impose, le neutraliser en release (`kReleaseMode`) et le retirer avant tout bump de version.

## Pull Requests

1. Branch depuis `main`
2. PR vers `main`
3. Description claire de ce qui change
4. `flutter analyze` doit passer sans erreur
5. `flutter test` doit passer
