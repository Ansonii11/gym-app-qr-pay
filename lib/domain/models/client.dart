import 'account_type.dart';

/// Socio del gimnasio (registro maestro en el teléfono del administrador).
class Client {
  const Client({
    required this.id,
    required this.name,
    required this.accountType,
    required this.createdAt,
    this.phone,
    this.shiftId,
    this.active = true,
    this.devicePublicKey,
    this.deviceId,
    this.inviteNonce,
    this.syncVersion = 0,
  });

  final String id;
  final String name;
  final String? phone;
  final AccountType accountType;
  final DateTime createdAt;
  final String? shiftId;
  final bool active;

  /// Clave pública Ed25519 del único dispositivo vinculado.
  final String? devicePublicKey;
  final String? deviceId;

  /// Nonce de invitación pendiente; se consume al vincular.
  final String? inviteNonce;

  /// Contador monotónico de paquetes emitidos al cliente (anti-rollback).
  final int syncVersion;

  bool get hasDevice => devicePublicKey != null;

  Client copyWith({
    String? name,
    String? phone,
    AccountType? accountType,
    String? shiftId,
    bool clearShift = false,
    bool? active,
    String? devicePublicKey,
    String? deviceId,
    bool clearDevice = false,
    String? inviteNonce,
    bool clearInvite = false,
    int? syncVersion,
  }) =>
      Client(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        accountType: accountType ?? this.accountType,
        createdAt: createdAt,
        shiftId: clearShift ? null : (shiftId ?? this.shiftId),
        active: active ?? this.active,
        devicePublicKey: clearDevice ? null : (devicePublicKey ?? this.devicePublicKey),
        deviceId: clearDevice ? null : (deviceId ?? this.deviceId),
        inviteNonce: clearInvite ? null : (inviteNonce ?? this.inviteNonce),
        syncVersion: syncVersion ?? this.syncVersion,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'type': accountType.code,
        'createdAt': createdAt.toIso8601String(),
        'shiftId': shiftId,
        'active': active,
        'devPk': devicePublicKey,
        'devId': deviceId,
        'invite': inviteNonce,
        'ver': syncVersion,
      };

  factory Client.fromJson(Map<String, dynamic> j) => Client(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        phone: j['phone'] as String?,
        accountType: AccountType.fromCode(j['type'] as String?),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        shiftId: j['shiftId'] as String?,
        active: j['active'] as bool? ?? true,
        devicePublicKey: j['devPk'] as String?,
        deviceId: j['devId'] as String?,
        inviteNonce: j['invite'] as String?,
        syncVersion: (j['ver'] as num?)?.toInt() ?? 0,
      );
}
