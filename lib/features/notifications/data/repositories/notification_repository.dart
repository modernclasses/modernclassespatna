import '../../../../core/errors/error_handler.dart';
import '../datasources/notification_remote_data_source.dart';
import '../models/notification_model.dart';

abstract class NotificationRepository {
  Future<List<NotificationModel>> getNotifications();
  Future<void> broadcastAnnouncement(NotificationModel notification);
}

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource _remoteDataSource;

  NotificationRepositoryImpl({NotificationRemoteDataSource? remoteDataSource})
    : _remoteDataSource =
          remoteDataSource ?? NotificationRemoteDataSourceImpl();

  @override
  Future<List<NotificationModel>> getNotifications() async {
    try {
      return await _remoteDataSource.getNotifications();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> broadcastAnnouncement(NotificationModel notification) async {
    try {
      await _remoteDataSource.broadcastAnnouncement(notification);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
