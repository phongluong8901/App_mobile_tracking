import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../controllers/attendance_controller.dart';

/// Bottom sheet cài đặt vị trí công ty & bán kính chấm công.
/// - Chạm lên bản đồ mini để chọn tâm công ty
/// - Kéo thanh trượt để chỉnh bán kính (vòng tròn cập nhật trực tiếp)
class OfficeSettingsDialog extends StatefulWidget {
  final AttendanceController controller;
  final VoidCallback onSaved;

  const OfficeSettingsDialog({
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
      builder: (_) => OfficeSettingsDialog(controller: controller, onSaved: onSaved),
    );
  }

  @override
  State<OfficeSettingsDialog> createState() => _OfficeSettingsDialogState();
}

class _OfficeSettingsDialogState extends State<OfficeSettingsDialog> {
  static const _primary = Color(0xFF2563EB);
  static const _primaryDark = Color(0xFF1E3A8A);
  static const _success = Color(0xFF059669);
  static const _warning = Color(0xFFD97706);

  final MapController _miniMap = MapController();
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late final TextEditingController _nameCtrl;
  late LatLng _center;
  late double _radius;
  bool _isSaving = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    _center = LatLng(c.officeLat, c.officeLng);
    _radius = c.officeRadius.clamp(50, 2000).toDouble();
    _latCtrl = TextEditingController(text: _center.latitude.toStringAsFixed(6));
    _lngCtrl = TextEditingController(text: _center.longitude.toStringAsFixed(6));
    _nameCtrl = TextEditingController(text: c.officeName);
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  // ---------- Helpers ----------

  void _setCenter(LatLng p, {bool moveMap = true}) {
    setState(() {
      _center = p;
      _latCtrl.text = p.latitude.toStringAsFixed(6);
      _lngCtrl.text = p.longitude.toStringAsFixed(6);
    });
    if (moveMap) {
      try {
        _miniMap.move(p, _zoomForRadius(_radius));
      } catch (_) {}
    }
  }

  double _zoomForRadius(double r) {
    if (r <= 80) return 17.5;
    if (r <= 150) return 16.8;
    if (r <= 300) return 16;
    if (r <= 600) return 15;
    if (r <= 1200) return 14;
    return 13.2;
  }

