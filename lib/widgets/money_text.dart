import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/models/txn_enums.dart';

/// An amount in ₹ with Indian grouping.
///
/// With [type] set it is signed: "−₹250" for money out, a green "+₹5,000"
/// for money in. Without it, a negative amount turns red.
class MoneyText extends StatelessWidget {
  const MoneyText(this.paise, {super.key, this.type, this.style = AppText.h3});

  final int paise;
  final TxnType? type;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (type) {
      TxnType.debit => ('−${formatPaise(paise)}', style.color),
      TxnType.credit => ('+${formatPaise(paise)}', AppColors.positive),
      null => (
        formatPaise(paise),
        paise < 0 ? AppColors.negative : style.color,
      ),
    };
    return Text(
      text,
      maxLines: 1,
      softWrap: false,
      style: style.copyWith(color: color),
    );
  }
}
