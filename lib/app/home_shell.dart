import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../core/services/storage_providers.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../features/louane/presentation/louane_palette.dart';
import '../features/louane/presentation/widgets/louane_avatar.dart';
import '../features/player/presentation/widgets/mini_player.dart';

class HomeShell extends ConsumerWidget {
  final StatefulNavigationShell shell;

  const HomeShell({super.key, required this.shell});

  static const _nomsOnglets = ['accueil', 'louane', 'profil'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          _QuijetoNav(
            currentIndex: shell.currentIndex,
            onTap: (index) {
              // Vigie : navigation entre onglets (quels espaces vivent ?).
              if (index != shell.currentIndex && index < _nomsOnglets.length) {
                ref.read(vigieProvider).log('onglet', {
                  'nom': _nomsOnglets[index],
                });
              }
              shell.goBranch(
                index,
                initialLocation: index == shell.currentIndex,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuijetoNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _QuijetoNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          // Filet discret, plus haut que les icônes pour laisser respirer.
          top: BorderSide(color: Color(0x2EFFFFFF), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Iconsax.home,
                iconActive: Iconsax.home_copy,
                label: 'Accueil',
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                customIcon: LouaneMiniAvatar(actif: currentIndex == 1),
                label: 'Louane',
                isActive: currentIndex == 1,
                activeColor: LouanePalette.accent,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Iconsax.profile_circle,
                iconActive: Iconsax.profile_circle_copy,
                label: 'Profil',
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  // Inactif volontairement plus doux que textMuted pour laisser respirer la barre.
  static const _inactive = Color(0x59FFFFFF);

  final IconData? icon;
  final IconData? iconActive;
  final Widget? customIcon;
  final String label;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback onTap;

  const _NavItem({
    this.icon,
    this.iconActive,
    this.customIcon,
    required this.label,
    required this.isActive,
    this.activeColor,
    required this.onTap,
  }) : assert(customIcon != null || (icon != null && iconActive != null));

  @override
  Widget build(BuildContext context) {
    final active = activeColor ?? AppColors.accent;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            customIcon ??
                Icon(
                  isActive ? iconActive : icon,
                  color: isActive ? active : _inactive,
                  size: 24,
                ),
            const SizedBox(height: 5),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10.5,
                letterSpacing: 0.2,
                color: isActive ? active : _inactive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
