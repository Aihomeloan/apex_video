import 'package:flutter/material.dart';

/// What can't be created in ApexVideo — our own rules plus what our AI
/// providers' safety filters block. Shown from the consent screen, the
/// home screen, the ⋯ menu, and Privacy & Terms.
const List<(String, String)> kContentRules = [
  ('Real people without permission',
      'No celebrities, public figures, or photos of anyone who hasn\'t agreed.'),
  ('Copyrighted characters & brands',
      'No movie, TV, or game characters, logos, or trademarks.'),
  ('Sexual or nude content',
      'Nothing sexual, and nothing suggestive involving anyone under 18.'),
  ('Graphic violence or gore', 'No gore, injury close-ups, or self-harm.'),
  ('Hate or harassment', 'Nothing that attacks or demeans people or groups.'),
  ('Illegal activity', 'No weapons, drugs, scams, or other illegal acts.'),
  ('Deception', 'No fake news, impersonation, or political deepfakes.'),
];

Future<void> showContentRules(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF111111),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.amber),
                  SizedBox(width: 8),
                  Text(
                    'What you can\'t create',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final (title, body) in kContentRules)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.block,
                                  size: 16, color: Colors.redAccent),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white,
                                      height: 1.35),
                                  children: [
                                    TextSpan(
                                      text: '$title\n',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    TextSpan(
                                      text: body,
                                      style:
                                          const TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    const Text(
                      'Our AI providers also run their own safety filters, '
                      'which can block or soften content and may change over '
                      'time. If something is blocked, your credits are '
                      'refunded automatically.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
