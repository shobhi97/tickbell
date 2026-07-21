import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/repository_providers.dart';
import 'notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(pushRepositoryProvider));
});
