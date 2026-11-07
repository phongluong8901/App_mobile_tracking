import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class AuthUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String department;
  final String role;
  final String? idToken;
  final bool hasRegisteredFace;
  final DateTime createdAt;

  const AuthUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.department = 'Khối Công Nghệ & AI',
    this.role = 'Nhân Viên',
    this.idToken,
    this.hasRegisteredFace = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'department': department,
        'role': role,
        'idToken': idToken,
        'hasRegisteredFace': hasRegisteredFace,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      uid: json['uid']?.toString() ?? 'NV_001',
      email: json['email']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Nhân Viên',
      photoUrl: json['photoUrl']?.toString(),
      department: json['department']?.toString() ?? 'Khối Công Nghệ & AI',
      role: json['role']?.toString() ?? 'Nhân Viên',
      idToken: json['idToken']?.toString(),
      hasRegisteredFace: json['hasRegisteredFace'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;

  AuthService._internal() {
    // Mặc định hoàn toàn NULL - Chưa có đăng nhập, chuẩn Production
    _currentUser = null;
  }

  AuthUser? _currentUser;
  bool _isLoading = false;

  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;

  String get firebaseApiKey => dotenv.env['FIREBASE_WEB_API_KEY']?.trim() ?? '';
  String get firebaseProjectId => dotenv.env['FIREBASE_PROJECT_ID']?.trim() ?? '';

  bool get hasRealFirebaseKey => firebaseApiKey.isNotEmpty && !firebaseApiKey.startsWith('AIzaSyDemo');
  bool get hasRealProjectId => firebaseProjectId.isNotEmpty;

  // =========================================================================
  // 1. CLOUD FIRESTORE REAL DATABASE: LƯU HỒ SƠ VÀO CLOUD FIRESTORE
  // =========================================================================
  Future<bool> saveUserProfileToFirestore({
    required String localId,
    required AuthUser user,
    String? idToken,
  }) async {
    if (!hasRealProjectId) return false;

    try {
      final url = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$firebaseProjectId/databases/(default)/documents/users/$localId',
      );

      final firestorePayload = {
        'fields': {
          'uid': {'stringValue': user.uid},
          'email': {'stringValue': user.email},
          'displayName': {'stringValue': user.displayName},
          'department': {'stringValue': user.department},
          'role': {'stringValue': user.role},
          'photoUrl': {'stringValue': user.photoUrl ?? ''},
          'hasRegisteredFace': {'booleanValue': user.hasRegisteredFace},
          'updatedAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
          'createdAt': {'timestampValue': user.createdAt.toUtc().toIso8601String()},
        }
      };

      final headers = {'Content-Type': 'application/json'};
      if (idToken != null && idToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $idToken';
      }

      final res = await http.patch(
        url,
        headers: headers,
        body: jsonEncode(firestorePayload),
      ).timeout(const Duration(seconds: 8));

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[AuthService] Lỗi Firestore: $e');
      return false;
    }
  }

  /// Truy vấn hồ sơ nhân viên thực tế từ Firestore
  Future<Map<String, dynamic>?> fetchUserProfileFromFirestore({
    required String localId,
    String? idToken,
  }) async {
    if (!hasRealProjectId) return null;

    try {
      final url = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$firebaseProjectId/databases/(default)/documents/users/$localId',
      );

      final headers = <String, String>{};
      if (idToken != null && idToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $idToken';
      }

      final res = await http.get(url, headers: headers).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final Map<String, dynamic> doc = jsonDecode(res.body);
        final fields = doc['fields'] as Map<String, dynamic>?;
        if (fields != null) {
          return {
            'uid': fields['uid']?['stringValue'],
            'email': fields['email']?['stringValue'],
            'displayName': fields['displayName']?['stringValue'],
            'department': fields['department']?['stringValue'],
            'role': fields['role']?['stringValue'],
            'photoUrl': fields['photoUrl']?['stringValue'],
            'hasRegisteredFace': fields['hasRegisteredFace']?['booleanValue'] == true,
          };
        }
      }
    } catch (_) {}
    return null;
  }

  // =========================================================================
  // 2. ĐĂNG KÝ USER THẬT TRÊN FIREBASE AUTH & LƯU VÀO CLOUD FIRESTORE
  // =========================================================================
  Future<({bool success, String message})> register({
    required String email,
    required String password,
    required String displayName,
    String? employeeCode,
    String? department,
    String? role,
  }) async {
    _isLoading = true;
    notifyListeners();

    if (displayName.trim().isEmpty) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Vui lòng nhập họ và tên nhân viên!');
    }

    if (email.trim().isEmpty || !email.contains('@')) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Địa chỉ email công việc không hợp lệ!');
    }

    if (password.length < 6) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Mật khẩu phải từ 6 ký tự trở lên!');
    }

    if (!hasRealFirebaseKey) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Chưa cấu hình FIREBASE_WEB_API_KEY trong file .env!');
    }

    try {
      final authUrl = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$firebaseApiKey',
      );

      final response = await http.post(
        authUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'returnSecureToken': true,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final idToken = data['idToken']?.toString();
        final localId = data['localId']?.toString() ?? 'NV_${DateTime.now().millisecondsSinceEpoch}';

        final code = (employeeCode != null && employeeCode.trim().isNotEmpty)
            ? employeeCode.trim().toUpperCase()
            : 'NV_${localId.substring(0, minVal(5, localId.length))}';

        final newUser = AuthUser(
          uid: code,
          email: email.trim().toLowerCase(),
          displayName: displayName.trim(),
          department: (department != null && department.trim().isNotEmpty) ? department.trim() : 'Khối Vận Hành',
          role: (role != null && role.trim().isNotEmpty) ? role.trim() : 'Nhân Viên',
          idToken: idToken,
          createdAt: DateTime.now(),
        );

        // Lưu đồng bộ hồ sơ sang Cloud Firestore thật
        await saveUserProfileToFirestore(
          localId: localId,
          user: newUser,
          idToken: idToken,
        );

        _currentUser = newUser;
        AppConfig.currentUserId = _currentUser!.uid;
        AppConfig.userName = _currentUser!.displayName;

        _isLoading = false;
        notifyListeners();
        return (
          success: true,
          message: 'Tạo tài khoản Firebase & Lưu Firestore thành công (Mã NV: ${newUser.uid})!'
        );
      } else {
        final errCode = data['error']?['message']?.toString() ?? 'Lỗi đăng ký';
        _isLoading = false;
        notifyListeners();
        return (success: false, message: _mapFirebaseError(errCode));
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Lỗi kết nối Firebase: $e');
    }
  }

  // =========================================================================
  // 3. ĐĂNG NHẬP THẬT FIREBASE AUTH & LOAD PROFILE TỪ CLOUD FIRESTORE
  // =========================================================================
  Future<({bool success, String message})> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    if (email.trim().isEmpty || !email.contains('@')) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Vui lòng nhập email hợp lệ!');
    }

    if (password.length < 6) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Mật khẩu phải từ 6 ký tự trở lên!');
    }

    if (!hasRealFirebaseKey) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Chưa cấu hình FIREBASE_WEB_API_KEY!');
    }

    try {
      final authUrl = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$firebaseApiKey',
      );

      final response = await http.post(
        authUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'returnSecureToken': true,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final idToken = data['idToken']?.toString();
        final localId = data['localId']?.toString() ?? '';
        final authDisplayName = data['displayName']?.toString();

        // Đọc dữ liệu hồ sơ thực tế từ Cloud Firestore
        final firestoreProfile = await fetchUserProfileFromFirestore(
          localId: localId,
          idToken: idToken,
        );

        final uid = firestoreProfile?['uid'] ?? 'NV_${localId.substring(0, minVal(5, localId.length))}';
        final displayName = firestoreProfile?['displayName'] ?? (authDisplayName?.isNotEmpty == true ? authDisplayName! : _extractName(email));
        final department = firestoreProfile?['department'] ?? 'Khối Vận Hành';
        final role = firestoreProfile?['role'] ?? 'Nhân Viên';
        final photoUrl = firestoreProfile?['photoUrl'];
        final hasFace = firestoreProfile?['hasRegisteredFace'] == true;

        _currentUser = AuthUser(
          uid: uid,
          email: email.trim().toLowerCase(),
          displayName: displayName,
          department: department,
          role: role,
          photoUrl: photoUrl,
          hasRegisteredFace: hasFace,
          idToken: idToken,
          createdAt: DateTime.now(),
        );

        AppConfig.currentUserId = _currentUser!.uid;
        AppConfig.userName = _currentUser!.displayName;

        _isLoading = false;
        notifyListeners();
        return (
          success: true,
          message: 'Đăng nhập Firebase thành công! Chào mừng ${_currentUser!.displayName}'
        );
      } else {
        final errCode = data['error']?['message']?.toString() ?? 'Lỗi xác thực';
        _isLoading = false;
        notifyListeners();
        return (success: false, message: _mapFirebaseError(errCode));
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Lỗi kết nối Firebase: $e');
    }
  }

  // =========================================================================
  // 4. ĐỔI MẬT KHẨU FIREBASE THẬT
  // =========================================================================
  Future<({bool success, String message})> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _isLoading = true;
    notifyListeners();

    if (currentPassword.isEmpty) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Vui lòng nhập mật khẩu hiện tại!');
    }

    if (newPassword.length < 6) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Mật khẩu mới phải từ 6 ký tự!');
    }

    if (newPassword != confirmPassword) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Mật khẩu xác nhận không khớp!');
    }

    if (currentPassword == newPassword) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Mật khẩu mới không được trùng mật khẩu cũ!');
    }

    if (_currentUser?.idToken != null && hasRealFirebaseKey) {
      try {
        final url = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:update?key=$firebaseApiKey',
        );
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'idToken': _currentUser!.idToken,
            'password': newPassword,
            'returnSecureToken': true,
          }),
        );
        if (response.statusCode == 200) {
          _isLoading = false;
          notifyListeners();
          return (success: true, message: 'Cập nhật mật khẩu mới trên Firebase thành công!');
        }
      } catch (_) {}
    }

    _isLoading = false;
    notifyListeners();
    return (success: false, message: 'Không thể cập nhật mật khẩu trên Firebase!');
  }

  // =========================================================================
  // 5. GỬI EMAIL ĐẶT LẠI MẬT KHẨU THẬT QUA GOOGLE FIREBASE
  // =========================================================================
  Future<({bool success, String message})> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    notifyListeners();

    if (email.trim().isEmpty || !email.contains('@')) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Vui lòng nhập địa chỉ email hợp lệ!');
    }

    if (hasRealFirebaseKey) {
      try {
        final url = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$firebaseApiKey',
        );
        final res = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'requestType': 'PASSWORD_RESET',
            'email': email.trim(),
          }),
        );
        if (res.statusCode == 200) {
          _isLoading = false;
          notifyListeners();
          return (success: true, message: 'Firebase đã gửi email đặt lại mật khẩu đến $email!');
        }
      } catch (_) {}
    }

    _isLoading = false;
    notifyListeners();
    return (success: false, message: 'Không thể gửi email đặt lại mật khẩu Firebase!');
  }

  Future<void> signOut() async {
    _currentUser = null;
    notifyListeners();
  }

  String _extractName(String email) {
    final inferred = email.split('@').first.replaceAll('.', ' ');
    if (inferred.isEmpty) return 'Nhân Viên';
    return inferred[0].toUpperCase() + inferred.substring(1);
  }

  int minVal(int a, int b) => a < b ? a : b;

  String _mapFirebaseError(String code) {
    if (code.contains('EMAIL_EXISTS')) return 'Email này đã được đăng ký trên Firebase!';
    if (code.contains('EMAIL_NOT_FOUND')) return 'Không tìm thấy tài khoản nhân viên với email này!';
    if (code.contains('INVALID_PASSWORD') || code.contains('INVALID_LOGIN_CREDENTIALS')) {
      return 'Sai mật khẩu hoặc thông tin đăng nhập không đúng!';
    }
    if (code.contains('USER_DISABLED')) return 'Tài khoản nhân viên này đã bị khóa!';
    if (code.contains('TOO_MANY_ATTEMPTS_TRY_LATER')) return 'Thao tác quá nhiều lần! Vui lòng thử lại sau.';
    return 'Lỗi Firebase: $code';
  }
}
