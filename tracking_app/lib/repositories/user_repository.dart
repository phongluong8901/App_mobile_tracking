import '../config/app_config.dart';
import '../models/user_model.dart';

class UserRepository {
  UserModel getCurrentUser() {
    return UserModel(
      userId: AppConfig.currentUserId,
      name: AppConfig.userName,
    );
  }

  String getDeviceId() {
    return AppConfig.deviceId;
  }
}

