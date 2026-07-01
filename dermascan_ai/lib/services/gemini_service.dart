import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for Google Gemini AI chat (free tier — 1500 req/day)
/// Get your free key at: https://aistudio.google.com/app/apikey
class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  // ─── Replace with your free key from https://aistudio.google.com ───
  static const String _apiKey = 'YOUR_GEMINI_API_KEY_HERE';
  static const String _model = 'gemini-1.5-flash'; // free, fast model
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static const String _systemPrompt = '''
You are DermaScan AI Assistant — a helpful, knowledgeable dermatology companion.
Your role is to:
- Answer questions about skin conditions, symptoms, and care
- Explain scan results in simple language
- Provide general skincare advice and sun protection tips
- Explain medical terms in a friendly, easy-to-understand way
- Remind users to consult a dermatologist for professional diagnosis

IMPORTANT RULES:
- Never diagnose a specific condition for a user based on description alone
- Always emphasize that your responses are informational only
- Recommend consulting a doctor for any concerning symptoms
- Keep responses concise (2-4 short paragraphs max)
- Be warm, supportive, and empathetic
- You may use appropriate emojis to make responses friendly
''';

  /// Send a message and get a response from Gemini
  Future<String> chat(List<Map<String, String>> history, String message) async {
    if (_apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      return '⚠️ Gemini API key not configured yet.\n\nTo enable AI chat:\n1. Visit https://aistudio.google.com/app/apikey\n2. Create a free API key\n3. Replace YOUR_GEMINI_API_KEY_HERE in gemini_service.dart\n\nThe free tier gives you 1,500 requests/day!';
    }

    try {
      // Build conversation history in Gemini format
      final contents = <Map<String, dynamic>>[];

      // Add system context as first user message if history is empty
      if (history.isEmpty) {
        contents.add({
          'role': 'user',
          'parts': [{'text': _systemPrompt}],
        });
        contents.add({
          'role': 'model',
          'parts': [{'text': 'Understood! I\'m ready to help with your skin health questions. 🌿'}],
        });
      }

      // Add conversation history
      for (final msg in history) {
        contents.add({
          'role': msg['role'] == 'user' ? 'user' : 'model',
          'parts': [{'text': msg['content']}],
        });
      }

      // Add current message
      contents.add({
        'role': 'user',
        'parts': [{'text': message}],
      });

      final response = await http
          .post(
            Uri.parse('$_baseUrl?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': contents,
              'generationConfig': {
                'temperature': 0.7,
                'maxOutputTokens': 600,
                'topP': 0.9,
              },
              'safetySettings': [
                {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
                {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
                {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
                {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates.first['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return parts.first['text'] as String? ?? 'No response generated.';
          }
        }
        return 'Sorry, I could not generate a response. Please try again.';
      } else if (response.statusCode == 429) {
        return '⚠️ Rate limit reached. You\'ve used the free tier limit for now. Please try again in a minute.';
      } else if (response.statusCode == 400) {
        return '❌ Invalid request. Please try rephrasing your question.';
      } else {
        return '❌ Error ${response.statusCode}: Could not reach the AI service. Please check your internet connection.';
      }
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        return '🔌 No internet connection. Please check your network and try again.';
      }
      return '❌ Something went wrong. Please try again.\n\nError: $e';
    }
  }
}
