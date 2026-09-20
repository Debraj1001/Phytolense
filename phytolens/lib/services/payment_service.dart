// lib/services/payment_service.dart

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
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
    required String plan,
    required String userEmail,
    required String userContact,
    String? planName,
    int? customAmountPaise,
  }) async {
    _currentPlan = plan;

    int amount = customAmountPaise ?? AppConstants.proMonthlyPaise;
    if (plan == 'farm' && customAmountPaise == null) {
      amount = AppConstants.farmMonthlyPaise;
    } else if (plan == 'trial' && customAmountPaise == null) {
      amount = 100;
    } else if (plan == 'emergency_doctor' && customAmountPaise == null) {
      amount = 1000;
    }

    String? orderId;
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'razorpay-checkout',
        body: {
          'action': 'create_order',
          'amount': amount,
          'currency': 'INR',
          'receipt': 'rcpt_${DateTime.now().millisecondsSinceEpoch}',
          'notes': {'plan': plan, 'email': userEmail},
        },
      );
      if (res.data != null && res.data['order_id'] != null) {
        orderId = res.data['order_id'] as String;
      }
    } catch (e) {
      debugPrint('Edge function order fallback: $e');
    }

    final options = {
      'key': Env.razorpayKeyId,
      'amount': amount,
      'name': 'PhytoLens',
      'description': planName ?? '$plan Subscription — PhytoLens AI',
      'timeout': 300,
      if (orderId != null) 'order_id': orderId,
      'prefill': {
        'contact': userContact.isNotEmpty ? userContact : '9999999999',
        'email': userEmail.isNotEmpty ? userEmail : 'farmer@phytolens.com',
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
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final plan = _currentPlan ?? 'pro';
    
    int amount = AppConstants.proMonthlyPaise;
    if (plan == 'farm') amount = AppConstants.farmMonthlyPaise;
    if (plan == 'trial') amount = 100;
    if (plan == 'emergency_doctor') amount = 1000;

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
        await _supabase.activateTrial(user.id);
      } else if (plan == 'emergency_doctor') {
        await _supabase.updateSubscription(
          user.id,
          'pro',
          days: 1,
          razorpaySubscriptionId: response.paymentId,
        );
      } else {
        await _supabase.updateSubscription(
          user.id,
          plan,
          days: 30,
          razorpaySubscriptionId: response.paymentId,
        );
      }

      // 3. Record payment record with exact Supabase table schema
      try {
        await _supabase.savePayment(
          userId: user.id,
          amount: amount ~/ 100,
          plan: plan,
          razorpayPaymentId: response.paymentId ?? 'test_${DateTime.now().millisecondsSinceEpoch}',
        );
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
