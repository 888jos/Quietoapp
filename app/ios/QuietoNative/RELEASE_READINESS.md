# Quieto Native — préparation de livraison

## Vérification locale

Depuis la racine du dépôt :

```sh
app/ios/QuietoNative/Scripts/release-check.sh
```

Cette commande valide les migrations SQL, la syntaxe des six localisations et une compilation SwiftUI sans signature. Le mode strict bloque aussi toute valeur distante restée en placeholder :

```sh
app/ios/QuietoNative/Scripts/release-check.sh strict
```

## Éléments externes obligatoires avant TestFlight

- remplacer uniquement par des valeurs **publiques** `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` et `SUPERWALL_API_KEY` ;
- appliquer les migrations Supabase, déployer les Edge Functions puis tester les politiques RLS avec deux comptes distincts ;
- vérifier le bundle ID, l’équipe Apple et les capacités dans Xcode ;
- publier les masters audio manquants dans le bucket privé `session-audio` ;
- configurer les produits et placements Superwall dans son tableau de bord ;
- exécuter les parcours sur un iPhone réel : arrière-plan/écran verrouillé, interruption téléphone, changement Bluetooth, notifications, achat/restauration et suppression de compte.

Ne jamais placer de clé Supabase `service_role`, de secret IA, de secret Superwall ou de secret Apple dans l’application.

## Parcours de recette

1. Ouvrir/créer un programme, changer son rythme, terminer une séance et vérifier la progression.
2. Envoyer, interrompre puis relancer une réponse Louane ; vérifier historique, temporaire, mémoire et suppression.
3. Tester favori, téléchargement disponible, annulation, suppression et fichier local manquant.
4. Activer les rappels, choisir plusieurs jours, modifier l’heure et vérifier l’absence de doublons.
5. Tester export, suppression, connexion Apple, restauration et gestion d’abonnement avec des comptes sandbox.
6. Relancer toute la recette en français, anglais, espagnol, allemand, japonais et coréen.
