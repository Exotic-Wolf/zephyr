import 'api_client.dart';

String apiErrorMessage(Object error) {
  if (error is ZephyrApiException) {
    return error.message;
  }

  final raw = _rawErrorText(error);
  final normalized = raw.toLowerCase();

  if (_isFirebasePermissionDeniedText(normalized) ||
      _isFirebaseUnauthorizedText(normalized)) {
    return 'Your secure session changed. Please sign in again.';
  }
  if (normalized.contains('unsupported image format')) {
    return 'This photo format is not supported. Try another photo.';
  }
  if (normalized.contains('image too large') ||
      normalized.contains('photo is too large')) {
    return 'This photo is too large. Choose a smaller photo.';
  }
  if (_isConnectionIssueText(normalized)) {
    return 'Connection issue. Please try again.';
  }
  if (normalized.startsWith('upload failed:')) {
    return 'Upload failed. Please try again.';
  }

  return raw.isEmpty ? 'Something went wrong. Please try again.' : raw;
}

String _rawErrorText(Object error) {
  if (error is ZephyrApiException) {
    return error.message.trim();
  }

  final raw = error.toString().trim();
  const exceptionPrefix = 'Exception: ';
  if (raw.startsWith(exceptionPrefix)) {
    return raw.substring(exceptionPrefix.length).trim();
  }
  return raw;
}

bool isAuthSessionInvalidError(Object error) {
  if (error is ZephyrApiException) {
    if (error.statusCode == 401) return true;
    if (error.statusCode == 403) {
      final String apiMessage = error.message.toLowerCase();
      return apiMessage.contains('another device') ||
          apiMessage.contains('expired') ||
          apiMessage.contains('invalid session') ||
          apiMessage.contains('session changed') ||
          apiMessage.contains('session moved') ||
          apiMessage.contains('stale session') ||
          apiMessage.contains('missing bearer') ||
          apiMessage.contains('invalid token');
    }
  }

  final String message = _rawErrorText(error).toLowerCase();
  return message.contains('another device') ||
      message.contains('expired') ||
      message.contains('invalid session') ||
      message.contains('session changed') ||
      message.contains('session moved') ||
      message.contains('stale session') ||
      message.contains('missing bearer') ||
      message.contains('invalid token');
}

bool isSessionMovedToAnotherDeviceError(Object error) {
  final String message = _rawErrorText(error).toLowerCase();
  return message.contains('another device') ||
      message.contains('session moved') ||
      message.contains('session changed') ||
      message.contains('stale session');
}

bool isFirebasePermissionDeniedError(Object error) {
  if (error is ZephyrApiException) return false;
  return _isFirebasePermissionDeniedText(_rawErrorText(error).toLowerCase());
}

bool _isFirebasePermissionDeniedText(String message) {
  return message.contains('permission-denied') ||
      message.contains('permission denied') ||
      message.contains('firebase database error: permission denied') ||
      message.contains('cloud_firestore/permission-denied') ||
      message.contains('firebase_database/permission-denied') ||
      message.contains('firebase_storage/unauthorized');
}

bool _isFirebaseUnauthorizedText(String message) {
  return message.contains('firebase') &&
      (message.contains('unauthorized') || message.contains('not authorized'));
}

bool _isConnectionIssueText(String message) {
  return message.contains('socket closed') ||
      message.contains('connection closed') ||
      message.contains('connection reset') ||
      message.contains('connection refused') ||
      message.contains('failed host lookup') ||
      message.contains('network is unreachable') ||
      message.contains('network error') ||
      message.contains('timed out') ||
      message.contains('timeout');
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
  if (normalized.contains('invalid direct call rate')) {
    return 'This call price is unavailable. Please try again.';
  }
  if (normalized.contains('secure session changed') ||
      normalized.contains('sign in again') ||
      normalized.contains('connection issue')) {
    return message;
  }

  return 'Call failed. Please try again.';
}
