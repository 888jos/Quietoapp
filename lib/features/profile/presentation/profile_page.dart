import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_scaffold.dart';
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

                    // ── Premium CTA ──────────────────────────
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('✨ Passer à Premium',
                              style: AppTextStyles.titleMedium),
                          const SizedBox(height: AppConstants.spacingSm),
                          Text(
                            'Accédez à toutes les séances sans limite.',
                            style: AppTextStyles.bodyMedium,
                          ),
                          const SizedBox(height: AppConstants.spacingMd),
                          AppButton(
                            label: 'Voir les offres',
                            onTap: () => context.push(AppRoutes.paywall),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppConstants.spacingXl),

                    // ── Paramètres ───────────────────────────
                    Text('Paramètres', style: AppTextStyles.titleMedium),
                    const SizedBox(height: AppConstants.spacingSm),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _ToggleItem(
                            emoji: '🔔',
                            label: 'Notifications',
                            value: profile.notificationsEnabled,
                            onChanged: notifier.toggleNotifications,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppConstants.spacingXl),

                    // ── Informations légales ─────────────────
                    Text('Informations légales',
                        style: AppTextStyles.titleMedium),
                    const SizedBox(height: AppConstants.spacingSm),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _TapItem(
                            emoji: '📄',
                            label: 'Politique de confidentialité',
                            onTap: () async {
                              try {
                                await launchUrl(
                                  Uri.parse('https://www.notion.so/Politique-de-Confidentialit-31de9e37b4a88093b560e0636712146e'),
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
                                  Uri.parse('https://www.notion.so/Terms-31de9e37b4a88085a949e24158d042e9'),
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

// ── Widgets privés ────────────────────────────────────

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

class _ToggleItem extends StatelessWidget {
  final String emoji;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleItem({
    required this.emoji,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(child: Text(label, style: AppTextStyles.bodyLarge)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.accent,
            inactiveTrackColor: AppColors.accentDim,
          ),
        ],
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
      onTap: onTap,
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
