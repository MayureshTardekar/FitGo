import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_chat_message.dart';
import '../providers/ai_provider.dart';
import '../services/ai/ai_chat_store.dart';
import '../services/ai/ai_failure.dart';
import '../ui/components/fitgo_primary_button.dart';
import '../ui/haptics.dart';
import '../ui/profile/ai_settings_sheet.dart';
import '../ui/theme/fitgo_tokens.dart';

/// Optional, data-grounded Gemini conversation.
///
/// The screen is chat-only on purpose: it never writes a goal, setting, or log.
/// The user's key is entered from Profile → Preferences, not here.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen>
    with WidgetsBindingObserver {
  static const _hints = [
    'Summarize week',
    'How is my water going?',
    'Explain my weight trend',
    'What should I focus on?',
  ];

  static const _suggestions = [
    'Summarize week',
    'Explain my weight trend',
    'How can I hit my water goal?',
    'What is one small win from my logs?',
  ];

  final _composer = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  late final AiChatStore _chatStore;

  Timer? _hintTimer;
  Timer? _draftSaveTimer;
  Future<void> _draftSaveQueue = Future<void>.value();
  int _hintIndex = 0;
  bool _appIsResumed = true;
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatStore = ref.read(aiChatStoreProvider);
    final savedDraft = _chatStore.loadDraft();
    if (savedDraft.isNotEmpty) {
      _composer.value = TextEditingValue(
        text: savedDraft,
        selection: TextSelection.collapsed(offset: savedDraft.length),
      );
      _canSend = true;
    }
    _composer.addListener(_onComposerChanged);
    _startHintTimer();
    _scheduleScroll(animated: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHintTimer();
    _persistDraftNow();
    _composer
      ..removeListener(_onComposerChanged)
      ..dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onComposerChanged() {
    final canSend = _composer.text.trim().isNotEmpty;
    if (canSend != _canSend) {
      setState(() => _canSend = canSend);
    }
    if (_composer.text.isEmpty) {
      _startHintTimer();
    } else {
      _stopHintTimer();
    }
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 350), _persistDraft);
  }

  void _startHintTimer() {
    if (!_appIsResumed || _composer.text.isNotEmpty || _hintTimer != null) {
      return;
    }
    _hintTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_appIsResumed || _composer.text.isNotEmpty) return;
      setState(() => _hintIndex = (_hintIndex + 1) % _hints.length);
    });
  }

  void _stopHintTimer() {
    _hintTimer?.cancel();
    _hintTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _appIsResumed = false;
      _stopHintTimer();
      // A notification shade/quick reply can leave Android's text input
      // connection stale. Keep the draft, but close it before backgrounding.
      _focusNode.unfocus();
      _persistDraftNow();
      return;
    }

    if (state == AppLifecycleState.resumed && mounted) {
      _appIsResumed = true;
      _startHintTimer();
    }
  }

  void _persistDraftNow() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = null;
    unawaited(_persistDraft());
  }

  Future<void> _persistDraft() {
    final draft = _composer.text;
    _draftSaveQueue = _draftSaveQueue.then((_) async {
      try {
        await _chatStore.saveDraft(draft);
      } catch (_) {
        // Draft persistence is best-effort; it must not interrupt chat.
      }
    });
    return _draftSaveQueue;
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(aiChatProvider);
    final settings = ref.watch(aiSettingsProvider).valueOrNull;

    ref.listen<AiChatState>(aiChatProvider, (previous, next) {
      final added =
          previous == null || next.messages.length != previous.messages.length;
      if (added || previous.sending != next.sending) {
        _scheduleScroll();
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('AI coach'),
        actions: [
          IconButton(
            tooltip: 'Clear conversation',
            onPressed: chat.hasMessages ? _confirmClear : null,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          IconButton(
            tooltip: 'AI coach settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: chat.hasMessages || chat.sending
                  ? _Conversation(
                      chat: chat,
                      scrollController: _scrollController,
                    )
                  : _EmptyState(
                      settings: settings,
                      suggestions: _suggestions,
                      onSuggestion: _sendText,
                      onSetup: _openSettings,
                    ),
            ),
            if (chat.failure != null)
              _FailureBanner(
                failure: chat.failure!,
                canRetry: chat.canRetry,
                onRetry: () => ref.read(aiChatProvider.notifier).retry(),
                onOpenSettings: _openSettings,
                onDismiss: () =>
                    ref.read(aiChatProvider.notifier).dismissFailure(),
              ),
            _Composer(
              controller: _composer,
              focusNode: _focusNode,
              hint: _hints[_hintIndex],
              canSend: _canSend,
              sending: chat.sending,
              modelLabel: chat.usingModel,
              onSend: _send,
              onStop: _stop,
            ),
          ],
        ),
      ),
    );
  }

  void _send() => _sendText(_composer.text);

  void _sendText(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;
    if (_composer.text != text) {
      _composer.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    _composer.clear();
    _draftSaveTimer?.cancel();
    _draftSaveTimer = null;
    unawaited(_persistDraft());
    _focusNode.requestFocus();
    FitGoHaptics.select();
    ref.read(aiChatProvider.notifier).send(text);
  }

  void _stop() {
    FitGoHaptics.select();
    ref.read(aiChatProvider.notifier).cancel();
  }

  Future<void> _openSettings() async {
    final saved = await showAiSettingsSheet(context);
    if (!mounted || saved != true) return;
    ref.read(aiChatProvider.notifier).dismissFailure();
  }

  Future<void> _confirmClear() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text(
          'This removes the chat history on this device. Your FitGo logs and '
          'Gemini key stay as they are.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (shouldClear != true) return;
    FitGoHaptics.select();
    await ref.read(aiChatProvider.notifier).clear();
  }

  void _scheduleScroll({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }
}

class _Conversation extends StatelessWidget {
  const _Conversation({required this.chat, required this.scrollController});

  final AiChatState chat;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final itemCount = chat.messages.length + (chat.sending ? 1 : 0) + 1;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        FitGoSpacing.md,
        FitGoSpacing.sm,
        FitGoSpacing.md,
        FitGoSpacing.md,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < chat.messages.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: FitGoSpacing.sm),
            child: _MessageBubble(message: chat.messages[index]),
          );
        }
        if (chat.sending && index == chat.messages.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: FitGoSpacing.sm),
            child: _TypingBubble(modelLabel: chat.usingModel),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            FitGoSpacing.xs,
            FitGoSpacing.sm,
            FitGoSpacing.xs,
            0,
          ),
          child: Text(
            'AI can make mistakes. It explains your FitGo data and cannot '
            'change goals, logs, or settings.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final AiChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final isUser = message.isUser;
    final foreground = isUser
        ? theme.colorScheme.onPrimary
        : tokens.textPrimary;

    return Semantics(
      label: isUser ? 'Your message' : 'AI coach message',
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.84,
          ),
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Padding(
                  padding: const EdgeInsets.only(
                    left: FitGoSpacing.xs,
                    bottom: FitGoSpacing.xxs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: tokens.emberDeep,
                      ),
                      const SizedBox(width: FitGoSpacing.xxs),
                      Flexible(
                        child: Text(
                          'FitGo coach',
                          maxLines: 2,
                          overflow: TextOverflow.visible,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: tokens.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Container(
                decoration: BoxDecoration(
                  color: isUser ? theme.colorScheme.primary : tokens.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 18 : 6),
                    bottomRight: Radius.circular(isUser ? 6 : 18),
                  ),
                  border: isUser ? null : Border.all(color: tokens.border),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: FitGoSpacing.md,
                  vertical: FitGoSpacing.sm,
                ),
                child: Text(
                  message.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({this.modelLabel});

  final String? modelLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: tokens.border),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: FitGoSpacing.md,
          vertical: FitGoSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _TypingDots(),
            const SizedBox(width: FitGoSpacing.xs),
            Flexible(
              child: Text(
                modelLabel == null ? 'Thinking…' : '$modelLabel is thinking…',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.tokens.emberDeep;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = (_controller.value + index / 3) % 1;
            final strength = 1 - (phase - 0.5).abs() * 2;
            return Padding(
              padding: EdgeInsets.only(right: index == 2 ? 0 : 3),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.3 + strength * 0.7),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.settings,
    required this.suggestions,
    required this.onSuggestion,
    required this.onSetup,
  });

  final AiSettings? settings;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestion;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final hasKey = settings?.hasKey ?? false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        FitGoSpacing.lg,
        FitGoSpacing.xl,
        FitGoSpacing.lg,
        FitGoSpacing.xl,
      ),
      children: [
        Center(
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [tokens.ember, tokens.emberDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 32,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(height: FitGoSpacing.md),
        Text(
          'Your coach, grounded in your logs',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: FitGoSpacing.xs),
        Text(
          'Ask about your progress, habits, or plan. FitGo computes the facts; '
          'the coach explains them.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: tokens.textSecondary,
          ),
        ),
        const SizedBox(height: FitGoSpacing.xl),
        if (!hasKey) ...[
          Container(
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(tokens.cardRadius),
              border: Border.all(color: tokens.border),
            ),
            padding: const EdgeInsets.all(FitGoSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Optional. Add your own free Gemini key to start.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: FitGoSpacing.sm),
                FitGoPrimaryButton(
                  label: 'Connect Gemini',
                  icon: Icons.key_rounded,
                  onPressed: onSetup,
                ),
              ],
            ),
          ),
          const SizedBox(height: FitGoSpacing.lg),
        ],
        Text(
          'Try asking',
          style: theme.textTheme.labelLarge?.copyWith(
            color: tokens.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: FitGoSpacing.sm),
        Wrap(
          spacing: FitGoSpacing.xs,
          runSpacing: FitGoSpacing.xs,
          children: [
            for (final suggestion in suggestions)
              _SuggestionChip(
                label: suggestion,
                onTap: hasKey ? () => onSuggestion(suggestion) : onSetup,
              ),
          ],
        ),
        const SizedBox(height: FitGoSpacing.xl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, size: 16, color: tokens.aqua),
            const SizedBox(width: FitGoSpacing.xs),
            Expanded(
              child: Text(
                'Requests go from this device to Google. No name, email, or '
                'account ID is sent.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Material(
      color: tokens.surface,
      shape: StadiumBorder(side: BorderSide(color: tokens.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FitGoSpacing.sm,
            vertical: FitGoSpacing.xs,
          ),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({
    required this.failure,
    required this.canRetry,
    required this.onRetry,
    required this.onOpenSettings,
    required this.onDismiss,
  });

  final AiFailure failure;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final actionLabel = failure.needsKey || failure.needsConsent
        ? 'Open settings'
        : canRetry
        ? 'Try again'
        : null;
    final action = failure.needsKey || failure.needsConsent
        ? onOpenSettings
        : canRetry
        ? onRetry
        : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        FitGoSpacing.md,
        0,
        FitGoSpacing.md,
        FitGoSpacing.xs,
      ),
      padding: const EdgeInsets.fromLTRB(
        FitGoSpacing.sm,
        FitGoSpacing.xs,
        FitGoSpacing.xxs,
        FitGoSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(FitGoRadii.cardSmall),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(width: FitGoSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  failure.userMessage,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                if (actionLabel != null)
                  TextButton(
                    onPressed: action,
                    style: TextButton.styleFrom(
                      foregroundColor: tokens.emberDeep,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(actionLabel),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.canSend,
    required this.sending,
    required this.modelLabel,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool canSend;
  final bool sending;
  final String? modelLabel;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
        FitGoSpacing.sm,
        FitGoSpacing.xs,
        FitGoSpacing.sm,
        FitGoSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: tokens.surfaceMuted,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: tokens.border),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      if (!sending && canSend) onSend();
                    },
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: tokens.textSecondary,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: FitGoSpacing.md,
                        vertical: FitGoSpacing.sm,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: FitGoSpacing.xs),
              IconButton.filled(
                onPressed: sending ? onStop : (canSend ? onSend : null),
                tooltip: sending ? 'Stop' : 'Send',
                style: IconButton.styleFrom(
                  minimumSize: const Size(46, 46),
                  backgroundColor: tokens.ember,
                  foregroundColor: theme.colorScheme.onPrimary,
                  disabledBackgroundColor: tokens.surfaceMuted,
                  disabledForegroundColor: tokens.textSecondary,
                ),
                icon: Icon(
                  sending ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FitGoSpacing.xs,
              FitGoSpacing.xxs,
              FitGoSpacing.xs,
              0,
            ),
            child: Text(
              sending
                  ? '${modelLabel ?? 'Gemini'} is answering. Tap stop to cancel.'
                  : 'AI can make mistakes. It cannot change goals or logs.',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
