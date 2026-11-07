import 'package:flutter/material.dart';
import '../../controllers/attendance_controller.dart';
import '../../models/attendance_model.dart';
import '../theme/app_design_tokens.dart';

class HistoryTab extends StatefulWidget {
  final AttendanceController controller;

  const HistoryTab({
    super.key,
    required this.controller,
  });

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  late int _selectedYear;
  late int _selectedMonth;
  late DateTime _selectedDate;
  String _viewMode = 'CALENDAR'; // 'CALENDAR' | 'TIMESHEET' | 'LOGS'

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  void _changeMonth(int delta) {
    setState(() {
      final next = DateTime(_selectedYear, _selectedMonth + delta, 1);
      _selectedYear = next.year;
      _selectedMonth = next.month;
      final now = DateTime.now();
      if (_selectedYear == now.year && _selectedMonth == now.month) {
        _selectedDate = DateTime(now.year, now.month, now.day);
      } else {
        _selectedDate = DateTime(_selectedYear, _selectedMonth, 1);
      }
    });
  }

  List<DailyTimesheetModel> _buildMonthSheets() {
    final daysInMonth = DateUtils.getDaysInMonth(_selectedYear, _selectedMonth);
    final List<DailyTimesheetModel> list = [];
    for (int d = 1; d <= daysInMonth; d++) {
      list.add(widget.controller.buildDailyTimesheet(DateTime(_selectedYear, _selectedMonth, d)));
    }
    return list;
  }

