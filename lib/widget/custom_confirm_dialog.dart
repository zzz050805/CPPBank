import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_text.dart';

Future<void> showCustomConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmText,
  String? cancelText,
  required FutureOr<void> Function() onConfirm,
  Color confirmColor = const Color(0xFFD92D20),
}) async {
  final String resolvedConfirmText =
      (confirmText == null || confirmText.trim().isEmpty)
      ? AppText.text(context, 'btn_yes')
      : confirmText;
  final String resolvedCancelText =
      (cancelText == null || cancelText.trim().isEmpty)
      ? AppText.text(context, 'btn_no')
      : cancelText;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF101828),
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 13,
            height: 1.45,
            color: const Color(0xFF475467),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF344054),
              textStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(resolvedCancelText),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(resolvedConfirmText),
          ),
        ],
      );
    },
  );
}
