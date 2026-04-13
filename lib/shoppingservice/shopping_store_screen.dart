import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/app_translations.dart';
import 'payment_confirmation_screen.dart';
import 'service_data.dart';
import 'service_model.dart';

class ServicePackageOption {
  const ServicePackageOption({
    this.title,
    required this.price,
    required this.discountPercent,
  });

  final String? title;
  final int price;
  final int discountPercent;
}

class ServicePricingData {
  const ServicePricingData({required this.packages});

  final List<ServicePackageOption> packages;
}

int _readDiscountPercent(dynamic raw) {
  final int parsed = int.tryParse((raw ?? 0).toString()) ?? 0;
  if (parsed < 0) {
    return 0;
  }
  if (parsed > 100) {
    return 100;
  }
  return parsed;
}

List<ServicePackageOption> _readPackageOptions(List<dynamic> rawPackages) {
  final List<ServicePackageOption> parsed = <ServicePackageOption>[];

  for (final dynamic item in rawPackages) {
    if (item is Map<String, dynamic>) {
      final String title = (item['title'] ?? item['name'] ?? '')
          .toString()
          .trim();
      final int price = (item['price'] is num)
          ? (item['price'] as num).toInt()
          : (int.tryParse((item['price'] ?? '').toString()) ?? 0);
      final int discountPercent = _readDiscountPercent(item['discountPercent']);
      if (price > 0) {
        parsed.add(
          ServicePackageOption(
            title: title.isEmpty ? null : title,
            price: price,
            discountPercent: discountPercent,
          ),
        );
      }
      continue;
    }

    if (item is Map) {
      final String title = (item['title'] ?? item['name'] ?? '')
          .toString()
          .trim();
      final int price = (item['price'] is num)
          ? (item['price'] as num).toInt()
          : (int.tryParse((item['price'] ?? '').toString()) ?? 0);
      final int discountPercent = _readDiscountPercent(item['discountPercent']);
      if (price > 0) {
        parsed.add(
          ServicePackageOption(
            title: title.isEmpty ? null : title,
            price: price,
            discountPercent: discountPercent,
          ),
        );
      }
      continue;
    }

    final int price = int.tryParse(item.toString()) ?? 0;
    if (price > 0) {
      parsed.add(
        ServicePackageOption(title: null, price: price, discountPercent: 0),
      );
    }
  }

  return parsed;
}

bool _isShoppingBundleDoc(Map<String, dynamic> data) {
  final String kind = (data['kind'] ?? 'shopping_bundle').toString().trim();
  return kind.isEmpty || kind == 'shopping_bundle';
}

Stream<QuerySnapshot<Map<String, dynamic>>> shoppingServicesQueryStream() {
  return FirebaseFirestore.instance.collection('services').snapshots();
}

Stream<Map<String, ServicePricingData>> shoppingPricingStream() {
  return shoppingServicesQueryStream().map((
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, ServicePricingData> pricing =
        <String, ServicePricingData>{};

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      if (!_isShoppingBundleDoc(data)) {
        continue;
      }
      final List<ServicePackageOption> packages = _readPackageOptions(
        (data['packages'] as List<dynamic>?) ?? <dynamic>[],
      );
      if (packages.isEmpty) {
        continue;
      }

      pricing[doc.id] = ServicePricingData(packages: packages);
    }

    return pricing;
  });
}

int discountedPrice(int originalPrice, int discountPercent) {
  if (discountPercent <= 0) {
    return originalPrice;
  }
  return ((originalPrice * (100 - discountPercent)) / 100).round();
}

class ShoppingStoreScreen extends StatefulWidget {
  const ShoppingStoreScreen({
    super.key,
    this.isFromNotification = false,
    this.targetServiceId,
    this.highlightServiceId,
  });

  final bool isFromNotification;
  final String? targetServiceId;
  final String? highlightServiceId;

  @override
  State<ShoppingStoreScreen> createState() => _ShoppingStoreScreenState();
}

class _ShoppingStoreScreenState extends State<ShoppingStoreScreen> {
  static const Color _primaryBlue = Color(0xFF000DC0);
  static const Color _lightBlue = Color(0xFFF5F8FF);
  static const Color _silverGray = Color(0xFF98A2B3);
  static const double _estimatedSectionExtent = 220;

