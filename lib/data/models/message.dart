class ChatMessage {
  final String id;
  final String senderId;
  final String? groupId;
  final String? recipientId;
  final String content;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    this.groupId,
    this.recipientId,
    required this.content,
    required this.createdAt,
  });

  bool get isGroupMessage => groupId != null;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        senderId: json['sender_id'] as String,
        groupId: json['group_id'] as String?,
        recipientId: json['recipient_id'] as String?,
        content: (json['content'] as String?) ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toInsertJson() => {
        'sender_id': senderId,
        'group_id': groupId,
        'recipient_id': recipientId,
        'content': content,
      };
}
