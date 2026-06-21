// chat_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final String partnerId;
  final String partnerName;
  final String? partnerAvatar;

  const ChatScreen({
    super.key,
    required this.partnerId,
    required this.partnerName,
    this.partnerAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  // App Theme Constants
  static const Color primaryColor = Color(0xFF0B2B26);       // Dark Teal
  static const Color secondaryColor = Color(0xFF8EB69B);     // Soft Sage Green
  static const Color scaffoldBackground = Color(0xFFF2F0FA); // White Lilac

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    if (_channel != null) {
      Supabase.instance.client.realtime.removeChannel(_channel!);
    }
    super.dispose();
  }

  void _subscribeToRealtime() {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    _channel = client
        .channel('chat-${user.id}-${widget.partnerId}')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final newRecord = payload.newRecord;
        if (newRecord == null) return;

        final String? senderId = newRecord['sender_id']?.toString();
        final String? receiverId = newRecord['receiver_id']?.toString();

        if (payload.eventType == PostgresChangeEvent.insert) {
          if (senderId == widget.partnerId && receiverId == user.id) {
            final alreadyExists = _messages.any((m) => m['id'].toString() == newRecord['id'].toString());
            if (!alreadyExists && mounted) {
              setState(() {
                _messages.add(Map<String, dynamic>.from(newRecord));
                _scrollToBottom();
              });
              _markMessageAsRead(newRecord['id']);
            }
          }
          else if (senderId == user.id && receiverId == widget.partnerId) {
            final alreadyExists = _messages.any((m) => m['id'].toString() == newRecord['id'].toString());
            if (!alreadyExists && mounted) {
              setState(() {
                _messages.add(Map<String, dynamic>.from(newRecord));
                _scrollToBottom();
              });
            }
          }
        }
        else if (payload.eventType == PostgresChangeEvent.update) {
          if (mounted) {
            final index = _messages.indexWhere((m) => m['id'].toString() == newRecord['id'].toString());
            if (index != -1) {
              setState(() {
                _messages[index]['read_at'] = newRecord['read_at'];
              });
            }
          }
        }
      },
    );

    _channel!.subscribe();
  }

  Future<void> _loadMessages() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final response = await client
          .from('messages')
          .select()
          .or('and(sender_id.eq.${user.id},receiver_id.eq.${widget.partnerId}),and(sender_id.eq.${widget.partnerId},receiver_id.eq.${user.id})')
          .order('created_at', ascending: true);

      final List<Map<String, dynamic>> msgs = List<Map<String, dynamic>>.from(response);

      if (mounted) {
        setState(() {
          _messages = msgs;
          _loading = false;
        });
      }

      await _markAllAsRead();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: $e')),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    try {
      await client
          .from('messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('receiver_id', user.id)
          .eq('sender_id', widget.partnerId)
          .isFilter('read_at', null);
    } catch (e) {
      print('Error checking read status: $e');
    }
  }

  Future<void> _markMessageAsRead(dynamic messageId) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    try {
      await client
          .from('messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', messageId)
          .eq('receiver_id', user.id);
    } catch (e) {
      print('Individual read confirmation error: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    _messageController.clear();
    final clientMockId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final tempMessage = {
      'id': clientMockId,
      'sender_id': user.id,
      'receiver_id': widget.partnerId,
      'content': text,
      'created_at': DateTime.now().toIso8601String(),
      'read_at': null,
    };

    setState(() {
      _messages.add(tempMessage);
      _scrollToBottom();
    });

    try {
      final insertedData = await client.from('messages').insert({
        'sender_id': user.id,
        'receiver_id': widget.partnerId,
        'content': text,
      }).select();

      if (insertedData.isNotEmpty && mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == clientMockId);
          if (index != -1) {
            _messages[index] = Map<String, dynamic>.from(insertedData.first);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == clientMockId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Authentication error.')));

    return Scaffold(
      backgroundColor: scaffoldBackground,
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: secondaryColor.withOpacity(0.3),
              backgroundImage: widget.partnerAvatar != null && widget.partnerAvatar!.isNotEmpty
                  ? NetworkImage(widget.partnerAvatar!)
                  : null,
              child: widget.partnerAvatar == null || widget.partnerAvatar!.isEmpty
                  ? Text(
                widget.partnerName.isNotEmpty ? widget.partnerName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.partnerName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Online',
                    style: TextStyle(fontSize: 11, color: secondaryColor.withOpacity(0.9), fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam_outlined, size: 24), onPressed: () {}),
          IconButton(icon: const Icon(Icons.phone_outlined, size: 22), onPressed: () {}),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor)))
                : _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMine = msg['sender_id'] == user.id;
                final isRead = msg['read_at'] != null;
                return _buildMessageBubble(msg, isMine, isRead);
              },
            ),
          ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: primaryColor.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text(
            'Say hello to ${widget.partnerName}!',
            style: TextStyle(color: primaryColor.withOpacity(0.5), fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMine, bool isRead) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isMine ? 64 : 0,
          right: isMine ? 0 : 64,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? primaryColor : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              msg['content'] ?? '',
              style: TextStyle(
                color: isMine ? Colors.white : Colors.black87,
                fontSize: 15,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _formatTime(msg['created_at']),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMine ? Colors.white70 : Colors.grey[500],
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 13,
                    color: isRead ? secondaryColor : Colors.white60,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 24, top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: scaffoldBackground,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(Icons.sentiment_satisfied_alt_outlined, color: primaryColor.withOpacity(0.6)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(fontSize: 15, color: Colors.black87),
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.attach_file_rounded, color: primaryColor.withOpacity(0.6), size: 22),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                height: 48,
                width: 48,
                decoration: const BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return '';
    }
  }
}