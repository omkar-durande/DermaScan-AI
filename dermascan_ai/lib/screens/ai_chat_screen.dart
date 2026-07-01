import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';
import '../services/chat_service.dart';

/// Chat message data model
class _ChatMsg {
  final String id;
  final String text;
  final bool isUser;
  final DateTime time;
  final bool isLoading;

  const _ChatMsg({
    required this.id,
    required this.text,
    required this.isUser,
    required this.time,
    this.isLoading = false,
  });
}

/// AI Dermatology Assistant — powered by Pollinations.ai (100% free, no API key)
class AiChatScreen extends StatefulWidget {
  /// Optional: pre-fill context from a scan result (e.g. disease name)
  final String? initialContext;
  const AiChatScreen({super.key, this.initialContext});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final List<_ChatMsg> _messages = [];
  final List<Map<String, String>> _history = [];

  bool _isSending = false;

  static const _suggestions = [
    '🔬 What is melanoma?',
    '☀️ How to protect from UV rays?',
    '🩹 Signs I need a dermatologist?',
    '💊 What is Actinic Keratosis?',
    '🧴 Daily skincare routine tips',
    '🏥 Is Basal Cell Carcinoma curable?',
  ];

  @override
  void initState() {
    super.initState();
    _addWelcome();
    // If launched from a results screen, auto-ask about the diagnosed disease
    if (widget.initialContext != null) {
      Future.delayed(const Duration(milliseconds: 700), () {
        _send('Tell me about ${widget.initialContext} — what is it, how serious is it, and what should I do next?');
      });
    }
  }

  void _addWelcome() {
    _messages.add(_ChatMsg(
      id: 'welcome',
      text:
          '👋 Hi! I\'m your *DermaScan AI Assistant*.\n\nAsk me anything about skin health — conditions, scan results, symptoms, or skincare tips.\n\n⚠️ *Informational only — always consult a licensed dermatologist for medical advice.*',
      isUser: false,
      time: DateTime.now(),
    ));
  }

  Future<void> _send(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _isSending) return;
    _input.clear();

    setState(() {
      _messages.add(_ChatMsg(id: _uid(), text: msg, isUser: true, time: DateTime.now()));
      _isSending = true;
      _messages.add(_ChatMsg(id: 'loading', text: '', isUser: false, time: DateTime.now(), isLoading: true));
    });
    _scrollDown();

    final reply = await _chatService.sendMessage(_history, msg);

    // Keep history (max 16 turns = 8 exchanges)
    _history.add({'role': 'user', 'content': msg});
    _history.add({'role': 'assistant', 'content': reply});
    if (_history.length > 16) _history.removeRange(0, 2);

    setState(() {
      _messages.removeWhere((m) => m.id == 'loading');
      _isSending = false;
      _messages.add(_ChatMsg(id: _uid(), text: reply, isUser: false, time: DateTime.now()));
    });
    _scrollDown();
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 160), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _uid() => DateTime.now().microsecondsSinceEpoch.toString();

  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Chat', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('This removes all messages and resets the conversation.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _messages.clear();
                _history.clear();
              });
              _addWelcome();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      resizeToAvoidBottomInset: true,
      appBar: _appBar(),
      body: Column(
        children: [
          _freeBadge(),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _bubble(_messages[i]),
            ),
          ),
          // Suggestions row — only before first user message
          if (_messages.length <= 1 && !_isSending) _suggestionsRow(),
          _inputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar() => AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('DermaScan Assistant',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                  Text('Skin health AI • Free',
                      style: TextStyle(color: Colors.white60, fontSize: 10.5),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_messages.length > 1)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
              tooltip: 'Clear chat',
              onPressed: _clearChat,
            ),
        ],
      );

  Widget _freeBadge() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        color: const Color(0xFF0A9396).withValues(alpha: 0.12),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_open_rounded, size: 12, color: AppColors.accent),
            SizedBox(width: 5),
            Flexible(
              child: Text(
                'Powered by Pollinations.ai · No API key · Completely Free',
                style: TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );

  Widget _suggestionsRow() => Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: _suggestions
                .map((s) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _send(s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
                          ),
                          child: Text(s,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      );

  Widget _bubble(_ChatMsg msg) {
    if (msg.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, right: 70),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: _bubbleDecoration(false),
          child: _TypingDots(),
        ),
      );
    }

    final isUser = msg.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: msg.text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Copied to clipboard'),
                duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating),
          );
        },
        child: Container(
          margin: EdgeInsets.only(
            bottom: 10,
            left: isUser ? 70 : 0,
            right: isUser ? 0 : 70,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: isUser
              ? BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))],
                )
              : _bubbleDecoration(false),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 11),
                    ),
                    const SizedBox(width: 6),
                    const Text('AI Assistant',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Text(
                msg.text,
                style: TextStyle(
                  fontSize: 14,
                  color: isUser ? Colors.white : AppColors.textPrimary,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _fmtTime(msg.time),
                style: TextStyle(
                  fontSize: 10,
                  color: isUser
                      ? Colors.white.withValues(alpha: 0.65)
                      : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _bubbleDecoration(bool isUser) => BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      );

  Widget _inputBar() => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -3))
            ],
          ),
          padding: const EdgeInsets.only(
              left: 14, right: 10, top: 10, bottom: 12),
          child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _input,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Ask about skin health...',
                    hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    border: InputBorder.none,
                  ),
                  onSubmitted: _send,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _isSending
                ? Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(23)),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: AppColors.primary),
                    ),
                  )
                : GestureDetector(
                    onTap: () => _send(_input.text),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(23),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
          ],
        ),
      ),
    );

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ─── Animated typing indicator ────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(
        3,
        (i) => AnimationController(
            vsync: this, duration: const Duration(milliseconds: 480)));
    _anims = _ctrls
        .map((c) => Tween<double>(begin: 0, end: -7).animate(
            CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) _ctrls[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => AnimatedBuilder(
          animation: _anims[i],
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _anims[i].value),
            child: Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: const BoxDecoration(
                  color: AppColors.accent, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}
