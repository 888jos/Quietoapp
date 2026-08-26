import 'package:flutter/cupertino.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode, CupertinoTheme,
        CupertinoThemeData;
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:purchases_flutter/purchases_flutter.dart' show Purchases;
import 'package:url_launcher/url_launcher.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/config/revenue_cat_config.dart';
import '../../../core/services/ambient_music.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/health_service.dart';
import '../../../core/services/storage_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/boutons_connexion.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../parcours/parcours_providers.dart';
import '../profile_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final notifier = ref.read(profileProvider.notifier);
    // userProgressProvider est réactif au sessionCompletionTickProvider :
    // les stats se mettent à jour automatiquement à chaque séance complétée.
    final progress = ref.watch(userProgressProvider);
    final isPremium = ref.watch(subscriptionProvider);

    return AppScaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingMd,
                AppConstants.spacingLg,
                AppConstants.spacingMd,
                AppConstants.spacingXxl,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────
                    Text(
                      '👤 ${profile.firstName.isNotEmpty ? profile.firstName : 'Mon profil'}',
                      style: AppTextStyles.displayLarge.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: AppConstants.spacingXs),
                    GestureDetector(
                      onTap: () => _showEditNameSheet(
                          context, profile.firstName, notifier),
                      child: Text(
                        'Modifier',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.accent),
                      ),
                    ),

                    const SizedBox(height: AppConstants.spacingXl),

                    // ── Stats ────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            value: '${progress.totalMinutes}',
                            label: 'minutes',
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingMd),
                        Expanded(
                          child: _StatCard(
                            value: '${progress.completedCount}',
                            label: 'séances',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppConstants.spacingXl),

                    // ── Premium ──────────────────────────────
                    // Abonné : on remercie, plus de CTA d'achat.
                    // Non abonné : incitation à découvrir les offres.
                    AppCard(
                      child: isPremium
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('✨ Tu es Premium',
                                    style: AppTextStyles.titleMedium),
                                const SizedBox(height: AppConstants.spacingSm),
                                Text(
                                  'Merci ! Tu as accès à Louane et à toutes '
                                  'les séances, sans limite.',
                                  style: AppTextStyles.bodyMedium,
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('✨ Passer à Premium',
                                    style: AppTextStyles.titleMedium),
                                const SizedBox(height: AppConstants.spacingSm),
                                Text(
                                  'Accédez à Louane et à toutes les séances, '
                                  'sans limite.',
                                  style: AppTextStyles.bodyMedium,
                                ),
                                const SizedBox(height: AppConstants.spacingMd),
                                AppButton(
                                  label: 'Voir les offres',
                                  onTap: () => context
                                      .push(AppRoutes.paywallDepuis('profil')),
                                ),
                              ],
                            ),
                    ),

                    // PROVISOIRE : outils de dev, invisibles en release.
                    // Forçage premium (sans effet en release, voir
                    // SubscriptionNotifier) + rejeu de l'animation de
                    // création de programme (fictif, zéro appel serveur —
                    // remplace le programme en cours).
                    if (!kReleaseMode) ...[
                      const SizedBox(height: AppConstants.spacingSm),
                      const _DevPremiumCard(),
                      const SizedBox(height: AppConstants.spacingSm),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _TapItem(
                              emoji: '🎬',
                              label: 'Animation programme (dev)',
                              onTap: () => context.push(
                                  '${AppRoutes.parcoursCreation}?demo=1'),
                            ),
                            _ItemDivider(),
                            // Coche le jour courant daté d'HIER : le jour
                            // suivant est jouable tout de suite (le verrou
                            // « un jour par jour » compare des dates).
                            _TapItem(
                              emoji: '⏩',
                              label: 'Avancer le programme d\'un jour (dev)',
                              onTap: () => _avancerParcoursDev(context, ref),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: AppConstants.spacingXl),

                    // ── Compte ───────────────────────────────
                    // Optionnel : l'app marche sans. Sert à retrouver sa
                    // progression en changeant de téléphone, et à savoir
                    // qui utilise Quieto.
                    Text('Mon compte', style: AppTextStyles.titleMedium),
                    const SizedBox(height: AppConstants.spacingSm),
                    _buildCompteCard(
                        context, ref, ref.watch(utilisateurProvider).value),

                    const SizedBox(height: AppConstants.spacingXl),

                    // ── Paramètres ───────────────────────────
                    Text('Paramètres', style: AppTextStyles.titleMedium),
                    const SizedBox(height: AppConstants.spacingSm),
                    _ReminderCard(
                      enabled: profile.notificationsEnabled,
                      time: profile.reminderTime ??
                          const TimeOfDay(hour: 19, minute: 0),
                      onToggle: (v) async {
                        final ok = await notifier.toggleNotifications(v);
                        // Permission refusée : le toggle reste éteint.
                        // iOS n'autorise qu'une seule popup système, donc on
                        // propose un raccourci direct vers les réglages.
                        if (v && !ok && context.mounted) {
                          _showSoftSnack(
                            context,
                            'Autorise les notifications '
                            'pour activer ton rappel.',
                            actionLabel: 'Ouvrir les réglages',
                            onAction: () => AppSettings.openAppSettings(
                              type: AppSettingsType.notification,
                            ),
                          );
                        }
                      },
                      onEditTime: () => _showTimePickerSheet(
                        context,
                        profile.reminderTime ??
                            const TimeOfDay(hour: 19, minute: 0),
                        notifier.setReminderTime,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingSm),
                    const _AmbientMusicCard(),
                    if (HealthService.instance.disponible) ...[
                      const SizedBox(height: AppConstants.spacingSm),
                      const _AppleHealthCard(),
                    ],

                    const SizedBox(height: AppConstants.spacingXl),

                    // ── Aide et informations ─────────────────
                    Text('Aide et informations',
                        style: AppTextStyles.titleMedium),
                    const SizedBox(height: AppConstants.spacingSm),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _TapItem(
                            emoji: '✉️',
                            label: 'Nous contacter',
                            onTap: () => _contacter(context),
                          ),
                          _ItemDivider(),
                          _TapItem(
                            emoji: '📄',
                            label: 'Politique de confidentialité',
                            onTap: () async {
                              try {
                                await launchUrl(
                                  Uri.parse('https://cofonde.com/quieto-confidentialite'),
                                  mode: LaunchMode.externalApplication,
                                );
                              } catch (_) {}
                            },
                          ),
                          _ItemDivider(),
                          _TapItem(
                            emoji: '📋',
                            label: 'Conditions d\'utilisation',
                            onTap: () async {
                              try {
                                await launchUrl(
                                  Uri.parse('https://cofonde.com/quieto-cgu'),
                                  mode: LaunchMode.externalApplication,
                                );
                              } catch (_) {}
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// PROVISOIRE (dev) : avance le programme d'un jour (daté d'hier) et dit
  /// où on en est. Sans programme, renvoie vers le bouton 🎬.
  Future<void> _avancerParcoursDev(BuildContext context, WidgetRef ref) async {
    final parcours = ref.read(parcoursProvider);
    if (parcours == null) {
      _showSoftSnack(context, 'Aucun programme en cours. Crée-en un avec 🎬.',
          emoji: '⏩');
      return;
    }
    if (parcours.tousJoursTermines) {
      _showSoftSnack(context,
          'Semaine déjà finie. Le bilan t\'attend sur la page programme.',
          emoji: '⏩');
      return;
    }
    final jour = parcours.jourCourant;
    await ref.read(parcoursProvider.notifier).avancerJourDev();
    if (!context.mounted) return;
    _showSoftSnack(
      context,
      jour < 7
          ? 'Jour $jour coché (daté d\'hier). Jour ${jour + 1} débloqué.'
          : 'Jour 7 coché. Semaine terminée, le bilan t\'attend.',
      emoji: '⏩',
    );
  }

  /// Carte « Mon compte » : boutons de connexion si personne n'est
  /// connecté, sinon l'e-mail du compte avec déconnexion et suppression
  /// (la suppression est exigée par Apple dès qu'on propose un compte).
  Widget _buildCompteCard(BuildContext context, WidgetRef ref, User? compte) {
    final auth = ref.read(authServiceProvider);

    if (compte == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🔐 Garde ta progression', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              'Connecte-toi pour retrouver Quieto si tu changes de téléphone.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppConstants.spacingMd),
            if (auth.appleDisponible) ...[
              BoutonConnexionApple(
                onTap: () => _connexion(context, ref, apple: true),
              ),
              const SizedBox(height: AppConstants.spacingSm),
            ],
            BoutonConnexionGoogle(
              onTap: () => _connexion(context, ref, apple: false),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🔐 Compte connecté', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            compte.email ?? compte.displayName ?? '',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppConstants.spacingMd),
          AppButton(
            label: 'Se déconnecter',
            variant: AppButtonVariant.secondary,
            onTap: () => _confirmerDeconnexion(context, ref),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Center(
            child: GestureDetector(
              onTap: () => _confirmerSuppression(context, ref),
              child: Text(
                'Supprimer mon compte',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.error),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _connexion(
    BuildContext context,
    WidgetRef ref, {
    required bool apple,
  }) async {
    final auth = ref.read(authServiceProvider);
    final resultat =
        apple ? await auth.connexionApple() : await auth.connexionGoogle();
    if (!context.mounted) return;
    switch (resultat) {
      case AuthResultat.ok:
        _showSoftSnack(context, 'Te voilà connecté.', emoji: '🔐');
      case AuthResultat.annule:
        break;
      case AuthResultat.erreur:
        _showSoftSnack(
          context,
          'La connexion n\'a pas fonctionné. Réessaie dans un instant.',
          emoji: '🌧️',
        );
    }
  }

  /// Petite confirmation avant la déconnexion : on rassure (rien n'est
  /// supprimé, l'abonnement et la progression restent) pour ne pas confondre
  /// avec la suppression de compte.
  void _confirmerDeconnexion(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        title: Text('Te déconnecter ?', style: AppTextStyles.titleMedium),
        content: Text(
          'Rien n\'est supprimé : ton abonnement et ta progression restent '
          'sur ce téléphone. Tu pourras te reconnecter quand tu veux.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Annuler',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(authServiceProvider).deconnexion();
              if (!context.mounted) return;
              _showSoftSnack(context, 'Tu es déconnecté.', emoji: '👋');
            },
            child: Text(
              'Se déconnecter',
              style:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmerSuppression(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        title: Text('Supprimer ton compte ?', style: AppTextStyles.titleMedium),
        content: Text(
          'Ton compte sera effacé pour de bon. Tes séances et ton '
          'abonnement restent liés à ton téléphone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Annuler',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final ok =
                  await ref.read(authServiceProvider).supprimerCompte();
              if (!context.mounted) return;
              _showSoftSnack(
                context,
                ok
                    ? 'Compte supprimé.'
                    : 'Par sécurité, reconnecte-toi puis réessaie '
                        'la suppression.',
                emoji: ok ? '🗑️' : '🔐',
              );
            },
            child: Text(
              'Supprimer',
              style:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  /// Ouvre l'app Mail pré-remplie ; si aucune app mail n'est installée,
  /// copie l'adresse pour que la personne puisse écrire autrement.
  Future<void> _contacter(BuildContext context) async {
    // La version et l'identifiant RevenueCat aident à retrouver la
    // personne (abonnement, quotas) sans lui demander quoi que ce soit.
    String? idSupport;
    if (revenueCatDisponible) {
      try {
        idSupport = await Purchases.appUserID;
      } catch (_) {}
    }
    final corps = '\n\n----------\nQuieto ${AppConstants.appVersion}'
        '${idSupport != null ? '\nIdentifiant : $idSupport' : ''}';
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      query: 'subject=${Uri.encodeComponent('Quieto : question')}'
          '&body=${Uri.encodeComponent(corps)}',
    );
    var ouvert = false;
    try {
      ouvert = await launchUrl(uri);
    } catch (_) {}
    if (!ouvert) {
      await Clipboard.setData(
        const ClipboardData(text: AppConstants.supportEmail),
      );
      if (context.mounted) {
        _showSoftSnack(
          context,
          'Adresse copiée : ${AppConstants.supportEmail}',
          emoji: '✉️',
        );
      }
    }
  }

  /// SnackBar « zen » : flottant, arrondi, aux couleurs du thème, avec une
  /// petite icône douce — bien plus chaleureux que le SnackBar brut par défaut.
  void _showSoftSnack(
    BuildContext context,
    String message, {
    String emoji = '🔕',
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        // Entrée et sortie ralenties avec une courbe amortie : le message
        // se dépose et s'efface en douceur, dans l'esprit calme de l'app.
        snackBarAnimationStyle: AnimationStyle(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          reverseDuration: const Duration(milliseconds: 500),
          reverseCurve: Curves.easeInCubic,
        ),
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.cardSurface,
          elevation: 0,
          duration: Duration(seconds: actionLabel != null ? 6 : 4),
          margin: const EdgeInsets.all(AppConstants.spacingMd),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            side: BorderSide(
              color: AppColors.accent.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          content: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Text(message, style: AppTextStyles.bodyMedium),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: AppConstants.spacingSm),
                GestureDetector(
                  onTap: () {
                    messenger.hideCurrentSnackBar();
                    onAction();
                  },
                  child: Text(
                    actionLabel,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
  }

  void _showTimePickerSheet(
    BuildContext context,
    TimeOfDay current,
    Future<void> Function(TimeOfDay) onSave,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusLg),
        ),
      ),
      builder: (_) => _ReminderTimeSheet(current: current, onSave: onSave),
    );
  }

  void _showEditNameSheet(
    BuildContext context,
    String currentName,
    ProfileNotifier notifier,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusLg),
        ),
      ),
      builder: (_) => _EditNameSheet(
        currentName: currentName,
        onSave: notifier.setFirstName,
      ),
    );
  }
}

// ── Bottom sheet édition du prénom ────────────────────

class _EditNameSheet extends StatefulWidget {
  final String currentName;
  final Future<void> Function(String) onSave;

  const _EditNameSheet({
    required this.currentName,
    required this.onSave,
  });

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_controller.text);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppConstants.spacingMd,
        right: AppConstants.spacingMd,
        top: AppConstants.spacingLg,
        bottom:
            MediaQuery.of(context).viewInsets.bottom + AppConstants.spacingLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Modifier le prénom', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppConstants.spacingMd),
          TextField(
            controller: _controller,
            autofocus: true,
            style: AppTextStyles.bodyLarge,
            cursorColor: AppColors.accent,
            decoration: InputDecoration(
              hintText: 'Votre prénom',
              hintStyle: AppTextStyles.bodyMedium,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: const BorderSide(color: AppColors.accentDim),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide:
                    const BorderSide(color: AppColors.accent, width: 1.5),
              ),
              filled: true,
              fillColor: AppColors.background,
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          AppButton(
            label: 'Sauvegarder',
            onTap: _saving ? null : _save,
            isLoading: _saving,
          ),
          const SizedBox(height: AppConstants.spacingSm),
        ],
      ),
    );
  }
}

// ── Bottom sheet heure du rappel ──────────────────────

class _ReminderTimeSheet extends StatefulWidget {
  final TimeOfDay current;
  final Future<void> Function(TimeOfDay) onSave;

  const _ReminderTimeSheet({required this.current, required this.onSave});

  @override
  State<_ReminderTimeSheet> createState() => _ReminderTimeSheetState();
}

class _ReminderTimeSheetState extends State<_ReminderTimeSheet> {
  late TimeOfDay _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingMd,
        AppConstants.spacingLg,
        AppConstants.spacingMd,
        AppConstants.spacingLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Heure du rappel', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            'Un seul rappel par jour, tout en douceur.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppConstants.spacingMd),
          SizedBox(
            height: 180,
            child: CupertinoTheme(
              data: const CupertinoThemeData(brightness: Brightness.dark),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: DateTime(
                    2024, 1, 1, widget.current.hour, widget.current.minute),
                onDateTimeChanged: (dt) => _selected =
                    TimeOfDay(hour: dt.hour, minute: dt.minute),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          AppButton(
            label: 'Sauvegarder',
            onTap: () async {
              await widget.onSave(_selected);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: AppConstants.spacingSm),
        ],
      ),
    );
  }
}

