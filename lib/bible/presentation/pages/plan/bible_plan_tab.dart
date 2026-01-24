import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:mychatolic_app/bible/bible_module.dart';
import 'package:mychatolic_app/bible/domain/entities/bible_entities.dart';
import 'package:mychatolic_app/bible/presentation/pages/plan/bible_plan_day_page.dart';
import 'package:mychatolic_app/bible/presentation/viewmodels/bible_plan_viewmodel.dart';
import 'package:mychatolic_app/bible/presentation/widgets/empty_state_view.dart';
import 'package:mychatolic_app/bible/presentation/widgets/error_state_view.dart';
import 'package:mychatolic_app/bible/core/design_tokens.dart';
import 'package:mychatolic_app/bible/presentation/widgets/app_components.dart';
import 'package:mychatolic_app/bible/presentation/widgets/section_title.dart';

class BiblePlanTab extends StatelessWidget {
  const BiblePlanTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          BiblePlanViewModel(planRepository: BibleModule.readingPlanRepository)
            ..loadPlans(),
      child: Consumer<BiblePlanViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (vm.errorMessage != null) {
            return ErrorStateView(
              message: vm.errorMessage!,
              onRetry: vm.loadPlans,
            );
          }

          if (vm.plans.isEmpty) {
            return const EmptyStateView(message: 'Belum ada rencana tersedia.');
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (vm.activePlan != null) ...[
                _ActivePlanCard(
                  plan: vm.activePlan!,
                  onReadToday: () => _openDay(
                    context,
                    vm.activePlan!,
                    vm.activePlan!.currentDay ?? 1,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              const SectionTitle('Semua Rencana'),
              const SizedBox(height: AppSpacing.md),
              ...vm.plans.map((plan) {
                return _PlanCard(
                  plan: plan,
                  onAction: () => vm.startPlan(plan),
                  isActive: vm.activePlan?.id == plan.id,
                );
              }),
            ],
          );
        },
      ),
    );
  }

  void _openDay(BuildContext context, ReadingPlan plan, int day) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BiblePlanDayPage(plan: plan, day: day),
      ),
    );
  }
}

class _ActivePlanCard extends StatelessWidget {
  final ReadingPlan plan;
  final VoidCallback onReadToday;

  const _ActivePlanCard({required this.plan, required this.onReadToday});

  @override
  Widget build(BuildContext context) {
    final progress = plan.progress ?? 0;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rencana Aktif',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            plan.title,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LinearProgressIndicator(value: progress == 0 ? null : progress),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(label: 'Baca hari ini', onPressed: onReadToday),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final ReadingPlan plan;
  final VoidCallback onAction;
  final bool isActive;

  const _PlanCard({
    required this.plan,
    required this.onAction,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('${plan.durationDays} hari • ${plan.theme ?? 'Umum'}'),
              ],
            ),
          ),
          PrimaryButton(
            label: isActive ? 'Aktif' : 'Mulai',
            onPressed: isActive ? null : onAction,
          ),
        ],
      ),
    );
  }
}
