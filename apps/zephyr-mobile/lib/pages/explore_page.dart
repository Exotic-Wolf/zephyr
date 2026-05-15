import 'dart:async';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import 'profile_page.dart';
import 'thread_page.dart';

// ── ExplorePage ───────────────────────────────────────────────────────────────

class ExplorePage extends StatefulWidget {
  const ExplorePage({
    super.key,
    required this.apiClient,
    required this.accessToken,
    required this.myUserId,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;
  final String myUserId;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final TextEditingController _ctrl = TextEditingController();
  List<UserProfile> _results = <UserProfile>[];
  bool _searching = false;
  bool _hasSearched = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    q = q.trim();
    if (q == _lastQuery) return;
    _lastQuery = q;
    if (q.length < 2) {
      setState(() { _results = <UserProfile>[]; _hasSearched = false; });
      return;
    }
    setState(() => _searching = true);
    try {
      final List<UserProfile> res = await widget.apiClient.searchUsers(q);
      if (mounted && q == _lastQuery) {
        setState(() { _results = res; _hasSearched = true; _searching = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _searching = false; _hasSearched = true; });
    }
  }

  void _openProfile(UserProfile profile) {
    final LiveFeedCard card = LiveFeedCard(
      roomId: '',
      title: profile.displayName,
      hostUserId: profile.id,
      hostDisplayName: profile.displayName,
      hostAvatarUrl: profile.avatarUrl,
      hostCountryCode: profile.countryCode ?? 'XX',
      hostLanguage: profile.language ?? '',
      hostStatus: 'online',
      audienceCount: 0,
      startedAt: DateTime.now(),
    );
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ProfilePage(
        feedCard: card,
        apiClient: widget.apiClient,
        accessToken: widget.accessToken,
        myUserId: widget.myUserId,
        onMessage: () => Navigator.of(context).pop(),
      ),
    ));
  }

  void _openThread(UserProfile profile) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ThreadPage(
        apiClient: widget.apiClient,
        accessToken: widget.accessToken,
        myUserId: widget.myUserId,
        otherUserId: profile.id,
        otherDisplayName: profile.displayName,
        otherAvatarUrl: profile.avatarUrl,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: <Widget>[
          // ── Hero header ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFFFF8F00), Color(0xFFE53935)],
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Explore',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Find anyone by name or 8-digit ID',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Icon(Icons.search_rounded,
                              color: Color(0xFFFF8F00), size: 22),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            onChanged: _search,
                            textInputAction: TextInputAction.search,
                            onSubmitted: _search,
                            decoration: const InputDecoration(
                              hintText: 'Name or 8-digit ID…',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        if (_ctrl.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 18, color: Colors.grey),
                            onPressed: () {
                              _ctrl.clear();
                              _search('');
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Results / states ─────────────────────────────────────────────
          if (_searching)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!_hasSearched)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: <Color>[
                                const Color(0xFFFF8F00).withValues(alpha: 0.28),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[Color(0xFFFFF176), Color(0xFFFF8F00), Color(0xFFE53935)],
                              stops: <double>[0.0, 0.5, 1.0],
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: const Color(0xFFFF8F00).withValues(alpha: 0.55),
                                blurRadius: 32,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.explore_rounded,
                              color: Colors.white, size: 42),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Discover people',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Search by name or enter an\nexact 8-digit public ID',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            )
          else if (_results.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.person_search_rounded,
                        size: 56, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('No users found',
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey.shade500)),
                    const SizedBox(height: 4),
                    Text('Try a different name or ID',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade400)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext ctx, int i) {
                    final UserProfile p = _results[i];
                    return _ExploreUserCard(
                      profile: p,
                      onProfile: () => _openProfile(p),
                      onMessage: () => _openThread(p),
                    );
                  },
                  childCount: _results.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExploreUserCard extends StatelessWidget {
  const _ExploreUserCard({
    required this.profile,
    required this.onProfile,
    required this.onMessage,
  });

  final UserProfile profile;
  final VoidCallback onProfile;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onProfile,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                // Avatar
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      const Color(0xFF1FA4EA).withValues(alpha: 0.15),
                  backgroundImage: profile.avatarUrl != null
                      ? NetworkImage(profile.avatarUrl!)
                      : null,
                  child: profile.avatarUrl == null
                      ? Text(
                          profile.displayName.isNotEmpty
                              ? profile.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Color(0xFF1FA4EA),
                              fontWeight: FontWeight.w700,
                              fontSize: 18),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              profile.displayName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (profile.isAdmin) ...<Widget>[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: <Color>[
                                  Color(0xFFFFD700),
                                  Color(0xFFFFA500)
                                ]),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('OWNER',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          // ID pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1FA4EA)
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'ID: ${profile.publicId}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF1FA4EA),
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (profile.countryCode != null) ...<Widget>[
                            const SizedBox(width: 8),
                            Text(
                              profile.countryCode!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Action buttons
                Column(
                  children: <Widget>[
                    _ActionBtn(
                      icon: Icons.chat_bubble_rounded,
                      color: const Color(0xFF1FA4EA),
                      onTap: onMessage,
                    ),
                    const SizedBox(height: 8),
                    _ActionBtn(
                      icon: Icons.person_rounded,
                      color: const Color(0xFF7B5EA7),
                      onTap: onProfile,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

