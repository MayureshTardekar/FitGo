import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../models/ai_chat_message.dart';
import 'ai_failure.dart';
import 'ai_models.dart';

class GeminiReply {
  const GeminiReply({required this.text, required this.modelId});

  final String text;
  final String modelId;
}

/// Direct device → Google Gemini client.
///
/// There is no FitGo proxy and no key is ever placed in a URL. Cancellation
/// closes the in-flight HTTP client so a user can leave the screen without
/// paying for a response they no longer need.
class GeminiClient {
  GeminiClient({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  final http.Client Function() _clientFactory;

  http.Client? _activeClient;
  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
    _activeClient?.close();
    _activeClient = null;
  }

  Future<GeminiReply> generate({
    required String apiKey,
    required AiModel model,
    required String systemPrompt,
    required String context,
    required List<AiChatMessage> messages,
    Duration timeout = const Duration(seconds: 35),
  }) async {
    _cancelled = false;
    final client = _clientFactory();
    _activeClient = client;

    try {
      final uri = Uri.parse('$_baseUrl/${model.id}:generateContent');
      final response = await client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode(_payload(systemPrompt, context, messages)),
          )
          .timeout(timeout);

      if (_cancelled) {
        throw const AiException(AiFailure(AiFailureCode.cancelled));
      }
      if (response.statusCode != 200) {
        throw AiException(_failureForResponse(response));
      }

      return GeminiReply(text: _extractText(response.body), modelId: model.id);
    } on AiException {
      rethrow;
    } on TimeoutException {
      throw AiException(
        _cancelled
            ? const AiFailure(AiFailureCode.cancelled)
            : const AiFailure(AiFailureCode.timeout),
      );
    } on SocketException {
      throw AiException(
        _cancelled
            ? const AiFailure(AiFailureCode.cancelled)
            : const AiFailure(AiFailureCode.network),
      );
    } on http.ClientException {
      throw AiException(
        _cancelled
            ? const AiFailure(AiFailureCode.cancelled)
            : const AiFailure(AiFailureCode.network),
      );
    } on FormatException {
      throw const AiException(AiFailure(AiFailureCode.unknown));
    } catch (_) {
      throw AiException(
        _cancelled
            ? const AiFailure(AiFailureCode.cancelled)
            : const AiFailure(AiFailureCode.unknown),
      );
    } finally {
      if (identical(_activeClient, client)) {
        _activeClient = null;
      }
      client.close();
    }
  }

  Map<String, Object?> _payload(
    String systemPrompt,
    String context,
    List<AiChatMessage> messages,
  ) {
    final recent = messages.length > 20
        ? messages.sublist(messages.length - 20)
        : messages;
    final contents = recent
        .map(
          (message) => {
            'role': message.isUser ? 'user' : 'model',
            'parts': [
              {'text': message.text},
            ],
          },
        )
        .toList();

    return {
      'systemInstruction': {
        'parts': [
          {'text': '$systemPrompt\n\n$context'},
        ],
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.45,
        'topP': 0.95,
        'maxOutputTokens': 1200,
      },
    };
  }

  AiFailure _failureForResponse(http.Response response) {
    final status = response.statusCode;
    if (status == 401 || status == 403) {
      return AiFailure(AiFailureCode.invalidKey, statusCode: status);
    }
    if (status == 404) {
      return AiFailure(AiFailureCode.modelUnavailable, statusCode: status);
    }
    if (status == 429) {
      return AiFailure(AiFailureCode.quota, statusCode: status);
    }

    final payload = _decode(response.body);
    final error = payload?['error'];
    final errorMap = error is Map ? error : null;
    final message = '${errorMap?['message'] ?? ''}'.toLowerCase();
    final details = jsonEncode(errorMap?['details'] ?? '').toLowerCase();

    if (status == 400) {
      if (message.contains('api key') ||
          message.contains('api_key_invalid') ||
          details.contains('api_key_invalid')) {
        return AiFailure(AiFailureCode.invalidKey, statusCode: status);
      }
      return AiFailure(AiFailureCode.badRequest, statusCode: status);
    }
    if (status >= 500) {
      return AiFailure(AiFailureCode.unavailable, statusCode: status);
    }
    return AiFailure(AiFailureCode.unknown, statusCode: status);
  }

  String _extractText(String body) {
    final payload = _decode(body);
    if (payload == null) {
      throw const AiException(AiFailure(AiFailureCode.unknown));
    }

    final feedback = payload['promptFeedback'];
    if (feedback is Map && feedback['blockReason'] != null) {
      throw const AiException(AiFailure(AiFailureCode.safety));
    }

    final candidates = payload['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const AiException(AiFailure(AiFailureCode.emptyResponse));
    }

    final candidate = candidates.first;
    if (candidate is! Map) {
      throw const AiException(AiFailure(AiFailureCode.emptyResponse));
    }

    final finishReason = '${candidate['finishReason'] ?? ''}';
    if (finishReason == 'SAFETY' ||
        finishReason == 'RECITATION' ||
        finishReason == 'BLOCKLIST' ||
        finishReason == 'PROHIBITED_CONTENT' ||
        finishReason == 'SPII') {
      throw const AiException(AiFailure(AiFailureCode.safety));
    }

    final content = candidate['content'];
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List) {
      throw const AiException(AiFailure(AiFailureCode.emptyResponse));
    }

    final textParts = <String>[];
    for (final part in parts) {
      if (part is! Map || part['thought'] == true) continue;
      final text = part['text'];
      if (text is String && text.trim().isNotEmpty) {
        textParts.add(text.trim());
      }
    }

    final text = textParts.join('\n').trim();
    if (text.isEmpty) {
      throw const AiException(AiFailure(AiFailureCode.emptyResponse));
    }
    return text;
  }

  Map<String, dynamic>? _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
