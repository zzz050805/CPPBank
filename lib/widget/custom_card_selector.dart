import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../l10n/app_text.dart';
import '../services/card_number_service.dart';
import '../services/user_firestore_service.dart';

class CustomCardSelection {
  const CustomCardSelection({
    required this.id,
    required this.title,
    required this.account,
    required this.balance,
    required this.totalAvailableBalance,
  });

  final String id;
  final String title;
  final String account;
  final double balance;
  final double totalAvailableBalance;
}

class CustomCardSelector extends StatefulWidget {
  const CustomCardSelector({
    super.key,
    required this.uid,
    required this.onChanged,
    this.selectedCardId,
    this.margin,
    this.backgroundColor,
    this.textColor,
  });

  final String uid;
  final String? selectedCardId;
  final ValueChanged<CustomCardSelection> onChanged;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  State<CustomCardSelector> createState() => _CustomCardSelectorState();
}

class _CustomCardSelectorState extends State<CustomCardSelector> {
  static final NumberFormat _moneyFormat = NumberFormat('#,###', 'vi_VN');

  String _lastEmission = '';

  Color get _effectiveBackgroundColor => widget.backgroundColor ?? Colors.white;

  Color get _effectiveTextColor => widget.textColor ?? const Color(0xFF1F2A44);

  double _parseBalance(dynamic raw) {
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      final String text = raw.trim();
      if (text.isEmpty) {
        return 0;
      }
      final double? direct = double.tryParse(text.replaceAll(',', '.'));
      if (direct != null) {
        return direct;
      }
      final String normalized = text.replaceAll(RegExp(r'[^0-9.-]'), '');
      if (normalized.isEmpty || normalized == '-' || normalized == '.') {
        return 0;
      }
      return double.tryParse(normalized) ?? 0;
    }
    return 0;
  }

  String _formatVnd(double amount) {
    return '${_moneyFormat.format(amount)} VND';
  }

  Color _cardTitleColor(String cardId) {
    return cardId == 'vip' ? const Color(0xFFB68A2A) : const Color(0xFF000DC0);
  }

  List<CustomCardSelection> _buildOptions(
    BuildContext context,
    Map<String, dynamic> userData,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final String fallbackRawCard = CardNumberService.readStoredCardNumber(
      userData,
    );
    final String fallbackCard = fallbackRawCard.isEmpty
        ? AppText.text(context, 'loading')
        : CardNumberService.formatCardNumber(fallbackRawCard);

    final List<CustomCardSelection> options = <CustomCardSelection>[];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final String cardId = doc.id.trim().toLowerCase();
      if (cardId != 'standard' && cardId != 'vip') {
        continue;
      }

      final Map<String, dynamic> cardData = doc.data();
      final bool available = UserFirestoreService.instance
          .isCardAvailableForTransactions(
            cardId: cardId,
            cardData: cardData,
            userData: userData,
          );
      if (!available) {
        continue;
      }

      final String rawCard = CardNumberService.readStoredCardNumber(cardData);
      final String account = rawCard.isEmpty
          ? fallbackCard
          : CardNumberService.formatCardNumber(rawCard);
      final String title = cardId == 'vip'
          ? AppText.text(context, 'card_vip')
          : AppText.text(context, 'card_standard');

      options.add(
        CustomCardSelection(
          id: cardId,
          title: title,
          account: account,
          balance: _parseBalance(cardData['balance']),
          totalAvailableBalance: 0,
        ),
      );
    }

    final double total = options.fold<double>(
      0,
      (double sum, CustomCardSelection card) => sum + card.balance,
    );

    return options
        .map(
          (CustomCardSelection option) => CustomCardSelection(
            id: option.id,
            title: option.title,
            account: option.account,
            balance: option.balance,
            totalAvailableBalance: total,
          ),
        )
        .toList(growable: false);
  }

  void _emitSelection(CustomCardSelection selection) {
    final String signature =
        '${selection.id}|${selection.balance}|${selection.totalAvailableBalance}|${selection.account}';
    if (signature == _lastEmission) {
      return;
    }

    _lastEmission = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onChanged(selection);
    });
  }

  Future<void> _showSelectorSheet(
    BuildContext context,
    List<CustomCardSelection> options,
    CustomCardSelection selected,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8DEEE),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppText.text(context, 'select_source_card'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF19213D),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext _, int index) {
                      final CustomCardSelection option = options[index];
                      final bool isSelected = option.id == selected.id;

                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          _emitSelection(option);
                          Navigator.pop(modalContext);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFEEF2FF)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF000DC0)
                                  : const Color(0xFFE6EAF3),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.credit_card_rounded,
                                color: Color(0xFF000DC0),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      option.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: _cardTitleColor(option.id),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      option.account,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: const Color(0xFF667085),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 104,
                                child: Text(
                                  _formatVnd(option.balance),
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFF000DC0),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String uid = widget.uid.trim();
    if (uid.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> userSnapshot,
          ) {
            final Map<String, dynamic> userData =
                userSnapshot.data?.data() ?? <String, dynamic>{};

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('cards')
                  .snapshots(),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                    cardsSnapshot,
                  ) {
                    final List<CustomCardSelection> options =
                        cardsSnapshot.hasData
                        ? _buildOptions(
                            context,
                            userData,
                            cardsSnapshot.data!.docs,
                          )
                        : const <CustomCardSelection>[];

                    if (cardsSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !cardsSnapshot.hasData) {
                      return Container(
                        margin: widget.margin,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _effectiveBackgroundColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE6EAF3)),
                        ),
                        child: Text(
                          AppText.text(context, 'loading'),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: _effectiveTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }

                    if (options.isEmpty) {
                      return Container(
                        margin: widget.margin,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _effectiveBackgroundColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE6EAF3)),
                        ),
                        child: Text(
                          AppText.text(context, 'card_unavailable'),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: _effectiveTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }

                    final String desiredId = (widget.selectedCardId ?? '')
                        .trim()
                        .toLowerCase();
                    final CustomCardSelection selected = options
                        .cast<CustomCardSelection?>()
                        .firstWhere(
                          (CustomCardSelection? option) =>
                              option?.id == desiredId,
                          orElse: () => options.first,
                        )!;

                    _emitSelection(selected);

                    return Container(
                      margin: widget.margin,
                      child: Material(
                        color: _effectiveBackgroundColor,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () =>
                              _showSelectorSheet(context, options, selected),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE6EAF3),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  Icons.credit_card_rounded,
                                  color: _effectiveTextColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        AppText.text(context, 'source_card'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: _effectiveTextColor.withValues(
                                            alpha: 0.82,
                                          ),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              '${selected.title} • ${selected.account}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: _cardTitleColor(
                                                  selected.id,
                                                ),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              '${AppText.text(context, 'available_balance')}: ${_formatVnd(selected.balance)}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: _effectiveTextColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: _effectiveTextColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
            );
          },
    );
  }
}
