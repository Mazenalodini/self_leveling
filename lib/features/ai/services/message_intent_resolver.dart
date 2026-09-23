import '../../../../domain/contracts/runtime_contract.dart';
import '../domain/entities/messaging_models.dart';

class MessageIntentResolver {
  const MessageIntentResolver();

  MessageIntent resolveForRequest({
    required MessageRequestKind requestKind,
    required InterventionStage stage,
  }) {
    switch (requestKind) {
      case MessageRequestKind.habitReminder:
        return MessageIntent.reminder;
      case MessageRequestKind.missedHabitNudge:
        return MessageIntent.encouragement;
      case MessageRequestKind.intervention:
        return resolveForStage(stage);
    }
  }

  MessageIntent resolveForStage(InterventionStage stage) {
    switch (stage) {
      case InterventionStage.s0:
        return MessageIntent.encouragement;
      case InterventionStage.s1:
      case InterventionStage.s2:
        return MessageIntent.warning;
      case InterventionStage.s4:
        return MessageIntent.advice;
      case InterventionStage.s3:
      case InterventionStage.s5:
        return MessageIntent.blockNotice;
    }
  }
}
