/// Google Play Billing Price Tier Resolver & Dynamic Coupon Downgrade Helper
/// 
/// Maps dynamic batch prices and post-coupon discounts to pre-registered 
/// Google Play In-App Product Tiers starting from ₹9 in increments of 10 up to ₹3,199:
/// (₹9, ₹19, ₹29, ₹39, ... ₹299, ... ₹599, ... ₹1,199, ... ₹2,199, ... ₹3,199).
class GooglePlayTierHelper {
  GooglePlayTierHelper._();

  static const String freeEnrollment = 'free_enrollment';
  static const String tierPrefix = 'course_tier_';

  // Benchmark Tier SKU Identifiers maintained for direct reference
  static const String tier9 = 'course_tier_9';
  static const String tier19 = 'course_tier_19';
  static const String tier29 = 'course_tier_29';
  static const String tier49 = 'course_tier_49';
  static const String tier99 = 'course_tier_99';
  static const String tier199 = 'course_tier_199';
  static const String tier299 = 'course_tier_299';
  static const String tier399 = 'course_tier_399';
  static const String tier499 = 'course_tier_499';
  static const String tier599 = 'course_tier_599';
  static const String tier799 = 'course_tier_799';
  static const String tier999 = 'course_tier_999';
  static const String tier1199 = 'course_tier_1199';
  static const String tier1499 = 'course_tier_1499';
  static const String tier1999 = 'course_tier_1999';
  static const String tier2199 = 'course_tier_2199';
  static const String tier2499 = 'course_tier_2499';
  static const String tier2999 = 'course_tier_2999';
  static const String tier3199 = 'course_tier_3199';
  static const String tier3999 = 'course_tier_3999';
  static const String tier4999 = 'course_tier_4999';
  static const String tier9999 = 'course_tier_9999';

  /// Check if the purchase is 100% free (bypasses Google Play Billing)
  static bool isFreeEnrollment(double payableAmount) {
    return payableAmount <= 0.0;
  }

  /// Calculates the matching Google Play Price Tier ending in 9 (9, 19, 29 ... 3199).
  ///
  /// - If [payable] <= 0: returns 0.
  /// - If [payable] <= 9: returns 9.
  /// - If [payable] >= 3199: returns 3199.
  /// - Otherwise, maps to the 10-step price ending in 9.
  /// - With [floor] = true (default), rounds down to the nearest <= tier so students 
  ///   are never charged more than the displayed payable price.
  static int resolveTierPrice(double payable, {bool floor = true}) {
    if (payable <= 0.0) return 0;
    if (payable <= 9.0) return 9;
    if (payable >= 3199.0) return 3199;

    final double step = (payable - 9.0) / 10.0;
    final int k = floor ? step.floor() : step.round();
    final int calculated = 9 + (k * 10);
    return calculated.clamp(9, 3199);
  }

  /// Construct the product ID for a given tier price (e.g. 399 -> 'course_tier_399')
  static String formatTierSku(int price) {
    return '$tierPrefix$price';
  }

  /// Resolve the appropriate Google Play Product ID based on payable amount.
  /// 
  /// If [finalPayable] is 0 or less, returns [freeEnrollment].
  /// If there is no discount applied ([finalPayable] >= [originalPrice]) and 
  /// a custom [batchProductId] is specified, that product ID is preserved.
  /// Otherwise, dynamically routes to the matching 'course_tier_X' across the
  /// 9 to 3199 10-step spectrum.
  static String resolveProductTier({
    required double originalPrice,
    required double finalPayable,
    String? batchProductId,
  }) {
    if (finalPayable <= 0.0) {
      return freeEnrollment;
    }

    // If no discount is active and batch specifies a custom product ID, preserve it
    final bool hasDiscount = finalPayable < (originalPrice - 0.01);
    if (!hasDiscount && batchProductId != null && batchProductId.trim().isNotEmpty) {
      return batchProductId.trim();
    }

    final int tierPrice = resolveTierPrice(finalPayable);
    return formatTierSku(tierPrice);
  }

  /// Returns user-friendly label for the resolved tier
  static String getTierDisplayName(String tierSku) {
    if (tierSku == freeEnrollment) {
      return '100% Scholarship / Free';
    }
    if (tierSku.startsWith(tierPrefix)) {
      final priceStr = tierSku.substring(tierPrefix.length);
      final price = int.tryParse(priceStr);
      if (price != null) {
        return 'Course Tier (₹$price)';
      }
    }
    return tierSku;
  }
}
