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
    required this.price,
    required this.discountPercent,
  });

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
      final int price = (item['price'] is num)
          ? (item['price'] as num).toInt()
          : (int.tryParse((item['price'] ?? '').toString()) ?? 0);
      final int discountPercent = _readDiscountPercent(item['discountPercent']);
      if (price > 0) {
        parsed.add(
          ServicePackageOption(price: price, discountPercent: discountPercent),
        );
      }
      continue;
    }

    if (item is Map) {
      final int price = (item['price'] is num)
          ? (item['price'] as num).toInt()
          : (int.tryParse((item['price'] ?? '').toString()) ?? 0);
      final int discountPercent = _readDiscountPercent(item['discountPercent']);
      if (price > 0) {
        parsed.add(
          ServicePackageOption(price: price, discountPercent: discountPercent),
        );
      }
      continue;
    }

    final int price = int.tryParse(item.toString()) ?? 0;
    if (price > 0) {
      parsed.add(ServicePackageOption(price: price, discountPercent: 0));
    }
  }

  return parsed;
}

Stream<Map<String, ServicePricingData>> shoppingPricingStream() {
  return FirebaseFirestore.instance
      .collection('admin')
      .doc('settings')
      .collection('services_pricing')
      .where('kind', isEqualTo: 'shopping_bundle')
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
        final Map<String, ServicePricingData> pricing =
            <String, ServicePricingData>{};

        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs) {
          final Map<String, dynamic> data = doc.data();
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
  });

  final bool isFromNotification;
  final String? targetServiceId;

  @override
  State<ShoppingStoreScreen> createState() => _ShoppingStoreScreenState();
}

class _ShoppingStoreScreenState extends State<ShoppingStoreScreen> {
  static const Color _primaryBlue = Color(0xFF000DC0);
  static const Color _lightBlue = Color(0xFFF5F8FF);
  static const Color _silverGray = Color(0xFF98A2B3);
  static const double _estimatedSectionExtent = 220;

  final ScrollController _scrollController = ScrollController();
  late final Map<String, GlobalKey> _serviceSectionKeys;
  String? _highlightedServiceId;
  bool _didConsumeRouteArgs = false;