  final ScrollController _scrollController = ScrollController();
  List<ServiceModel> _currentServices = <ServiceModel>[];
  String? _highlightedServiceId;
  bool _didConsumeRouteArgs = false;
  bool _isPackageSheetOpen = false;

  static final Map<String, ServiceModel> _serviceTemplateById =
      <String, ServiceModel>{
        for (final ServiceModel service in shoppingServices)
          service.id: service,
      };

  static const List<ServiceAccountField> _defaultDynamicAccountFields =
      <ServiceAccountField>[
        ServiceAccountField(
          id: 'email',
          label: <String, String>{'vi': 'Email', 'en': 'Email'},
          hint: <String, String>{
            'vi': 'Nhap email tai khoan dich vu',
            'en': 'Enter service account email',
          },
          type: ServiceAccountInputType.email,
          regexPattern: r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
          errorText: <String, String>{
            'vi': 'Vui long nhap Email hop le.',
            'en': 'Please enter a valid email address.',
          },
        ),
      ];

  @override
  void initState() {
    super.initState();
    _currentServices = List<ServiceModel>.from(shoppingServices);
    final String initialTarget = widget.isFromNotification
        ? (widget.highlightServiceId ?? widget.targetServiceId ?? '').trim()
        : '';
    if (initialTarget.isNotEmpty) {
      _activateHighlight(initialTarget, fromInit: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToHighlightedService();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didConsumeRouteArgs) {
      return;
    }
    _didConsumeRouteArgs = true;

    if (_highlightedServiceId != null && _highlightedServiceId!.isNotEmpty) {
      return;
    }

    final Object? args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) {
      return;
    }

    final bool isFromNotification = args['isFromNotification'] == true;
    final String targetId = (args['targetServiceId'] ?? '').toString().trim();
    if (!isFromNotification || targetId.isEmpty) {
      return;
    }

    _activateHighlight(targetId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToHighlightedService();
    });
  }

  void _activateHighlight(String targetId, {bool fromInit = false}) {
    if (fromInit) {
      _highlightedServiceId = targetId;
    } else {
      setState(() {
        _highlightedServiceId = targetId;
      });
    }

    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!mounted || _highlightedServiceId != targetId) {
        return;
      }
      setState(() {
        _highlightedServiceId = null;
      });
    });
  }

  Future<void> _scrollToHighlightedService() async {
    final String? targetId = _highlightedServiceId;
    if (!mounted || targetId == null || targetId.isEmpty) {
      return;
    }

    final int targetIndex = _currentServices.indexWhere(
      (ServiceModel service) => service.id == targetId,
    );
    if (targetIndex < 0 || !_scrollController.hasClients) {
      return;
    }

    final double maxOffset = _scrollController.position.maxScrollExtent;
    final double targetOffset = (targetIndex * _estimatedSectionExtent).clamp(
      0,
      maxOffset,
    );

    await _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );

    if (!mounted) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 2600));
    if (!mounted || _highlightedServiceId != targetId) {
      return;
    }

    setState(() {
      _highlightedServiceId = null;
    });
  }

  String _formatAmount(int amount) {
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    ).format(amount);
  }

  List<ServiceModel> _servicesFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
        snapshot.docs
            .where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
              return _isShoppingBundleDoc(doc.data());
            })
            .toList(growable: false)
          ..sort((a, b) {
            final String aName =
                (a.data()['nameVi'] ?? a.data()['name'] ?? a.id).toString();
            final String bName =
                (b.data()['nameVi'] ?? b.data()['name'] ?? b.id).toString();
            return aName.compareTo(bName);
          });

    if (docs.isEmpty) {
      return List<ServiceModel>.from(shoppingServices);
    }

    return docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          return _serviceFromDoc(doc);
        })
        .toList(growable: false);
  }

  ServiceModel _serviceFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    final String templateId = (data['id'] ?? '').toString().trim();
    final ServiceModel? template =
        _serviceTemplateById[templateId] ?? _serviceTemplateById[doc.id];

    final String nameVi =
        (data['nameVi'] ?? data['name'] ?? template?.name['vi'] ?? doc.id)
            .toString()
            .trim();
    final String nameEn =
        (data['nameEn'] ?? data['name'] ?? template?.name['en'] ?? nameVi)
            .toString()
            .trim();
    final String logoPath = (data['logoPath'] ?? template?.logoPath ?? '')
        .toString()
        .trim();
    final String descVi =
        (data['descriptionVi'] ??
                data['description'] ??
                template?.description['vi'] ??
                'Dich vu so')
            .toString()
            .trim();
    final String descEn =
        (data['descriptionEn'] ??
                data['description'] ??
                template?.description['en'] ??
                'Digital service')
            .toString()
            .trim();

    final List<ServicePackageOption> packageOptions = _readPackageOptions(
      (data['packages'] as List<dynamic>?) ?? <dynamic>[],
    );
    final List<int> packages = packageOptions.isNotEmpty
        ? packageOptions
              .map((ServicePackageOption option) => option.price)
              .toList(growable: false)
        : (template?.packages ?? <int>[50000]);

    return ServiceModel(
      id: doc.id,
      name: <String, String>{
        'vi': nameVi.isEmpty ? doc.id : nameVi,
        'en': nameEn.isEmpty ? (nameVi.isEmpty ? doc.id : nameVi) : nameEn,
      },
      logoPath: logoPath,
      description: <String, String>{
        'vi': descVi.isEmpty ? 'Dich vu so' : descVi,
        'en': descEn.isEmpty ? 'Digital service' : descEn,
      },
      packages: packages,
      accountFields: (template?.accountFields.isNotEmpty ?? false)
          ? template!.accountFields
          : _defaultDynamicAccountFields,
    );
  }

  Widget _buildServiceLogo(
    String logoPath, {
    required double iconSize,
    required IconData fallbackIcon,
  }) {
    if (logoPath.startsWith('http://') || logoPath.startsWith('https://')) {
      return Image.network(
        logoPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: const Color(0xFFF2F4F7),
            alignment: Alignment.center,
            child: Icon(
              fallbackIcon,
              size: iconSize,
              color: const Color(0xFF98A2B3),
            ),
          );
        },
      );
    }

    return Image.asset(
      logoPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: const Color(0xFFF2F4F7),
          alignment: Alignment.center,
          child: Icon(
            fallbackIcon,
            size: iconSize,
            color: const Color(0xFF98A2B3),
          ),
        );
      },
    );
  }

  List<ServicePackageOption> _effectivePackages(
    ServiceModel service,
    Map<String, ServicePricingData> pricing,
  ) {
    final ServicePricingData? servicePricing = pricing[service.id];
    if (servicePricing == null || servicePricing.packages.isEmpty) {
      return service.packages
          .map(
            (int price) => ServicePackageOption(
              title: null,
              price: price,
              discountPercent: 0,
            ),
          )
          .toList(growable: false);
    }
    return servicePricing.packages;
  }

  String _packageName(
    BuildContext context,
    int index,
    ServicePackageOption package,
  ) {
    final String customTitle = (package.title ?? '').trim();
    if (customTitle.isNotEmpty) {
      return customTitle;
    }
    final String packageLabel = AppTranslations.getText(context, 'package');
    return '$packageLabel ${index + 1}';
  }

  IconData _packageIcon(ServiceModel service) {
    switch (service.id) {
      case 'riot_games':
      case 'steam':
        return Icons.sports_esports_rounded;
      case 'netflix':
      case 'spotify':
      case 'apple_music':
        return Icons.subscriptions_rounded;
      case 'grab':
      case 'xanh_sm':
        return Icons.directions_car_rounded;
      case 'chatgpt':
      case 'gemini':
        return Icons.auto_awesome_rounded;
      default:
        return Icons.shopping_bag_rounded;
    }
  }

  void _goToPaymentConfirmation({
    required ServiceModel service,
    required int selectedAmount,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentConfirmationScreen(
          service: service,
          selectedAmount: selectedAmount,
        ),
      ),
    );
  }

  String _saleLabel(BuildContext context) {
    return AppTranslations.getText(context, 'on_sale');
  }

  String _serviceSubtitle(BuildContext context, ServiceModel service) {
    final String languageCode = AppTranslations.currentLanguageCode(context);
    final bool isVi = languageCode == 'vi';

    switch (service.id) {
      case 'shopee':
        return isVi ? 'Mua sắm' : 'Shopping';
      case 'netflix':
      case 'spotify':
      case 'apple_music':
      case 'steam':
      case 'riot_games':
      case 'chatgpt':
      case 'gemini':
        return isVi ? 'Giải trí' : 'Entertainment';
      case 'xanh_sm':
      case 'grab':
        return isVi ? 'Di chuyển' : 'Mobility';
      default:
        return isVi ? 'Dịch vụ số' : 'Digital service';
    }
  }

  bool _isPopularPackage(int index, String packageName) {
    if (index == 1) {
      return true;
    }

    final String normalized = packageName.trim().toLowerCase();
    return normalized.contains('basic') ||
        normalized.contains('individual') ||
        normalized.contains('co ban') ||
        normalized.contains('ca nhan');
  }

  String _popularBadgeLabel(BuildContext context) {
    final String languageCode = AppTranslations.currentLanguageCode(context);
    return languageCode == 'vi' ? '⭐ Phổ biến' : '⭐ Popular';
  }

  String _bottomSheetTagline(BuildContext context) {
    final String languageCode = AppTranslations.currentLanguageCode(context);
    return languageCode == 'vi'
        ? 'Lựa chọn gói dịch vụ phù hợp với nhu cầu. Thanh toán an toàn và tiện lợi.'
        : 'Choose the package that fits your needs. Safe and convenient payments.';
  }

  Widget _buildServiceGridCard(
    ServiceModel service,
    Map<String, ServicePricingData> pricing,
    bool isHighlighted,
  ) {
    final String languageCode = AppTranslations.currentLanguageCode(context);
    final String subtitle = _serviceSubtitle(context, service);
    final List<ServicePackageOption> packageOptions = _effectivePackages(
      service,
      pricing,
    );
    final bool hasSale = packageOptions.any(
      (ServicePackageOption option) => option.discountPercent > 0,
    );
    final String newBadgeLabel = languageCode == 'vi' ? 'MỚI' : 'NEW';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        _showServicePackagesSheet(service);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: const Color(0xFF1E34D8).withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: const Color(0xFFE9EEFB)),
        ),
        child: Stack(
          children: <Widget>[
            if (isHighlighted)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    newBadgeLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            Align(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _buildServiceLogo(
                        service.logoPath,
                        iconSize: 22,
                        fallbackIcon: Icons.image_not_supported_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    service.localizedName(languageCode),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (hasSale)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _saleLabel(context),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheetPackageCard(
    BuildContext context,
    ServiceModel service,
    int index,
    ServicePackageOption package,
    int totalPackages,
  ) {
    final int originalPrice = package.price;
    final int discountPercent = package.discountPercent;
    final int finalPrice = discountedPrice(originalPrice, discountPercent);
    final String packageName = _packageName(context, index, package);
    final bool isPopular = _isPopularPackage(index, packageName);
    final Color borderColor = isPopular
        ? const Color(0xFF86A8FF)
        : _silverGray.withOpacity(0.18);

    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        top: index == 0 ? 8 : 0,
        bottom: index == totalPackages - 1 ? 20 : 10,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).pop<int>(finalPrice);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: borderColor,
                  width: isPopular ? 1.4 : 1,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _lightBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _packageIcon(service),
                      size: 21,
                      color: _primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          packageName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475467),
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (discountPercent > 0) ...<Widget>[
                          Text(
                            _saleLabel(context),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE11D48),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatAmount(finalPrice),
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _primaryBlue,
                            ),
                          ),
                          Text(
                            _formatAmount(originalPrice),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF94A3B8),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ] else
                          Text(
                            _formatAmount(originalPrice),
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _primaryBlue,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isPopular)
              Positioned(
                right: 10,
                top: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFF22C55E).withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    _popularBadgeLabel(context),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showServicePackagesSheet(ServiceModel service) async {
    if (!mounted || _isPackageSheetOpen) {
      return;
    }
    _isPackageSheetOpen = true;

    final String languageCode = AppTranslations.currentLanguageCode(context);

    int? selectedAmount;
    try {
      selectedAmount = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withOpacity(0.35),
        builder: (BuildContext sheetContext) {
          return Container(
            height: MediaQuery.of(sheetContext).size.height * 0.76,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.98),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 10),
                Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D9EE),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _buildServiceLogo(
                            service.logoPath,
                            iconSize: 18,
                            fallbackIcon: Icons.image_not_supported_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          service.localizedName(languageCode),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _bottomSheetTagline(sheetContext),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Divider(color: Colors.grey[200], thickness: 1, height: 1),
                Expanded(
                  child: StreamBuilder<Map<String, ServicePricingData>>(
                    stream: shoppingPricingStream(),
                    builder:
                        (
                          BuildContext itemContext,
                          AsyncSnapshot<Map<String, ServicePricingData>>
                          snapshot,
                        ) {
                          final Map<String, ServicePricingData> pricing =
                              snapshot.data ?? <String, ServicePricingData>{};
                          final List<ServicePackageOption> packageOptions =
                              _effectivePackages(service, pricing);

                          if (packageOptions.isEmpty) {
                            return Center(
                              child: Text(
                                AppTranslations.getText(
                                  itemContext,
                                  'service_not_found',
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: packageOptions.length,
                            itemBuilder: (BuildContext cardContext, int index) {
                              return _buildBottomSheetPackageCard(
                                cardContext,
                                service,
                                index,
                                packageOptions[index],
                                packageOptions.length,
                              );
                            },
                          );
                        },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      _isPackageSheetOpen = false;
    }

    if (!mounted || selectedAmount == null) {
      return;
    }
    final int resolvedAmount = selectedAmount;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _goToPaymentConfirmation(
        service: service,
        selectedAmount: resolvedAmount,
      );
    });
  }

  Widget _buildServiceHeader(ServiceModel service) {
    final String languageCode = AppTranslations.currentLanguageCode(context);

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: _buildServiceLogo(
                service.logoPath,
                iconSize: 18,
                fallbackIcon: Icons.image_outlined,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              service.localizedName(languageCode),
              style: GoogleFonts.poppins(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: _primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(
    BuildContext context,
    ServiceModel service,
    int index,
    ServicePackageOption package,
    int totalPackages,
  ) {
    final int originalPrice = package.price;
    final int discountPercent = package.discountPercent;
    final int finalPrice = discountedPrice(originalPrice, discountPercent);
    final String packageName = _packageName(context, index, package);

    return Container(
      width: 176,
      margin: EdgeInsets.only(
        left: index == 0 ? 20 : 0,
        right: index == totalPackages - 1 ? 20 : 12,
        top: 4,
        bottom: 6,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          _goToPaymentConfirmation(
            service: service,
            selectedAmount: finalPrice,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _silverGray.withOpacity(0.18), width: 1),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _lightBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _packageIcon(service),
                  size: 22,
                  color: _primaryBlue,
                ),
              ),
              const SizedBox(height: 10),
              if (discountPercent > 0) ...<Widget>[
                Text(
                  _formatAmount(finalPrice),
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _primaryBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatAmount(originalPrice),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ] else
                Text(
                  _formatAmount(originalPrice),
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _primaryBlue,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                packageName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _silverGray,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppTranslations.getText(context, 'service_store'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      backgroundColor: const Color(0xFFF4F6FB),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: shoppingServicesQueryStream(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final QuerySnapshot<Map<String, dynamic>> serviceSnapshot =
                  snapshot.data!;
              final Map<String, ServicePricingData> pricing =
                  <String, ServicePricingData>{};
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in serviceSnapshot.docs) {
                final Map<String, dynamic> data = doc.data();
                if (!_isShoppingBundleDoc(data)) {
                  continue;
                }

                final List<ServicePackageOption> packages = _readPackageOptions(
                  (data['packages'] as List<dynamic>?) ?? <dynamic>[],
                );
                if (packages.isEmpty) {
                  continue;
                }
                pricing[doc.id] = ServicePricingData(packages: packages);
              }

              final List<ServiceModel> services = _servicesFromSnapshot(
                serviceSnapshot,
              );
              _currentServices = services;

              if (services.isEmpty) {
                return Center(
                  child: Text(
                    AppTranslations.getText(context, 'service_not_found'),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.15,
                ),
                itemCount: services.length,
                itemBuilder: (BuildContext context, int index) {
                  final ServiceModel service = services[index];
                  final bool isHighlighted =
                      service.id == _highlightedServiceId;
                  final Widget card = _buildServiceGridCard(
                    service,
                    pricing,
                    isHighlighted,
                  );

                  if (!isHighlighted) {
                    return card;
                  }

                  return TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 1, end: 1.1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutBack,
                    builder:
                        (BuildContext context, double scale, Widget? child) {
                          return Transform.scale(scale: scale, child: child);
                        },
                    child: card,
                  );
                },
              );
            },
      ),
    );
  }
}

class ShoppingServiceDetailScreen extends StatefulWidget {
  const ShoppingServiceDetailScreen({
    super.key,
    required this.serviceId,
    this.isFromNotification = false,
  });

  final String serviceId;
  final bool isFromNotification;

  @override
  State<ShoppingServiceDetailScreen> createState() =>
      _ShoppingServiceDetailScreenState();
}

class _ShoppingServiceDetailScreenState
    extends State<ShoppingServiceDetailScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primaryBlue = Color(0xFF000DC0);

  late final AnimationController _zoomController;
  late final Animation<double> _zoomAnimation;

  String _formatAmount(int amount) {
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    ).format(amount);
  }

  @override
  void initState() {
    super.initState();
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _zoomAnimation = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.08,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
    ]).animate(_zoomController);

    if (widget.isFromNotification) {
      _zoomController.forward();
    }
  }

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  ServiceModel? _resolveService() {
    for (final ServiceModel service in shoppingServices) {
      if (service.id == widget.serviceId) {
        return service;
      }
    }
    return null;
  }

  String _packageName(
    BuildContext context,
    int index,
    ServicePackageOption package,
  ) {
    final String customTitle = (package.title ?? '').trim();
    if (customTitle.isNotEmpty) {
      return customTitle;
    }
    final String packageLabel = AppTranslations.getText(context, 'package');
    return '$packageLabel ${index + 1}';
  }

  void _goToPayment(ServiceModel service, int amount) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PaymentConfirmationScreen(service: service, selectedAmount: amount),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ServiceModel? service = _resolveService();
    if (service == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Service detail')),
        body: Center(
          child: Text(AppTranslations.getText(context, 'service_not_found')),
        ),
      );
    }

    final String languageCode = AppTranslations.currentLanguageCode(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          service.localizedName(languageCode),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<Map<String, ServicePricingData>>(
        stream: shoppingPricingStream(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<Map<String, ServicePricingData>> snapshot,
            ) {
              final Map<String, ServicePricingData> pricing =
                  snapshot.data ?? <String, ServicePricingData>{};
              final ServicePricingData? servicePricing = pricing[service.id];
              final List<ServicePackageOption> packageOptions =
                  servicePricing?.packages.isNotEmpty == true
                  ? servicePricing!.packages
                  : service.packages
                        .map(
                          (int amount) => ServicePackageOption(
                            title: null,
                            price: amount,
                            discountPercent: 0,
                          ),
                        )
                        .toList(growable: false);

              final int firstDiscountedIndex = packageOptions.indexWhere(
                (ServicePackageOption option) => option.discountPercent > 0,
              );
              final int highlightedIndex =
                  (widget.isFromNotification && firstDiscountedIndex >= 0)
                  ? firstDiscountedIndex
                  : -1;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: packageOptions.length,
                itemBuilder: (BuildContext context, int index) {
                  final ServicePackageOption option = packageOptions[index];
                  final int originalPrice = option.price;
                  final int discountPercent = option.discountPercent;
                  final int finalPrice = discountedPrice(
                    originalPrice,
                    discountPercent,
                  );
                  final Widget card = Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _goToPayment(service, finalPrice),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  _packageName(context, index, option),
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (discountPercent > 0) ...<Widget>[
                                  Text(
                                    _formatAmount(finalPrice),
                                    style: GoogleFonts.poppins(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: _primaryBlue,
                                    ),
                                  ),
                                  Text(
                                    _formatAmount(originalPrice),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: const Color(0xFF94A3B8),
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ] else
                                  Text(
                                    _formatAmount(originalPrice),
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: _primaryBlue,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                  if (index != highlightedIndex) {
                    return card;
                  }

                  return AnimatedBuilder(
                    animation: _zoomAnimation,
                    builder: (BuildContext context, Widget? child) {
                      return Transform.scale(
                        scale: _zoomAnimation.value,
                        child: child,
                      );
                    },
                    child: card,
                  );
                },
              );
            },
      ),
    );
  }
}
