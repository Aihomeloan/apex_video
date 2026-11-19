import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/purchase_service.dart';
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

  late final ProjectState _state;
  int _lastCredits = 0;

  @override
  void initState() {
    super.initState();
    _state = context.read<ProjectState>();
    _lastCredits = _state.credits;
    _state.addListener(_onStateChanged);
    _load();
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    super.dispose();
  }

  /// Shows a confirmation when a purchase lands.
  void _onStateChanged() {
    if (!mounted) return;
    final now = _state.credits;
    if (now > _lastCredits) {
      final added = now - _lastCredits;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('+$added credits added. Balance: $now')),
      );
    }
    _lastCredits = now;
  }

  Future<void> _load() async {
    try {
      final available = await _state.purchaseService.isAvailable();
      if (!mounted) return;
      if (!available) {
        setState(() {
          _error = 'The App Store isn\'t available right now. '
              'Check your connection and try again.';
          _loading = false;
        });
        return;
      }
      final products = await _state.purchaseService.queryProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Couldn\'t load credit packs. $e';
        _loading = false;
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _load();
  }

  Future<void> _buy(ProductDetails product) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _state.purchaseService.buy(product);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Couldn\'t start the purchase: $e')),
      );
    }
  }

  Future<void> _openLegal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String? _tagFor(String id) {
    if (id == PurchaseService.credits36) return 'MOST POPULAR';
    if (id == PurchaseService.credits72) return 'BEST VALUE';
    return null;
  }

  String _videosLine(String id) {
    switch (id) {
      case PurchaseService.credits12:
        return '2 Standard or 1 HD 15-second video';
      case PurchaseService.credits36:
        return '6 Standard or 3 HD 15-second videos';
      case PurchaseService.credits72:
        return '12 Standard or 7 HD 15-second videos';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectState>();
    final purchaseError = (state.errorMessage != null &&
            state.errorMessage!.startsWith('Purchase error'))
        ? state.errorMessage
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Buy credits')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Current balance: ${state.credits} credit${state.credits == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'No subscription. Buy credits only when you need a video.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // What a video costs.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What a video costs',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Text('Standard (768P):  10 sec = 4 credits  ·  15 sec = 6 credits',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                SizedBox(height: 4),
                Text('HD (2K):  10 sec = 7 credits  ·  15 sec = 10 credits',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                SizedBox(height: 4),
                Text('If a video fails, your credits are refunded.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Center(
            child: Text(
              'Includes In-App Purchases',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),

          if (!_loading && _error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 8),
            Center(
              child: OutlinedButton(
                  onPressed: _retry, child: const Text('Try again')),
            ),
          ],

          if (!_loading && _error == null && _products.isEmpty) ...[
            const Text(
              'No credit packs found. Please try again in a moment.',
              style: TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 8),
            Center(
              child: OutlinedButton(
                  onPressed: _retry, child: const Text('Try again')),
            ),
          ],

          ValueListenableBuilder<String?>(
            valueListenable: state.purchaseService.buying,
            builder: (context, busyId, _) {
              return Column(
                children: _products.map((product) {
                  final tag = _tagFor(product.id);
                  final credits =
                      PurchaseService.creditsByProduct[product.id] ?? 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: tag != null
                          ? const BorderSide(color: Colors.amber, width: 1.5)
                          : BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (tag != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      tag,
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                Text(
                                  '$credits credits',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _videosLine(product.id),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 100,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed:
                                  busyId == null ? () => _buy(product) : null,
                              child: busyId == product.id
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : Text(product.price),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          if (purchaseError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(purchaseError,
                  style: const TextStyle(color: Colors.redAccent)),
            ),

          const SizedBox(height: 20),
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
    );
  }
}
