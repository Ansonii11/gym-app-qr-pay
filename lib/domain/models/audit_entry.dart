/// Registro de auditoría inmutable.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.at,
    this.targetId,
    this.detail,
    this.reason,
  });

  final String id;
  final String action;
  final DateTime at;
  final String? targetId;
  final String? detail;
  final String? reason;

  Map<String, dynamic> toJson() => {
        'id': id,
        'action': action,
        'at': at.toIso8601String(),
        'target': targetId,
        'detail': detail,
        'reason': reason,
      };

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        id: j['id'] as String,
        action: j['action'] as String? ?? '',
        at: DateTime.parse(j['at'] as String),
        targetId: j['target'] as String?,
        detail: j['detail'] as String?,
        reason: j['reason'] as String?,
      );
}
