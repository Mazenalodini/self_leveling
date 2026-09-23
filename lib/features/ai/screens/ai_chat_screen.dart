import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/system_background.dart';
import '../domain/entities/chat_models.dart';
import '../providers/ai_provider.dart';

class AIChatScreen extends ConsumerStatefulWidget {
  const AIChatScreen({super.key});

  @override
  ConsumerState<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends ConsumerState<AIChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  int _lastMessageCount = 0;
  bool _lastSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatControllerProvider);
    final messages = chatState.messages;

    if (_lastMessageCount != messages.length ||
        _lastSending != chatState.isSending) {
      _lastMessageCount = messages.length;
      _lastSending = chatState.isSending;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return SystemBackground(
      particleCount: 6,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: _buildThreadDrawer(chatState),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Column(
            children: [
              _buildHeader(context, chatState),
              _buildDivider(),
              Expanded(
                child: chatState.isLoading
                    ? _buildLoadingState()
                    : messages.isEmpty && !chatState.isSending
                        ? _buildEmptyState()
                        : _buildMessageList(messages, chatState),
              ),
              _buildInputBar(chatState),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════

  Widget _buildHeader(BuildContext context, AIChatState chatState) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
        child: Row(
          children: [
            // Drawer toggle
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_rounded,
                    color: AppColors.textSecondary, size: 24),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                tooltip: AppStrings.conversations,
              ),
            ),

            const SizedBox(width: 4),

            // AI Avatar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Icon(Icons.psychology_rounded,
                  color: Colors.white, size: 20),
            ),

            const SizedBox(width: 12),

            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.levelingCoach,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
                  Text(
                    chatState.cloudConfigured
                        ? AppStrings.coachSubtitle
                        : AppStrings.coachSubtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // New chat button
            Container(
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primaryBlue.withOpacity(0.2)),
              ),
              child: IconButton(
                icon: const Icon(Icons.edit_note_rounded,
                    color: AppColors.primaryBlue, size: 22),
                onPressed: () => ref
                    .read(aiChatControllerProvider.notifier)
                    .createNewThread(),
                tooltip: AppStrings.newChat,
                constraints:
                    const BoxConstraints(minWidth: 38, minHeight: 38),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ).animate().fadeIn().slideY(begin: -0.2),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.primaryBlue.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // THREAD DRAWER (Conversation History)
  // ═══════════════════════════════════════

  Widget _buildThreadDrawer(AIChatState chatState) {
    final threads = chatState.allThreads;
    final currentId = chatState.thread?.id;

    return Drawer(
      backgroundColor: const Color(0xFF0F1923),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.chat_bubble_outline_rounded,
                        color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Text(AppStrings.conversations,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // New Chat Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(aiChatControllerProvider.notifier)
                      .createNewThread();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primaryBlue.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_rounded,
                          color: AppColors.primaryBlue, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        AppStrings.newChat,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Thread List
            Expanded(
              child: threads.isEmpty
                  ? Center(
                      child: Text(
                        AppStrings.noConversationsYet,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: threads.length,
                      itemBuilder: (context, index) {
                        final thread = threads[index];
                        final isActive = thread.id == currentId;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              dense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              tileColor: isActive
                                  ? AppColors.primaryBlue.withOpacity(0.12)
                                  : Colors.transparent,
                              leading: Icon(
                                Icons.chat_outlined,
                                size: 18,
                                color: isActive
                                    ? AppColors.primaryBlue
                                    : AppColors.textTertiary,
                              ),
                              title: Text(
                                thread.title.isNotEmpty
                                    ? thread.title
                                    : AppStrings.newChat,
                                style: AppTextStyles.caption.copyWith(
                                  color: isActive
                                      ? AppColors.primaryBlue
                                      : AppColors.textSecondary,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                _formatThreadDate(thread.updatedAt),
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textTertiary,
                                  fontSize: 10,
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.delete_outline_rounded,
                                    size: 16,
                                    color:
                                        AppColors.danger.withOpacity(0.6)),
                                onPressed: () =>
                                    _confirmDeleteThread(thread),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                ref
                                    .read(aiChatControllerProvider.notifier)
                                    .switchToThread(thread.id);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteThread(AIChatThread thread) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppStrings.deleteConversation,
            style: AppTextStyles.bodyMedium),
        content: Text(
          AppStrings.deleteConversationConfirm,
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text(AppStrings.cancel, style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // close drawer
              ref
                  .read(aiChatControllerProvider.notifier)
                  .deleteThread(thread.id);
            },
            child: Text(AppStrings.delete,
                style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // EMPTY STATE (Suggestions)
  // ═══════════════════════════════════════

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        children: [
          // Coach avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.psychology_rounded,
                color: Colors.white, size: 36),
          ).animate().scale(begin: const Offset(0.8, 0.8)).fadeIn(),

          const SizedBox(height: 20),

          Text(
            AppStrings.levelingCoach,
            style: AppTextStyles.h2,
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 8),

          Text(
            AppStrings.startNewConversation,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 32),

          // Suggestion chips
          _buildSuggestionChip(AppStrings.suggestionHabits, 400),
          const SizedBox(height: 10),
          _buildSuggestionChip(AppStrings.suggestionFocus, 500),
          const SizedBox(height: 10),
          _buildSuggestionChip(AppStrings.suggestionProgress, 600),
          const SizedBox(height: 10),
          _buildSuggestionChip(AppStrings.suggestionMotivation, 700),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text, int delayMs) {
    return GestureDetector(
      onTap: () {
        _messageController.text = text.replaceAll(RegExp(r'^[^\s]+ '), '');
        final chatState = ref.read(aiChatControllerProvider);
        _sendMessage(chatState, overrideText: text.replaceAll(RegExp(r'^[^\s]+ '), ''));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primaryBlue.withOpacity(0.15)),
        ),
        child: Text(
          text,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delayMs)).slideX(begin: -0.1);
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primaryBlue),
    );
  }

  // ═══════════════════════════════════════
  // MESSAGE LIST
  // ═══════════════════════════════════════

  Widget _buildMessageList(
      List<AIChatMessage> messages, AIChatState chatState) {
    return SelectionArea(
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: messages.length + (chatState.isSending ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= messages.length) {
            if (chatState.streamingText != null &&
                chatState.streamingText!.isNotEmpty) {
              return _buildStreamingBubble(chatState.streamingText!);
            }
            return _buildTypingIndicator();
          }
          return _MessageBubble(
            message: messages[index],
            index: index,
            onCopy: () => _copyMessage(messages[index].body),
          );
        },
      ),
    );
  }

  Widget _buildStreamingBubble(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAIAvatar(small: true),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardBackground.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(
                  color: AppColors.primaryBlue.withOpacity(0.15),
                ),
              ),
              child: MarkdownBody(
                data: text,
                selectable: false,
                styleSheet: _markdownStyle(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAIAvatar(small: true),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cardBackground.withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(
                  color: AppColors.primaryBlue.withOpacity(0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(200),
                const SizedBox(width: 4),
                _buildDot(400),
                const SizedBox(width: 8),
                Text(
                  AppStrings.thinking,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: -0.1);
  }

  Widget _buildDot(int delayMs) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.6),
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 0.6, end: 1.0, duration: 600.ms)
        .then(delay: Duration(milliseconds: delayMs));
  }

  Widget _buildAIAvatar({bool small = false}) {
    final size = small ? 28.0 : 32.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(small ? 8 : 10),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Icon(Icons.psychology_rounded,
          color: Colors.white, size: small ? 16 : 18),
    );
  }

  // ═══════════════════════════════════════
  // INPUT BAR
  // ═══════════════════════════════════════

  Widget _buildInputBar(AIChatState chatState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground.withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.08),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: TextField(
                controller: _messageController,
                style: AppTextStyles.bodyMedium,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: AppStrings.askAnything,
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(chatState),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: chatState.isSending ? null : () => _sendMessage(chatState),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: chatState.isSending
                    ? null
                    : AppColors.primaryGradient,
                color: chatState.isSending
                    ? AppColors.cardBackground
                    : null,
                shape: BoxShape.circle,
                boxShadow: chatState.isSending
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.primaryBlue.withOpacity(0.5),
                          blurRadius: 16,
                        ),
                      ],
              ),
              child: Icon(
                chatState.isSending
                    ? Icons.hourglass_top_rounded
                    : Icons.arrow_upward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2);
  }

  // ═══════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════

  Future<void> _sendMessage(AIChatState chatState,
      {String? overrideText}) async {
    if (chatState.isSending) return;
    final text = overrideText ?? _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    await ref.read(aiChatControllerProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.messageCopied),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A2332),
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatThreadDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }

  /// Retry: put the message text back into the input field for editing.
  void _retryMessage(String text) {
    _messageController.text = text;
    // Move cursor to end
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
  }

  /// Markdown theme matching the app's dark design.
  MarkdownStyleSheet _markdownStyle(BuildContext context) {
    return MarkdownStyleSheet(
      p: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textSecondary,
        height: 1.6,
        fontSize: 14,
      ),
      strong: AppTextStyles.bodyMedium.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
      em: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textSecondary,
        fontStyle: FontStyle.italic,
        fontSize: 14,
      ),
      h1: AppTextStyles.bodyMedium.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 18,
      ),
      h2: AppTextStyles.bodyMedium.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
      h3: AppTextStyles.bodyMedium.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      listBullet: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.primaryBlue,
        fontSize: 14,
      ),
      blockSpacing: 10,
      listBulletPadding: const EdgeInsets.only(right: 8),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: AppColors.primaryBlue.withOpacity(0.4),
            width: 3,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(8),
      ),
      code: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.primaryCyan,
        fontSize: 13,
        fontFamily: 'monospace',
      ),
    );
  }
}