// ── Widgets privés ────────────────────────────────────

/// PROVISOIRE : interrupteur de forçage premium pour le dev.
/// N'apparaît jamais en release ; l'état local reflète le flag persisté
/// (le vrai statut RevenueCat n'est pas modifié).
class _DevPremiumCard extends ConsumerStatefulWidget {
  const _DevPremiumCard();

  @override
  ConsumerState<_DevPremiumCard> createState() => _DevPremiumCardState();
}

class _DevPremiumCardState extends ConsumerState<_DevPremiumCard> {
  late bool _force;

  @override
  void initState() {
    super.initState();
    _force = ref.read(subscriptionProvider.notifier).forceDev;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Text('🛠', style: TextStyle(fontSize: 18)),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Premium forcé (dev)',
                    style: AppTextStyles.bodyLarge
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  'Provisoire, invisible en release.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Switch(
            value: _force,
            onChanged: (v) async {
              HapticFeedback.selectionClick();
              await ref
                  .read(subscriptionProvider.notifier)
                  .basculerForceDev();
              if (mounted) setState(() => _force = v);
            },
            activeThumbColor: AppColors.accent,
            inactiveTrackColor: AppColors.accentDim,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Text(value,
              style:
                  AppTextStyles.displayLarge.copyWith(color: AppColors.accent)),
          Text(label, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

/// Carte « Rappel quotidien » repensée : une icône en pastille, un titre +
/// un sous-texte qui explique en douceur ce que fait le rappel, le toggle, et —
/// quand c'est activé — un encart révélant l'heure choisie, mise en avant en
/// gros et en turquoise. Tout est animé (apparition douce de l'heure).
class _ReminderCard extends StatelessWidget {
  final bool enabled;
  final TimeOfDay time;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEditTime;

  const _ReminderCard({
    required this.enabled,
    required this.time,
    required this.onToggle,
    required this.onEditTime,
  });

  String get _formattedTime =>
      '${time.hour}h${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ligne principale : pastille + texte + toggle ──
          Row(
            children: [
              // Pastille douce qui porte l'icône, comme dans le récap.
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentDim,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: const Text('🔔', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rappel quotidien',
                        style: AppTextStyles.bodyLarge
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      'Une petite invitation à prendre\nun moment pour toi.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeThumbColor: AppColors.accent,
                inactiveTrackColor: AppColors.accentDim,
              ),
            ],
          ),

          // ── Encart heure : apparaît / disparaît en douceur ──
          AnimatedSize(
            duration: const Duration(milliseconds: AppConstants.animNormal),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedOpacity(
              opacity: enabled ? 1 : 0,
              duration: const Duration(milliseconds: AppConstants.animNormal),
              child: enabled
                  ? Padding(
                      padding:
                          const EdgeInsets.only(top: AppConstants.spacingMd),
                      child: _ReminderTimeTile(
                        time: _formattedTime,
                        onTap: onEditTime,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tuile cliquable qui affiche l'heure du rappel, bien en évidence.
class _ReminderTimeTile extends StatelessWidget {
  final String time;
  final VoidCallback onTap;

  const _ReminderTimeTile({required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        splashColor: AppColors.accentDim,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingMd,
          ),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Text('🕐', style: TextStyle(fontSize: 16)),
              const SizedBox(width: AppConstants.spacingSm),
              Expanded(
                child: Text('Chaque jour à', style: AppTextStyles.bodyMedium),
              ),
              Text(
                time,
                style: AppTextStyles.titleMedium
                    .copyWith(color: AppColors.accent),
              ),
              const SizedBox(width: AppConstants.spacingXs),
              const Icon(Icons.chevron_right,
                  color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _TapItem extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _TapItem({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      splashColor: AppColors.accentDim,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingMd,
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: AppConstants.spacingMd),
            Expanded(child: Text(label, style: AppTextStyles.bodyLarge)),
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ItemDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppColors.accentDim,
      indent: AppConstants.spacingMd,
      endIndent: AppConstants.spacingMd,
    );
  }
}

/// Connexion à Apple Santé depuis le profil : pour ceux qui ont répondu
/// « Plus tard » pendant l'onboarding, ou pour vérifier que c'est bien relié.
/// L'état affiché s'appuie sur l'écriture Pleine conscience, le seul statut
/// que HealthKit accepte de révéler (les refus de lecture restent cachés).
class _AppleHealthCard extends ConsumerStatefulWidget {
  const _AppleHealthCard();

  @override
  ConsumerState<_AppleHealthCard> createState() => _AppleHealthCardState();
}

class _AppleHealthCardState extends ConsumerState<_AppleHealthCard>
    with WidgetsBindingObserver {
  String _etat = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _charger();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Au retour dans l'app (ex. la personne revient de l'app Santé après
  /// avoir rouvert l'accès) : l'état se remet à jour tout seul, et si la
  /// connexion vient d'être accordée, on relit les évaluations pour Louane.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final avant = _etat;
    _charger().then((_) {
      if (avant != 'autorise' && _etat == 'autorise') {
        HealthService.instance.reconnecter();
      }
    });
  }

  Future<void> _charger() async {
    final etat = await HealthService.instance.etatConnexion();
    if (mounted) setState(() => _etat = etat);
  }

  Future<void> _connecter() async {
    if (_busy) return;
    setState(() => _busy = true);
    await HealthService.instance.reconnecter();
    // La feuille système ne reviendra plus : inutile que le premier play
    // retente la demande (filet du handler audio).
    await ref.read(storageServiceProvider).setHealthPromptSeen();
    await _charger();
    if (mounted) setState(() => _busy = false);
  }

  /// La feuille système ne s'affiche qu'une fois : après un refus, seul
  /// l'app Santé permet de rouvrir l'accès. On l'ouvre directement.
  Future<void> _ouvrirSante() async {
    try {
      await launchUrl(
        Uri.parse('x-apple-health://'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final connecte = _etat == 'autorise';
    final refuse = _etat == 'refuse';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentDim,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: const Text('❤️', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Apple Santé',
                        style: AppTextStyles.bodyLarge
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      connecte
                          ? 'Connecté. Tes minutes de calme\nsont ajoutées dans Santé.'
                          : refuse
                              ? 'Accès refusé pour l\'instant.\nÇa se rouvre dans l\'app Santé.'
                              : 'Tes minutes de calme dans Santé,\net Louane lit tes questionnaires.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              if (connecte) ...[
                const SizedBox(width: AppConstants.spacingSm),
                const Icon(Icons.check_circle,
                    color: AppColors.accent, size: 22),
              ],
            ],
          ),
          if (!connecte) ...[
            const SizedBox(height: AppConstants.spacingMd),
            AppButton(
              label: refuse ? 'Ouvrir l\'app Santé' : 'Connecter',
              variant: AppButtonVariant.secondary,
              isLoading: _busy,
              onTap: refuse ? _ouvrirSante : _connecter,
            ),
            if (refuse) ...[
              const SizedBox(height: AppConstants.spacingSm),
              Text(
                'Dans Santé : ta photo de profil, puis Apps,\n'
                'puis Quieto, et active ce que tu veux partager.',
                style: AppTextStyles.caption,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Réglage de la musique d'ambiance (déplacé depuis la Home) : interrupteur
/// pour couper/relancer, curseur de volume quand elle est active.
class _AmbientMusicCard extends ConsumerWidget {
  const _AmbientMusicCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(ambientLevelProvider);
    final notifier = ref.read(ambientLevelProvider.notifier);
    final active = level > 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ligne principale : pastille + texte + toggle ──
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentDim,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.music_note_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Musique d\'ambiance',
                        style: AppTextStyles.bodyLarge
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      'La nappe sonore douce qui\naccompagne l\'application.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Switch(
                value: active,
                onChanged: (_) {
                  HapticFeedback.selectionClick();
                  notifier.toggleMute();
                },
                activeThumbColor: AppColors.accent,
                inactiveTrackColor: AppColors.accentDim,
              ),
            ],
          ),

          // ── Curseur de volume : apparaît quand la musique est active ──
          AnimatedSize(
            duration: const Duration(milliseconds: AppConstants.animNormal),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !active
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: AppConstants.spacingSm),
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        activeTrackColor: AppColors.accent,
                        inactiveTrackColor:
                            AppColors.textPrimary.withValues(alpha: 0.15),
                        thumbColor: AppColors.accent,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 14),
                      ),
                      child: Slider(
                        value: level,
                        onChanged: notifier.set,
                        onChangeEnd: (_) => notifier.commit(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
