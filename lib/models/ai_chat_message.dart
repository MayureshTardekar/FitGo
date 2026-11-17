/// One locally stored turn in the optional AI coach conversation.
///
/// Messages are kept in the active account's Hive settings box, never in the
/// cloud backup. The model receives only the recent turns plus a deterministic
/// summary of the user's FitGo logs.
enum AiChatRole { user, model }

class AiChatMessage {
  const AiChatMessage({
    required this.role,
    required this.text,
    required this.createdAt,
  });

  final AiChatRole role;
  final String text;
  final DateTime createdAt;

  bool get isUser => role == AiChatRole.user;

  Map<String, dynamic> toJson() => {
    'role': role.name,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  static AiChatMessage? fromJson(Object? value) {
    if (value is! Map) return null;
    final roleValue = value['role'];
    final textValue = value['text'];
    if (roleValue is! String || textValue is! String) return null;
    final text = textValue.trim();
    if (text.isEmpty) return null;

    final role = roleValue == AiChatRole.user.name
        ? AiChatRole.user
        : roleValue == AiChatRole.model.name
        ? AiChatRole.model
        : null;
    if (role == null) return null;

    return AiChatMessage(
      role: role,
      text: text,
      createdAt:
          DateTime.tryParse('${value['createdAt'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
