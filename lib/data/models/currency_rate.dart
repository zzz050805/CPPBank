class CurrencyRate {
  final String code;
  final String countryName;
  final String buyPrice;
  final String sellPrice;
  final String flagUrl;

  const CurrencyRate({
    required this.code,
    required this.countryName,
    required this.buyPrice,
    required this.sellPrice,
    required this.flagUrl,
  });
}