  void _onCoordTyped() {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat == null || lng == null) return;
    if (lat.abs() > 90 || lng.abs() > 180) return;
    setState(() => _center = LatLng(lat, lng));
    try {
      _miniMap.move(_center, _zoomForRadius(_radius));
    } catch (_) {}
  }

  void _toast(String msg, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? _success : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    final pos = widget.controller.currentPosition ?? await widget.controller.fetchCurrentLocation();
    if (!mounted) return;
    setState(() => _isLocating = false);

    if (pos == null) {
      _toast('Không lấy được GPS. Hãy bật Vị trí trên điện thoại!', ok: false);
      return;
    }
    _setCenter(LatLng(pos.latitude, pos.longitude));
    _toast('📍 Đã đặt vị trí hiện tại làm công ty');
  }

  Future<void> _handleSave() async {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
      _toast('Tọa độ không hợp lệ!', ok: false);
      return;
    }

    setState(() => _isSaving = true);
    final name = _nameCtrl.text.trim().isEmpty ? 'Trụ sở công ty' : _nameCtrl.text.trim();
    final ok = await widget.controller.updateOfficeLocation(
      lat: lat,
      lng: lng,
      radius: _radius,
      name: name,
    );
    if (!mounted) return;

    // Lấy messenger TRƯỚC khi pop để tránh dùng context đã bị huỷ
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    widget.onSaved();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '✅ Đã lưu "$name" • bán kính ${_radius.toInt()}m (đồng bộ MongoDB)'
              : '⚠️ Đã lưu trên máy. Server chưa phản hồi, kiểm tra kết nối!',
        ),
        backgroundColor: ok ? _success : _warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final cur = widget.controller.currentPosition;
    final curLatLng = cur != null ? LatLng(cur.latitude, cur.longitude) : null;
    final preview = widget.controller.calculateDistanceToOffice(_center.latitude, _center.longitude);
    final inside = preview >= 0 && preview <= _radius;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade200,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              _header(),
              const SizedBox(height: 14),

              // ===== Bản đồ mini chọn vị trí =====
              _miniMapCard(curLatLng, inside),
              const SizedBox(height: 10),

              // ===== Nút lấy GPS hiện tại =====
              _gradientButton(
                icon: _isLocating ? null : Icons.my_location_rounded,
                loading: _isLocating,
                label: 'Dùng vị trí hiện tại của tôi',
                colors: const [_primary, Color(0xFF4F46E5)],
                onTap: _isLocating ? null : _useCurrentLocation,
                height: 46,
              ),
              const SizedBox(height: 16),

              // ===== Thông tin văn phòng =====
              _sectionCard(
                title: 'Thông tin văn phòng',
                icon: Icons.apartment_rounded,
                child: Column(
                  children: [
                    _input(_nameCtrl, 'Tên văn phòng / chi nhánh', Icons.badge_outlined),
                    const SizedBox(height: 10),
                    if (MediaQuery.sizeOf(context).width < 330) ...[
                      _input(_latCtrl, 'Vĩ độ (Latitude)', Icons.swap_vert_rounded,
                          number: true, onChanged: (_) => _onCoordTyped()),
                      const SizedBox(height: 10),
                      _input(_lngCtrl, 'Kinh độ (Longitude)', Icons.swap_horiz_rounded,
                          number: true, onChanged: (_) => _onCoordTyped()),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: _input(_latCtrl, 'Vĩ độ (Lat)', Icons.swap_vert_rounded,
                                number: true, onChanged: (_) => _onCoordTyped()),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _input(_lngCtrl, 'Kinh độ (Lng)', Icons.swap_horiz_rounded,
                                number: true, onChanged: (_) => _onCoordTyped()),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _presetChip('Hà Nội', 21.028511, 105.854444, Colors.indigo),
                          _presetChip('TP.HCM', 10.776889, 106.700806, Colors.teal),
                          _presetChip('Đà Nẵng', 16.054407, 108.202167, Colors.deepOrange),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ===== Bán kính =====
              _sectionCard(
                title: 'Bán kính chấm công',
                icon: Icons.radar_rounded,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_primary, _primaryDark]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_radius.toInt()} m',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        activeTrackColor: _primary,
                        inactiveTrackColor: _primary.withValues(alpha: 0.15),
                        thumbColor: Colors.white,
                        overlayColor: _primary.withValues(alpha: 0.12),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11, elevation: 3),
                      ),
                      child: Slider(
                        value: _radius,
                        min: 50,
                        max: 2000,
                        divisions: 39,
                        onChanged: (v) => setState(() => _radius = v),
                        onChangeEnd: (v) {
                          try {
                            _miniMap.move(_center, _zoomForRadius(v));
                          } catch (_) {}
                        },
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [50, 100, 200, 500, 1000].map((r) {
                        final sel = _radius.toInt() == r;
                        return ChoiceChip(
                          label: Text('${r}m'),
                          selected: sel,
                          showCheckmark: false,
                          selectedColor: _primary,
                          backgroundColor: Colors.white,
                          side: BorderSide(color: sel ? _primary : Colors.blueGrey.shade100),
                          labelStyle: TextStyle(
                            color: sel ? Colors.white : Colors.blueGrey.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          onSelected: (_) {
                            setState(() => _radius = r.toDouble());
                            try {
                              _miniMap.move(_center, _zoomForRadius(_radius));
                            } catch (_) {}
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ===== Xem trước khoảng cách =====
              if (preview >= 0) _previewBanner(preview, inside),
              if (preview >= 0) const SizedBox(height: 14),

              _gradientButton(
                icon: _isSaving ? null : Icons.cloud_done_rounded,
                loading: _isSaving,
                label: _isSaving ? 'Đang lưu...' : 'LƯU & ĐỒNG BỘ',
                colors: const [_success, Color(0xFF10B981)],
                onTap: _isSaving ? null : _handleSave,
                height: 52,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_primary, _primaryDark]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.location_city_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vị trí công ty',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              SizedBox(height: 2),
              Text('Chạm lên bản đồ để chọn tâm chấm công',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
            ],
          ),
        ),
        IconButton(
          style: IconButton.styleFrom(backgroundColor: Colors.white),
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _miniMapCard(LatLng? curLatLng, bool inside) {
    final ringColor = inside ? _success : _primary;
    return Container(
      height: 230,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _miniMap,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: _zoomForRadius(_radius),
                minZoom: 3,
                maxZoom: 19,
                onTap: (_, p) => _setCenter(p, moveMap: false),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'vn.phongluong.tracking.attendance',
                ),
                CircleLayer(circles: [
                  CircleMarker(
                    point: _center,
                    radius: _radius,
                    useRadiusInMeter: true,
                    color: ringColor.withValues(alpha: 0.16),
                    borderColor: ringColor,
                    borderStrokeWidth: 2.5,
                  ),
                ]),
                MarkerLayer(markers: [
                  if (curLatLng != null)
                    Marker(
                      point: curLatLng,
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.4), blurRadius: 8)],
                        ),
                      ),
                    ),
                  Marker(
                    point: _center,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.location_on_rounded, color: Color(0xFFDC2626), size: 44),
                  ),
                ]),
              ],
            ),
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app_rounded, size: 15, color: _primary),
                    SizedBox(width: 4),
                    Text('Chạm để chọn vị trí', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            if (curLatLng != null)
              Positioned(
                right: 10,
                bottom: 10,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: IconButton(
                    tooltip: 'Về vị trí của tôi',
                    icon: const Icon(Icons.gps_fixed_rounded, color: _primary, size: 20),
                    onPressed: () {
                      try {
                        _miniMap.move(curLatLng, 16.5);
                      } catch (_) {}
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _previewBanner(double d, bool inside) {
    final c = inside ? _success : _warning;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(inside ? Icons.verified_rounded : Icons.near_me_disabled_rounded, color: c, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bạn đang cách vị trí này ${_fmtDistance(d)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  inside ? 'Nằm trong bán kính – có thể chấm công' : 'Ngoài bán kính ${_radius.toInt()}m',
                  style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _input(
    TextEditingController c,
    String label,
    IconData icon, {
    bool number = false,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: c,
      onChanged: onChanged,
      keyboardType: number ? const TextInputType.numberWithOptions(decimal: true, signed: true) : null,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.6),
        ),
      ),
    );
  }

  Widget _presetChip(String label, double lat, double lng, MaterialColor color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(Icons.place_rounded, size: 16, color: color.shade700),
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color.shade900)),
        backgroundColor: color.shade50,
        side: BorderSide(color: color.shade100),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: () {
          _nameCtrl.text = 'Chi nhánh $label';
          _setCenter(LatLng(lat, lng));
        },
      ),
    );
  }

  Widget _gradientButton({
    required String label,
    required List<Color> colors,
    required VoidCallback? onTap,
    IconData? icon,
    bool loading = false,
    double height = 48,
  }) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled && !loading ? 0.6 : 1,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: colors.first.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  else if (icon != null)
                    Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _fmtDistance(double m) => m >= 1000 ? '${(m / 1000).toStringAsFixed(2)} km' : '${m.toInt()} m';
}
