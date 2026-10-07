# Quieto Analytics

Dashboard web interne : acquisition, onboarding écran par écran, rétention, usage et abonnements.
Les données viennent de Supabase, via les fonctions SQL `dashboard_*`
(`supabase/migrations/20261006200000_analytics_dashboard.sql`). Amplitude reçoit les mêmes événements
pour l’exploration ad hoc ; ce dashboard, lui, lit la copie que Quieto possède.

## Lancer en local

```bash
cd dashboard
npm install
cp .env.example .env.local   # URL + clé publishable Supabase (les mêmes que l’app iOS)
npm run dev                  # http://localhost:5180
```

Sans `.env.local`, le dashboard tourne sur des **données de démonstration** (bandeau visible en haut).

## Mise en service (une fois)

1. **Migration** : `supabase db push` (ou coller le fichier dans le SQL editor).
2. **Compte** : Supabase → Authentication → Users → *Invite user* avec ton email.
   Le formulaire de connexion n’ouvre pas de compte tout seul (`shouldCreateUser: false`).
3. **Autorisation** : dans le SQL editor
   ```sql
   insert into private.dashboard_admins (email) values ('ton@email.com');
   ```
4. **URL de redirection** : Authentication → URL Configuration → ajouter l’URL du dashboard
   (et `http://localhost:5180` pour le dev) aux *Redirect URLs*.

## Déployer

Site statique : `npm run build` produit `dist/`. N’importe quel hébergeur statique convient
(Vercel, Netlify, Cloudflare Pages) avec les deux variables `VITE_SUPABASE_*` définies au build.
Seule la clé **publishable** est exposée ; sans email autorisé, les fonctions renvoient `dashboard_access_denied`.

## Ce que mesurent les chiffres

| Indicateur | Source | Définition |
|---|---|---|
| Actif | `analytics_events` + `practice_entries` | au moins un événement ou une pratique |
| Onboarding commencé / terminé | `onboarding_started` / `onboarding_completed` | personnes distinctes sur la période |
| Abandon sur un écran | `onboarding_step` | a vu l’écran mais pas le suivant (hors écrans conditionnels) |
| Temps actif d’onboarding | `onboarding_completed.active_seconds` | somme des temps par écran, chaque écran plafonné à 5 min |
| Rétention J+N | profils des 90 derniers jours | actif exactement N jours après l’inscription |
| Cohortes | profils par semaine d’inscription | part active chaque semaine suivante |
| Revenu, conversions, résiliations | `subscription_events` (webhook Superwall) | production uniquement, `proceeds` en USD |
| Abonnés payants / en essai | `subscription_accounts` | état actuel, non expiré, non révoqué |

Les réponses sensibles de l’onboarding (raisons, stress, sommeil, sécurité, prénom) ne sont jamais envoyées aux analytics.
