// chat_list_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late Future<List<Map<String, dynamic>>> _conversationsFuture;

  static const Color primaryColor = Color(0xFF0B2B26);
  static const Color secondaryColor = Color(0xFF8EB69B);
  static const Color scaffoldBackground = Color(0xFFF2F0FA);

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  void _loadConversations() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _conversationsFuture = Future.value([]);
      return;
    }
    _conversationsFuture = _fetchConversations(user.id);
    setState(() {});
  }

  Future<List<Map<String, dynamic>>> _fetchConversations(String userId) async {
    final client = Supabase.instance.client;

    try {
      // 1. Get all partner IDs from sent and received messages
      final sent = await client
          .from('messages')
          .select('receiver_id')
          .eq('sender_id', userId);
      final received = await client
          .from('messages')
          .select('sender_id')
          .eq('receiver_id', userId);

      Set<String> partnerIds = {};
      for (var row in sent as List) {
        if (row['receiver_id'] != null) {
          partnerIds.add(row['receiver_id'].toString());
        }
      }
      for (var row in received as List) {
        if (row['sender_id'] != null) {
          partnerIds.add(row['sender_id'].toString());
        }
      }

      if (partnerIds.isEmpty) return [];

      List<Map<String, dynamic>> conversations = [];

      for (String pid in partnerIds) {
        // 2. Get latest message from either direction
        final fromMe = await client
            .from('messages')
            .select('content, created_at, sender_id')
            .eq('sender_id', userId)
            .eq('receiver_id', pid)
            .order('created_at', ascending: false)
            .limit(1);

        final fromThem = await client
            .from('messages')
            .select('content, created_at, sender_id')
            .eq('sender_id', pid)
            .eq('receiver_id', userId)
            .order('created_at', ascending: false)
            .limit(1);

        Map<String, dynamic>? latestMsg;
        if (fromMe.isNotEmpty && fromThem.isNotEmpty) {
          final timeMe = DateTime.parse(fromMe[0]['created_at']);
          final timeThem = DateTime.parse(fromThem[0]['created_at']);
          latestMsg = timeMe.isAfter(timeThem) ? fromMe[0] : fromThem[0];
        } else if (fromMe.isNotEmpty) {
          latestMsg = fromMe[0];
        } else if (fromThem.isNotEmpty) {
          latestMsg = fromThem[0];
        }

        if (latestMsg == null) continue;

        // 3. Get unread count for this partner
        final unreadResponse = await client
            .from('messages')
            .select('id')
            .eq('receiver_id', userId)
            .eq('sender_id', pid)
            .isFilter('read_at', null);
        final unreadCount = (unreadResponse as List).length;

        // 4. Get partner profile (now allowed by the new RLS policy)
        final partnerProfile = await client
            .from('profiles')
            .select('full_name, avatar_url')
            .eq('id', pid)
            .maybeSingle();

        // Even if partnerProfile is null, we still add a conversation with a fallback name.
        conversations.add({
          'partner_id': pid,
          'full_name': partnerProfile?['full_name'] ?? 'Unknown User',
          'avatar_url': partnerProfile?['avatar_url'],
          'last_message': latestMsg['content'] ?? '',
          'last_message_time': latestMsg['created_at'],
          'unread_count': unreadCount,
          'last_sender_id': latestMsg['sender_id'],
        });
      }

      // Sort by latest message time (most recent first)
      conversations.sort((a, b) {
        if (a['last_message_time'] == null) return 1;
        if (b['last_message_time'] == null) return -1;
        return b['last_message_time'].compareTo(a['last_message_time']);
      });

      return conversations;
    } catch (e) {
      print('Error fetching conversations: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: scaffoldBackground,
        body: Center(
          child: Text(
            'Please log in to view messages.',
            style: TextStyle(color: primaryColor),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Messages',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () {
              setState(() => _loadConversations());
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _conversationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red[300], size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load conversations.',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _loadConversations()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final conversations = snapshot.data ?? [];
          if (conversations.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final convo = conversations[index];
              final isLastFromMe = convo['last_sender_id'] == user.id;
              final int unreadCount = convo['unread_count'] ?? 0;
              final hasUnread = unreadCount > 0;
              final String name = convo['full_name'];

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            partnerId: convo['partner_id'],
                            partnerName: convo['full_name'],
                            partnerAvatar: convo['avatar_url'],
                          ),
                        ),
                      ).then((_) => _loadConversations());
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: hasUnread ? secondaryColor : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: secondaryColor.withOpacity(0.2),
                                  backgroundImage: convo['avatar_url'] != null &&
                                      convo['avatar_url'].toString().isNotEmpty
                                      ? NetworkImage(convo['avatar_url'])
                                      : null,
                                  child: convo['avatar_url'] == null ||
                                      convo['avatar_url'].toString().isEmpty
                                      ? Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  )
                                      : null,
                                ),
                              ),
                              if (hasUnread)
                                Positioned(
                                  right: 2,
                                  bottom: 2,
                                  child: Container(
                                    height: 12,
                                    width: 12,
                                    decoration: BoxDecoration(
                                      color: secondaryColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  isLastFromMe
                                      ? 'You: ${convo['last_message']}'
                                      : convo['last_message'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                                    color: hasUnread ? Colors.black87 : Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _formatDateTime(convo['last_message_time']),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                                  color: hasUnread ? secondaryColor : Colors.grey[400],
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (hasUnread)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: const BoxConstraints(minWidth: 20),
                                  child: Text(
                                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              else
                                const SizedBox(height: 18),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 54, color: primaryColor.withOpacity(0.25)),
          const SizedBox(height: 16),
          const Text(
            'No conversations yet',
            style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Your chat records will appear here.',
            style: TextStyle(color: primaryColor.withOpacity(0.5), fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => setState(() => _loadConversations()),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final messageDate = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();

      if (messageDate.year == now.year &&
          messageDate.month == now.month &&
          messageDate.day == now.day) {
        final hour = messageDate.hour.toString().padLeft(2, '0');
        final minute = messageDate.minute.toString().padLeft(2, '0');
        return '$hour:$minute';
      } else if (now.difference(messageDate).inDays == 1) {
        return 'Yesterday';
      } else {
        return '${messageDate.day}/${messageDate.month}/${messageDate.year.toString().substring(2)}';
      }
    } catch (_) {
      return '';
    }
  }
}