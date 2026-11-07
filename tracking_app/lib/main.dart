import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/app_config.dart';
import 'services/app_settings_service.dart';
import 'services/auth_service.dart';
import 'views/attendance_screen.dart';
import 'views/auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  await AppConfig.init();

  runApp(const TrackingAttendanceApp());
}

class TrackingAttendanceApp extends StatelessWidget {
  const TrackingAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsService.instance;
    final auth = AuthService.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([settings, auth]),
      builder: (context, _) {
        return MaterialApp(
          title: 'Smart Attendance & GPS',
          debugShowCheckedModeBanner: false,
          theme: settings.activeTheme,
          builder: (context, child) {
            // Giữ tỷ lệ chữ ổn định trên Samsung OneUI & màn hình gập Galaxy Z Fold 4
            return MediaQuery.withClampedTextScaling(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.1,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: auth.isAuthenticated
              ? const AttendanceScreen()
              : LoginScreen(
                  onLoginSuccess: () {
                    // Tự động rebuild chuyển vào AttendanceScreen
                  },
                ),
        );
      },
    );
  }
}
