import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../navigation/app_router.dart';
import '../../ai/domain/enums/output_channel.dart';
import '../../ai/providers/ai_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class AIDebugScreen extends ConsumerWidget {
  const AIDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msgContext = ref.watch(messageContextBuilderProvider);
    final recContext = ref.watch(recommendationContextBuilderProvider);
    final msgGenerator = ref.watch(localMessageGeneratorProvider);
    final recEngine = ref.watch(localRecommendationEngineProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Engine Debug (Phase 4A)'),
        backgroundColor: AppColors.surfaceDark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: 'Context Snapshot',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Language: ${msgContext.currentLanguage}', style: AppTextStyles.bodyMedium),
                  Text('Target Identity: ${msgContext.profile.primaryIdentity}', style: AppTextStyles.bodyMedium),
                  Text('Level / Escalation: S${msgContext.currentStage.index}', style: AppTextStyles.bodyMedium),
                  Text('Pending Habits: ${recContext.pendingHabits.length}', style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: 'Recommendation Engine Output',
              child: FutureBuilder(
                future: recEngine.getBestAction(recContext),
                builder: (context, snap) {
                  if (!snap.hasData) return const CircularProgressIndicator();
                  final data = snap.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Action Type: ${data.actionType.name}', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryBlue)),
                      Text('Title: ${data.title}', style: AppTextStyles.bodyLarge),
                      Text('Subtitle: ${data.subtitle ?? ''}', style: AppTextStyles.bodySmall),
                      Text('Tags: ${data.reasoningTags.join(', ')}', style: AppTextStyles.caption.copyWith(color: Colors.white54)),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: 'Local Message Generator',
              child: Column(
                children: OutputChannel.values.map((channel) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: FutureBuilder(
                      future: msgGenerator.generateMessage(msgContext, channel),
                      builder: (context, snap) {
                        if (!snap.hasData) return const SizedBox();
                        final data = snap.data!;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('[Output: ${channel.name}]', style: AppTextStyles.caption.copyWith(color: AppColors.primaryBlue)),
                              const SizedBox(height: 4),
                              Text(data.headline, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(data.body, style: AppTextStyles.bodyMedium),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    color: Colors.white10,
                                    child: Text(data.tone, style: AppTextStyles.caption),
                                  ),
                                  const SizedBox(width: 8),
                                  if (data.actionLabel != null)
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      color: AppColors.primaryBlue.withOpacity(0.2),
                                      child: Text(data.actionLabel!, style: AppTextStyles.caption.copyWith(color: AppColors.primaryBlue)),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.go(RoutePaths.welcome);
              },
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('DEBUG: Sign Out', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3.copyWith(color: Colors.white, fontSize: 18)),
          const Divider(color: Colors.white12, height: 24),
          child,
        ],
      ),
    );
  }
}
