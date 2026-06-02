import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'api_client.dart';

/// Product IDs that match App Store Connect + Google Play Console.
/// These MUST match the backend coin pack IDs exactly.
const Set<String> kProductIds = {
  'pack_299',
  'pack_599',
  'pack_999',
  'pack_2999',
  'pack_5999',
  'pack_9999',
};

/// Result of a purchase verification.
class IapPurchaseResult {
  const IapPurchaseResult({
    required this.success,
    required this.coinsAwarded,
    this.error,
  });

  final bool success;
  final int coinsAwarded;
  final String? error;
}

/// Bulletproof IAP service.
///
/// Responsibilities:
/// 1. Connect to store, query available products
/// 2. Initiate purchases
/// 3. Listen for purchase updates (including pending/restored)
/// 4. Send receipts to backend for verification
/// 5. Complete/finish transactions ONLY after backend confirms
/// 6. Recover pending purchases on app restart
///
/// This is a singleton — lives for the app's lifetime.
class IapService {
  IapService._();
  static final IapService instance = IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Available products from the store.
  final ValueNotifier<List<ProductDetails>> products = ValueNotifier([]);

  /// Whether the store is available.
  bool _storeAvailable = false;
  bool get storeAvailable => _storeAvailable;

  /// Whether a purchase is currently in progress.
  final ValueNotifier<bool> purchasing = ValueNotifier(false);

  /// API client and token — set these before calling initialize().
  ZephyrApiClient? _apiClient;
  String? _accessToken;

  /// Callback invoked after a successful purchase (with coins awarded).
  void Function(int coinsAwarded)? onPurchaseSuccess;

  /// Callback invoked on purchase failure.
  void Function(String error)? onPurchaseError;

  /// Initialize the IAP service. Call once at app startup.
  Future<void> initialize({
    required ZephyrApiClient apiClient,
    required String accessToken,
  }) async {
    _apiClient = apiClient;
    _accessToken = accessToken;

    _storeAvailable = await _iap.isAvailable();
    if (!_storeAvailable) {
      debugPrint('[IAP] Store not available');
      return;
    }

    // Listen to purchase stream — this is CRITICAL.
    // The stream fires for:
    //  - New purchases
    //  - Pending purchases that complete later
    //  - Restored purchases
    //  - Failed purchases
    _subscription?.cancel();
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        debugPrint('[IAP] Purchase stream error: $error');
        purchasing.value = false;
      },
      onDone: () {
        debugPrint('[IAP] Purchase stream closed');
      },
    );

    // Query available products from store
    await _loadProducts();
  }

  /// Update credentials (e.g. after token refresh).
  void updateCredentials({
    required ZephyrApiClient apiClient,
    required String accessToken,
  }) {
    _apiClient = apiClient;
    _accessToken = accessToken;
  }

  /// Load products from the store.
  Future<void> _loadProducts() async {
    final ProductDetailsResponse response =
        await _iap.queryProductDetails(kProductIds);

    if (response.error != null) {
      debugPrint('[IAP] Error loading products: ${response.error}');
    }

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('[IAP] Products not found: ${response.notFoundIDs}');
    }

    // Sort by price ascending
    final sorted = List<ProductDetails>.from(response.productDetails)
      ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

    products.value = sorted;
    debugPrint('[IAP] Loaded ${sorted.length} products');
  }

  /// Initiate a purchase for the given product.
  Future<void> buyProduct(ProductDetails product) async {
    if (!_storeAvailable) {
      onPurchaseError?.call('Store not available');
      return;
    }

    if (purchasing.value) {
      debugPrint('[IAP] Purchase already in progress, ignoring');
      return;
    }

    purchasing.value = true;

    final PurchaseParam param = PurchaseParam(productDetails: product);

    try {
      // Consumable purchase (coins are consumed immediately)
      final bool success = await _iap.buyConsumable(
        purchaseParam: param,
        autoConsume: false, // We consume AFTER backend verification
      );
      if (!success) {
        purchasing.value = false;
        onPurchaseError?.call('Purchase could not be initiated');
      }
      // If success, the purchase stream will fire with updates
    } catch (e) {
      purchasing.value = false;
      onPurchaseError?.call(e.toString());
    }
  }

  /// Handle all purchase updates from the stream.
  Future<void> _handlePurchaseUpdates(
      List<PurchaseDetails> purchaseList) async {
    for (final PurchaseDetails purchase in purchaseList) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // Purchase is pending (e.g. waiting for parental approval)
          debugPrint('[IAP] Purchase pending: ${purchase.productID}');
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Purchase successful — verify with backend then complete
          await _verifyAndComplete(purchase);
          break;

        case PurchaseStatus.error:
          debugPrint('[IAP] Purchase error: ${purchase.error}');
          purchasing.value = false;
          onPurchaseError?.call(
            purchase.error?.message ?? 'Purchase failed',
          );
          // Must still complete the transaction to clear it from the queue
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.canceled:
          debugPrint('[IAP] Purchase canceled: ${purchase.productID}');
          purchasing.value = false;
          // Must still complete the transaction to clear it from the queue
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;
      }
    }
  }

  /// Verify the purchase receipt with our backend, credit coins, then finalize.
  Future<void> _verifyAndComplete(PurchaseDetails purchase) async {
    final String store = Platform.isIOS ? 'apple' : 'google';
    final String transactionId = _extractTransactionId(purchase);
    final String? receiptData = _extractReceiptData(purchase);

    if (_apiClient == null || _accessToken == null) {
      debugPrint('[IAP] Cannot verify — no API client/token');
      purchasing.value = false;
      onPurchaseError?.call('Not logged in');
      return;
    }

    try {
      // Send to backend for verification + coin credit
      final result = await _apiClient!.verifyPurchase(
        _accessToken!,
        store: store,
        productId: purchase.productID,
        transactionId: transactionId,
        receiptData: receiptData,
      );

      // Backend confirmed — now safe to complete/consume the purchase
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }

      purchasing.value = false;
      onPurchaseSuccess?.call(result.coinsAwarded);
      debugPrint(
          '[IAP] Purchase verified + completed: ${purchase.productID}, coins=${result.coinsAwarded}');
    } catch (e) {
      debugPrint('[IAP] Backend verification failed: $e');
      purchasing.value = false;
      // DO NOT complete the purchase — it will retry on next app launch.
      // This ensures the user never loses money:
      // - If backend is down, the purchase stays pending
      // - Next time the app starts, the purchaseStream will re-emit it
      // - We retry verification until it succeeds
      onPurchaseError?.call('Verification failed. Your purchase is safe and will be retried.');
    }
  }

  /// Extract the store-specific transaction ID.
  String _extractTransactionId(PurchaseDetails purchase) {
    if (Platform.isIOS) {
      // StoreKit 2: purchaseID is the transaction ID
      return purchase.purchaseID ?? purchase.transactionDate ?? '';
    } else {
      // Google Play: purchaseID contains the order ID
      return purchase.purchaseID ?? '';
    }
  }

  /// Extract receipt data for server-side verification.
  String? _extractReceiptData(PurchaseDetails purchase) {
    if (Platform.isIOS) {
      // StoreKit 2: the verificationData contains the signed JWS transaction
      return purchase.verificationData.serverVerificationData;
    } else {
      // Google Play: the token for server-side verification
      return purchase.verificationData.serverVerificationData;
    }
  }

  /// Restore purchases (mostly for non-consumables, but included for completeness).
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  /// Dispose — cancel stream subscription.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
