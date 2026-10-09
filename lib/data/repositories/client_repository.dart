import '../../core/storage/local_db.dart';
import '../../domain/qr/qr_payloads.dart';

/// Datos de vinculación del dispositivo cliente con su gimnasio.
class ClientLink {
  const ClientLink({
    required this.gymId,
    required this.gymName,
    required this.adminPublicKey,
    required this.clientId,
    required this.clientName,
    required this.deviceId,
    required this.nonce,
  });

  final String gymId;
  final String gymName;
  final String adminPublicKey;
  final String clientId;
  final String clientName;
  final String deviceId;
  final String nonce;

  Map<String, dynamic> toJson() => {
        'g': gymId,
        'gn': gymName,
        'apk': adminPublicKey,
        'c': clientId,
        'cn': clientName,
        'd': deviceId,
        'n': nonce,
      };

  factory ClientLink.fromJson(Map<String, dynamic> j) => ClientLink(
        gymId: j['g'] as String,
        gymName: j['gn'] as String,
        adminPublicKey: j['apk'] as String,
        clientId: j['c'] as String,
        clientName: j['cn'] as String,
        deviceId: j['d'] as String,
        nonce: j['n'] as String,
      );
}

/// Copia local y limitada de los datos del propio cliente (PRD §9.1).
class ClientRepository {
  ClientRepository._(this._box);
  final JsonBox _box;

  static Future<ClientRepository> open(LocalDb db) async => ClientRepository._(await db.box('state'));

  ClientLink? loadLink() {
    final j = _box.get('link');
    return j == null ? null : ClientLink.fromJson(j);
  }

  Future<void> saveLink(ClientLink l) => _box.put('link', l.toJson());

  ReceiptPayload? loadReceipt() {
    final j = _box.get('receipt');
    return j == null ? null : ReceiptPayload.tryParse(j);
  }

  DateTime? get lastSync => DateTime.tryParse(_box.get('sync')?['at'] as String? ?? '');

  Future<void> saveReceipt(ReceiptPayload r, DateTime receivedAt) async {
    await _box.put('receipt', r.toJson());
    await _box.put('sync', {'at': receivedAt.toIso8601String()});
  }

  List<Map<String, dynamic>> loadHistory() =>
      (_box.get('history')?['items'] as List? ?? const []).cast<Map<String, dynamic>>();

  Future<void> addHistory(Map<String, dynamic> item) async {
    final items = loadHistory().where((e) => e['pi'] != item['pi']).toList()..insert(0, item);
    await _box.put('history', {'items': items.take(100).toList()});
  }
}
