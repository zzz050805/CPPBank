import 'package:flutter/material.dart';

class AppText {
  static String tr(BuildContext context, String vi, String en) {
    final String code = Localizations.localeOf(context).languageCode;
    return code == 'en' ? en : vi;
  }
}
