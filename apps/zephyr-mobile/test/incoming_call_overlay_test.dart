import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_mobile/features/call/incoming_call_overlay.dart';

void main() {
  testWidgets('incoming call overlay portal appears above pushed routes', (
    WidgetTester tester,
  ) async {
    final harnessKey = GlobalKey<_IncomingCallPortalHarnessState>();
    var accepted = false;
    var threadTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: _IncomingCallPortalHarness(
          key: harnessKey,
          onAccept: () => accepted = true,
          onThreadTap: () => threadTapped = true,
        ),
      ),
    );

    await tester.tap(find.text('Open thread'));
    await tester.pumpAndSettle();
    expect(find.text('Thread route'), findsOneWidget);

    harnessKey.currentState!.showCall();
    await tester.pump();
    await tester.pump();

    expect(find.text('Mira'), findsOneWidget);
    expect(find.text('Incoming video call'), findsOneWidget);

    await tester.tap(find.text('Accept'));
    await tester.pump();

    expect(accepted, isTrue);
    expect(threadTapped, isFalse);
  });

  testWidgets('incoming call overlay fits tight safe-area phone viewports', (
    WidgetTester tester,
  ) async {
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final viewports = <_ViewportCase>[
      const _ViewportCase(
        label: 'iPhone compact safe area',
        size: Size(402, 700),
        padding: EdgeInsets.only(top: 59, bottom: 34),
      ),
      const _ViewportCase(
        label: 'Android compact navigation bar',
        size: Size(360, 640),
        padding: EdgeInsets.only(top: 28, bottom: 28),
      ),
      const _ViewportCase(
        label: 'small phone fallback',
        size: Size(320, 568),
        padding: EdgeInsets.only(top: 24, bottom: 20),
      ),
    ];

    for (final viewport in viewports) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewport.size;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: viewport.size,
              padding: viewport.padding,
            ),
            child: IncomingCallOverlay(
              callerId: 'caller-1',
              callerName: 'Mastermind Soul With Long Name',
              onAccept: () {},
              onReject: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(tester.takeException(), isNull, reason: viewport.label);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
    }
  });
}

class _ViewportCase {
  const _ViewportCase({
    required this.label,
    required this.size,
    required this.padding,
  });

  final String label;
  final Size size;
  final EdgeInsets padding;
}

class _IncomingCallPortalHarness extends StatefulWidget {
  const _IncomingCallPortalHarness({
    super.key,
    required this.onAccept,
    required this.onThreadTap,
  });

  final VoidCallback onAccept;
  final VoidCallback onThreadTap;

  @override
  State<_IncomingCallPortalHarness> createState() =>
      _IncomingCallPortalHarnessState();
}

class _IncomingCallPortalHarnessState
    extends State<_IncomingCallPortalHarness> {
  String? _callerId;

  void showCall() {
    setState(() => _callerId = 'caller-1');
  }

  @override
  Widget build(BuildContext context) {
    return IncomingCallOverlayPortal(
      callerId: _callerId,
      callerName: 'Mira',
      onAccept: widget.onAccept,
      onReject: () => setState(() => _callerId = null),
      child: Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onThreadTap,
                      child: const Center(child: Text('Thread route')),
                    ),
                  ),
                ),
              );
            },
            child: const Text('Open thread'),
          ),
        ),
      ),
    );
  }
}
