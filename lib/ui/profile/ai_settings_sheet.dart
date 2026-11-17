import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ai_provider.dart';
import '../../services/ai/ai_models.dart';
import '../components/fitgo_card.dart';
import '../components/fitgo_loading.dart';
import '../components/fitgo_pill.dart';
import '../components/fitgo_primary_button.dart';
import '../components/fitgo_sheet.dart';
import '../haptics.dart';
import '../theme/fitgo_tokens.dart';

const _apiKeyUrl = 'https://aistudio.google.com/apikey';
const _termsUrl = 'https://ai.google.dev/gemini-api/terms';

/// Opens the single AI settings surface. Returns true when a key was saved so
/// the caller can continue straight into the chat.
Future<bool?> showAiSettingsSheet(BuildContext context) {
  return showFitGoSheet<bool>(context, builder: (_) => const AiSettingsSheet());
}

class AiSettingsSheet extends ConsumerStatefulWidget {
  const AiSettingsSheet({super.key});

  @override
  ConsumerState<AiSettingsSheet> createState() => _AiSettingsSheetState();
}

class _AiSettingsSheetState extends ConsumerState<AiSettingsSheet> {
  final _keyController = TextEditingController();
  bool _obscure = true;
  bool _replacing = false;
  bool _saving = false;
  bool _consent = false;
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final settingsAsync = ref.watch(aiSettingsProvider);
    final settings = settingsAsync.valueOrNull;
    final consentAccepted = _consent || (settings?.consentAccepted ?? false);

    return FitGoSheet(
      title: 'AI coach',
      subtitle: 'Optional. Your logs stay yours.',
      child: settingsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(FitGoSpacing.xl),
          child: Center(child: FitGoLoading()),
        ),
        error: (_, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Could not open secure storage. Your FitGo logs are unaffected.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: FitGoSpacing.md),
            OutlinedButton(
              onPressed: () => ref.read(aiSettingsProvider.notifier).refresh(),
              child: const Text('Try again'),
            ),
          ],
        ),
        data: (settings) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (settings.hasKey && !_replacing) ...[
                _SavedKeyCard(settings: settings),
                const SizedBox(height: FitGoSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () {
                    FitGoHaptics.select();
                    setState(() {
                      _replacing = true;
                      _error = null;
                    });
                  },
                  icon: const Icon(Icons.key_outlined),
                  label: const Text('Replace key'),
                ),
                const SizedBox(height: FitGoSpacing.xxs),
                TextButton.icon(
                  onPressed: _saving ? null : _deleteAll,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete AI data'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: FitGoSpacing.xs),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ] else ...[
                TextField(
                  controller: _keyController,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
                  onChanged: (_) => setState(() => _error = null),
                  decoration: InputDecoration(
                    labelText: 'Gemini API key',
                    hintText: 'Paste your key',
                    prefixIcon: const Icon(Icons.key_outlined),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show key' : 'Hide key',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: FitGoSpacing.xs),
                Wrap(
                  spacing: FitGoSpacing.xs,
                  children: [
                    TextButton.icon(
                      onPressed: () => _copyLink(_apiKeyUrl, 'Key page copied'),
                      icon: const Icon(Icons.open_in_new_rounded, size: 17),
                      label: const Text('Get a free key'),
                    ),
                    TextButton(
                      onPressed: () =>
                          _copyLink(_termsUrl, 'Terms link copied'),
                      child: const Text('Gemini terms'),
                    ),
                  ],
                ),
                const SizedBox(height: FitGoSpacing.sm),
                const _PrivacyNote(),
                if (!settings.consentAccepted) ...[
                  const SizedBox(height: FitGoSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _consent,
                        onChanged: (value) =>
                            setState(() => _consent = value ?? false),
                      ),
                      const SizedBox(width: FitGoSpacing.xs),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _consent = !_consent),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: Text(
                              'I understand and want to use my own key with '
                              'Google’s free tier.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: tokens.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: FitGoSpacing.xs),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: FitGoSpacing.md),
                FitGoPrimaryButton(
                  label: _replacing ? 'Replace key' : 'Save key',
                  loading: _saving,
                  icon: Icons.check_rounded,
                  onPressed:
                      _saving ||
                          !consentAccepted ||
                          _keyController.text.trim().length < 20
                      ? null
                      : _save,
                ),
                if (_replacing) ...[
                  const SizedBox(height: FitGoSpacing.xs),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            _replacing = false;
                            _keyController.clear();
                            _error = null;
                          }),
                    child: const Text('Cancel'),
                  ),
                ],
              ],
              const SizedBox(height: FitGoSpacing.md),
              Text(
                'AI can make mistakes. It explains your FitGo data but cannot '
                'change goals, logs, or settings.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    FitGoHaptics.select();
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final settings = ref.read(aiSettingsProvider).valueOrNull;
      await ref
          .read(aiSettingsProvider.notifier)
          .saveKey(
            _keyController.text,
            consent: _consent || (settings?.consentAccepted ?? false),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AiSettingsException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save the key. Try again.';
      });
    }
  }

  Future<void> _deleteAll() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete AI data?'),
        content: const Text(
          'This removes the Gemini key, chat history, and usage counters from '
          'this device. Your FitGo logs are untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    setState(() => _saving = true);
    try {
      await ref.read(aiSettingsProvider.notifier).deleteAllAiData();
      if (!mounted) return;
      Navigator.of(context).pop(false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not delete AI data. Try again.';
      });
    }
  }

  Future<void> _copyLink(String url, String message) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SavedKeyCard extends StatelessWidget {
  const _SavedKeyCard({required this.settings});

  final AiSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return FitGoCard(
      color: tokens.surfaceMuted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tokens.ember.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(FitGoRadii.input),
                ),
                child: Icon(Icons.key_rounded, color: tokens.emberDeep),
              ),
              const SizedBox(width: FitGoSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gemini key saved',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      settings.maskedKey,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: FitGoSpacing.sm),
          Wrap(
            spacing: FitGoSpacing.xs,
            runSpacing: FitGoSpacing.xs,
            children: [
              FitGoPill(
                label:
                    '${settings.usage.premiumRemaining} of '
                    '${AiModels.premiumDailyLimit} premium left today',
                icon: Icons.bolt_rounded,
                color: tokens.emberDeep,
              ),
              const FitGoPill(
                label: 'Flash Lite fallback',
                icon: Icons.offline_bolt_outlined,
              ),
            ],
          ),
          const SizedBox(height: FitGoSpacing.xs),
          Text(
            'The first 10 requests alternate between 3.8 Flash and 3.6 Flash. '
            'Flash Lite keeps chat working after that.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return FitGoCard(
      color: tokens.surfaceMuted,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 18, color: tokens.aqua),
          const SizedBox(width: FitGoSpacing.xs),
          Expanded(
            child: Text(
              'The key is stored only on this device and requests go '
              'directly to Google. Free-tier prompts may be reviewed to '
              'improve Google products; a paid key has stricter privacy. '
              'No email, name, or account ID is sent.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
