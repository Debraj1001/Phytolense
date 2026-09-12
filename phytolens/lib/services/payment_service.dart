// lib/services/payment_service.dart

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';
import '../config/env.dart';
import 'supabase_service.dart';

class PaymentService {
  final Razorpay _razorpay = Razorpay();
  final SupabaseService _supabase = SupabaseService();

  Function(String plan)? onSuccess;
  Function(String error)? onError;
  String? _currentPlan;

  void init({
    required Function(String plan) onSuccess,
    required Function(String error) onError,
  }) {
    this.onSuccess = onSuccess;
    this.onError = onError;

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleWallet);
  }

  void setPlan(String plan) => _currentPlan = plan;

  Future<void> openCheckout({
    required String plan, // 'pro' | 'farm'
    required String userId,
    required String email,
    int? amountInPaise,
    String phone = '',
  }) async {
    _currentPlan = plan;
    int? defaultAmount;
    if (plan == 'pro') {
      defaultAmount = AppConstants.proMonthlyPaise;
    } else if (plan == 'farm') {
      defaultAmount = AppConstants.farmMonthlyPaise;
    } else if (plan == 'trial') {
      defaultAmount = 100; // 1 Rupee in paise
    }

    final amount = amountInPaise ?? (defaultAmount ?? 100);
    final rupeeAmount = amount ~/ 100;

    String? orderId;

    // 1. Try to create order on backend edge function if available
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'razorpay-checkout',
        body: {
          'action': 'create_order',
          'amount': amount,
          'currency': 'INR',
          'user_id': userId,
          'plan': plan,
        },
      );
      if (res.data != null && res.data['id'] != null) {
        orderId = res.data['id'];
      }
    } catch (e) {
      debugPrint('Edge function order creation skipped/fallback: $e');
    }

    // 2. Open Razorpay checkout (with orderId or standard direct test mode options)
    final options = <String, dynamic>{
      'key': Env.razorpayTestKeyId,
      'amount': amount,
      'name': 'PhytoLens',
      'description': plan == 'trial' ? '2-Day Trial Activation - ₹$rupeeAmount' : (plan == 'pro' ? 'Pro Plan - ₹$rupeeAmount/month' : 'Farm Pack - ₹$rupeeAmount/month'),
      'currency': 'INR',
      if (orderId != null) 'order_id': orderId,
      'prefill': {
        if (phone.isNotEmpty) 'contact': phone,
        if (email.isNotEmpty) 'email': email,
      },
      'notes': {
        'user_id': userId,
        'plan': plan,
      },
      'theme': {'color': '#10B981'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay open error: $e');
      onError?.call('Unable to open payment checkout. Please check your network connection.');
    }
  }

  Future<void> _handleSuccess(PaymentSuccessResponse response) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final plan = _currentPlan ?? 'pro';
    
    int amount = AppConstants.proMonthlyPaise;
    if (plan == 'farm') amount = AppConstants.farmMonthlyPaise;
    if (plan == 'trial') amount = 100;

    try {
      // 1. Attempt backend verification
      try {
        await Supabase.instance.client.functions.invoke(
          'razorpay-checkout',
          body: {
            'action': 'verify_payment',
            'razorpay_payment_id': response.paymentId,
            'razorpay_order_id': response.orderId,
            'razorpay_signature': response.signature,
            'plan': plan,
            'amount': amount,
          },
        );
      } catch (e) {
        debugPrint('Edge function verify fallback: $e');
      }

      // 2. Guaranteed subscription update in Supabase
      if (plan == 'trial') {
        await _supabase.activateTrial(user.uid);
      } else {
        await _supabase.updateSubscription(user.uid, plan, days: 30);
      }

      // 3. Record payment record
      try {
        await Supabase.instance.client.from(AppConstants.tablePayments).insert({
          'user_id': user.uid,
          'plan': plan,
          'amount': amount ~/ 100,
          'payment_id': response.paymentId ?? 'test_${DateTime.now().millisecondsSinceEpoch}',
          'order_id': response.orderId,
          'status': 'completed',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Payment record log error: $e');
      }

      onSuccess?.call(plan);
    } catch (e) {
      debugPrint('Payment processing error: $e');
      onError?.call('Payment received, but activation is taking longer than usual. Please refresh your profile in a moment.');
    }
  }

  void _handleError(PaymentFailureResponse response) {
    debugPrint('Razorpay Error: code=${response.code}, message=${response.message}');
    final msg = response.message?.toLowerCase() ?? '';
    // Handle cancellation
    if (response.code == Razorpay.PAYMENT_CANCELLED ||
        msg.contains('cancel') ||
        msg.contains('undefined error') ||
        msg.contains('cancelled by the user') ||
        msg.contains('bad_request_error') ||
        msg.contains('back pressed')) {
      onError?.call('Payment was cancelled');
      return;
    }
    if (response.code == Razorpay.NETWORK_ERROR || msg.contains('network')) {
      onError?.call('Network connection lost. Please check your internet and try again.');
      return;
    }
    onError?.call(response.message ?? 'Payment could not be completed. Please try again.');
  }

  void _handleWallet(ExternalWalletResponse response) {}

  void dispose() {
    _razorpay.clear();
  }
}
