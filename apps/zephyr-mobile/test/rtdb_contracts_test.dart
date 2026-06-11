import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_mobile/services/rtdb_contracts.dart';

void main() {
  group('RtdbPresenceContract', () {
    test('normalizes valid presence and exposes live room context', () {
      final Map<String, dynamic> raw = <String, dynamic>{
        'schemaVersion': 1,
        'connection': 'online',
        'activity': 'free_live_host',
        'availability': 'available',
        'routing': <String, dynamic>{'directCall': true, 'randomCall': true},
        'displayStatus': 'live',
        'interruptible': true,
        'state': 'live',
        'roomId': 'room-1',
        'roomMode': 'free_live',
        'lastSeen': 1760000000000,
        'updatedAt': 1760000000000,
        'demo': <String, dynamic>{
          'simulator': 'for_you',
          'nextRotationAt': 1760000030000,
        },
      };

      final Map<String, dynamic> normalized = RtdbPresenceContract.normalize(
        raw,
      );

      expect(normalized['displayStatus'], 'live');
      expect(RtdbPresenceContract.liveRoomId(raw), 'room-1');
      expect(
        RtdbPresenceContract.demoNextRotationAt(raw),
        DateTime.fromMillisecondsSinceEpoch(1760000030000),
      );
    });

    test('fails closed for malformed, incoherent, or unknown presence', () {
      final Map<String, dynamic> malformed = <String, dynamic>{
        'schemaVersion': 1,
        'connection': 'online',
        'activity': 'free_live_host',
        'availability': 'available',
        'routing': <String, dynamic>{'directCall': true, 'randomCall': true},
        'displayStatus': 'live',
        'interruptible': true,
        'state': 'busy',
        'roomId': 'room-1',
        'lastSeen': 1760000000000,
        'updatedAt': 1760000000000,
      };

      expect(RtdbPresenceContract.displayStatus(malformed), 'offline');
      expect(RtdbPresenceContract.liveRoomId(malformed), isNull);
      expect(RtdbPresenceContract.displayStatus(null), 'offline');
      expect(
        RtdbPresenceContract.displayStatus(<String, dynamic>{
          ...malformed,
          'displayStatus': 'mystery',
          'state': 'mystery',
        }),
        'offline',
      );
      expect(
        RtdbPresenceContract.displayStatus(
          <String, dynamic>{...malformed, 'state': 'live'}..remove('lastSeen'),
        ),
        'offline',
      );
    });
  });

  group('RtdbProfileContract', () {
    test('parses complete visible identity and rejects malformed identity', () {
      final RtdbProfileData? profile =
          RtdbProfileContract.parse(<String, dynamic>{
            'displayName': ' Ava ',
            'avatarUrl': 'https://example.com/a.png',
            'countryCode': 'MU',
            'language': 'English',
            'birthday': '2000-01-01',
          });

      expect(profile, isNotNull);
      expect(profile!.displayName, 'Ava');
      expect(profile.avatarUrl, 'https://example.com/a.png');
      expect(RtdbProfileContract.parse(<String, dynamic>{}), isNull);
      expect(
        RtdbProfileContract.parse(<String, dynamic>{
          'displayName': '',
          'countryCode': 'MU',
          'language': 'English',
        }),
        isNull,
      );
    });
  });

  group('RtdbDirectCallSignalContract', () {
    test('builds and parses direct ringing signals', () {
      final Map<String, dynamic>? payload =
          RtdbDirectCallSignalContract.ringingPayload(
            callerId: 'alice',
            callerName: 'Alice',
            callerAvatarUrl: null,
            sessionId: 'session-1',
            timestamp: 1760000000000,
          );

      expect(payload, isNotNull);
      expect(payload!['status'], 'ringing');
      expect(RtdbDirectCallSignalContract.parse(payload), payload);
      expect(
        RtdbDirectCallSignalContract.ringingPayload(
          callerId: '',
          callerName: 'Alice',
          sessionId: 'session-1',
          timestamp: 1,
        ),
        isNull,
      );
    });

    test('accepts valid random events and rejects unusable signals', () {
      final Map<String, dynamic> matched = <String, dynamic>{
        'event': 'matched',
        'status': 'matched',
        'callerId': 'alice',
        'callerName': 'Alice',
        'sessionId': 'session-1',
        'appId': 'agora-app',
        'channelName': 'random-session-1',
        'uid': 123,
        'token': 'receiver-token',
        'partnerId': 'alice',
        'ts': 1760000000000,
      };

      expect(RtdbDirectCallSignalContract.parse(matched), matched);
      expect(
        RtdbDirectCallSignalContract.parse(<String, dynamic>{
          ...matched,
          'token': '',
        }),
        isNull,
      );
      expect(
        RtdbDirectCallSignalContract.parse(<String, dynamic>{
          'event': 'partner_left',
          'sessionId': 'session-1',
          'partnerId': 'alice',
          'ts': 1760000000000,
        }),
        isNotNull,
      );
      expect(
        RtdbDirectCallSignalContract.parse(<String, dynamic>{
          'status': 'cancelled',
          'callerId': 'alice',
          'sessionId': 'session-1',
          'ts': 1760000000000,
        }),
        isNull,
      );
    });
  });

  group('RtdbLiveRoomContract', () {
    test('parses live audience, comments, reactions, gifts, and end state', () {
      expect(
        RtdbLiveRoomContract.audienceCount(<String, dynamic>{
          'alice': <String, dynamic>{},
          'bob': <String, dynamic>{},
        }),
        2,
      );

      final RtdbLiveComment? comment = RtdbLiveRoomContract.comment(
        <String, dynamic>{
          'userId': 'alice',
          'name': 'Alice',
          'text': 'Hi',
          'ts': 1760000000000,
        },
      );
      expect(comment?.name, 'Alice');
      expect(RtdbLiveRoomContract.comment(<String, dynamic>{}), isNull);

      expect(
        RtdbLiveRoomContract.reactionEmoji(<String, dynamic>{
          'userId': 'bob',
          'emoji': 'heart',
          'ts': 1760000000000,
        }, 'alice'),
        'heart',
      );
      expect(
        RtdbLiveRoomContract.reactionEmoji(<String, dynamic>{
          'userId': 'alice',
          'emoji': 'heart',
          'ts': 1760000000000,
        }, 'alice'),
        isNull,
      );

      final RtdbLiveGift? gift = RtdbLiveRoomContract.gift(<String, dynamic>{
        'trusted': true,
        'senderName': 'Alice',
        'giftName': 'Rose',
        'quantity': 2,
        'ts': 1760000000000,
      });
      expect(gift?.quantity, 2);
      expect(
        RtdbLiveRoomContract.gift(<String, dynamic>{
          'senderName': 'Alice',
          'giftName': 'Rose',
          'quantity': 2,
          'ts': 1760000000000,
        }),
        isNull,
      );
      expect(RtdbLiveRoomContract.isEnded('ended'), isTrue);
      expect(RtdbLiveRoomContract.isEnded('live'), isFalse);
    });
  });
}
