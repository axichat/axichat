part of 'accessibility_action_bloc.dart';

class AccessibilityActionState extends Equatable {
  static const Object _unset = Object();

  const AccessibilityActionState({
    required this.visible,
    required this.stack,
    required this.sections,
    required this.composerText,
    required this.newContactInput,
    required this.busy,
    required this.statusMessage,
    required this.errorMessage,
    required this.recipients,
    required this.messages,
    required this.activeChatJid,
  });

  const AccessibilityActionState.initial()
      : visible = false,
        stack = const [
          AccessibilityStepEntry(kind: AccessibilityStepKind.root),
        ],
        sections = const [],
        composerText = '',
        newContactInput = '',
        busy = false,
        statusMessage = null,
        errorMessage = null,
        recipients = const [],
        messages = const [],
        activeChatJid = null;

  final bool visible;
  final List<AccessibilityStepEntry> stack;
  final List<AccessibilityMenuSection> sections;
  final String composerText;
  final String newContactInput;
  final bool busy;
  final String? statusMessage;
  final String? errorMessage;
  final List<AccessibilityContact> recipients;
  final List<Message> messages;
  final String? activeChatJid;

  AccessibilityStepEntry get currentEntry => stack.last;

  AccessibilityActionState copyWith({
    bool? visible,
    List<AccessibilityStepEntry>? stack,
    List<AccessibilityMenuSection>? sections,
    String? composerText,
    String? newContactInput,
    bool? busy,
    Object? statusMessage = _unset,
    Object? errorMessage = _unset,
    List<AccessibilityContact>? recipients,
    List<Message>? messages,
    Object? activeChatJid = _unset,
  }) =>
      AccessibilityActionState(
        visible: visible ?? this.visible,
        stack: stack ?? this.stack,
        sections: sections ?? this.sections,
        composerText: composerText ?? this.composerText,
        newContactInput: newContactInput ?? this.newContactInput,
        busy: busy ?? this.busy,
        statusMessage: statusMessage == _unset
            ? this.statusMessage
            : statusMessage as String?,
        errorMessage: errorMessage == _unset
            ? this.errorMessage
            : errorMessage as String?,
        recipients: recipients ?? this.recipients,
        messages: messages ?? this.messages,
        activeChatJid: activeChatJid == _unset
            ? this.activeChatJid
            : activeChatJid as String?,
      );

  @override
  List<Object?> get props => [
        visible,
        stack,
        sections,
        composerText,
        newContactInput,
        busy,
        statusMessage,
        errorMessage,
        recipients,
        messages,
        activeChatJid,
      ];
}
