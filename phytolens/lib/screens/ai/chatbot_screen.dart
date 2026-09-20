// lib/screens/ai/chatbot_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../data/chat_database.dart';
import '../../services/groq_service.dart';
import '../../services/local_llm_service.dart';
import '../../services/sync_service.dart';
import '../../services/scan_limiter.dart';
import '../../providers/ai_limit_provider.dart';
import '../../providers/ai_settings_provider.dart';
import '../../theme/colors.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/loading_dots.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/glass_button.dart';
import '../subscription/upgrade_screen.dart';
import '../subscription/trial_activation_screen.dart';
import '../../providers/app_config_provider.dart';

class ChatMessage {
  final int? id;
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime time;
  final String source; // 'online' | 'offline'

  const ChatMessage({
    this.id,
    required this.role,
    required this.content,
    required this.time,
    this.source = 'online',
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
  final _chatDb = ChatDatabase();
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isOffline = false;
  bool _isLoadingHistory = true;
  String? _sessionId;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    await _checkConnectivity();
    // Proactively push any unsynced offline chat usage
    _syncService.syncOfflineChatUsage();
    await _loadHistory();
    if (widget.initialMessage != null && widget.initialMessage!.trim().isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _sendMessage(widget.initialMessage!);
      });
    }
  }

  Future<void> _checkConnectivity() async {
    final online = await _syncService.isOnline();
    if (mounted) setState(() => _isOffline = !online);
  }

  Future<void> _loadHistory() async {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? 'guest_user';
    _userId = uid;
    try {
      _sessionId = await _chatDb.getOrCreateActiveSession(uid);
      final rawMsgs = await _chatDb.getSessionMessages(_sessionId!);
      if (rawMsgs.isNotEmpty) {
        _messages = rawMsgs.map((m) {
          return ChatMessage(
            id: m['id'] as int?,
            role: m['role'] as String,
            content: m['content'] as String,
            time: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
            source: m['source'] as String? ?? 'online',
          );
        }).toList();
      } else {
        _addWelcome();
      }
    } catch (e) {
      debugPrint('Error loading chat history from SQLite: $e');
      _addWelcome();
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
      _scrollToBottom();
    }
  }

  void _addWelcome() {
    final offlineNote = _isOffline
        ? '\n\n📱 *You are offline — I\'m using on-device AI. Quality may vary, but I\'m here to help!*'
        : '';
    final welcomeMsg = ChatMessage(
      role: 'assistant',
      content: '🌿 Hi! I\'m PhytoLens AI${_isOffline ? ' (Offline Mode)' : ''}. I can help with plant diseases, treatments, growing tips, and garden advice.$offlineNote\n\nWhat\'s on your mind today?',
      time: DateTime.now(),
      source: _isOffline ? 'offline' : 'online',
    );
    _messages = [welcomeMsg];
  }

  Future<void> _resetConversation() async {
    if (_userId == null) return;
    ref.read(aiLimitProvider.notifier).refreshLimit();
    try {
      final newSessionId = await _chatDb.createNewSession(_userId!);
      if (mounted) {
        setState(() {
          _sessionId = newSessionId;
          _messages = [];
          _addWelcome();
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Reset conversation error: $e');
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isTyping) return;

    // Re-check connectivity
    await _checkConnectivity();

    // Enforce AI limit check (both offline and online)
    final limitCheck = await ScanLimiter().checkAiLimit();
    if (!limitCheck.canUse) {
      if ((limitCheck.isExpired || limitCheck.isNotStarted) && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => limitCheck.isNotStarted ? const TrialActivationScreen() : const UpgradeScreen(),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(limitCheck.reason ?? 'Daily AI limit reached on your plan.'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final trimmedText = text.trim();
    final userMsg = ChatMessage(
      role: 'user',
      content: trimmedText,
      time: DateTime.now(),
      source: _isOffline ? 'offline' : 'online',
    );

    // Save user message immediately to local SQLite
    if (_sessionId != null && _userId != null) {
      await _chatDb.saveMessage(
        sessionId: _sessionId!,
        userId: _userId!,
        role: 'user',
        content: trimmedText,
        source: _isOffline ? 'offline' : 'online',
        synced: _isOffline ? 0 : 1,
      );
    }

    setState(() {
      _messages.add(userMsg);
      _messages.add(ChatMessage(
        role: 'assistant',
        content: '',
        time: DateTime.now(),
        source: _isOffline ? 'offline' : 'online',
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
        history.removeLast(); // Remove empty placeholder
      }

      Stream<String> stream;

      final isAiEngineEnabled = ref.read(aiEngineProvider);
      if (_isOffline || !isAiEngineEnabled) {
        // ── OFFLINE / AI ENGINE DISABLED: Use local LLM ──
        if (_llmService.isModelLoaded) {
          stream = _llmService.streamChat(trimmedText, history);
        } else if (await _llmService.isModelDownloaded()) {
          await _llmService.loadModel();
          stream = _llmService.streamChat(trimmedText, history);
        } else {
          // Model not downloaded — provide clear instruction
          if (mounted) {
            setState(() {
              final lastIdx = _messages.length - 1;
              _messages[lastIdx] = ChatMessage(
                role: 'assistant',
                content: !isAiEngineEnabled
                    ? '📱 AI Engine is disabled in settings. You need to download the offline AI model (~669 MB) in Settings to use the chatbot locally, or re-enable the AI Engine in Profile Settings.'
                    : '📱 The offline AI model needs to be downloaded first (~669 MB, one-time).\n\nGo to **Profile → AI Model Manager** to download, or connect to the internet to use cloud AI.',
                time: DateTime.now(),
                source: 'offline',
              );
              _isTyping = false;
            });
            if (_sessionId != null && _userId != null) {
              await _chatDb.saveMessage(
                sessionId: _sessionId!,
                userId: _userId!,
                role: 'assistant',
                content: _messages.last.content,
                source: 'offline',
                synced: 1,
              );
            }
          }
          return;
        }
      } else {
        // ── ONLINE: Use Groq ──
        stream = _groq.streamChat(trimmedText, history);
      }

      await for (final chunk in stream) {
        if (!mounted) break;
        setState(() {
          final lastIdx = _messages.length - 1;
          _messages[lastIdx] = ChatMessage(
            role: 'assistant',
            content: _messages[lastIdx].content + chunk,
            time: _messages[lastIdx].time,
            source: _isOffline ? 'offline' : 'online',
          );
        });
        _scrollToBottom();
      }

      // Sanitize response to prevent code leakage and tags
      final lastIdx = _messages.length - 1;
      final cleanedResponse = LocalLLMService.cleanResponse(_messages[lastIdx].content);
      if (mounted) {
        setState(() {
          _messages[lastIdx] = ChatMessage(
            role: 'assistant',
            content: cleanedResponse,
            time: _messages[lastIdx].time,
            source: _isOffline ? 'offline' : 'online',
          );
        });
      }

      // Persist assistant message to local SQLite
      if (_sessionId != null && _userId != null && cleanedResponse.isNotEmpty) {
        await _chatDb.saveMessage(
          sessionId: _sessionId!,
          userId: _userId!,
          role: 'assistant',
          content: cleanedResponse,
          source: _isOffline ? 'offline' : 'online',
          synced: 1,
        );
      }

      // Count offline or online usage
      if (_isOffline) {
        await ScanLimiter().incrementLocalAiCount();
      } else {
        final len = cleanedResponse.length;
        await ref.read(aiLimitProvider.notifier).recordUsage(len);
      }

      if (mounted) setState(() => _isTyping = false);
    } catch (e) {
      if (mounted) {
        final errMsg = _isOffline
            ? '⚠️ The on-device AI had a problem. Try closing other apps to free memory.'
            : '⚠️ Sorry, I couldn\'t get a response. Please check your connection and try again.';
        final lastIdx = _messages.length - 1;
        final cleanErr = LocalLLMService.cleanResponse(errMsg);
        setState(() {
          _messages[lastIdx] = ChatMessage(
            role: 'assistant',
            content: cleanErr,
            time: DateTime.now(),
            source: _isOffline ? 'offline' : 'online',
          );
          _isTyping = false;
        });

        if (_sessionId != null && _userId != null) {
          await _chatDb.saveMessage(
            sessionId: _sessionId!,
            userId: _userId!,
            role: 'assistant',
            content: cleanErr,
            source: _isOffline ? 'offline' : 'online',
            synced: 1,
          );
        }
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
        leadingWidth: 54,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: GlassButton.back(),
          ),
        ),
        title: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0x2600897B),
              child: Icon(Icons.smart_toy, color: AppColors.secondary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
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
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: GlassButton(
                size: 38,
                icon: Icons.refresh_rounded,
                iconSize: 19,
                tooltip: 'Reset Conversation',
                onTap: _resetConversation,
              ),
            ),
          ),
        ],
      ),
      body: _isLoadingHistory
          ? const Center(child: LoadingDots(size: 8, color: AppColors.primary))
          : Column(
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

                // Input bar with safe area padding
                _buildInputBar(),
              ],
            ),
    );
  }

  Widget _buildInputBar() {
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    final aiLimitState = ref.watch(aiLimitProvider);
    final isLoading = aiLimitState.isLoading || aiLimitState.value == null;
    final limit = aiLimitState.value;
    final limitReached = !isLoading && !(limit!.canUse);

    if (limitReached) {
      final isOffline = !limit.isExpired && limit.reason != null && limit.reason!.contains('Internet');
      
      if (isOffline) {
        // ── OFFLINE MODE: Show subtle banner but ALLOW input ──
        return Container(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + safeBottom),
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
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone_android_rounded, size: 16, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
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
              _buildChatInput(safeBottom: 0),
            ],
          ),
        );
      }

      final cfg = ref.watch(appConfigProvider).value ?? const AppConfig();

      return Container(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + safeBottom),
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

    return _buildChatInput(safeBottom: safeBottom);
  }

  Widget _buildChatInput({double? safeBottom}) {
    final bottomInset = safeBottom ?? MediaQuery.of(context).viewPadding.bottom;
    final aiLimitState = ref.watch(aiLimitProvider);
    final isLoading = aiLimitState.isLoading || aiLimitState.value == null;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomInset),
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
          BouncingButton(
            scaleFactor: 0.90,
            onTap: (_isTyping || isLoading) ? null : () => _sendMessage(_textCtrl.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: (_isTyping || isLoading) ? null : AppColors.primaryGradient,
                color: (_isTyping || isLoading) ? const Color(0xFFE2E8F0) : null,
                shape: BoxShape.circle,
                boxShadow: (_isTyping || isLoading)
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: Icon(
                Icons.arrow_upward_rounded,
                size: 22,
                color: (_isTyping || isLoading) ? AppColors.lightTextMuted : Colors.white,
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
                      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                      child: LoadingDots(size: 6, color: AppColors.secondary),
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
                        codeblockDecoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        codeblockPadding: const EdgeInsets.all(10),
                      ),
                    ),
                  if (message.content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('HH:mm').format(message.time),
                          style: TextStyle(
                            fontSize: 10,
                            color: isUser
                                ? Colors.white54
                                : AppColors.textMuted,
                          ),
                        ),
                        if (message.source == 'offline') ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.offline_bolt_rounded,
                            size: 11,
                            color: isUser ? Colors.white54 : AppColors.textMuted,
                          ),
                        ],
                      ],
                    ),
                  ],
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
