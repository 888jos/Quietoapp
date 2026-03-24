import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../../../app/router.dart';

class PaywallPage extends ConsumerWidget {
  const PaywallPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PaywallView(
      onDismiss: () => context.go(AppRoutes.home),
      onPurchaseCompleted: (customerInfo, transaction) {
        context.go(AppRoutes.home);
      },
      onRestoreCompleted: (customerInfo) {
        context.go(AppRoutes.home);
      },
    );
  }
}
