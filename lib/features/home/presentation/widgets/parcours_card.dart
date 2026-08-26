import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/models/parcours_model.dart';
import '../../../../core/services/storage_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../parcours/parcours_providers.dart';

/// La carte « programme en cours » de l'accueil : titre, barre de
/// progression en 7 segments, et la séance du jour (ou « à demain » si
/// elle est déjà faite). Invisible s'il n'y a pas de programme, ou une fois
/// le bilan envoyé.
class ParcoursCard extends ConsumerWidget {
  const ParcoursCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parcours = ref.watch(parcoursProvider);
    if (parcours == null || parcours.termine) {
      return const SizedBox.shrink();
    }

    final aujourdHui = ParcoursModel.cleJourLocal(DateTime.now());
    final faiteAujourdhui = parcours.seanceDuJourFaite(aujourdHui);
    final duJour = parcours.seanceDuJour;

    final String sousTexte;
    if (parcours.tousJoursTermines) {
      sousTexte = 'Ta semaine est terminée, viens faire le bilan';
    } else if (faiteAujourdhui) {
      sousTexte = 'Jour ${parcours.joursTermines.length} terminé, à demain';
    } else if (duJour != null) {
      sousTexte =
          'Aujourd\'hui : ${duJour.titreSeance}, ${duJour.dureeMin} min';
    } else {
      sousTexte = 'Ton programme t\'attend';
    }

    // L'espacement vertical vit ICI (et pas dans le SliverPadding de la
    // Home) : sans programme, la carte ET son espace disparaissent ensemble,
    // aucun trou entre le header et « Priorité du moment ». En dessous,
    // spacingLg : la carte respire, bien détachée de la section suivante.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingLg),
      child: Material(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            ref.read(vigieProvider).log('parcours_ouvert', {'source': 'home'});
            context.push(AppRoutes.parcours);
          },
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          splashColor: AppColors.accentDim,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              border: Border.all(color: AppColors.accent, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    Text(
                      'TON PROGRAMME AVEC LOUANE',
                      style: AppTextStyles.caption.copyWith(letterSpacing: 1.1),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingSm),
                Text(
                  parcours.titre,
                  style: AppTextStyles.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppConstants.spacingSm),
                // La progression : 7 petits segments, un par jour.
                Row(
                  children: [
                    for (var j = 1; j <= 7; j++)
                      Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(right: j < 7 ? 4 : 0),
                          decoration: BoxDecoration(
                            color: parcours.jourTermine(j)
                                ? AppColors.accent
                                : AppColors.accentDim,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingSm),
                Text(sousTexte, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
