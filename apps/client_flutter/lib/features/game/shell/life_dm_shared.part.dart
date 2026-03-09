part of '../game_shell_page.dart';

class _DirectMessageAvatar extends StatelessWidget {
  const _DirectMessageAvatar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final trimmed = label.trim();
    final glyph = trimmed.isEmpty ? '?' : trimmed.substring(0, 1);
    return SizedBox(
      width: 46,
      height: 46,
      child: PixelPanel(
        tone: PixelTone.blue,
        padding: EdgeInsets.zero,
        cut: 10,
        shadowDepth: 2,
        child: Center(
          child: Text(
            glyph.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF1F2740),
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _DmSecurityStatus {
  const _DmSecurityStatus({required this.label, required this.tone});

  final String label;
  final PixelTone tone;
}

_DmSecurityStatus _resolveDmSecurityStatus({
  required AppStrings strings,
  required DmThreadSecuritySnapshot? security,
  required String? serverMode,
}) {
  final effectiveMode = serverMode ?? security?.threadMode;
  if (effectiveMode == DmE2eeService.encryptedMode) {
    return _DmSecurityStatus(label: strings.encrypted, tone: PixelTone.green);
  }
  if (security?.canEncryptNewMessages ?? false) {
    return _DmSecurityStatus(
      label: strings.encryptionReady,
      tone: PixelTone.blue,
    );
  }
  return _DmSecurityStatus(label: strings.notEncrypted, tone: PixelTone.slate);
}

String _resolveDmSecuritySubtitle({
  required AppStrings strings,
  required DmThreadSecuritySnapshot? security,
  required String? serverMode,
}) {
  final effectiveMode = serverMode ?? security?.threadMode;
  if (effectiveMode == DmE2eeService.encryptedMode) {
    return strings.encryptedSubtitle;
  }
  if (security?.canEncryptNewMessages ?? false) {
    return strings.encryptionReadySubtitle;
  }
  return strings.plaintextSubtitle;
}

class _DirectMessageTimelineEntry {
  const _DirectMessageTimelineEntry.day(this.dayLabel) : message = null;
  const _DirectMessageTimelineEntry.message(this.message) : dayLabel = null;

  final String? dayLabel;
  final DirectMessage? message;

  bool get isDayDivider => dayLabel != null;
}

List<_DirectMessageTimelineEntry> _buildDirectMessageTimeline(
  List<DirectMessage> messages,
  AppStrings strings,
) {
  final entries = <_DirectMessageTimelineEntry>[];
  DateTime? lastDay;
  for (final message in messages) {
    final local = message.sentAt.toLocal();
    final currentDay = DateTime(local.year, local.month, local.day);
    if (lastDay == null || !_sameCalendarDay(lastDay, currentDay)) {
      entries.add(
        _DirectMessageTimelineEntry.day(
          _formatDirectMessageDayLabel(currentDay, strings),
        ),
      );
      lastDay = currentDay;
    }
    entries.add(_DirectMessageTimelineEntry.message(message));
  }
  return entries;
}

bool _sameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _formatDirectMessageDayLabel(DateTime value, AppStrings strings) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  if (_sameCalendarDay(value, today)) {
    return strings.tr(zh: '今天', en: 'Today');
  }
  if (_sameCalendarDay(value, yesterday)) {
    return strings.tr(zh: '昨天', en: 'Yesterday');
  }
  if (value.year == today.year) {
    return '${value.month}/${value.day}';
  }
  return '${value.year}/${value.month}/${value.day}';
}

String _formatDirectMessageListTime(DateTime value, AppStrings strings) {
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final targetDay = DateTime(local.year, local.month, local.day);
  if (_sameCalendarDay(today, targetDay)) {
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  final yesterday = today.subtract(const Duration(days: 1));
  if (_sameCalendarDay(yesterday, targetDay)) {
    return strings.tr(zh: '昨天', en: 'Yday');
  }
  if (local.year == now.year) {
    return '${local.month}/${local.day}';
  }
  return '${local.year}/${local.month}/${local.day}';
}
