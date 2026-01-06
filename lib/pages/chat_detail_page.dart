import 'package:flutter/material.dart';

class ChatDetailPage extends StatelessWidget {
  final String chatId;
  final Map<String, dynamic> otherUser;
  const ChatDetailPage({Key? key, required this.chatId, required this.otherUser}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(otherUser['name'] ?? 'Chat'),
      ),
      body: Center(
        child: Text('Chat with @${otherUser['username'] ?? ''}'),
      ),
    );
  }
}
