import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'content_rules.dart';

/// One-time AI data disclosure + consent (App Store guideline 5.1.2).
/// Names every outside AI provider and what is sent to each, and asks for
/// agreement before anything can be created. Shown once, then remembered.
class ConsentGate extends StatefulWidget {
  final Widget child;
  const ConsentGate({super.key, required this.child});

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<ConsentGate> {
  static const _key = 'apexvideo_ai_consent_v1';
  static const _privacyUrl =
      'https://goldenapexapps.com/privacy-policy.html#apexvideo';

  bool? _consented;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _consented = prefs.getBool(_key) ?? false);
  }

  Future<void> _agree() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    await prefs.setString('${_key}_at', DateTime.now().toIso8601String());
    if (mounted) setState(() => _consented = true);
  }

  Future<void> _openPrivacy() async {
    final uri = Uri.parse(_privacyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _bullet(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.circle, size: 7, color: Colors.amber),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 14, color: Colors.white, height: 1.4),
                children: [
                  TextSpan(
                    text: '$title  ',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.amber),
                  ),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_consented == null) {
      return const Scaffold(backgroundColor: Color(0xFF0A0A0A));
    }
    if (_consented == true) return widget.child;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            const Icon(Icons.auto_awesome, color: Colors.amber, size: 40),
            const SizedBox(height: 16),
            const Text(
              'Before you create',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'ApexVideo uses outside AI services to make your videos. When '
              'you create something, this content is sent through '
              'GoldenApexApps\' secure server to these companies:',
              style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 20),
            _bullet(
              'Google (Gemini)',
              'your scene description and AI Assist text, to create the '
                  'starting image and improve your prompt.',
            ),
            _bullet(
              'MiniMax',
              'your scene description, dialogue lines, and starting image '
                  '(including any photo you upload), to create the video '
                  'with speech.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Please don\'t include personal or sensitive information about '
              'yourself or anyone else.\n\n'
              'GoldenApexApps never sells your data and does not use it for '
              'advertising. Our server does not keep your prompts, dialogue, '
              'or images. Your finished videos are saved only on your device.',
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 16,
              children: [
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => showContentRules(context),
                  child: const Text('What you can\'t create'),
                ),
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: _openPrivacy,
                  child: const Text('Privacy Policy'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _checked,
              onChanged: (v) => setState(() => _checked = v ?? false),
              activeColor: Colors.amber,
              checkColor: Colors.black,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'I understand and agree to send this content to Google and '
                'MiniMax to create my videos, and to follow the content rules.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _checked ? _agree : null,
              child: const Text('Agree & Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
