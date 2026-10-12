import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/chat_service.dart';

final ChatService chatService = ChatService();

const _violet = Color(0xFF8A2BE2);
const _purple = Color(0xFF6A1B9A);

// Round gradient avatar with the first letter. Shared by the list and the
// chat header. (tag is unused now that the hero animation is removed)
class UserAvatar extends StatelessWidget {
  final String tag;
  final String name;
  final double radius;
  final bool ring;

  const UserAvatar({
    super.key,
    required this.tag,
    required this.name,
    this.radius = 22,
    this.ring = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [_violet, _purple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: ring ? Border.all(color: Colors.white54, width: 1.5) : null,
      ),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: radius * 0.85,
          color: Colors.white,
        ),
      ),
    );
  }
}

class ChatDetailScreen extends StatefulWidget {
  final String currentUserEmail;
  final Map<String, dynamic> tappedUser;

  const ChatDetailScreen({
    Key? key,
    required this.currentUserEmail,
    required this.tappedUser,
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final FocusNode _msgFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  late final String _currentUserId;
  late final String _tappedUserId;
  late final Stream<QuerySnapshot> _messagesStream;
  // only messages sent after opening the screen get the entrance animation
  final Timestamp _openedAt = Timestamp.now();
  // ids that already played their animation (so scrolling doesn't replay it)
  final Set<String> _animatedIds = {};
  bool _markingSeen = false;
  bool _canSend = false;
  bool _showJump = false; // "scroll to latest" button

  @override
  void initState() {
    super.initState();
    _currentUserId = chatService.firebaseAuth.currentUser?.uid ?? '';
    _tappedUserId = widget.tappedUser['uid'].toString();
    // create the stream once so typing doesn't restart it
    _messagesStream = chatService.getMessage(_currentUserId, _tappedUserId);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _msgFocus.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  // list is reversed, so offset 0 is the newest message
  void _onScroll() {
    final show = _scrollCtrl.hasClients && _scrollCtrl.offset > 300;
    if (show != _showJump) setState(() => _showJump = show);
  }

  void _scrollToLatest() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    // clear right away, the bubble shows "sending..." until it is saved
    _msgCtrl.clear();
    setState(() => _canSend = false);
    _msgFocus.requestFocus();
    _scrollToLatest();

    try {
      await chatService.sendMessage(_tappedUserId, text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Failed to send: $e'),
        ),
      );
    }
  }

  void _copy(String text) {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
          content: Text('Message copied'),
        ),
      );
  }

  // ---------- helpers ----------

  Map<String, dynamic> _dataOf(QueryDocumentSnapshot doc) =>
      doc.data() as Map<String, dynamic>;

  String _senderOf(QueryDocumentSnapshot doc) =>
      (_dataOf(doc)['senderId'] ?? '').toString();

  DateTime? _timeOf(QueryDocumentSnapshot doc) {
    final ts = _dataOf(doc)['timestamp'];
    if (ts is Timestamp) return ts.toDate();
    // a message that is still being saved has no server time yet
    if (doc.metadata.hasPendingWrites) return DateTime.now();
    return null;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatTime(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${t.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _dateLabel(DateTime t) {
    final now = DateTime.now();
    if (_sameDay(t, now)) return 'Today';
    if (_sameDay(t, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return '${_months[t.month - 1]} ${t.day}, ${t.year}';
  }

  // ---------- widgets ----------

  // small pill showing the date between messages
  Widget _dateChip(DateTime t, bool isDark) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(isDark ? 0.22 : 0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _dateLabel(t),
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ),
    );
  }

  // status icon: clock (sending) -> check (delivered) -> double check (seen)
  Widget _statusIcon({required bool pending, required bool seen}) {
    late final IconData icon;
    late final Color color;
    late final String key;
    if (pending) {
      icon = Icons.schedule;
      color = Colors.white70;
      key = 'pending';
    } else if (seen) {
      icon = Icons.done_all;
      color = Colors.lightBlueAccent;
      key = 'seen';
    } else {
      icon = Icons.done;
      color = Colors.white70;
      key = 'sent';
    }
    return SizedBox(
      width: 15,
      height: 15,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: anim,
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: Icon(icon, key: ValueKey(key), size: 14, color: color),
      ),
    );
  }

  // One chat bubble. The width follows the message. The time/status sits at the bottom-right inside the bubble.
  Widget _bubble(
    QueryDocumentSnapshot doc,
    Map<String, dynamic> data,
    bool isMe, {
    required bool firstInGroup,
    required bool lastInGroup,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final msgText = (data['message'] ?? '').toString();
    final time = _timeOf(doc);
    final pending = doc.metadata.hasPendingWrites; // not saved yet
    final seen = data['seen'] == true;

    final textColor =
        isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);
    final metaColor = isMe ? Colors.white70 : Colors.grey;

    // messages of the same sender stacked together have a flatter inner corner
    const big = Radius.circular(20);
    const small = Radius.circular(5);
    final topInner = firstInGroup ? big : small;
    final bottomInner = lastInGroup ? small : small;
    final radius = BorderRadius.only(
      topLeft: isMe ? big : topInner,
      topRight: isMe ? topInner : big,
      bottomLeft: isMe ? big : bottomInner,
      bottomRight: isMe ? bottomInner : big,
    );

    // empty space reserved at the end of the text so the time never overlaps it
    final reserve = (isMe ? 74 : 52).sp;

    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isMe && pending
              ? 'sending…'
              : (time != null ? _formatTime(time) : ''),
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10.sp,
            color: metaColor,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 3),
          _statusIcon(pending: pending, seen: seen),
        ],
      ],
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: msgText.isEmpty ? null : () => _copy(msgText),
        child: AnimatedOpacity(
          // slightly dimmed while it is still being saved
          opacity: isMe && pending ? 0.8 : 1,
          duration: const Duration(milliseconds: 200),
          child: Container(
            margin: EdgeInsets.fromLTRB(
              12,
              firstInGroup ? 10 : 2,
              12,
              lastInGroup ? 2 : 0,
            ),
            padding: const EdgeInsets.fromLTRB(13, 8, 10, 6),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            decoration: BoxDecoration(
              // my messages get a gradient, theirs stay grey
              gradient: isMe
                  ? const LinearGradient(
                      colors: [_violet, _purple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isMe
                  ? null
                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: (isMe ? _purple : Colors.black)
                      .withOpacity(isMe ? 0.22 : 0.05),
                  blurRadius: isMe ? 8 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: msgText.isNotEmpty ? msgText : '[empty]'),
                      WidgetSpan(child: SizedBox(width: reserve)),
                    ],
                  ),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.sp,
                    height: 1.35,
                    color: textColor,
                  ),
                ),
                Positioned(right: 0, bottom: 0, child: meta),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String name, bool isDark) {
    final color = isDark ? Colors.white54 : Colors.black45;
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutBack,
        builder: (context, v, child) => Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.85 + 0.15 * v, child: child),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _violet.withOpacity(isDark ? 0.18 : 0.1),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 34,
                  color: _violet,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No messages yet',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Say hi to $name',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.sp,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composer(bool isDark) {
    final fill = isDark ? const Color(0xFF2B2D33) : const Color(0xFFF2F2F5);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey.withOpacity(0.15)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  focusNode: _msgFocus,
                  textInputAction: TextInputAction.send,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 4,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp),
                  onChanged: (value) {
                    final can = value.trim().isNotEmpty;
                    if (can != _canSend) setState(() => _canSend = can);
                  },
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.sp,
                    ),
                    filled: true,
                    fillColor: fill,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // send button fills with the accent color once there is text
              AnimatedScale(
                scale: _canSend ? 1 : 0.92,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _canSend
                        ? const LinearGradient(
                            colors: [_violet, _purple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: _canSend
                        ? null
                        : (isDark ? Colors.grey.shade700 : Colors.grey.shade400),
                    boxShadow: _canSend
                        ? [
                            BoxShadow(
                              color: _purple.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: IconButton(
                    tooltip: 'Send',
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.send_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                    onPressed: _canSend ? _send : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // small round button to jump back to the newest message
  Widget _jumpButton(bool isDark) {
    return Positioned(
      right: 14,
      bottom: 12,
      child: IgnorePointer(
        ignoring: !_showJump,
        child: AnimatedScale(
          scale: _showJump ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Material(
            color: isDark ? const Color(0xFF2B2D33) : Colors.white,
            elevation: 3,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _scrollToLatest,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 24,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = ChatService.displayName(widget.tappedUser);
    final email = (widget.tappedUser['email'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        // gradient header
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_violet, _purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _purple.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            UserAvatar(
              tag: 'avatar_$_tappedUserId',
              name: name,
              radius: 18,
              ring: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.sp,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: Stack(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator.adaptive(),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                            'Error loading messages: ${snapshot.error}'),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    // mark messages I received as seen
                    final unseen = docs.where((d) {
                      final data = _dataOf(d);
                      return data['receiverId'] == _currentUserId &&
                          data['seen'] != true &&
                          !d.metadata.hasPendingWrites;
                    }).map((d) => d.reference).toList();
                    if (unseen.isNotEmpty && !_markingSeen) {
                      _markingSeen = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        try {
                          await chatService.markMessagesAsSeen(unseen);
                        } finally {
                          _markingSeen = false;
                        }
                      });
                    }

                    if (docs.isEmpty) return _emptyState(name, isDark);

                    return ListView.builder(
                      controller: _scrollCtrl,
                      reverse: true,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(top: 8, bottom: 10),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = _dataOf(doc);
                        final sender = _senderOf(doc);
                        final isMe = sender == _currentUserId;
                        final time = _timeOf(doc);

                        // list is reversed: index + 1 is older, index - 1 is newer
                        final older = index + 1 < docs.length
                            ? docs[index + 1]
                            : null;
                        final newer = index > 0 ? docs[index - 1] : null;
                        final olderTime = older != null ? _timeOf(older) : null;
                        final newerTime = newer != null ? _timeOf(newer) : null;

                        // date chip when the day changes
                        final showDate = time != null &&
                            (olderTime == null || !_sameDay(time, olderTime));

                        // group = consecutive messages of the same sender, same day
                        final firstInGroup = older == null ||
                            showDate ||
                            _senderOf(older) != sender;
                        final lastInGroup = newer == null ||
                            _senderOf(newer) != sender ||
                            (time != null &&
                                newerTime != null &&
                                !_sameDay(time, newerTime));

                        // only new messages animate in, and only once. A message
                        // that is still being saved has no server time yet, so
                        // pending writes count as new too.
                        final ts = data['timestamp'];
                        final isNew = doc.metadata.hasPendingWrites ||
                            (ts is Timestamp && ts.compareTo(_openedAt) >= 0);
                        final animate = isNew && !_animatedIds.contains(doc.id);

                        return Column(
                          children: [
                            if (showDate) _dateChip(time, isDark),
                            _AnimatedBubble(
                              key: ValueKey(doc.id),
                              animate: animate,
                              isMe: isMe,
                              onPlayed: () => _animatedIds.add(doc.id),
                              child: _bubble(
                                doc,
                                data,
                                isMe,
                                firstInGroup: firstInGroup,
                                lastInGroup: lastInGroup,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                _jumpButton(isDark),
              ],
            ),
          ),
          _composer(isDark),
        ],
      ),
    );
  }
}

// fades, slides in from its own side and scales up from its corner (plays once)
class _AnimatedBubble extends StatefulWidget {
  final bool animate;
  final bool isMe;
  final VoidCallback? onPlayed;
  final Widget child;

  const _AnimatedBubble({
    super.key,
    required this.animate,
    required this.isMe,
    required this.child,
    this.onPlayed,
  });

  @override
  State<_AnimatedBubble> createState() => _AnimatedBubbleState();
}

class _AnimatedBubbleState extends State<_AnimatedBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );
  late final Animation<double> _curve =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      widget.onPlayed?.call();
      _ctrl.forward();
    } else {
      _ctrl.value = 1;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) {
        final v = _curve.value;
        if (v >= 1) return child!;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset((widget.isMe ? 22 : -22) * (1 - v), 12 * (1 - v)),
            child: Transform.scale(
              scale: 0.9 + 0.1 * v,
              alignment:
                  widget.isMe ? Alignment.bottomRight : Alignment.bottomLeft,
              child: child,
            ),
          ),
        );
      },
    );
  }
}