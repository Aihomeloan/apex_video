import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../state/project_state.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  List<ProductDetails> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<ProjectState>();
    try {
      final available = await state.purchaseService.isAvailable();
      if (!available) {
        setState(() {
          _error = 'The store isn\'t available right now.';
          _loading = false;
        });
        return;
      }
      final products = await state.purchaseService.queryProducts();
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openLegal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Buy credits')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current balance: ${state.credits} credit${state.credits == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              '1 credit = 1 generated clip (up to 8 seconds). A 20-second '
              'video uses 3 credits, a 30-second video uses 4.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ..._products.map((product) => Card(
                  child: ListTile(
                    title: Text(product.title),
                    subtitle: Text(product.description),
                    trailing: FilledButton(
                      onPressed: () => state.purchaseService.buy(product),
                      child: Text(product.price),
                    ),
                  ),
                )),
            const SizedBox(height: 24),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: () => _openLegal(
                        'https://goldenapexapps.com/terms-of-service.html#apexvideo'),
                    child: const Text('Terms of Service',
                        style: TextStyle(fontSize: 12)),
                  ),
                  const Text('·', style: TextStyle(color: Colors.grey)),
                  TextButton(
                    onPressed: () => _openLegal(
                        'https://goldenapexapps.com/privacy-policy.html#apexvideo'),
                    child: const Text('Privacy Policy',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
