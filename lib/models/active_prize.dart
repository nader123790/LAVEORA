/// Represents a winner prize that has been verified (phone + winner code
/// matched a 'winners' document in Firestore) but not yet redeemed.
///
/// Field names on the Firestore 'winners' document aren't fully fixed by
/// the existing client code, so parsing here is intentionally tolerant —
/// it accepts a few common alternate key names so this works whether the
/// admin/backend stored e.g. `discountPercent` or `discount_percent`.
class ActivePrize {
  final String docPath;
  final String phone;
  final String winnerCode;
  final String prizeType; // 'Discount' | 'Buy X Get Y' | 'Free Item' | other
  final String prizeDescription;

  // Discount
  final num? discountPercent;
  final num? discountAmount;

  // Free Item / Buy X Get Y
  final String? freeItemName;
  final String? requiredItemName;
  final int? requiredItemQty;

  const ActivePrize({
    required this.docPath,
    required this.phone,
    required this.winnerCode,
    required this.prizeType,
    required this.prizeDescription,
    this.discountPercent,
    this.discountAmount,
    this.freeItemName,
    this.requiredItemName,
    this.requiredItemQty,
  });

  static T? _firstNonNull<T>(List<T? Function()> getters) {
    for (final g in getters) {
      final v = g();
      if (v != null) return v;
    }
    return null;
  }

  factory ActivePrize.fromMap(
    Map<String, dynamic> map,
    String docPath,
    String phone,
  ) {
    num? asNum(dynamic v) {
      if (v == null) return null;
      if (v is num) return v;
      return num.tryParse(v.toString());
    }

    // Pulls just the numeric part out of a value that might be a plain
    // number OR a string with units/symbols around it (e.g. "30%", "30 %",
    // "100 ج.م", " 100"). Plain num.tryParse() fails the moment there's a
    // '%' or currency text next to the digits, which silently turned every
    // such value into `null` — and a discount prize with both
    // discountPercent and discountAmount null applies ZERO discount. This
    // is the actual root cause of "الخصم مش بيتحسب": the number was there,
    // it just couldn't be parsed because of the extra characters around it.
    num? extractNumber(dynamic v) {
      if (v == null) return null;
      if (v is num) return v;
      final match =
          RegExp(r'[-+]?[0-9]+(?:[.,][0-9]+)?').firstMatch(v.toString());
      if (match == null) return null;
      return num.tryParse(match.group(0)!.replaceAll(',', '.'));
    }

    bool hasPercentSign(dynamic v) => v != null && v.toString().contains('%');

    String? asStr(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    final prizeType = map['prizeType']?.toString() ?? '';
    final description = map['prizeDescription']?.toString() ?? '';

    // 1) Dedicated percent/amount fields, now tolerant of "30", "30%",
    //    " 30 % " etc. — whichever dedicated field is present wins.
    num? discountPercent = _firstNonNull<num>([
      () => extractNumber(map['discountPercent']),
      () => extractNumber(map['discount_percent']),
      () => extractNumber(map['percentOff']),
    ]);
    num? discountAmount = _firstNonNull<num>([
      () => extractNumber(map['discountAmount']),
      () => extractNumber(map['discount_amount']),
      () => extractNumber(map['amountOff']),
    ]);

    // 2) Fallback: a single generic "how much is the discount" field where
    //    the ONLY thing distinguishing percent vs flat amount is whether a
    //    '%' sign is written next to the number — e.g. discountValue:
    //    "30%" means 30% off the bill, discountValue: "100" (or 100 as a
    //    plain number) means 100 ج.م off the bill. This mirrors exactly how
    //    the admin panel enters a discount reward as one value.
    if (discountPercent == null && discountAmount == null) {
      for (final key in [
        'discountValue',
        'discount_value',
        'discount',
        'value',
        'prizeValue',
        'prize_value',
      ]) {
        if (!map.containsKey(key) || map[key] == null) continue;
        final raw = map[key];
        final n = extractNumber(raw);
        if (n == null) continue;
        if (hasPercentSign(raw)) {
          discountPercent = n;
        } else {
          discountAmount = n;
        }
        break;
      }
    }

    // 3) Last resort: read it straight out of the prize description text
    //    (e.g. "خصم 30%" -> 30% off, "خصم 100 جنيه" -> 100 ج.م off), for
    //    winners documents that only ever stored a human-readable
    //    description and no structured discount field at all.
    if (discountPercent == null &&
        discountAmount == null &&
        description.isNotEmpty) {
      final percentMatch =
          RegExp(r'([0-9]+(?:[.,][0-9]+)?)\s*%').firstMatch(description);
      if (percentMatch != null) {
        discountPercent =
            num.tryParse(percentMatch.group(1)!.replaceAll(',', '.'));
      } else {
        final numberMatch =
            RegExp(r'([0-9]+(?:[.,][0-9]+)?)').firstMatch(description);
        if (numberMatch != null) {
          discountAmount =
              num.tryParse(numberMatch.group(1)!.replaceAll(',', '.'));
        }
      }
    }

    return ActivePrize(
      docPath: docPath,
      phone: phone,
      winnerCode: map['winnerCode']?.toString() ?? '',
      prizeType: prizeType,
      prizeDescription: description,
      discountPercent: discountPercent,
      discountAmount: discountAmount,
      freeItemName: _firstNonNull<String>([
        () => asStr(map['freeItemName']),
        () => asStr(map['free_item_name']),
        () => asStr(map['itemName']),
        () => asStr(map['gift']),
      ]),
      requiredItemName: _firstNonNull<String>([
        () => asStr(map['requiredItemName']),
        () => asStr(map['required_item_name']),
        () => asStr(map['buyItemName']),
      ]),
      requiredItemQty: _firstNonNull<num>([
        () => asNum(map['requiredItemQty']),
        () => asNum(map['required_item_qty']),
        () => asNum(map['buyQty']),
      ])?.toInt(),
    );
  }

  bool get isDiscount => prizeType.toLowerCase().contains('discount');
  bool get isBuyXGetY =>
      prizeType.toLowerCase().contains('buy') &&
      prizeType.toLowerCase().contains('get');
  bool get isFreeItem =>
      !isBuyXGetY && prizeType.toLowerCase().contains('free');

  Map<String, dynamic> toJson() => {
        'docPath': docPath,
        'phone': phone,
        'winnerCode': winnerCode,
        'prizeType': prizeType,
        'prizeDescription': prizeDescription,
        'discountPercent': discountPercent,
        'discountAmount': discountAmount,
        'freeItemName': freeItemName,
        'requiredItemName': requiredItemName,
        'requiredItemQty': requiredItemQty,
      };

  factory ActivePrize.fromJson(Map<String, dynamic> j) => ActivePrize(
        docPath: j['docPath']?.toString() ?? '',
        phone: j['phone']?.toString() ?? '',
        winnerCode: j['winnerCode']?.toString() ?? '',
        prizeType: j['prizeType']?.toString() ?? '',
        prizeDescription: j['prizeDescription']?.toString() ?? '',
        discountPercent: j['discountPercent'] as num?,
        discountAmount: j['discountAmount'] as num?,
        freeItemName: j['freeItemName']?.toString(),
        requiredItemName: j['requiredItemName']?.toString(),
        requiredItemQty: (j['requiredItemQty'] as num?)?.toInt(),
      );
}
