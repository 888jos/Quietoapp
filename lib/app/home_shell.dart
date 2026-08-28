import 'dart:ui' show ImageFilter;

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
      // Le contenu file DERRIÈRE la barre flottante : c'est lui que le
      // flou de la pilule capture.
      extendBody: true,
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          // Sur l'onglet Louane la barre s'efface (décision Paul 28/08) :
          // la conversation est immersive, seul le champ d'écriture vit en
          // bas. La sortie, c'est le chevron de l'en-tête du chat.
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: shell.currentIndex == 1
                ? const SizedBox.shrink()
                : _QuijetoNav(
                    currentIndex: shell.currentIndex,
                    onTap: (index) {
                      // Vigie : navigation entre onglets (quels espaces
                      // vivent ?).
                      if (index != shell.currentIndex &&
                          index < _nomsOnglets.length) {
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
          ),
        ],
      ),
    );
  }
}

/// Barre de navigation façon pilule flottante (inspirée de Headspace,
/// demande de Paul du 28/08) : détachée des bords, fond translucide qui
/// FLOUTE le contenu qui défile derrière, halo qui glisse sous l'onglet
/// actif. Les icônes restent celles de Quieto.
class _QuijetoNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _QuijetoNav({required this.currentIndex, required this.onTap});

  static const _hauteur = 68.0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Container(
          // L'ombre vit HORS du ClipRRect, sinon elle serait rognée.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_hauteur / 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_hauteur / 2),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                height: _hauteur,
                decoration: BoxDecoration(
                  // Semi-transparent : le flou fait le reste.
                  color: AppColors.background.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(_hauteur / 2),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Stack(
                  children: [
                    // Le halo de l'onglet actif : une pilule douce qui
                    // GLISSE d'un onglet à l'autre.
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment(-1.0 + currentIndex * 1.0, 0),
                      child: FractionallySizedBox(
                        widthFactor: 1 / 3,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _NavItem(
                            icon: Iconsax.home,
                            iconActive: Iconsax.home_copy,
                            label: 'Accueil',
                            isActive: currentIndex == 0,
                            onTap: () => onTap(0),
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            customIcon:
                                LouaneMiniAvatar(actif: currentIndex == 1),
                            label: 'Louane',
                            isActive: currentIndex == 1,
                            activeColor: LouanePalette.accent,
                            onTap: () => onTap(1),
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            icon: Iconsax.profile_circle,
                            iconActive: Iconsax.profile_circle_copy,
                            label: 'Profil',
                            isActive: currentIndex == 2,
                            onTap: () => onTap(2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
      // La couleur FOND d'un état à l'autre au lieu de sauter, au même
      // tempo que le halo qui glisse (300 ms).
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: isActive ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) {
          final couleur = Color.lerp(_inactive, active, t)!;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              customIcon ??
                  Icon(
                    isActive ? iconActive : icon,
                    color: couleur,
                    size: 24,
                  ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10.5,
                  letterSpacing: 0.2,
                  color: couleur,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
