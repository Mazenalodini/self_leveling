import '../enums/output_channel.dart';
import '../enums/action_type.dart';

/// The structured output of the Message Generator.
class GeneratedMessage {
  final String headline;
  final String body;
  final String tone; // e.g. "gentle", "strict", "reflective"
  final OutputChannel channel;
  final String? actionLabel; // e.g. "Breathe", "Close App"
  final List<String> reasoningTags; // e.g. ["identity_conflict", "weakness_window"]
  final String language;

  const GeneratedMessage({
    required this.headline,
    required this.body,
    required this.tone,
    required this.channel,
    this.actionLabel,
    this.reasoningTags = const [],
    required this.language,
  });
}

/// The structured output of the Recommendation Engine.
class RecommendationResult {
  final ActionType actionType;
  final String title;
  final String? subtitle;
  final List<String> reasoningTags;
  final double confidenceScore; // 0.0 - 1.0 ranking weight

  // Could optionally hold a specific Habit ID if it recommends a pending habit
  final String? targetId;

  const RecommendationResult({
    required this.actionType,
    required this.title,
    this.subtitle,
    this.reasoningTags = const [],
    required this.confidenceScore,
    this.targetId,
  });
}
