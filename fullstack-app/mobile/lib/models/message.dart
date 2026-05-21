class Message {
  final String role;
  final String content;
  final DateTime timestamp;

  const Message({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  bool get isUser => role == 'user';

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };

  Message copyWith({String? content}) => Message(
        role: role,
        content: content ?? this.content,
        timestamp: timestamp,
      );
}
