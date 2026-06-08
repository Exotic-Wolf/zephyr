import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../chat/thread_firebase_page.dart';

Future<String?> showCallReportReasonSheet(BuildContext context) {
  const reasons = <String>[
    'Harassment or abuse',
    'Nudity or unsafe behavior',
    'Scam or payment request',
    'Other safety concern',
  ];

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext context) {
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const ListTile(
                title: Text('Report call'),
                subtitle: Text('Choose the closest reason.'),
              ),
              for (final reason in reasons)
                ListTile(
                  leading: const Icon(Icons.report_gmailerrorred_rounded),
                  title: Text(reason),
                  onTap: () => Navigator.of(context).pop(reason),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class CallEndedScreen extends StatefulWidget {
  const CallEndedScreen({
    super.key,
    required this.apiClient,
    required this.accessToken,
    required this.sessionId,
    required this.partnerId,
    required this.partnerName,
    this.partnerAvatarUrl,
    this.myUserId,
    this.myDisplayName,
    this.myAvatarUrl,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;
  final String sessionId;
  final String partnerId;
  final String partnerName;
  final String? partnerAvatarUrl;
  final String? myUserId;
  final String? myDisplayName;
  final String? myAvatarUrl;

  @override
  State<CallEndedScreen> createState() => _CallEndedScreenState();
}

class _CallEndedScreenState extends State<CallEndedScreen> {
  bool _reporting = false;
  bool _reported = false;

  Future<void> _reportCall() async {
    if (_reporting || _reported) return;
    final reason = await showCallReportReasonSheet(context);
    if (reason == null || !mounted) return;

    setState(() => _reporting = true);
    try {
      await widget.apiClient.reportCall(
        accessToken: widget.accessToken,
        sessionId: widget.sessionId,
        reportedUserId: widget.partnerId,
        reason: reason,
      );
      if (!mounted) return;
      setState(() => _reported = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report sent. Thank you.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send report. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  void _openMessage() {
    final myUserId = widget.myUserId;
    if (myUserId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ThreadFirebasePage(
          myUserId: myUserId,
          myDisplayName: widget.myDisplayName ?? 'User',
          myAvatarUrl: widget.myAvatarUrl,
          otherUserId: widget.partnerId,
          otherDisplayName: widget.partnerName,
          otherAvatarUrl: widget.partnerAvatarUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canMessage = widget.myUserId != null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CircleAvatar(
                    radius: 42,
                    backgroundImage: widget.partnerAvatarUrl != null
                        ? NetworkImage(widget.partnerAvatarUrl!)
                        : null,
                    child: widget.partnerAvatarUrl == null
                        ? Text(
                            widget.partnerName.isNotEmpty
                                ? widget.partnerName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontSize: 30),
                          )
                        : null,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Call ended',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.partnerName,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: canMessage ? _openMessage : null,
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text('Message'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('call-ended-report-button'),
                      onPressed: _reporting || _reported ? null : _reportCall,
                      icon: _reporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _reported
                                  ? Icons.verified_user_rounded
                                  : Icons.report_gmailerrorred_rounded,
                            ),
                      label: Text(_reported ? 'Reported' : 'Report call'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
