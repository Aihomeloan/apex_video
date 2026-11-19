import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Consumable credit packs. These exact IDs must exist in App Store
/// Connect (and Play Console, if you ship Android) as Consumable
/// in-app purchases before this will find anything.
class PurchaseService {
  static const credits12 = 'com.goldenapexapps.apexvideo.credits12';
  static const credits36 = 'com.goldenapexapps.apexvideo.credits36';
  static const credits72 = 'com.goldenapexapps.apexvideo.credits72';

  static const productIds = <String>{credits12, credits36, credits72};

  static const Map<String, int> creditsByProduct = {
    credits12: 12,
    credits36: 36,
    credits72: 72,
  };

  /// Purchase IDs we've already paid out, so a replayed transaction
  /// never grants the same credits twice.
  static const _grantedKey = 'apexvideo_granted_purchase_ids';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// The product currently being bought, or null. The UI uses this to
  /// show a spinner and block double-taps.
  final ValueNotifier<String?> buying = ValueNotifier<String?>(null);

  Future<bool> isAvailable() => _iap.isAvailable();

  /// Returns the packs sorted cheapest first.
  Future<List<ProductDetails>> queryProducts() async {
    final response = await _iap.queryProductDetails(productIds);
    if (response.error != null) {
      throw Exception('Store query failed: ${response.error!.message}');
    }
    final products = [...response.productDetails];
    products.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
    return products;
  }

  /// Call once, early (e.g. app startup). [onCreditsGranted] fires once
  /// per completed purchase; [onError] fires on failure.
  void listenForPurchases({
    required void Function(int credits) onCreditsGranted,
    required void Function(String message) onError,
  }) {
    _subscription?.cancel();
    _subscription = _iap.purchaseStream.listen((purchases) async {
      for (final purchase in purchases) {
        if (purchase.status == PurchaseStatus.pending) continue;

        if (purchase.status == PurchaseStatus.error) {
          onError(purchase.error?.message ?? 'Purchase failed.');
        } else if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          final credits = creditsByProduct[purchase.productID] ?? 0;
          if (credits > 0 && await _markGrantedIfNew(purchase)) {
            onCreditsGranted(credits);
          }
        }
        // PurchaseStatus.canceled: the user backed out — nothing to do.

        // Required on iOS — an uncompleted transaction stays pending
        // forever and the user can be charged without ever "finishing."
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }

        if (buying.value == purchase.productID) buying.value = null;
      }
    }, onError: (e) {
      buying.value = null;
      onError(e.toString());
    });
  }

  /// Records this purchase as paid out. Returns false if it already was.
  Future<bool> _markGrantedIfNew(PurchaseDetails p) async {
    final id = p.purchaseID ??
        (p.transactionDate != null
            ? '${p.productID}_${p.transactionDate}'
            : null);
    // No stable ID to check against — grant rather than risk shorting
    // someone who paid.
    if (id == null) return true;

    final prefs = await SharedPreferences.getInstance();
    final granted = prefs.getStringList(_grantedKey) ?? <String>[];
    if (granted.contains(id)) return false;
    granted.add(id);
    if (granted.length > 500) {
      granted.removeRange(0, granted.length - 500);
    }
    await prefs.setStringList(_grantedKey, granted);
    return true;
  }

  Future<void> buy(ProductDetails product) async {
    if (buying.value != null) return;
    buying.value = product.id;
    try {
      final started = await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) buying.value = null;
    } catch (e) {
      buying.value = null;
      rethrow;
    }
  }

  void dispose() {
    _subscription?.cancel();
    buying.dispose();
  }
}
