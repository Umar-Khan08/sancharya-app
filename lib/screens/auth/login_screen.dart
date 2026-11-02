import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routing/app_routes.dart';
import '../../data/interfaces/i_auth_service.dart';
import '../../repositories/auth_repository.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';

/// Farmer Login & Genuine Phone OTP Verification Screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _districtController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isRequestingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isGuestLoggingIn = false;

  // Active OTP Session state
  OtpSession? _otpSession;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;
  String? _authError;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _phoneController.dispose();
    _nameController.dispose();
    _districtController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startCooldownTimer([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds > 0) {
        if (mounted) setState(() => _cooldownSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _handleSendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;

    setState(() {
      _isRequestingOtp = true;
      _authError = null;
    });

    try {
      final authRepo = context.read<AuthRepository>();
      final session = await authRepo.requestOtp(_phoneController.text);

      if (!mounted) return;
      setState(() {
        _otpSession = session;
        _otpController.clear();
      });
      _startCooldownTimer(session.cooldownSeconds);
    } catch (e) {
      if (mounted) {
        setState(() => _authError = e.toString().replaceAll('AppException: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isRequestingOtp = false);
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otpText = _otpController.text.trim();
    if (otpText.length != 6) {
      setState(() => _authError = 'Please enter the full 6-digit OTP code.');
      return;
    }

    if (_otpSession == null) return;

    setState(() {
      _isVerifyingOtp = true;
      _authError = null;
    });

    try {
      final authRepo = context.read<AuthRepository>();
      await authRepo.verifyOtp(
        verificationId: _otpSession!.verificationId,
        otp: otpText,
        name: _nameController.text,
        district: _districtController.text,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } catch (e) {
      if (mounted) {
        setState(() => _authError = e.toString().replaceAll('AppException: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  Future<void> _handleGuestLogin() async {
    setState(() => _isGuestLoggingIn = true);
    try {
      final authRepo = context.read<AuthRepository>();
      await authRepo.loginAsGuest();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } finally {
      if (mounted) setState(() => _isGuestLoggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // Top Brand Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.agriculture_rounded,
                          color: AppColors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        AppConstants.appName,
                        style: TextStyle(
                          color: AppColors.deepGreen,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.language_rounded, color: AppColors.primaryGreen),
                    tooltip: loc.languageSetting,
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.language);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Welcome Title
              Text(
                loc.welcomeTitle,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                loc.welcomeSubtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),

              // Error Banner (if any)
              if (_authError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.riskHighBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.riskHigh.withAlpha(80), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.riskHigh, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _authError!,
                          style: const TextStyle(
                            color: AppColors.riskHigh,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // STEP 1: Phone & Details Form (If OTP not requested yet)
              if (_otpSession == null) ...[
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _phoneFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          controller: _phoneController,
                          label: loc.enterMobileNumber,
                          hint: loc.mobileNumberHint,
                          keyboardType: TextInputType.phone,
                          prefixIcon: Icons.phone_android_rounded,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (value) {
                            if (value == null || value.trim().length != 10) {
                              return loc.invalidMobileError;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        AppTextField(
                          controller: _nameController,
                          label: loc.fullName,
                          hint: loc.fullNameHint,
                          prefixIcon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 16),

                        AppTextField(
                          controller: _districtController,
                          label: loc.districtState,
                          hint: loc.districtStateHint,
                          prefixIcon: Icons.location_on_outlined,
                        ),
                        const SizedBox(height: 24),

                        AppButton(
                          label: loc.sendOtpButton,
                          variant: AppButtonVariant.primaryGreen,
                          icon: Icons.sms_outlined,
                          isLoading: _isRequestingOtp,
                          onPressed: _handleSendOtp,
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // STEP 2: Dedicated OTP Entry View
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  loc.enterOtpTitle,
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '+91 ${_otpSession!.phoneNumber}',
                                  style: const TextStyle(
                                    color: AppColors.primaryGreen,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              _cooldownTimer?.cancel();
                              setState(() {
                                _otpSession = null;
                                _authError = null;
                              });
                            },
                            child: Text(loc.editMobile),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Real SMS Delivery Status or Unconfigured Gateway Notice
                      if (_otpSession != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _otpSession!.isSmsDelivered
                                ? AppColors.riskLowBg
                                : AppColors.demoBadgeBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _otpSession!.isSmsDelivered
                                  ? AppColors.primaryGreenLight
                                  : AppColors.demoBadgeBorder,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _otpSession!.isSmsDelivered
                                        ? Icons.mark_email_read_rounded
                                        : Icons.info_outline_rounded,
                                    size: 16,
                                    color: _otpSession!.isSmsDelivered
                                        ? AppColors.primaryGreen
                                        : AppColors.demoBadgeText,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _otpSession!.isSmsDelivered
                                          ? (loc.isHindi ? 'एसएमएस कोड भेजा गया' : 'SMS Code Dispatched')
                                          : (loc.isHindi ? 'एसएमएस गेटवे कॉन्फ़िगर नहीं है (टेस्ट मोड)' : 'SMS Gateway Not Configured (Sandbox Mode)'),
                                      style: TextStyle(
                                        color: _otpSession!.isSmsDelivered
                                            ? AppColors.primaryGreen
                                            : AppColors.demoBadgeText,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                loc.isHindi
                                    ? (_otpSession!.statusMessageHi ?? 'सर्वर संदेश प्राप्त हुआ।')
                                    : (_otpSession!.statusMessageEn ?? 'Verification session initialized on server.'),
                                style: TextStyle(
                                  color: _otpSession!.isSmsDelivered
                                      ? AppColors.deepGreen
                                      : AppColors.demoBadgeText,
                                  fontSize: 11,
                                ),
                              ),
                              if (!_otpSession!.isProviderConfigured && _otpSession!.testCodeForDisplay != null) ...[
                                const SizedBox(height: 8),
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      loc.isHindi ? 'सैंडबॉक्स कोड: ' : 'Sandbox Code: ',
                                      style: const TextStyle(fontSize: 11, color: AppColors.demoBadgeText),
                                    ),
                                    Text(
                                      _otpSession!.testCodeForDisplay!,
                                      style: const TextStyle(
                                        color: AppColors.deepGreen,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 3.0,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      loc.isHindi ? '(5 मिनट में समाप्त)' : '(Expires in 5m)',
                                      style: TextStyle(
                                        color: AppColors.demoBadgeText.withAlpha(200),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 6-digit OTP input box
                      AppTextField(
                        controller: _otpController,
                        label: loc.enterOtpTitle,
                        hint: '• • • • • •',
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.lock_outline_rounded,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Verify & Sign In Button
                      AppButton(
                        label: loc.verifyOtpButton,
                        variant: AppButtonVariant.primaryGreen,
                        icon: Icons.check_circle_outline_rounded,
                        isLoading: _isVerifyingOtp,
                        onPressed: _handleVerifyOtp,
                      ),
                      const SizedBox(height: 14),

                      // Resend OTP Action with Cooldown
                      Center(
                        child: _cooldownSeconds > 0
                            ? Text(
                                '${loc.resendOtpPrompt} 00:${_cooldownSeconds.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            : TextButton(
                                onPressed: _isRequestingOtp ? null : _handleSendOtp,
                                child: Text(
                                  loc.resendOtpButton,
                                  style: const TextStyle(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Separate Guest Mode (Zero Friction for Evaluators / Offline Farmers)
              AppButton(
                label: loc.continueAsGuest,
                variant: AppButtonVariant.goldenYellow,
                icon: Icons.person_pin_circle_outlined,
                isLoading: _isGuestLoggingIn,
                onPressed: _handleGuestLogin,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
