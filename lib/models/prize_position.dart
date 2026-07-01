class PrizePosition {
  final int position;
  final String prizeType;
  final String prizeDescription;

  const PrizePosition({
    required this.position,
    required this.prizeType,
    required this.prizeDescription,
  });

  factory PrizePosition.fromMap(Map<String, dynamic> map) => PrizePosition(
        position: (map['position'] as num?)?.toInt() ?? 1,
        prizeType: map['prizeType']?.toString() ?? '',
        prizeDescription: map['prizeDescription']?.toString() ?? '',
      );
  String get medal {
    switch (position) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '🏅';
    }
  }
}
