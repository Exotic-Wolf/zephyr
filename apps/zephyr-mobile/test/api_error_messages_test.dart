import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_mobile/services/api_client.dart';
import 'package:zephyr_mobile/services/api_error_messages.dart';

void main() {
  group('directCallFailureMessage', () {
    test('maps known direct-call states to product copy', () {
      expect(
        directCallFailureMessage(
          const ZephyrApiException(
            statusCode: 400,
            message: 'Caller is busy in another live call',
            responseBody: '{}',
          ),
        ),
        'You are already in another call',
      );

      expect(
        directCallFailureMessage(
          const ZephyrApiException(
            statusCode: 400,
            message: 'Receiver is not available',
            responseBody: '{}',
          ),
        ),
        'They are not available right now',
      );
    });

    test('does not leak raw backend or Firebase setup errors', () {
      expect(
        directCallFailureMessage(
          Exception(
            '[firebase_database/permission-denied] permission_denied at /direct_calls/user: Client does not have permission to access the desired data.',
          ),
        ),
        'Your secure session changed. Please sign in again.',
      );

      expect(
        directCallFailureMessage(
          const ZephyrApiException(
            statusCode: 400,
            message:
                'directRateCoinsPerMinute must be an integer number, directRateCoinsPerMinute must not be less than 1',
            responseBody: '{}',
          ),
        ),
        'Call failed. Please try again.',
      );
    });
  });

  group('giftFailureMessage', () {
    test('maps common gift backend errors to product copy', () {
      expect(
        giftFailureMessage(
          const ZephyrApiException(
            statusCode: 400,
            message: 'Insufficient coin balance for gift',
            responseBody: '{}',
          ),
        ),
        'Not enough coins for this gift.',
      );

      expect(
        giftFailureMessage(
          const ZephyrApiException(
            statusCode: 400,
            message: 'Gift context does not match receiver',
            responseBody: '{}',
          ),
        ),
        'This chat changed. Reopen it and try again.',
      );
    });
  });
}
