import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_translations.dart';
import 'payment_confirmation_screen.dart';
import 'service_data.dart';
import 'service_model.dart';

class ShoppingStoreScreen extends StatefulWidget {
  const ShoppingStoreScreen({super.key});

  @override
  State<ShoppingStoreScreen> createState() => _ShoppingStoreScreenState();
}

class _ShoppingStoreScreenState extends State<ShoppingStoreScreen> {
  static const Color _primaryBlue = Color(0xFF000DC0);
  static const Color _lightBlue = Color(0xFFF5F8FF);
  static const Color _silverGray = Color(0xFF98A2B3);

  String _formatAmount(int amount) {
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    ).format(amount);
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
              style: const TextStyle(
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
  ) {
    final int amount = service.packages[index];
    final String packageName = _packageName(context, service, index, amount);

    return Container(
      width: 176,
      margin: EdgeInsets.only(
        left: index == 0 ? 20 : 0,
        right: index == service.packages.length - 1 ? 20 : 12,
        top: 4,
        bottom: 6,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          _goToPaymentConfirmation(service: service, selectedAmount: amount);
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
            children: [
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
              Text(
                _formatAmount(amount),
                style: TextStyle(
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
                style: TextStyle(
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

  Widget _buildServiceSection(BuildContext context, int index) {
    final ServiceModel service = shoppingServices[index];

    return Padding(
      padding: EdgeInsets.only(top: index == 0 ? 14 : 6, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildServiceHeader(service),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: service.packages.length,
              itemBuilder: (context, packageIndex) {
                return _buildPackageCard(context, service, packageIndex);
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.getText(context, 'service_store')),
      ),
      backgroundColor: Colors.white,
      body: ListView.builder(
        itemCount: shoppingServices.length,
        itemBuilder: _buildServiceSection,
      ),
    );
  }
}
