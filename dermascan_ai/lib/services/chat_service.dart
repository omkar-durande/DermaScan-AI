import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fully FREE AI chat service using Pollinations.ai
///
/// ✅ NO API key required
/// ✅ NO registration needed
/// ✅ NO credit card
/// ✅ Unlimited usage
/// 📖 Docs: https://text.pollinations.ai
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  // Pollinations.ai free text endpoint — no auth required
  static const String _baseUrl = 'https://text.pollinations.ai/';

  // Model options (all free):
  // 'openai'       → GPT-4o mini  (fast, smart)
  // 'openai-large' → GPT-4o       (smarter, slower)
  // 'mistral'      → Mistral 7B   (very fast)
  // 'llama'        → Llama 3.3    (open-source)
  static const String _model = 'openai'; // GPT-4o mini — best balance

  static const String _systemPrompt =
      'You are DermaScan AI Assistant — a helpful dermatology companion. '
      'Answer questions about skin conditions, scan results, symptoms, skincare, and sun protection. '
      'Keep responses concise (2-3 short paragraphs). Use simple, friendly language and relevant emojis. '
      'IMPORTANT: Always remind users to consult a real dermatologist for diagnosis. '
      'Never diagnose specific conditions from descriptions alone. '
      'You are informational only — not a medical replacement.';

  /// Send a message with conversation history and receive a response.
  /// [history] — list of past messages: [{'role':'user','content':'...'}, {'role':'assistant','content':'...'}]
  /// [message] — the new user message
  Future<String> sendMessage(
      List<Map<String, String>> history, String message) async {
    try {
      // Build messages array: system prompt + history + new message
      final messages = <Map<String, String>>[
        {'role': 'system', 'content': _systemPrompt},
        ...history,
        {'role': 'user', 'content': message},
      ];

      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': messages,
              'model': _model,
              'seed': 42,
              'private': true, // don't log to public feed
            }),
          )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) {
          return '🤔 I received an empty response. Please try again.';
        }
        return body;
      } else if (response.statusCode == 429) {
        return '⏳ The AI is busy right now. Please wait a moment and try again.';
      } else if (response.statusCode >= 500) {
        return '🔧 The AI service is temporarily unavailable. Please try again in a few seconds.';
      } else {
        return '❌ Unexpected error (${response.statusCode}). Please try again.';
      }
    } catch (e) {
      final err = e.toString();
      if (err.contains('SocketException') ||
          err.contains('NetworkException') ||
          err.contains('Failed host lookup')) {
        return '🔌 No internet connection. Please check your network and try again.';
      }
      if (err.contains('TimeoutException')) {
        return '⏱️ Request timed out. The AI might be busy — please try again.';
      }
      return '❌ Something went wrong. Please try again.';
    }
  }
}
