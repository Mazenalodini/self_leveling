import '../entities/ai_contexts.dart';
import '../entities/ai_outputs.dart';
import '../enums/output_channel.dart';

/// Abstract interface for generating intelligent messages.
/// Designed to allow swapping between Local rules-engines and future Cloud LLMs.
abstract class MessageGenerator {
  Future<GeneratedMessage> generateMessage(
    MessageContext context,
    OutputChannel targetChannel,
  );
}
