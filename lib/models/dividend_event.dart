class DividendEvent {
  const DividendEvent({
    required this.symbol,
    required this.name,
    this.exDate,
    this.paymentDate,
    this.declarationDate,
    this.amount,
    this.currency,
    this.frequency,
  });

  final String symbol;
  final String name;
  final DateTime? exDate;
  final DateTime? paymentDate;
  final DateTime? declarationDate;
  final double? amount;
  final String? currency;
  final String? frequency;

  bool get hasUpcomingExDate {
    if (exDate == null) return false;
    final now = DateTime.now();
    return !exDate!.isBefore(DateTime(now.year, now.month, now.day));
  }

  DividendEvent copyWith({
    String? symbol,
    String? name,
    DateTime? exDate,
    DateTime? paymentDate,
    DateTime? declarationDate,
    double? amount,
    String? currency,
    String? frequency,
  }) {
    return DividendEvent(
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      exDate: exDate ?? this.exDate,
      paymentDate: paymentDate ?? this.paymentDate,
      declarationDate: declarationDate ?? this.declarationDate,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      frequency: frequency ?? this.frequency,
    );
  }
}
