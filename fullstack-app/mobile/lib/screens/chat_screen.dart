import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/agent.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final Agent agent;
  const ChatScreen({super.key, required this.agent});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Message> _messages = [];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    final userMsg = Message(role: 'user', content: text, timestamp: DateTime.now());
    setState(() { _messages.add(userMsg); _sending = true; });
    _ctrl.clear();
    _scrollBottom();
    final assistantMsg = Message(role: 'assistant', content: '', timestamp: DateTime.now());
    setState(() => _messages.add(assistantMsg));
    try {
      final stream = context.read<ApiService>().streamChat(
        agentSlug: widget.agent.slug,
        message: text,
        history: _messages.where((m) => m.content.isNotEmpty).take(_messages.length - 1).toList(),
      );
      final buf = StringBuffer();
      await for (final chunk in stream) {
        buf.write(chunk);
        setState(() { _messages[_messages.length - 1] = assistantMsg.copyWith(content: buf.toString()); });
        _scrollBottom();
      }
    } catch (e) {
      setState(() { _messages[_messages.length - 1] = assistantMsg.copyWith(content: 'Error: $e'); });
    } finally {
      setState(() => _sending = false);
    }
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        elevation: 0, titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => Navigator.pop(context)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: widget.agent.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(widget.agent.icon, style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.agent.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text(widget.agent.domain, style: TextStyle(fontSize: 12, color: widget.agent.color, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 72, height: 72,
                          decoration: BoxDecoration(color: widget.agent.color.withOpacity(0.1), shape: BoxShape.circle),
                          child: Center(child: Text(widget.agent.icon, style: const TextStyle(fontSize: 36)))),
                        const SizedBox(height: 16),
                        Text('Chat with ${widget.agent.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(widget.agent.description, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.5)),
                      ],
                    ),
                  ))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => MessageBubble(message: _messages[i], agentColor: widget.agent.color),
                  ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    enabled: !_sending,
                    onSubmitted: (_) => _send(),
                    maxLines: 4, minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Ask ${widget.agent.name} anything…',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      filled: true, fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: widget.agent.color.withOpacity(0.4), width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sending ? null : _send,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _sending ? Colors.grey.shade300 : widget.agent.color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_sending ? Icons.hourglass_empty : Icons.send_rounded, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
