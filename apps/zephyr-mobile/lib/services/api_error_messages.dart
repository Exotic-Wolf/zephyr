import 'api_client.dart';

String apiErrorMessage(Object error) {
  if (error is ZephyrApiException) {
    return error.message;
  }

  final raw = error.toString().trim();
  const exceptionPrefix = 'Exception: ';
  if (raw.startsWith(exceptionPrefix)) {
    return raw.substring(exceptionPrefix.length).trim();
  }
  return raw;
}

String directCallFailureMessage(Object error) {
  final message = apiErrorMessage(error);
  final normalized = message.toLowerCase();

  if (normalized.contains('caller is busy')) {
    return 'You are already in another call';
  }
  if (normalized.contains('receiver is busy') || normalized.contains('busy')) {
    return 'They are on another call';
  }
  if (normalized.contains('receiver is not available')) {
    return 'They are not available right now';
  }
  if (normalized.contains('receiver not found')) {
    return 'This user is not available';
  }
  if (normalized.contains('cannot call this user')) {
    return 'Cannot call this user';
  }
  if (normalized.contains('insufficient')) {
    return 'Not enough coins for this call';
  }

  return message.isEmpty ? 'Call failed' : message;
}
