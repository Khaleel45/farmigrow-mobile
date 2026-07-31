import 'package:flutter/material.dart';
import 'package:farmigrow_ai/theme/app_theme.dart';
import 'package:farmigrow_ai/services/auth_service.dart';
import 'package:farmigrow_ai/screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _otpSent = false;
  bool _loading = false;
  String? _verificationId;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Enter a valid 10-digit phone number');
      return;
    }
    setState(() { _loading = true; _error = null; });

    await AuthService.sendOtp(
      phoneNumber: phone,
      onCodeSent: (verificationId) {
        setState(() {
          _verificationId = verificationId;
          _otpSent = true;
          _loading = false;
        });
      },
      onError: (error) {
        setState(() { _error = error; _loading = false; });
      },
      onAutoVerified: (_) => _goHome(),
    );
  }

  Future<void> _verifyOtp() async {
    if (_verificationId == null) return;
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit OTP');
      return;
    }
    setState(() { _loading = true; _error = null; });

    final error = await AuthService.verifyOtp(
      verificationId: _verificationId!,
      otp: otp,
    );

    if (!mounted) return;
    if (error == null) {
      _goHome();
    } else {
      setState(() { _error = error; _loading = false; });
    }
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spaceXXL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Logo
              Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.eco, color: AppTheme.primaryGreen, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FarmiGrow AI', style: AppTheme.h1()),
                      Text('Satellite-Powered Farm Intelligence',
                          style: AppTheme.caption()),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 48),

              Text(
                _otpSent ? 'Enter OTP' : 'Welcome, Farmer',
                style: AppTheme.display().copyWith(fontSize: 32),
              ),
              const SizedBox(height: 8),
              Text(
                _otpSent
                    ? 'We sent a 6-digit OTP to +91 ${_phoneController.text}'
                    : 'Enter your phone number to continue',
                style: AppTheme.bodySmall(),
              ),
              const SizedBox(height: 40),

              if (!_otpSent) ...[
                // Phone input
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  style: AppTheme.h1().copyWith(letterSpacing: 2),
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: AppTheme.bodySmall(),
                    prefixText: '+91  ',
                    prefixStyle: AppTheme.body().copyWith(color: AppTheme.primaryGreen),
                    counterText: '',
                    filled: true,
                    fillColor: AppTheme.bgCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                    ),
                  ),
                ),
              ] else ...[
                // OTP input
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: AppTheme.h1().copyWith(fontSize: 28, letterSpacing: 8),
                  decoration: InputDecoration(
                    labelText: '6-digit OTP',
                    labelStyle: AppTheme.bodySmall(),
                    counterText: '',
                    filled: true,
                    fillColor: AppTheme.bgCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                    ),
                  ),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    border: Border.all(color: AppTheme.dangerRed.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.dangerRed, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: AppTheme.bodySmall().copyWith(color: AppTheme.dangerRed))),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Action button
              SizedBox(
                width: double.infinity,
                height: AppTheme.buttonHeight,
                child: ElevatedButton(
                  onPressed: _loading ? null : (_otpSent ? _verifyOtp : _sendOtp),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                        )
                      : Text(
                          _otpSent ? 'Verify OTP & Login' : 'Send OTP',
                          style: AppTheme.button(),
                        ),
                ),
              ),

              if (_otpSent) ...[
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : () {
                      setState(() {
                        _otpSent = false;
                        _otpController.clear();
                        _error = null;
                      });
                    },
                    child: Text('Change phone number',
                        style: AppTheme.bodySmall().copyWith(color: AppTheme.textGrey)),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : _sendOtp,
                    child: Text('Resend OTP',
                        style: AppTheme.bodySmall().copyWith(color: AppTheme.primaryGreen)),
                  ),
                ),
              ],

              const SizedBox(height: 48),

              // Info
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                decoration: AppTheme.cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.security, color: AppTheme.primaryGreen, size: 16),
                        const SizedBox(width: 8),
                        Text('Why phone login?', style: AppTheme.h3()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your farms and scan history are linked to your phone number. '
                      'You can switch phones or reinstall the app and all your data comes back.',
                      style: AppTheme.bodySmall(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
