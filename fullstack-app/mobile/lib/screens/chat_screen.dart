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
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;

    final userMsg = Message(
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _sending = true;
    });
    _inputController.clear();
    _scrollToBottom();

    // Placeholder for streaming assistant reply
    final assistantMsg = Message(
      role: 'assistant',
      content: '',
      timestamp: DateTime.now(),
    );
    setState(() => _messages.add(assistantMsg));

    try {
      final api = context.read<ApiService>();
      final stream = api.streamChat(
        agentSlug: widget.agent.slug,
        message: text,
        history: _messages
            .where((m) => m.content.isNotEmpty)
            .take(_messages.length - 1)
            .toList(),
      );

      final buffer = StringBuffer();
      await for (final chunk in stream) {
        buffer.write(chunk);
        setState(() {
          _messages[_messages.length - 1] =
              assistantMsg.copyWith(content: buffer.toString());
        });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        _messages[_messages.length - 1] = assistantMsg.copyWith(
          content: 'Error: ${e.toString()}',
        );
      });
    } finally {
      setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text('This will delete all messages in this chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _messages.clear());
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.background,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: widget.agent.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(widget.agent.icon, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.agent.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                widget.agent.domain,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.agent.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (_messages.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: _clearChat,
            tooltip: 'Clear chat',
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (_, i) => MessageBubble(
        message: _messages[i],
        agentColor: widget.agent.color,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: widget.agent.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(widget.agent.icon, style: const TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Chat with ${widget.agent.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              widget.agent.description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.5),
            ),
            const SizedBox(height: 24),
            _buildSuggestionChips(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChips() {
    final suggestions = _suggestionsFor(widget.agent.slug);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: suggestions
          .map(
            (s) => GestureDetector(
              onTap: () {
                _inputController.text = s;
                _sendMessage();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: widget.agent.color.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(20),
                  color: widget.agent.color.withOpacity(0.06),
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.agent.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              enabled: !_sending,
              onSubmitted: (_) => _sendMessage(),
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Ask ${widget.agent.name} anything…',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                      color: widget.agent.color.withOpacity(0.4), width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _sending ? Colors.grey.shade300 : widget.agent.color,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _sending ? null : _sendMessage,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _suggestionsFor(String slug) {
    const Map<String, List<String>> suggestions = {
      'cs-senior-engineer': [
        'Review my code architecture',
        'Best practices for this feature?',
        'How should I refactor this?',
      ],
      'cs-backend-engineer': [
        'Design a REST API for me',
        'How to optimize this query?',
        'Best auth strategy for my app?',
      ],
      'cs-frontend-engineer': [
        'Review my UI component',
        'How to improve performance?',
        'Best state management approach?',
      ],
      'startup-cto': [
        'Should we build or buy?',
        'How do I scale my team?',
        'What stack should we use?',
      ],
      'cs-ceo-advisor': [
        'Help me think through this strategy',
        'How do I prepare for fundraising?',
        'How should I structure my board?',
      ],
      'cs-product-manager': [
        'Help me write a PRD',
        'How should I prioritize the roadmap?',
        'What metrics should I track?',
      ],
      'cs-content-creator': [
        'Write a LinkedIn post about my product',
        'Create a content calendar',
        'Improve my landing page copy',
      ],
      'cs-research': [
        'Analyze my market',
        'Who are my top 3 competitors?',
        'What trends should I watch?',
      ],
    };

    return suggestions[slug] ??
        [
          'How can you help me?',
          'What should I focus on first?',
          'Give me your top recommendation',
        ];
  }
}
