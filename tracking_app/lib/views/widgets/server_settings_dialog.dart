import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../controllers/attendance_controller.dart';
import '../../services/attendance_api_service.dart';

class ServerSettingsDialog extends StatefulWidget {
  final AttendanceController controller;
  final VoidCallback onSaved;

  const ServerSettingsDialog({
    super.key,
    required this.controller,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context,
    AttendanceController controller,
    VoidCallback onSaved,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      backgroundColor: Colors.transparent,
      builder: (context) => ServerSettingsDialog(
        controller: controller,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<ServerSettingsDialog> createState() => _ServerSettingsDialogState();
}

class _ServerSettingsDialogState extends State<ServerSettingsDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _userIdController;
  late final TextEditingController _nameController;

  bool _isChecking = false;
  bool? _isOnline;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: AppConfig.serverUrl);
    _userIdController = TextEditingController(text: AppConfig.currentUserId);
    _nameController = TextEditingController(text: AppConfig.userName);
    _testConnection();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userIdController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isChecking = true;
      _statusText = 'Đang kiểm tra kết nối tới Server...';
    });

    AppConfig.serverUrl = _urlController.text;
    final result = await AppConfig.checkServerHealth();

    if (!mounted) return;
    setState(() {
      _isChecking = false;
      _isOnline = result.isOnline;
      _statusText = result.message;
    });
  }

  void _applyPreset(String url) {
    _urlController.text = url;
    _testConnection();
  }

  Future<void> _scanWifiServer() async {
    setState(() {
      _isChecking = true;
      _statusText = 'Đang tự quét mạng Wi-Fi tìm máy tính...';
    });

    final found = await AttendanceApiService().discoverWorkingServer();

    if (!mounted) return;
    if (found != null) {
      _urlController.text = found;
      _testConnection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Đã tìm thấy máy tính tại: $found'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    } else {
      setState(() {
        _isChecking = false;
        _isOnline = false;
        _statusText = 'Không tìm thấy máy tính. Hãy kiểm tra "npm run dev" trên PC.';
      });
    }
  }

  void _saveSettings() {
    AppConfig.serverUrl = _urlController.text;
    AppConfig.currentUserId = _userIdController.text;
    AppConfig.userName = _nameController.text;

    widget.controller.reconnectSocket();

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    widget.onSaved();

    messenger.showSnackBar(
      SnackBar(
        content: Text('✅ Đã lưu cấu hình: ${AppConfig.serverUrl}'),
        backgroundColor: const Color(0xFF059669),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 340;

    return Container(
      padding: EdgeInsets.only(
        top: 14,
        left: 18,
        right: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header (Chống tràn trên màn ngoài Fold 4)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.dns_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kết Nối Máy Chủ Backend',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Đồng bộ Wi-Fi & MongoDB Atlas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Trạng thái Ping Test
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _isOnline == true
                    ? const Color(0xFFECFDF5)
                    : (_isOnline == false ? const Color(0xFFFEF2F2) : Colors.white),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isOnline == true
                      ? const Color(0xFF34D399)
                      : (_isOnline == false ? const Color(0xFFF87171) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  if (_isChecking)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      _isOnline == true ? Icons.check_circle_rounded : Icons.error_rounded,
                      color: _isOnline == true ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      size: 20,
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusText.isEmpty ? 'Chưa kiểm tra' : _statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _isOnline == true
                            ? const Color(0xFF065F46)
                            : (_isOnline == false ? const Color(0xFF991B1B) : const Color(0xFF334155)),
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.refresh_rounded, size: 19),
                    tooltip: 'Kiểm tra lại',
                    onPressed: _testConnection,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Server URL Input
            _buildField(
              controller: _urlController,
              label: 'Địa chỉ Backend Server URL',
              hint: 'http://192.168.1.6:3000',
              icon: Icons.link_rounded,
            ),
            const SizedBox(height: 10),

            // Nút bấm gợi ý IP nhanh
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.wifi_find_rounded, size: 16, color: Color(0xFF2563EB)),
                  label: const Text(
                    'Quét Wi-Fi Tìm PC',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                  ),
                  backgroundColor: const Color(0xFFEFF6FF),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  onPressed: _isChecking ? null : _scanWifiServer,
                ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.wifi_rounded, size: 15, color: Color(0xFF059669)),
                  label: const Text(
                    'PC 192.168.1.6',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                  ),
                  backgroundColor: const Color(0xFFECFDF5),
                  side: const BorderSide(color: Color(0xFFA7F3D0)),
                  onPressed: () => _applyPreset('http://192.168.1.6:3000'),
                ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('Máy ảo (10.0.2.2)', style: TextStyle(fontSize: 11.5)),
                  onPressed: () => _applyPreset('http://10.0.2.2:3000'),
                ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('Localhost', style: TextStyle(fontSize: 11.5)),
                  onPressed: () => _applyPreset('http://localhost:3000'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Thông tin nhân viên (Tự xếp dọc nếu màn ngoài Fold 4 quá hẹp)
            if (isNarrow) ...[
              _buildField(
                controller: _userIdController,
                label: 'Mã Nhân Viên (User ID)',
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 10),
              _buildField(
                controller: _nameController,
                label: 'Họ và Tên Nhân Viên',
                icon: Icons.person_outline_rounded,
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      controller: _userIdController,
                      label: 'Mã NV (User ID)',
                      icon: Icons.badge_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildField(
                      controller: _nameController,
                      label: 'Tên Nhân Viên',
                      icon: Icons.person_outline_rounded,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 18),

            // Nút Lưu
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: const Text(
                  'LƯU & KẾT NỐI NGAY',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 19),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }
}
