/// User-safe failure categories for every Gemini call.
///
/// The raw response body is deliberately not stored here: it may contain the
/// prompt, account metadata, or provider diagnostics. Only a stable category
/// and HTTP status are retained for routing and tests.
enum AiFailureCode {
  missingKey,
  consentRequired,
  invalidKey,
  quota,
  modelUnavailable,
  safety,
  network,
  timeout,
  unavailable,
  emptyResponse,
  cancelled,
  badRequest,
  unknown,
}

class AiFailure {
  const AiFailure(this.code, {this.statusCode});

  final AiFailureCode code;
  final int? statusCode;

  /// Whether another model can be tried without user involvement.
  bool get canFallback => switch (code) {
    AiFailureCode.quota ||
    AiFailureCode.modelUnavailable ||
    AiFailureCode.network ||
    AiFailureCode.timeout ||
    AiFailureCode.unavailable ||
    AiFailureCode.emptyResponse ||
    AiFailureCode.badRequest ||
    AiFailureCode.unknown => true,
    AiFailureCode.missingKey ||
    AiFailureCode.consentRequired ||
    AiFailureCode.invalidKey ||
    AiFailureCode.safety ||
    AiFailureCode.cancelled => false,
  };

  /// Whether the request reached Google and should count against the daily
  /// allowance. Network failures and local cancellations do not consume quota.
  bool get countsAgainstQuota => switch (code) {
    AiFailureCode.network ||
    AiFailureCode.timeout ||
    AiFailureCode.cancelled ||
    AiFailureCode.consentRequired => false,
    _ => true,
  };

  bool get retryable => switch (code) {
    AiFailureCode.network ||
    AiFailureCode.timeout ||
    AiFailureCode.unavailable ||
    AiFailureCode.emptyResponse ||
    AiFailureCode.unknown => true,
    _ => false,
  };

  bool get needsKey =>
      code == AiFailureCode.missingKey || code == AiFailureCode.invalidKey;

  bool get needsConsent => code == AiFailureCode.consentRequired;

  String get userMessage => switch (code) {
    AiFailureCode.missingKey =>
      'Add your Gemini key in Profile → Preferences to start.',
    AiFailureCode.consentRequired =>
      'Review and accept the AI privacy note in Profile → Preferences.',
    AiFailureCode.invalidKey =>
      'That Gemini key was rejected. Update it in Profile → Preferences.',
    AiFailureCode.quota =>
      'Gemini’s free limit is used up for now. Try again later.',
    AiFailureCode.modelUnavailable =>
      'Gemini’s models are unavailable right now. Try again in a moment.',
    AiFailureCode.safety =>
      'I can’t help with that request. Try asking about your FitGo logs or plan.',
    AiFailureCode.network =>
      'Couldn’t reach Google. Your logs are safe on this device.',
    AiFailureCode.timeout => 'Gemini took too long to answer. Try again.',
    AiFailureCode.unavailable =>
      'The AI coach is unavailable right now. Try again.',
    AiFailureCode.emptyResponse =>
      'Gemini returned an empty answer. Try again.',
    AiFailureCode.cancelled => 'Stopped.',
    AiFailureCode.badRequest =>
      'The AI coach couldn’t process that request. Try again.',
    AiFailureCode.unknown => 'The AI coach hit a problem. Try again.',
  };

  @override
  String toString() => 'AiFailure(${code.name}, status: $statusCode)';
}

class AiException implements Exception {
  const AiException(this.failure);

  final AiFailure failure;

  @override
  String toString() => failure.toString();
}
