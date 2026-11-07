import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../controllers/attendance_controller.dart';
import '../../models/location_data.dart';
import '../../services/app_settings_service.dart';
import '../theme/app_design_tokens.dart';
import '../widgets/office_settings_dialog.dart';

class LocationTab extends StatefulWidget {
  final AttendanceController controller;
  final Function(String message, bool isSuccess) onShowMessage;

  const LocationTab({
    super.key,
    required this.controller,
    required this.onShowMessage,
  });

  @override
  State<LocationTab> createState() => _LocationTabState();
}

class _LocationTabState extends State<LocationTab> {
  final MapController _mapController = MapController();
  int _tileIndex = 0; // 0: OpenStreetMap Free, 1: Esri World Street Map Free
  LatLng? _lastMovedLatLng;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onPositionChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPositionChanged);
    super.dispose();
  }

  void _onPositionChanged() {
    final pos = widget.controller.currentPosition;
    if (pos != null) {
      final newLatLng = LatLng(pos.latitude, pos.longitude);
      if (_lastMovedLatLng == null ||
          _lastMovedLatLng!.latitude != newLatLng.latitude ||
          _lastMovedLatLng!.longitude != newLatLng.longitude) {
        _lastMovedLatLng = newLatLng;
        try {
          _mapController.move(newLatLng, 16.5);
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final pos = c.currentPosition;
    final isInside = c.isInsideGeofence;
    final distance = c.distanceToOffice;
    final officeLatLng = LatLng(c.officeLat, c.officeLng);
    final isDark = AppSettingsService.instance.isDarkMode;

    final Color statusColor = distance < 0
        ? AppDesignTokens.brandPrimaryLight
        : (isInside ? AppDesignTokens.successEmerald : AppDesignTokens.warningAmber);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideFold = constraints.maxWidth >= 580;

        return Stack(
          children: [
            // 1. Bản đồ Leaflet (OpenStreetMap & Esri miễn phí, không watermark)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: pos != null
                    ? LatLng(pos.latitude, pos.longitude)
                    : officeLatLng,
                initialZoom: 16.0,
                minZoom: 4.0,
                maxZoom: 19.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: _tileIndex == 0
                      ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                      : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.example.tracking_app',
                ),

                // Vòng tròn Geofence bán kính văn phòng công ty
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: officeLatLng,
                      radius: c.officeRadius,
                      useRadiusInMeter: true,
                      color: AppDesignTokens.brandPrimary.withValues(alpha: 0.16),
                      borderColor: AppDesignTokens.brandPrimaryLight,
                      borderStrokeWidth: 2.2,
                    ),
                    if (pos != null)
                      CircleMarker(
                        point: LatLng(pos.latitude, pos.longitude),
                        radius: 8.0,
                        useRadiusInMeter: false,
                        color: AppDesignTokens.accentCyan,
                        borderColor: Colors.white,
                        borderStrokeWidth: 2.5,
                      ),
                  ],
                ),

                // Marker Văn phòng & Marker Vị trí nhân viên
                MarkerLayer(
                  markers: [
                    // Marker Công ty
                    Marker(
                      point: officeLatLng,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: AppDesignTokens.glowShadow(const Color(0xFF1E3A8A)),
                        ),
                        child: const Icon(Icons.business_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                    // Marker Nhân viên GPS
                    if (pos != null)
                      Marker(
                        point: LatLng(pos.latitude, pos.longitude),
                        width: 46,
                        height: 46,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isInside ? AppDesignTokens.successEmerald : AppDesignTokens.dangerRose,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: AppDesignTokens.glowShadow(isInside ? AppDesignTokens.successEmerald : AppDesignTokens.dangerRose),
                          ),
                          child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 28),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // 2. Floating Header Geofence Status (Thanh trạng thái nổi)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isWideFold ? 560 : double.infinity),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.cardSurface(isDark).withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppDesignTokens.border(isDark)),
                      boxShadow: AppDesignTokens.softShadow(isDark),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.14), shape: BoxShape.circle),
                          child: Icon(
                            distance < 0 ? Icons.gps_fixed_rounded : (isInside ? Icons.check_circle_rounded : Icons.location_off_rounded),
                            color: statusColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                distance < 0
                                    ? 'Đang đồng bộ tọa độ GPS...'
                                    : (isInside ? 'Đủ điều kiện chấm công' : 'Ngoài bán kính cho phép'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppDesignTokens.textPrimary(isDark),
                                ),
                              ),
                              Text(
                                distance < 0
                                    ? '${c.officeName} (Bán kính ${c.officeRadius.toInt()}m)'
                                    : 'Cách văn phòng ${distance.toStringAsFixed(0)}m • Tối đa ${c.officeRadius.toInt()}m',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppDesignTokens.textSecondary(isDark),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.tune_rounded, size: 20, color: AppDesignTokens.textSecondary(isDark)),
                          tooltip: 'Chỉnh bán kính',
                          onPressed: () => OfficeSettingsDialog.show(context, c, () {}),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. Floating Bottom Controls: Đổi Map Layer & Live Tracking & Định vị
            Positioned(
              bottom: 104,
              left: 12,
              right: 12,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isWideFold ? 560 : double.infinity),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.cardSurface(isDark).withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppDesignTokens.border(isDark)),
                      boxShadow: AppDesignTokens.softShadow(isDark),
                    ),
                    child: Row(
                      children: [
                        // Nút Đổi bản đồ
                        IconButton(
                          icon: Icon(
                            _tileIndex == 0 ? Icons.layers_outlined : Icons.map_outlined,
                            color: AppDesignTokens.textPrimary(isDark),
                          ),
                          tooltip: 'Đổi kiểu bản đồ',
                          onPressed: () {
                            setState(() => _tileIndex = (_tileIndex + 1) % 2);
                            widget.onShowMessage(_tileIndex == 0 ? 'Đã đổi: OpenStreetMap' : 'Đã đổi: Esri Street Map', true);
                          },
                        ),
                        // Nút Định vị lại
                        IconButton(
                          icon: Icon(Icons.my_location_rounded, color: AppDesignTokens.textPrimary(isDark)),
                          tooltip: 'Định vị GPS hiện tại',
                          onPressed: () async {
                            final p = await c.fetchCurrentLocation();
                            if (p != null) {
                              _mapController.move(LatLng(p.latitude, p.longitude), 16.5);
                            }
                          },
                        ),
                        const SizedBox(width: 4),
                        // Nút Live Tracking Realtime
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () async {
                              final active = await c.toggleLiveTracking();
                              widget.onShowMessage(
                                active ? 'Đã bật Live Tracking GPS lên Dashboard' : 'Đã dừng Live Tracking',
                                active,
                              );
                            },
                            icon: Icon(
                              c.isTrackingLocation ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                              size: 18,
                            ),
                            label: Text(
                              c.isTrackingLocation ? 'Dừng Live' : 'Live Tracking GPS',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: c.isTrackingLocation ? AppDesignTokens.dangerRose : AppDesignTokens.brandPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
