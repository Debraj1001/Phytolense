// lib/screens/ai/chatbot_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../services/groq_service.dart';
import '../../services/local_llm_service.dart';
import '../../services/sync_service.dart';
import '../../services/scan_limiter.dart';
import '../../providers/ai_limit_provider.dart';
import '../../providers/ai_settings_provider.dart';
import '../../theme/colors.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/loading_dots.dart';
import '../subscription/upgrade_screen.dart';
import '../subscription/trial_activation_screen.dart';
import '../../providers/app_config_provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime time;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.time,
  });
}

class ChatbotScreen extends ConsumerStatefulWidget {
  final String? initialMessage;

  const ChatbotScreen({super.key, this.initialMessage});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final _groq = GroqService();
  final _llmService = LocalLLMService();
  final _syncService = SyncService();
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _addWelcome();
    if (widget.initialMessage != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _sendMessage(widget.initialMessage!);
      });
    }
  }

  Future<void> _checkConnectivity() async {
    final online = await _syncService.isOnline();
    if (mounted) setState(() => _isOffline = !online);
  }

  void _addWelcome() {
    final offlineNote = _isOffline
        ? '\n\n📱 *You are offline — I\'m using on-device AI. Quality may vary, but I\'m here to help!*'
        : '';
    _messages = [
      ChatMessage(
        role: 'assistant',
        content: '🌿 Hi! I\'m PhytoLens AI${_isOffline ? ' (Offline Mode)' : ''}. I can help with plant diseases, treatments, growing tips, and garden advice.$offlineNote\n\nWhat\'s on your mind today?',
        time: DateTime.now(),
      ),
    ];
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isTyping) return;

    // Re-check connectivity
    await _checkConnectivity();

    // Check AI limit
    final limit = ref.read(aiLimitProvider).value;
    if (limit == null || !limit.canUse || limit.isExpired) {
      if (limit?.isExpired == true && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const UpgradeScreen()));
      }
      return;
    }

    final userMsg = ChatMessage(
      role: 'user',
      content: text.trim(),
      time: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _messages.add(ChatMessage(
        role: 'assistant',
        content: '',
        time: DateTime.now(),
      ));
      _isTyping = true;
    });
    _textCtrl.clear();
    _scrollToBottom();

    try {
      // Build history for context
      final history = _messages
          .where((m) => m.role != 'assistant' || _messages.indexOf(m) > 0)
          .map((m) => {'role': m.role, 'content': m.content})
          .toList()
          .cast<Map<String, String>>();
      
      if (history.isNotEmpty && history.last['role'] == 'assistant' && history.last['content']!.isEmpty) {
        history.removeLast(); // Remove the empty placeholder
      }

      Stream<String> stream;

      final isAiEngineEnabled = ref.read(aiEngineProvider);
      if (_isOffline || !isAiEngineEnabled) {
        // ── OFFLINE / AI ENGINE DISABLED: Use local LLM ──
        if (_llmService.isModelLoaded) {
          stream = _llmService.streamChat(text, history);
        } else if (await _llmService.isModelDownloaded()) {
          await _llmService.loadModel();
          stream = _llmService.streamChat(text, history);
        } else {
          // Model not downloaded — show prompt
          if (mounted) {
            setState(() {
              final lastIdx = _messages.length - 1;
              _messages[lastIdx] = ChatMessage(
                role: 'assistant',
                content: !isAiEngineEnabled
                    ? '📱 AI Engine is disabled in settings. You need to download the offline AI model (1.5 GB, one-time) in Settings to use the chatbot locally, or re-enable the AI Engine in Profile Settings.'
                    : '📱 The AI model needs to be downloaded first (1.5 GB, one-time).\n\nGo to **Settings → AI Model** to download, or connect to the internet to use cloud AI.',
                time: DateTime.now(),
              );
              _isTyping = false;
            });
          }
          return;
        }
        // Increment local AI count for offline tier tracking
        await ScanLimiter().incrementLocalAiCount();
      } else {
        // ── ONLINE: Use Groq (existing behavior) ──
        stream = _groq.streamChat(text, history);
      }

      await for (final chunk in stream) {
        if (!mounted) break;
        setState(() {
          final lastIdx = _messages.length - 1;
          _messages[lastIdx] = ChatMessage(
            role: 'assistant',
            content: _messages[lastIdx].content + chunk,
            time: _messages[lastIdx].time,
          );
        });
        _scrollToBottom();
      }

      // Record AI usage after full response
      if (!_isOffline) {
        final len = _messages.last.content.length;
        await ref.read(aiLimitProvider.notifier).recordUsage(len);
      }

      if (mounted) setState(() => _isTyping = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          final lastIdx = _messages.length - 1;
          _messages[lastIdx] = ChatMessage(
            role: 'assistant',
            content: _isOffline
                ? '⚠️ The on-device AI had a problem. Try closing other apps to free memory.'
                : '⚠️ Sorry, I couldn\'t get a response. Please check your connection and try again.',
            time: DateTime.now(),
          );
          _isTyping = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0x2600897B),
              child: Icon(Icons.smart_toy, color: AppColors.secondary, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PhytoLens AI',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Consumer(
                  builder: (context, ref, child) {
                    final aiState = ref.watch(aiLimitProvider);
                    if (aiState.isLoading || aiState.value == null) {
                      return const Text('Plant Health Expert', style: TextStyle(fontSize: 11, color: AppColors.textMuted));
                    }
                    final limit = aiState.value!;
                    if (limit.isNotStarted) {
                      return const Text('Trial Required • 2-Day Trial for ₹1', style: TextStyle(fontSize: 11, color: AppColors.primaryLight));
                    }
                    if (limit.isExpired) {
                      return const Text('Trial Ended • Upgrade to Chat', style: TextStyle(fontSize: 11, color: AppColors.warning));
                    }
                    if (limit.isUnlimited) {
                      return Text('Unlimited chats • ${limit.tier.toUpperCase()}', style: const TextStyle(fontSize: 11, color: AppColors.primaryLight));
                    }
                    return Text(
                      '${limit.remaining} / ${limit.limit} chats left • ${limit.tier.toUpperCase()}',
                      style: const TextStyle(fontSize: 11, color: AppColors.primaryLight),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              ref.read(aiLimitProvider.notifier).refreshLimit();
              setState(() {
                _messages = [];
                _addWelcome();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                return _ChatBubble(message: _messages[i]);
              },
            ),
          ),

          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final aiLimitState = ref.watch(aiLimitProvider);
    final isLoading = aiLimitState.isLoading || aiLimitState.value == null;
    final limit = aiLimitState.value;
    final limitReached = !isLoading && !(limit!.canUse);

    if (limitReached) {
      final isOffline = !limit.isExpired && limit.reason != null && limit.reason!.contains('Internet');
      
      if (isOffline) {
        // ── OFFLINE MODE: Show subtle banner but ALLOW input ──
        // The model download prompt is shown if SLM is not downloaded.
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            border: Border(
              top: BorderSide(color: AppColors.textMuted.withValues(alpha: 0.1)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Offline banner
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone_android_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    const Text(
                      '📱 Offline Mode — On-device AI',
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Chat input (ENABLED for offline)
              _buildChatInput(),
            ],
          ),
        );
      }

      final cfg = ref.watch(appConfigProvider).value ?? const AppConfig();

      return Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          border: Border(
            top: BorderSide(color: AppColors.textMuted.withValues(alpha: 0.1)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              limit.isExpired
                  ? 'Free Trial Concluded'
                  : (limit.isNotStarted ? (cfg.trialPrice <= 0 ? 'Start ${cfg.trialDays}-Day Free Trial' : 'Start ₹${cfg.trialPrice.toInt()} Trial') : 'Daily AI Limit Reached'),
              style: TextStyle(
                color: limit.isExpired ? AppColors.error : AppColors.warning,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              limit.isExpired
                  ? 'Your ${cfg.trialDays}-day Free Trial has ended. There is no permanent free tier. Please upgrade to Pro (${cfg.proPrice}/mo) or Farm Pack (${cfg.farmPrice}/mo) to continue chatting with AI Plant Doctor.'
                  : (limit.isNotStarted
                      ? 'Activate your ${cfg.trialDays}-Day Trial (${cfg.trialPrice <= 0 ? "Free" : "₹${cfg.trialPrice.toInt()}"}) to ask up to ${limit.limit} questions every day to our AI Botanist.'
                      : 'You\'ve reached your daily limit of ${limit.limit} AI chats on your plan. Resets at midnight, or upgrade for higher allowances.'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
              textAlign: TextAlign.center,
            ),
            if (!limit.isExpired) ...[
              const SizedBox(height: 12),
              const _CountdownText(),
            ],
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => limit.isNotStarted ? const TrialActivationScreen() : const UpgradeScreen()),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(limit.isNotStarted ? Icons.stars_rounded : Icons.flash_on_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      limit.isExpired
                          ? 'UPGRADE TO PRO OR FARM'
                          : (limit.isNotStarted ? (cfg.trialPrice <= 0 ? 'START FREE TRIAL' : 'ACTIVATE ₹${cfg.trialPrice.toInt()} TRIAL') : 'UPGRADE PLAN'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _buildChatInput();
  }

  Widget _buildChatInput() {
    final aiLimitState = ref.watch(aiLimitProvider);
    final isLoading = aiLimitState.isLoading || aiLimitState.value == null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textCtrl,
              focusNode: _focusNode,
              enabled: !isLoading,
              style: TextStyle(color: isLoading ? AppColors.textMuted : AppColors.textPrimary, fontSize: 14),
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: isLoading ? 'Checking AI status...' : 'Ask about your plant...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
              ),
              onSubmitted: isLoading ? null : (v) => _sendMessage(v),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: (_isTyping || isLoading) ? null : () => _sendMessage(_textCtrl.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: (_isTyping || isLoading) ? null : AppColors.primaryGradient,
                color: (_isTyping || isLoading) ? AppColors.lightCard : null,
                shape: BoxShape.circle,
                boxShadow: (_isTyping || isLoading)
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Icon(
                Icons.send_rounded,
                size: 20,
                color: (_isTyping || isLoading) ? AppColors.textMuted : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _groq.dispose();
    super.dispose();
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  bool get isUser => message.role == 'user';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
              child: const Icon(Icons.smart_toy, size: 14, color: AppColors.secondary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primary
                    : AppColors.cardDark,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: AppColors.textMuted.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.content.isEmpty && !isUser)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: TypingIndicator(),
                    )
                  else if (isUser)
                    Text(
                      message.content,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        height: 1.5,
                      ),
                    )
                  else
                    MarkdownBody(
                      data: message.content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                        strong: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        em: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          fontStyle: FontStyle.italic,
                        ),
                        h1: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                        h2: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        h3: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        listBullet: const TextStyle(
                          fontSize: 14,
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.bold,
                        ),
                        code: TextStyle(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          color: AppColors.primaryLight,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(message.time),
                    style: TextStyle(
                      fontSize: 10,
                      color: isUser
                          ? Colors.white54
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.1, end: 0);
  }
}

class _CountdownText extends StatefulWidget {
  const _CountdownText();

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  late Timer _timer;
  late Duration _remaining;
  late DateTime _resetTime;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Midnight tomorrow
    _resetTime = DateTime(now.year, now.month, now.day + 1);
    _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _calculateRemaining();
    });
  }

  void _calculateRemaining() {
    setState(() {
      final now = DateTime.now();
      if (now.isAfter(_resetTime)) {
        _remaining = Duration.zero;
        // Optionally trigger a provider refresh here
      } else {
        _remaining = _resetTime.difference(now);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) {
      return const Text(
        'Daily limit has reset! Refreshing...',
        style: TextStyle(color: AppColors.primaryLight, fontSize: 13),
      );
    }
    
    final hours = _remaining.inHours.toString().padLeft(2, '0');
    final minutes = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    
    return Text(
      'Daily AI limit reached.\nResets in $hours:$minutes:$seconds',
      style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
      textAlign: TextAlign.center,
    );
  }
}
