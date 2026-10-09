import '../../core/storage/local_db.dart';
import '../../domain/models/audit_entry.dart';
import '../../domain/models/client.dart';
import '../../domain/models/gym_settings.dart';
import '../../domain/models/payment.dart';
import '../../domain/models/plan.dart';
import '../../domain/models/shift.dart';

/// Persistencia de la base maestra del administrador (cifrada).
class AdminRepository {
  AdminRepository._(this._clients, this._payments, this._plans, this._shifts, this._meta, this._audit, this._nonces);

  final JsonBox _clients;
  final JsonBox _payments;
  final JsonBox _plans;
  final JsonBox _shifts;
  final JsonBox _meta;
  final JsonBox _audit;
  final JsonBox _nonces;

  static Future<AdminRepository> open(LocalDb db) async => AdminRepository._(
        await db.box('clients'),
        await db.box('payments'),
        await db.box('plans'),
        await db.box('shifts'),
        await db.box('meta'),
        await db.box('audit'),
        await db.box('nonces'),
      );

  // ---- Clientes
  List<Client> loadClients() => _clients.all().map(Client.fromJson).toList();
  Future<void> saveClient(Client c) => _clients.put(c.id, c.toJson());

  // ---- Pagos (nunca se eliminan)
  List<Payment> loadPayments() => _payments.all().map(Payment.fromJson).toList();
  Future<void> savePayment(Payment p) => _payments.put(p.id, p.toJson());

  // ---- Planes
  List<Plan> loadPlans() => _plans.all().map(Plan.fromJson).toList();
  Future<void> savePlan(Plan p) => _plans.put(p.id, p.toJson());

  // ---- Turnos
  List<Shift> loadShifts() => _shifts.all().map(Shift.fromJson).toList();
  Future<void> saveShift(Shift s) => _shifts.put(s.id, s.toJson());
  Future<void> deleteShift(String id) => _shifts.delete(id);

  // ---- Ajustes y metadatos
  GymSettings loadSettings() {
    final j = _meta.get('settings');
    return j == null ? const GymSettings() : GymSettings.fromJson(j);
  }

  Future<void> saveSettings(GymSettings s) => _meta.put('settings', s.toJson());

  String? get gymId => _meta.get('gym')?['id'] as String?;
  Future<void> setGymId(String id) => _meta.put('gym', {'id': id});

  bool get seeded => _meta.get('seed')?['done'] == true;
  Future<void> markSeeded() => _meta.put('seed', {'done': true});

  // ---- Auditoría
  List<AuditEntry> loadAudit() => _audit.all().map(AuditEntry.fromJson).toList()
    ..sort((a, b) => b.at.compareTo(a.at));
  Future<void> addAudit(AuditEntry e) => _audit.put(e.id, e.toJson());

  // ---- Nonces consumidos (anti-repetición / idempotencia)
  bool nonceUsed(String nonce) => _nonces.contains(nonce);
  String? paymentForNonce(String nonce) => _nonces.get(nonce)?['pid'] as String?;
  Future<void> markNonce(String nonce, String paymentId, DateTime at) =>
      _nonces.put(nonce, {'pid': paymentId, 'at': at.toIso8601String()});
  Future<void> releaseNonce(String nonce) => _nonces.delete(nonce);
}
