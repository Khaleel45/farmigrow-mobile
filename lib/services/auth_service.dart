import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles Firebase Phone OTP authentication.
/// Phone number is used as the farmer's identity — their farms and
/// ponds in Railway's database are linked to this number, not just
/// a device ID. This means reinstalling the app on the same phone
/// or using a second phone both see the same farms after logging in.
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _phoneKey = 'logged_in_phone';

  /// Current logged-in user (null if not logged in)
  static User? get currentUser => _auth.currentUser;

  /// Phone number of the logged-in user
  static String? get currentPhone => _auth.currentUser?.phoneNumber;

  /// Whether the user is currently logged in
  static bool get isLoggedIn => _auth.currentUser != null;

  /// Sends OTP to the given phone number.
  /// [onCodeSent] is called with the verificationId when OTP is sent.
  /// [onError] is called with an error message if something fails.
  static Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    Function(PhoneAuthCredential)? onAutoVerified,
  }) async {
    // Ensure phone number has country code
    String formatted = phoneNumber.trim();
    if (!formatted.startsWith('+')) {
      formatted = '+91$formatted'; // Default to India
    }

    await _auth.verifyPhoneNumber(
      phoneNumber: formatted,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        // Auto-verification on Android (rare but possible)
        try {
          await _auth.signInWithCredential(credential);
          await _savePhone(formatted);
          onAutoVerified?.call(credential);
        } catch (e) {
          onError('Auto-verification failed: $e');
        }
      },
      verificationFailed: (e) {
        print('Firebase auth error: ${e.code} - ${e.message}');
        if (e.code == 'invalid-phone-number') {
          onError('Invalid phone number. Use format: 9876543210');
        } else if (e.code == 'too-many-requests') {
          onError('Too many OTP requests. Please wait 10 minutes and try again.');
        } else if (e.code == 'app-not-authorized') {
          onError('App not authorized. Add SHA-1 fingerprint to Firebase console.');
        } else if (e.code == 'quota-exceeded') {
          onError('SMS quota exceeded. Try again tomorrow.');
        } else if (e.code == 'network-request-failed') {
          onError('No internet connection. Please check your network and try again.');
        } else if (e.message?.contains('BILLING_NOT_ENABLED') == true) {
          onError(
            'Firebase billing not enabled.\n\n'
            'To fix: Go to console.firebase.google.com → '
            'Your project → Upgrade to Blaze plan (pay-as-you-go, free tier still applies).\n\n'
            'Or add test numbers at: Authentication → Sign-in method → Phone → '
            'Scroll down to "Phone numbers for testing".'
          );
        } else {
          onError('OTP send failed (${e.code}): ${e.message ?? "Unknown error"}');
        }
      },
      codeSent: (verificationId, resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (verificationId) {
        // Auto-retrieval timed out — user must enter OTP manually
      },
    );
  }

  /// Verifies the OTP entered by the user.
  /// Returns null on success, error message on failure.
  static Future<String?> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp.trim(),
      );
      final result = await _auth.signInWithCredential(credential);
      if (result.user != null) {
        await _savePhone(result.user!.phoneNumber ?? '');
        return null; // Success
      }
      return 'Login failed — please try again';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        return 'Wrong OTP. Please check and try again.';
      } else if (e.code == 'session-expired') {
        return 'OTP expired. Please request a new one.';
      }
      return 'Verification failed: ${e.message}';
    } catch (e) {
      return 'Something went wrong: $e';
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_phoneKey);
  }

  static Future<void> _savePhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phoneKey, phone);
  }

  /// Device identity for backend — uses Firebase UID when logged in,
  /// falls back to device UUID for backward compatibility.
  static Future<String> getBackendUserId() async {
    final user = _auth.currentUser;
    if (user != null) {
      return 'phone_${user.uid}';
    }
    // Fallback to device UUID if not logged in
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_id_v1') ?? 'unknown';
  }
}
