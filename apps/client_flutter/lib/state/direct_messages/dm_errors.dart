import '../../core/network/api_client.dart';

bool isUnauthorizedDirectMessageError(Object error) {
  return error is ApiException &&
      (error.statusCode == 401 || error.statusCode == 403);
}

String humanizeDirectMessageError(
  Object error, {
  required String fallbackZh,
  required String fallbackEn,
}) {
  if (isUnauthorizedDirectMessageError(error)) {
    return '登入狀態已過期，請重新登入後再開啟私訊。 Session expired, please sign in again.';
  }
  final compact = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  final snippet = compact.length > 120
      ? '${compact.substring(0, 120)}...'
      : compact;
  return '$fallbackZh / $fallbackEn: $snippet';
}