  List<AttendanceRecordModel> get _filteredLogs {
    final all = widget.controller.attendanceLogs;
    final prefix = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
    return all.where((r) => r.timestamp.startsWith(prefix)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monthSheets = _buildMonthSheets();

    double totalWorkUnits = 0.0;
    double totalWorkedHours = 0.0;
    int fullOnTimeDays = 0;
    int lateOrEarlyDays = 0;
    int halfOrAbsentDays = 0;
    int totalLateMins = 0;

    for (final s in monthSheets) {
      totalWorkUnits += s.workUnits;
      totalWorkedHours += s.totalWorkedHours;
      totalLateMins += s.totalLateMinutes;

      switch (s.status) {
        case DayAttendanceStatus.fullOnTime:
          fullOnTimeDays++;
          break;
        case DayAttendanceStatus.lateOrEarly:
          lateOrEarlyDays++;
          break;
        case DayAttendanceStatus.halfDay:
        case DayAttendanceStatus.absent:
        case DayAttendanceStatus.rejected:
          halfOrAbsentDays++;
          break;
        case DayAttendanceStatus.offOrFuture:
          break;
      }
    }

    final selectedSheet = widget.controller.buildDailyTimesheet(_selectedDate);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideFold = constraints.maxWidth >= 580;

        if (isWideFold) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 10,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildMonthSelectorBar(isDark),
                        const SizedBox(height: 12),
                        _buildSummaryBentoCard(
                          totalWorkUnits,
                          totalWorkedHours,
                          fullOnTimeDays,
                          lateOrEarlyDays,
                          halfOrAbsentDays,
                          totalLateMins,
                          isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildDayDetailCard(selectedSheet, isDark),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 12,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 110),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.cardSurface(isDark),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppDesignTokens.border(isDark)),
                      boxShadow: AppDesignTokens.softShadow(isDark),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildViewSwitchBar(isDark),
                        const SizedBox(height: 14),
                        Expanded(
                          child: _viewMode == 'CALENDAR'
                              ? SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: _buildCalendarGrid(monthSheets, isDark),
                                )
                              : (_viewMode == 'TIMESHEET'
                                  ? _buildTimesheetList(monthSheets, isDark)
                                  : _buildLogsList(isDark)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: widget.controller.fetchAttendanceLogs,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMonthSelectorBar(isDark),
                const SizedBox(height: 12),
                _buildSummaryBentoCard(
                  totalWorkUnits,
                  totalWorkedHours,
                  fullOnTimeDays,
                  lateOrEarlyDays,
                  halfOrAbsentDays,
                  totalLateMins,
                  isDark,
                ),
                const SizedBox(height: 12),
                _buildViewSwitchBar(isDark),
                const SizedBox(height: 12),
                if (_viewMode == 'CALENDAR') ...[
                  _buildCalendarGrid(monthSheets, isDark),
                  const SizedBox(height: 12),
                  _buildDayDetailCard(selectedSheet, isDark),
                ] else if (_viewMode == 'TIMESHEET') ...[
                  _buildTimesheetInline(monthSheets, isDark),
                ] else ...[
                  _buildLogsInline(isDark),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthSelectorBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface(isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppDesignTokens.border(isDark)),
        boxShadow: AppDesignTokens.softShadow(isDark),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _changeMonth(-1),
            icon: Icon(Icons.chevron_left_rounded, color: AppDesignTokens.textSecondary(isDark)),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Tháng ${_selectedMonth.toString().padLeft(2, '0')} / $_selectedYear',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppDesignTokens.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ca Sáng 08:00–12:00 • Ca Chiều 13:30–17:00',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppDesignTokens.textSecondary(isDark),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _changeMonth(1),
            icon: Icon(Icons.chevron_right_rounded, color: AppDesignTokens.textSecondary(isDark)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: widget.controller.isLoadingLogs ? null : widget.controller.fetchAttendanceLogs,
            icon: widget.controller.isLoadingLogs
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.refresh_rounded, color: AppDesignTokens.textSecondary(isDark), size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBentoCard(
    double totalUnits,
    double totalHours,
    int onTime,
    int lateOrEarly,
    int absent,
    int lateMins,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesignTokens.border(isDark)),
        boxShadow: AppDesignTokens.softShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppDesignTokens.brandPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.analytics_outlined, color: AppDesignTokens.brandPrimaryLight, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tổng Hợp Công • ${widget.controller.userName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppDesignTokens.textPrimary(isDark),
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppDesignTokens.subtleSurface(isDark),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${totalHours.toStringAsFixed(1)}h làm',
                  style: TextStyle(
                    color: AppDesignTokens.textSecondary(isDark),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _bentoStat('Tổng Công', totalUnits.toStringAsFixed(1), '/ 26 công', AppDesignTokens.brandPrimaryLight, isDark)),
              const SizedBox(width: 10),
              Expanded(child: _bentoStat('Đúng Giờ', '$onTime', 'ngày', AppDesignTokens.successEmerald, isDark)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _bentoStat('Muộn / Sớm', '$lateOrEarly', lateMins > 0 ? '($lateMins phút)' : 'ngày', AppDesignTokens.warningAmber, isDark)),
              const SizedBox(width: 10),
              Expanded(child: _bentoStat('Thiếu / Vắng', '$absent', 'ngày', AppDesignTokens.dangerRose, isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bentoStat(String label, String val, String unit, Color dotColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppDesignTokens.subtleSurface(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppDesignTokens.border(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppDesignTokens.textSecondary(isDark),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  val,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppDesignTokens.textPrimary(isDark),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  unit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppDesignTokens.textSecondary(isDark),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewSwitchBar(bool isDark) {
    final modes = [
      ('CALENDAR', Icons.calendar_month_rounded, 'Lịch Tháng'),
      ('TIMESHEET', Icons.view_timeline_rounded, 'Bảng Công'),
      ('LOGS', Icons.fact_check_rounded, 'Lịch Sử Quét'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppDesignTokens.subtleSurface(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppDesignTokens.border(isDark)),
      ),
      child: Row(
        children: modes.map((m) {
          final isSel = _viewMode == m.$1;
          return Expanded(
            child: Material(
              color: isSel ? AppDesignTokens.cardSurface(isDark) : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: () => setState(() => _viewMode = m.$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        m.$2,
                        size: 15,
                        color: isSel ? AppDesignTokens.textPrimary(isDark) : AppDesignTokens.textSecondary(isDark),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          m.$3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            color: isSel ? AppDesignTokens.textPrimary(isDark) : AppDesignTokens.textSecondary(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(List<DailyTimesheetModel> sheets, bool isDark) {
    final firstDay = DateTime(_selectedYear, _selectedMonth, 1);
    final leading = firstDay.weekday - 1;
    final headers = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesignTokens.border(isDark)),
      ),
      child: Column(
        children: [
          Row(
            children: headers
                .map(
                  (h) => Expanded(
                    child: Center(
                      child: Text(
                        h,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppDesignTokens.textSecondary(isDark),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leading + sheets.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.9,
            ),
            itemBuilder: (context, idx) {
              if (idx < leading) return const SizedBox.shrink();
              final s = sheets[idx - leading];
              final isSel = _selectedDate.day == s.date.day && _selectedDate.month == s.date.month;

              Color dot = Colors.transparent;
              String txt = '';

              switch (s.status) {
                case DayAttendanceStatus.fullOnTime:
                  dot = AppDesignTokens.successEmerald;
                  txt = '1.0';
                  break;
                case DayAttendanceStatus.lateOrEarly:
                  dot = AppDesignTokens.warningAmber;
                  txt = s.workUnits.toStringAsFixed(1);
                  break;
                case DayAttendanceStatus.halfDay:
                  dot = AppDesignTokens.brandPrimaryLight;
                  txt = '0.5';
                  break;
                case DayAttendanceStatus.absent:
                  dot = AppDesignTokens.textMuted(isDark);
                  txt = '0';
                  break;
                case DayAttendanceStatus.rejected:
                case DayAttendanceStatus.offOrFuture:
                  break;
              }

              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _selectedDate = s.date),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSel
                        ? AppDesignTokens.brandPrimary.withValues(alpha: isDark ? 0.18 : 0.10)
                        : AppDesignTokens.subtleSurface(isDark),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSel ? AppDesignTokens.brandPrimary : AppDesignTokens.border(isDark),
                      width: isSel ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${s.date.day}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                          color: AppDesignTokens.textPrimary(isDark),
                        ),
                      ),
                      if (txt.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 4.5,
                              height: 4.5,
                              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              txt,
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w600,
                                color: AppDesignTokens.textSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayDetailCard(DailyTimesheetModel s, bool isDark) {
    final d = s.date.day.toString().padLeft(2, '0');
    final m = s.date.month.toString().padLeft(2, '0');
    final weekdayNames = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ Nhật'];
    final wName = weekdayNames[s.date.weekday - 1];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesignTokens.border(isDark)),
        boxShadow: AppDesignTokens.softShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$wName, $d/$m/${s.date.year}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: AppDesignTokens.textPrimary(isDark),
                ),
              ),
              Text(
                'Tổng: ${s.workUnits} công (${s.totalWorkedHours}h)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                  color: AppDesignTokens.textSecondary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _slotMini('Vào Sáng', '08:00', s.morningIn, isDark)),
              const SizedBox(width: 8),
              Expanded(child: _slotMini('Ra Trưa', '12:00', s.morningOut, isDark)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _slotMini('Vào Chiều', '13:30', s.afternoonIn, isDark)),
              const SizedBox(width: 8),
              Expanded(child: _slotMini('Ra Chiều', '17:00', s.afternoonOut, isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slotMini(String name, String std, AttendanceRecordModel? rec, bool isDark) {
    final has = rec != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppDesignTokens.subtleSurface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppDesignTokens.border(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.textSecondary(isDark),
                ),
              ),
              Text(
                std,
                style: TextStyle(
                  fontSize: 10,
                  color: AppDesignTokens.textMuted(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            has ? '${rec.shortTime} (${rec.shiftLabel})' : '--:--',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: has ? AppDesignTokens.textPrimary(isDark) : AppDesignTokens.textMuted(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimesheetList(List<DailyTimesheetModel> sheets, bool isDark) {
    return ListView.separated(
      itemCount: sheets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, idx) => _timesheetRow(sheets[idx], isDark),
    );
  }

  Widget _buildTimesheetInline(List<DailyTimesheetModel> sheets, bool isDark) {
    return Column(
      children: sheets
          .take(15)
          .map((s) => Padding(padding: const EdgeInsets.only(bottom: 6), child: _timesheetRow(s, isDark)))
          .toList(),
    );
  }

  Widget _timesheetRow(DailyTimesheetModel s, bool isDark) {
    final d = s.date.day.toString().padLeft(2, '0');
    final m = s.date.month.toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppDesignTokens.border(isDark)),
      ),
      child: Row(
        children: [
          Text(
            '$d/$m',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: AppDesignTokens.textPrimary(isDark),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${s.morningIn?.shortTime ?? "--:--"} → ${s.morningOut?.shortTime ?? "--:--"}\n${s.afternoonIn?.shortTime ?? "--:--"} → ${s.afternoonOut?.shortTime ?? "--:--"}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppDesignTokens.textSecondary(isDark),
              ),
            ),
          ),
          Text(
            '${s.workUnits.toStringAsFixed(1)} công',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppDesignTokens.textPrimary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList(bool isDark) {
    final list = _filteredLogs;
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) => _logCard(list[idx], isDark),
    );
  }

  Widget _buildLogsInline(bool isDark) {
    final list = _filteredLogs;
    return Column(
      children: list
          .take(15)
          .map((rec) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _logCard(rec, isDark)))
          .toList(),
    );
  }

  Widget _logCard(AttendanceRecordModel r, bool isDark) {
    final ok = r.isSuccess;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignTokens.border(isDark)),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: ok ? AppDesignTokens.successEmerald : AppDesignTokens.dangerRose,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.typeLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: AppDesignTokens.textPrimary(isDark),
                  ),
                ),
                Text(
                  '${r.shiftLabel} • Cách ${r.distance}m • Khớp ${(r.similarity * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppDesignTokens.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
          Text(
            r.shortTime,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppDesignTokens.textPrimary(isDark),
            ),
          ),
        ],
      ),
    );
  }
}
