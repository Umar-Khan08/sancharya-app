import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';

/// Service for validating, formatting, and launching real phone calls to
/// mandis, APMC secretaries, and cold-storage facilities.
class PhoneCallService {
  PhoneCallService._();

  /// Normalizes an Indian phone number: removes formatting, handles +91/0 prefixes.
  /// Returns standard E.164 string (+91XXXXXXXXXX) or standard landline, or null if invalid.
  static String? normalizePhoneNumber(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // Filter out common dummy or placeholder strings
    final lower = trimmed.toLowerCase();
    if (lower.contains('not available') ||
        lower.contains('na') ||
        lower.contains('none') ||
        lower.contains('0000000000')) {
      return null;
    }

    // Keep only digits and leading plus
    var digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return null;

    if (digitsOnly == '0000000000' ||
        digitsOnly == '1234567890' ||
        digitsOnly == '123456789' ||
        RegExp(r'^(\d)\1{7,}$').hasMatch(digitsOnly)) {
      return null;
    }

    // If starts with 91 and has 12 digits (standard Indian mobile with 91 prefix)
    if (digitsOnly.startsWith('91') && digitsOnly.length == 12) {
      final local = digitsOnly.substring(2);
      if (RegExp(r'^[6-9]').hasMatch(local)) {
        return '+91$local';
      }
      return null;
    }

    // If starts with 0 and has 11 digits (e.g. 09876543210 or STD landline)
    if (digitsOnly.startsWith('0') && digitsOnly.length == 11) {
      digitsOnly = digitsOnly.substring(1);
    }

    // Standard 10-digit Indian mobile number (must start with 6, 7, 8, or 9)
    if (digitsOnly.length == 10 && RegExp(r'^[6-9]').hasMatch(digitsOnly)) {
      return '+91$digitsOnly';
    }

    // Standard Indian landline with STD code (e.g. 011-23456789 or 020-25678901)
    if ((digitsOnly.length == 10 || digitsOnly.length == 11) &&
        (digitsOnly.startsWith('11') ||
         digitsOnly.startsWith('20') ||
         digitsOnly.startsWith('22') ||
         digitsOnly.startsWith('33') ||
         digitsOnly.startsWith('44') ||
         digitsOnly.startsWith('80') ||
         RegExp(r'^[2-5]').hasMatch(digitsOnly))) {
      return '+91$digitsOnly';
    }

    return null;
  }

  /// Checks if a string represents a valid, credible phone number
  static bool isValidPhoneNumber(String? raw) {
    final normalized = normalizePhoneNumber(raw);
    if (normalized == null) return false;
    final digits = normalized.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 && digits.length <= 13;
  }

  /// User-friendly display format (e.g., +91 98765 43210)
  static String formatForDisplay(String? raw) {
    final normalized = normalizePhoneNumber(raw);
    if (normalized == null) return raw ?? '';
    final digits = normalized.replaceAll(RegExp(r'^\+91'), '');
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return normalized;
  }

  /// Displays confirmation dialog with facility name & phone number,
  /// then launches the device phone dialer without automatic placement.
  static Future<bool> promptAndLaunchCall({
    required BuildContext context,
    required String facilityName,
    required String? rawPhoneNumber,
    required bool isHindi,
  }) async {
    final normalized = normalizePhoneNumber(rawPhoneNumber);
    if (normalized == null) {
      _showNotice(
        context,
        isHindi
            ? 'फोन नंबर उपलब्ध नहीं है या अमान्य है।'
            : 'Phone number not available or invalid.',
        isError: true,
      );
      return false;
    }

    final formatted = formatForDisplay(normalized);

    // Explicit confirmation dialog showing facility name & number before dialing
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.resourceBlueLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.call_rounded, color: AppColors.resourceBlue, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isHindi ? 'सुविधा को कॉल करें?' : 'Call Facility?',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                facilityName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatted,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryGreen,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isHindi
                    ? 'यह आपके फोन का डायलर खोलेगा। जाने से पहले परिचालन समय, शुल्क और भंडारण उपलब्धता की पुष्टि अवश्य करें।'
                    : 'This will populate your phone dialer. Verify operating hours, storage space, and charges before visiting.',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                isHindi ? 'रद्द करें' : 'Cancel',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.phone_forwarded_rounded, size: 16),
              label: Text(isHindi ? 'डायल करें' : 'Open Dialer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.resourceBlue,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return false;

    // Launch tel URI
    final uri = Uri.parse('tel:$normalized');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        _handleDialerFailure(context, formatted, isHindi);
        return false;
      }
      return true;
    } catch (_) {
      if (context.mounted) {
        _handleDialerFailure(context, formatted, isHindi);
      }
      return false;
    }
  }

  static void _handleDialerFailure(BuildContext context, String formattedNumber, bool isHindi) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isHindi ? 'डायलर खोलने में असमर्थ' : 'Could Not Open Dialer',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isHindi
                    ? 'इस उपकरण पर कोई फोन एप्लिकेशन उपलब्ध नहीं है। आप नीचे दिए गए नंबर को कॉपी कर सकते हैं:'
                    : 'No phone dialing application is available on this device. You can copy the contact number below:',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 10),
              SelectableText(
                formattedNumber,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isHindi ? 'बंद करें' : 'Close'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text(isHindi ? 'नंबर कॉपी करें' : 'Copy Number'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: formattedNumber));
                Navigator.pop(ctx);
                _showNotice(
                  context,
                  isHindi ? 'नंबर कॉपी किया गया!' : 'Phone number copied to clipboard!',
                );
              },
            ),
          ],
        );
      },
    );
  }

  static void _showNotice(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.riskHigh : AppColors.primaryGreen,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
