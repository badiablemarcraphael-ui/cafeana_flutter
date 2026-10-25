// Stub implementation for non-web platforms

Future<bool> requestWebNotificationPermission() async => false;

Future<bool> showWebNotification({
  required String title,
  required String body,
  String? tag,
  String? icon,
}) async =>
    false;

bool isWebNotificationSupported() => false;
