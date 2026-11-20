import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'content_rules.dart';

/// Built-in Privacy Policy + Terms for ApexVideo (works offline), with
/// links to the full pages on goldenapexapps.com. Keep in sync with the site.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  static const effectiveDate = 'November 20, 2026';
  static const privacyUrl =
      'https://goldenapexapps.com/privacy-policy.html#apexvideo';
  static const termsUrl =
      'https://goldenapexapps.com/terms-of-service.html#apexvideo';

  static const List<(String, String)> privacy = [
    ("Who we are",
        "ApexVideo is made by GoldenApexApps LLC, 9241 Old State Hwy Unit 91, "
        "Newcastle, CA 95658. Contact: info@goldenapexapps.com."),
    ("No accounts, no tracking",
        "ApexVideo has no sign-up or login. We do not collect your name, email, "
        "phone number, contacts, or location. We do not use advertising IDs, "
        "show ads, track you across apps or websites, or sell your data."),
    ("What goes to AI providers",
        "When you create, your content is sent through our secure server "
        "(hosted on Cloudflare) to:\n"
        "• Google (Gemini): your scene description and AI Assist text, to "
        "create the starting image and improve your prompt.\n"
        "• MiniMax: your scene description, dialogue lines, and starting image "
        "(including any photo you upload), to create the video with speech.\n"
        "These companies process it under their own terms and privacy "
        "policies, and may process it outside your country. Please don't "
        "include personal or sensitive information about yourself or others."),
    ("What our server keeps",
        "• A random device ID created by the app (not linked to your identity), "
        "kept in your device's keychain so your credits survive reinstalling.\n"
        "• Your credit balance and purchase transaction IDs from Apple.\n"
        "• Video job records: length, quality, status, times, and a temporary "
        "link to the finished video so it can be delivered to you. Deleted "
        "after 30 days.\n"
        "• Short-lived request records used to prevent abuse. Deleted within "
        "1 hour.\n"
        "Our server does not store your prompts, dialogue, or images."),
    ("Your videos",
        "Finished videos are saved only on your device. Deleted videos stay in "
        "Recently Deleted for 30 days, then are removed. Saving to Photos or "
        "sharing is always your choice."),
    ("Payments",
        "Purchases are handled by Apple. We never see your payment details; we "
        "only receive a transaction ID to confirm the purchase and add your "
        "credits."),
    ("Children",
        "ApexVideo is not directed to children under 13, and we do not "
        "knowingly collect information from them."),
    ("Your choices",
        "You can delete videos in the app at any time. To delete your device "
        "record and credit balance from our server, email "
        "info@goldenapexapps.com. Deleting it removes any unused credits."),
    ("Changes",
        "If this policy changes, we will update it here and on our website "
        "with a new effective date."),
  ];

  static const List<(String, String)> terms = [
    ("Agreement",
        "By using ApexVideo you agree to these terms. ApexVideo is provided by "
        "GoldenApexApps LLC."),
    ("Credits",
        "Credits are one-time purchases, not a subscription. They do not "
        "expire, have no cash value, and cannot be transferred. The credits a "
        "video needs are shown before you create it. If a video fails or is "
        "blocked by a safety filter, its credits are refunded automatically. "
        "Refunds for purchases are handled by Apple under Apple's policies."),
    ("Content rules",
        "You may not create, or try to create, any of the content listed "
        "under \"What you can't create\" below. Our AI providers also run "
        "their own safety filters, which may block or soften content."),
    ("Your content",
        "You are responsible for what you create and share. Only upload photos "
        "you own or have permission to use, and only show real people with "
        "their permission. As between you and us, you own the videos you "
        "create, to the extent the law allows. We claim no ownership of them."),
    ("AI output",
        "Videos are made by AI and may be inaccurate, unexpected, or similar "
        "to content made for others. Review every video before you use it, "
        "and label it as AI-generated where a platform or the law requires."),
    ("Availability",
        "We may change, pause, or stop features at any time, including when an "
        "AI provider is unavailable. We may suspend use that breaks these "
        "terms or abuses the service."),
    ("No warranty",
        "ApexVideo is provided \"as is\" without warranties of any kind. To the "
        "fullest extent the law allows, GoldenApexApps LLC is not liable for "
        "indirect or consequential damages, and our total liability is limited "
        "to the amount you paid us in the past 12 months."),
    ("Governing law",
        "These terms are governed by the laws of the State of California, USA."),
    ("Contact", "Questions: info@goldenapexapps.com"),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Privacy & Terms'),
          bottom: const TabBar(
            indicatorColor: Colors.amber,
            labelColor: Colors.amber,
            tabs: [Tab(text: 'Privacy'), Tab(text: 'Terms')],
          ),
        ),
        body: TabBarView(
          children: [
            _page(context, privacy, privacyUrl, 'Privacy Policy',
                showRules: false),
            _page(context, terms, termsUrl, 'Terms of Service',
                showRules: true),
          ],
        ),
      ),
    );
  }

  Widget _page(BuildContext context, List<(String, String)> sections,
      String url, String title,
      {required bool showRules}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('ApexVideo $title',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Effective $effectiveDate',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        for (final (h, b) in sections) ...[
          Text(h,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber)),
          const SizedBox(height: 4),
          Text(b, style: const TextStyle(fontSize: 13, height: 1.45)),
          const SizedBox(height: 16),
        ],
        if (showRules) ...[
          const Text("What you can't create",
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber)),
          const SizedBox(height: 6),
          for (final (t, b) in kContentRules)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('• $t: $b',
                  style: const TextStyle(fontSize: 13, height: 1.4)),
            ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text('View on goldenapexapps.com'),
          onPressed: () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
      ],
    );
  }
}
