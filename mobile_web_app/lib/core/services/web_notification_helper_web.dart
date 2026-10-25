// Web implementation of web notification helpers using JS interop
import 'dart:js_interop';

@JS('cafeanaRequestNotificationPermission')
external JSPromise<JSString>? _cafeanaRequestNotificationPermission();

@JS('cafeanaShowNotification')
external JSPromise<JSBoolean>? _cafeanaShowNotification(
  JSString title,
  JSString body,
  JSString tag,
  JSString icon,
);

@JS('cafeanaGetNotificationPermission')
external JSString? _cafeanaGetNotificationPermission();

Future<bool> requestWebNotificationPermission() async {
  try {
    final promise = _cafeanaRequestNotificationPermission();
    if (promise == null) return false;
    final result = await promise.toDart;
    return result.toDart == 'granted';
  } catch (e) {
    return false;
  }
}

Future<bool> showWebNotification({
  required String title,
  required String body,
  String? tag,
  String? icon,
}) async {
  try {
    final promise = _cafeanaShowNotification(
      title.toJS,
      body.toJS,
      (tag ?? 'cafeana-order').toJS,
      (icon ?? 'favicon.png').toJS,
    );
    if (promise == null) return false;
    final result = await promise.toDart;
    return result.toDart;
  } catch (e) {
    return false;
  }
}

bool isWebNotificationSupported() {
  try {
    final perm = _cafeanaGetNotificationPermission();
    return perm != null && perm.toDart != 'unsupported';
  } catch (e) {
    return false;
  }
}