// ═══════════════════════════════════════
// MESSAGE BUBBLE
// ═══════════════════════════════════════

class _MessageBubble extends StatelessWidget {
  final AIChatMessage message;
  final int index;
  final VoidCallback onCopy;

  const _MessageBubble({
    required this.message,
    required this.index,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AIChatRole.user;
    final text = message.body;
    final time = DateFormat('h:mm a').format(message.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.psychology_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.primaryBlue.withOpacity(0.12)
                        : AppColors.cardBackground.withOpacity(0.5),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    border: Border.all(
                      color: isUser
                          ? AppColors.primaryBlue.withOpacity(0.25)
                          : AppColors.primaryBlue.withOpacity(0.1),
                    ),
                  ),
                  child: isUser
                      ? Text(
                          text,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            height: 1.5,
                            fontSize: 14,
                          ),
                        )
                      : MarkdownBody(
                          data: text,
                          selectable: false,
                          styleSheet: MarkdownStyleSheet(
                            p: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.6,
                              fontSize: 14,
                            ),
                            strong: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            em: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                              fontSize: 14,
                            ),
                            h1: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                            h2: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                            h3: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            listBullet: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primaryBlue,
                              fontSize: 14,
                            ),
                            blockSpacing: 10,
                            listBulletPadding:
                                const EdgeInsets.only(right: 8),
                            blockquoteDecoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color:
                                      AppColors.primaryBlue.withOpacity(0.4),
                                  width: 3,
                                ),
                              ),
                            ),
                            blockquotePadding: const EdgeInsets.only(
                                left: 12, top: 4, bottom: 4),
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                    if (!isUser) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onCopy,
                        child: Icon(
                          Icons.copy_rounded,
                          size: 13,
                          color: AppColors.textTertiary.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryCyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.primaryCyan.withOpacity(0.3)),
              ),
              child: const Icon(Icons.person_rounded,
                  color: AppColors.primaryCyan, size: 16),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: index < 10 ? 80 + index * 50 : 0))
        .slideX(begin: isUser ? 0.1 : -0.1);
  }
}