  @override
  void initState() {
    super.initState();
    _serviceSectionKeys = <String, GlobalKey>{
      for (final ServiceModel service in shoppingServices)
        service.id: GlobalKey(debugLabel: 'service_section_${service.id}'),
    };

    _highlightedServiceId = widget.isFromNotification
        ? widget.targetServiceId?.trim()
        : null;

    if (_highlightedServiceId != null && _highlightedServiceId!.isNotEmpty) {
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

    setState(() {
      _highlightedServiceId = targetId;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToHighlightedService();
    });
  }

  Future<void> _scrollToHighlightedService() async {
    final String? targetId = _highlightedServiceId;
    if (!mounted || targetId == null || targetId.isEmpty) {
      return;
    }

    final int targetIndex = shoppingServices.indexWhere(
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

    final BuildContext? targetContext =
        _serviceSectionKeys[targetId]?.currentContext;
    if (targetContext != null) {
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOut,
        alignment: 0.18,
      );
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

  List<ServicePackageOption> _effectivePackages(
    ServiceModel service,
    Map<String, ServicePricingData> pricing,
  ) {
    final ServicePricingData? servicePricing = pricing[service.id];
    if (servicePricing == null || servicePricing.packages.isEmpty) {
      return service.packages
          .map(
            (int price) =>
                ServicePackageOption(price: price, discountPercent: 0),
          )
          .toList(growable: false);
    }
    return servicePricing.packages;
  }

  String _packageName(
    BuildContext context,
    ServiceModel service,
    int index,
    int amount,
  ) {
    switch (service.id) {
      case 'netflix':
        const List<String> plans = <String>[
          'mobile_plan',
          'basic_plan',
          'premium_plan',
        ];
        return index < plans.length
            ? AppTranslations.getText(context, plans[index])
            : _formatAmount(amount);
      case 'spotify':
        const List<String> plans = <String>[
          'mini_plan',
          'individual_plan',
          'family_plan',
        ];
        return index < plans.length
            ? AppTranslations.getText(context, plans[index])
            : _formatAmount(amount);
      case 'apple_music':
        const List<String> plans = <String>[
          'student_plan',
          'individual_plan',
          'family_plan',
        ];
        return index < plans.length
            ? AppTranslations.getText(context, plans[index])
            : _formatAmount(amount);
      case 'chatgpt':
        const List<String> plans = <String>[
          'basic_plan',
          'plus_plan',
          'pro_plan',
        ];
        return index < plans.length
            ? AppTranslations.getText(context, plans[index])
            : _formatAmount(amount);
      case 'gemini':
        const List<String> plans = <String>[
          'starter_plan',
          'advanced_plan',
          'ultra_plan',
        ];
        return index < plans.length
            ? AppTranslations.getText(context, plans[index])
            : _formatAmount(amount);
      default:
        return _formatAmount(amount);
    }
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
              child: Image.asset(
                service.logoPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFFF2F4F7),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_outlined,
                      size: 18,
                      color: Color(0xFF98A2B3),
                    ),
                  );
                },
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
    final String packageName = _packageName(
      context,
      service,
      index,
      originalPrice,
    );

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

  Widget _buildServiceSection(
    ServiceModel service,
    int index,
    Map<String, ServicePricingData> pricing,
  ) {
    final List<ServicePackageOption> packageOptions = _effectivePackages(
      service,
      pricing,
    );

    return Padding(
      key: _serviceSectionKeys[service.id],
      padding: EdgeInsets.only(top: index == 0 ? 14 : 6, bottom: 14),
      child: _ServiceItemPulse(
        active: service.id == _highlightedServiceId,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildServiceHeader(service),
            const SizedBox(height: 12),
            SizedBox(
              height: 188,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: packageOptions.length,
                itemBuilder: (BuildContext context, int packageIndex) {
                  return _buildPackageCard(
                    context,
                    service,
                    packageIndex,
                    packageOptions[packageIndex],
                    packageOptions.length,
                  );
                },
              ),
            ),
          ],
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
      backgroundColor: Colors.white,
      body: StreamBuilder<Map<String, ServicePricingData>>(
        stream: shoppingPricingStream(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<Map<String, ServicePricingData>> snapshot,
            ) {
              final Map<String, ServicePricingData> pricing =
                  snapshot.data ?? <String, ServicePricingData>{};

              return ListView.builder(
                controller: _scrollController,
                itemCount: shoppingServices.length,
                itemBuilder: (BuildContext context, int index) {
                  return _buildServiceSection(
                    shoppingServices[index],
                    index,
                    pricing,
                  );
                },
              );
            },
      ),
    );
  }
}

class _ServiceItemPulse extends StatefulWidget {
  const _ServiceItemPulse({required this.child, required this.active});

  final Widget child;
  final bool active;

  @override
  State<_ServiceItemPulse> createState() => _ServiceItemPulseState();
}

class _ServiceItemPulseState extends State<_ServiceItemPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _isPulsing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scale = Tween<double>(
      begin: 1,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runPulse();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _ServiceItemPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _runPulse();
    }
    if (!widget.active && oldWidget.active) {
      _controller.stop();
      _controller.value = 0;
      _isPulsing = false;
    }
  }

  Future<void> _runPulse() async {
    if (_isPulsing || !widget.active || !mounted) {
      return;
    }
    _isPulsing = true;

    for (int i = 0; i < 3; i++) {
      if (!mounted || !widget.active) {
        break;
      }
      await _controller.forward(from: 0);
      if (!mounted || !widget.active) {
        break;
      }
      await _controller.reverse();
    }

    _isPulsing = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
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
    ServiceModel service,
    int index,
    int amount,
  ) {
    switch (service.id) {
      case 'netflix':
        const List<String> plans = <String>[
          'mobile_plan',
          'basic_plan',
          'premium_plan',
        ];
        return index < plans.length
            ? AppTranslations.getText(context, plans[index])
            : _formatAmount(amount);
      case 'spotify':
        const List<String> plans = <String>[
          'mini_plan',
          'individual_plan',
          'family_plan',
        ];
        return index < plans.length
            ? AppTranslations.getText(context, plans[index])
            : _formatAmount(amount);
      case 'apple_music':
        const List<String> plans = <String>[
          'student_plan',
          'individual_plan',
          'family_plan',
        ];
        return index < plans.length
            ? AppTranslations.getText(context, plans[index])
            : _formatAmount(amount);
      default:
        return _formatAmount(amount);
    }
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
                                  _packageName(
                                    context,
                                    service,
                                    index,
                                    originalPrice,
                                  ),
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
