enum Sender { user, assistant }

class ChatMessage {
  final String text;
  final Sender sender;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.sender,
    DateTime? timestamp,
  }) : this.timestamp = timestamp ?? DateTime.now();
}
