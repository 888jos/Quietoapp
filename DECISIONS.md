# Décisions techniques — Quieto

## ADR-001 — Riverpod pour le state management

**Décision** : `flutter_riverpod ^2.5.1`

**Pourquoi** : Riverpod est compilé et type-safe contrairement à Provider. Il permet l'injection de dépendances propre (overrides dans ProviderScope) et évite les BuildContext dans les couches non-UI. La famille `StateNotifierProvider.family` couvre parfaitement le cas du player par sessionId.

**Alternative rejetée** : Bloc — trop verbeux pour une app de taille MVP.

---

## ADR-002 — GoRouter pour la navigation

**Décision** : `go_router ^14.0.0`

**Pourquoi** : Gestion déclarative des routes avec deep linking natif. `ShellRoute` est idéal pour la bottom navigation avec persistance d'état. Support officiel Flutter.

**Alternative rejetée** : `auto_route` — génération de code non nécessaire à ce stade.

---

## ADR-003 — Contenu audio statique (pas de Firebase Storage)

**Décision** : Les fichiers audio sont embarqués dans `assets/audio/`.

**Pourquoi** : Simplicité maximale pour le MVP. Zéro infrastructure à gérer, fonctionnel hors-ligne par défaut. La taille des assets sera gérée au moment de l'ajout des fichiers réels (compression opus/mp3).

**Évolution prévue** : Migration vers Firebase Storage (remote URL) avec cache local via `just_audio` quand le catalogue grandira.

---

## ADR-004 — SharedPreferences pour la persistence locale

**Décision** : `shared_preferences ^2.2.0` avec `StorageService` wrapper.

**Pourquoi** : Suffisant pour la progression utilisateur (JSON sérialisé). Hive ou Isar seraient over-engineered pour les données MVP.

**Évolution prévue** : Migration vers Isar si le volume de données (historique, favoris) le justifie.

---

## ADR-005 — RevenueCat pour les achats in-app

**Décision** : `purchases_flutter ^7.0.0` (RevenueCat)

**Pourquoi** : Abstraction cross-platform (iOS StoreKit + Android Billing) avec tableau de bord analytics. Évite la complexité de gérer les webhooks de validation de reçus manuellement.

**Configuration nécessaire** : Remplacer les placeholders dans `AppConstants` par les vraies clés RevenueCat.

---

## ADR-006 — Dark theme uniquement

**Décision** : Pas de mode clair, `ThemeData` unique.

**Pourquoi** : Cohérence visuelle forte avec la palette forêt/sage. Le mode clair dégraderait l'expérience. Décision produit assumée.

---

## ADR-007 — Architecture feature-first

**Décision** : Organisation par domaine métier, pas par type de fichier.

**Pourquoi** : Plus scalable que layer-first quand le nombre de features grandit. Chaque feature est auto-contenue et peut être développée / supprimée indépendamment.

---

## ADR-008 — Système free/premium par catégorie entière

**Décision** : Une seule catégorie gratuite (🧘 Découverte). Toutes les autres sont premium. Pas de cadenas — le paywall s'affiche au tap.

**Pourquoi** : Modèle plus simple qu'un mix sessions gratuites/premium par catégorie. La catégorie Découverte offre une vraie valeur introductive aux non-abonnés sans fragmenter le contenu premium.

**Implémentation** : `categoryRouteProvider(categoryId)` dans `explore_providers.dart` calcule la destination (detail ou paywall). Zéro logique dans les widgets — ils lisent seulement le provider et appellent `context.push`. `subscriptionProvider` dans `storage_providers.dart` lit SharedPreferences ; sera remplacé par RevenueCat (ADR-005).

---

## ADR-009 — Badge "New !" sur Actualité uniquement

**Décision** : `CategoryModel.isNew` (bool) contrôle l'affichage du badge. Seule la catégorie Actualité a `isNew: true` pour le MVP.

**Pourquoi** : Mettre en avant le contenu le plus actuel sans surcharger l'UI. Le badge est un signal éditorial, pas un indicateur technique.
