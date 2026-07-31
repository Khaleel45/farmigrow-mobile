import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:farmigrow_ai/theme/app_theme.dart';

class AgriAIScreen extends StatefulWidget {
  const AgriAIScreen({super.key});
  @override
  State<AgriAIScreen> createState() => _AgriAIScreenState();
}

class _AgriAIScreenState extends State<AgriAIScreen> {
  final _controller = TextEditingController();
  final List<Map<String, String>> _messages = [
    {
      'role': 'ai',
      'text': 'నమస్కారం! Hello Farmer 👋\n\nI am your FarmiGrow AI Crop Advisor. Ask me anything about your crops, soil, irrigation, or pest control.\n\nనేను మీ పంటల గురించి సహాయం చేస్తాను!'
    },
  ];
  bool _loading = false;

  final List<String> _quickQuestions = [
    'Water stress remedy for rice?',
    'Best pesticide for Jassids?',
    'NDVI is 0.48 - what does it mean?',
    'When to harvest cotton?',
  ];

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _loading = true;
    });
    _controller.clear();

    await Future.delayed(const Duration(seconds: 2));

    // Mock AI responses
    String response;
    if (text.toLowerCase().contains('water') || text.toLowerCase().contains('irrigation')) {
      response = '💧 Water Stress Advisory:\n\n'
          'For rice during water stress:\n'
          '• Irrigate immediately with 30-40mm water\n'
          '• Apply within 48 hours for kernel formation\n'
          '• Water early morning (5-7 AM) to reduce evaporation\n'
          '• Check if NDWI reading is below 0.2\n\n'
          'తెలుగు: వరికి నీటి తడి వెంటనే ఇవ్వండి, 48 గంటల్లో.';
    } else if (text.toLowerCase().contains('ndvi')) {
      response = '🌱 NDVI Reading Interpretation:\n\n'
          'NDVI of 0.48 indicates MODERATE STRESS\n\n'
          '• > 0.7 = Healthy (Excellent)\n'
          '• 0.5-0.7 = Moderate (Good)\n'
          '• 0.3-0.5 = Stress (Action Needed) ← You are here\n'
          '• < 0.3 = Severe Stress (Critical)\n\n'
          '📋 Action: Check soil moisture and water status immediately.';
    } else if (text.toLowerCase().contains('pest') || text.toLowerCase().contains('jassid')) {
      response = '🐛 Pest Control Advisory:\n\n'
          'For Jassid (Green Leafhopper) on Cotton:\n'
          '• Apply Imidacloprid 17.8% SL @ 0.3ml/L water\n'
          '• OR Thiamethoxam 25% WG @ 0.2g/L water\n'
          '• Spray in evening to avoid beneficial insects\n'
          '• Repeat after 10 days if infestation persists\n\n'
          'Cost estimate: ₹300-450 per acre\n\n'
          'తెలుగు: పచ్చదోమకు ఇమిడాక్లోప్రిడ్ పిచికారీ చేయండి.';
    } else {
      response = '🤖 FarmiGrow AI Response:\n\n'
          'Based on your current satellite analysis and weather data for Telangana region:\n\n'
          '• Soil moisture: Below optimal (35%)\n'
          '• Temperature: 35.4°C (High stress risk)\n'
          '• Recommended action: Monitor closely and irrigate if needed\n\n'
          'For specific crop advice, ask about your crop type and current issue.\n\n'
          'మీ పంట రకం మరియు సమస్య చెప్పండి.';
    }

    setState(() {
      _messages.add({'role': 'ai', 'text': response});
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy,
                  color: AppTheme.primaryGreen, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Agri AI Advisor',
                    style: GoogleFonts.poppins(
                        color: AppTheme.textWhite,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                Text('Online · Telugu & English',
                    style: GoogleFonts.poppins(
                        color: AppTheme.primaryGreen, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length) {
                  return _buildTypingIndicator();
                }
                final msg = _messages[i];
                return _buildMessage(msg['role']!, msg['text']!);
              },
            ),
          ),

          // Quick questions
          if (_messages.length <= 2)
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quickQuestions.length,
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => _sendMessage(_quickQuestions[i]),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Text(_quickQuestions[i],
                        style: GoogleFonts.poppins(
                            color: AppTheme.textGrey, fontSize: 11)),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Input
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            color: AppTheme.bgDark,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: GoogleFonts.poppins(
                        color: AppTheme.textWhite, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Ask about your crops...',
                      hintStyle: GoogleFonts.poppins(
                          color: AppTheme.textGrey, fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.bgCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppTheme.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppTheme.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppTheme.primaryGreen),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _sendMessage(_controller.text),
                  child: Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send,
                        color: Colors.black, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(String role, String text) {
    final isAI = role == 'ai';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isAI ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isAI) ...[
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy,
                  color: AppTheme.primaryGreen, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isAI ? AppTheme.bgCard : AppTheme.primaryGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isAI ? AppTheme.borderColor : AppTheme.primaryGreen.withOpacity(0.4),
                ),
              ),
              child: Text(text,
                  style: GoogleFonts.poppins(
                      color: AppTheme.textWhite,
                      fontSize: 13,
                      height: 1.5)),
            ),
          ),
          if (!isAI) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF30363D),
              child: Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy,
                color: AppTheme.primaryGreen, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 40, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primaryGreen),
                ),
                const SizedBox(width: 8),
                Text('AI is thinking...',
                    style: GoogleFonts.poppins(
                        color: AppTheme.textGrey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
