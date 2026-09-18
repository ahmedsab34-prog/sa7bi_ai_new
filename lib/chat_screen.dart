import 'package:flutter/material.dart';
import 'ai_service.dart';

class ChatScreen extends StatefulWidget {
  final String? serviceTitle;
  final String? serviceContext;

  const ChatScreen({
    super.key,
    this.serviceTitle,
    this.serviceContext,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [];

  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _isLoading) {
      return;
    }

    _controller.clear();

    setState(() {
      _messages.add({
        'role': 'user',
        'content': text,
      });

      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final history = _messages
          .take(_messages.length - 1)
          .map(
            (message) => {
              'role': message['role']!,
              'content': message['content']!,
            },
          )
          .toList();

      final reply = await AiService.getResponse(
        text,
        serviceContext: widget.serviceContext,
        history: history,
      );

      if (!mounted) return;

      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': reply,
        });

        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add({
          'role': 'assistant',
          'content':
              'حدث خطأ أثناء الاتصال بالمساعد.\n\n'
              'تفاصيل الخطأ: $e',
        });

        _isLoading = false;
      });

      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.serviceTitle ?? 'صَحبي AI';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF11111A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? _buildWelcome()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        12,
                        16,
                        12,
                        16,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];

                        final isUser =
                            message['role'] == 'user';

                        return _buildMessage(
                          message['content'] ?? '',
                          isUser,
                        );
                      },
                    ),
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 8,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'صَحبي بيكتب...',
                        style: TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome() {
    final title = widget.serviceTitle ?? 'صَحبي AI';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFD700),
                    Color(0xFFFF8C00),
                    Color(0xFF8A2BE2),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.25),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'س',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'أنا صَحبي AI 👋\n'
              'اكتب رسالتك وأنا هساعدك.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(
    String text,
    bool isUser,
  ) {
    return Align(
      alignment:
          isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 340,
        ),
        margin: const EdgeInsets.only(
          bottom: 12,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [
                    Color(0xFF6A1B9A),
                    Color(0xFF4527A0),
                  ],
                )
              : const LinearGradient(
                  colors: [
                    Color(0xFF242432),
                    Color(0xFF171721),
                  ],
                ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(
              isUser ? 18 : 4,
            ),
            bottomRight: Radius.circular(
              isUser ? 4 : 18,
            ),
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        child: Text(
          text,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        10,
        8,
        10,
        10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF11111A),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 5,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'اكتب رسالتك...',
                hintTextDirection: TextDirection.rtl,
                hintStyle: const TextStyle(
                  color: Colors.white38,
                ),
                filled: true,
                fillColor: const Color(0xFF1C1C27),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) {
                _sendMessage();
              },
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFFD700),
                  Color(0xFFFF8C00),
                ],
              ),
            ),
            child: IconButton(
              onPressed:
                  _isLoading ? null : _sendMessage,
              icon: const Icon(
                Icons.send_rounded,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
