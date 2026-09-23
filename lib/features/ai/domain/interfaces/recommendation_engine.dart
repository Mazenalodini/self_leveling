import '../entities/ai_contexts.dart';
import '../entities/ai_outputs.dart';

/// Abstract interface for recommending the best next action.
/// Designed to be pure and context-driven. Does not rely on hidden database state.
abstract class RecommendationEngine {
  Future<RecommendationResult> getBestAction(RecommendationContext context);
}
