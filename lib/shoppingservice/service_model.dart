enum ServiceAccountInputType { phone, email, riotTag, steamId, userId, icloud }

String _localizedText(Map<String, String> values, String languageCode) {
  if (values.isEmpty) {
    return '';
  }
  return values[languageCode] ??
      values['vi'] ??
      values['en'] ??
      values.values.first;
}

class ServiceAccountField {
  const ServiceAccountField({
    required this.id,
    required this.label,
    required this.hint,
    required this.type,
    this.regexPattern,
    this.errorText,
    this.maxLength,
    this.digitsOnly = false,
  });

  final String id;
  final Map<String, String> label;
  final Map<String, String> hint;
  final ServiceAccountInputType type;
  final String? regexPattern;
  final Map<String, String>? errorText;
  final int? maxLength;
  final bool digitsOnly;

  String localizedLabel(String languageCode) {
    return _localizedText(label, languageCode);
  }

  String localizedHint(String languageCode) {
    return _localizedText(hint, languageCode);
  }

  String? localizedErrorText(String languageCode) {
    final Map<String, String>? value = errorText;
    if (value == null || value.isEmpty) {
      return null;
    }
    return _localizedText(value, languageCode);
  }
}

class ServiceModel {
  const ServiceModel({
    required this.id,
    required this.name,
    required this.logoPath,
    required this.description,
    required this.packages,
    this.accountFields = const <ServiceAccountField>[],
  });

  final String id;
  final Map<String, String> name;
  final String logoPath;
  final Map<String, String> description;
  final List<int> packages;
  final List<ServiceAccountField> accountFields;

  String localizedName(String languageCode) {
    return _localizedText(name, languageCode);
  }

  String localizedDescription(String languageCode) {
    return _localizedText(description, languageCode);
  }
}
