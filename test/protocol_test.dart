import 'package:flutter_test/flutter_test.dart';
import 'package:gympass_control/core/crypto/key_manager.dart';
import 'package:gympass_control/core/crypto/signed_qr.dart';
import 'package:gympass_control/core/storage/secure_store.dart';
import 'package:gympass_control/domain/qr/qr_payloads.dart';

void main() {
  test('firma Ed25519: válida, manipulada y con clave ajena', () async {
    final admin = KeyManager(MemorySecretStore());
    final attacker = KeyManager(MemorySecretStore());
    await admin.ensureKeys();
    await attacker.ensureKeys();

    final payload = PayRequestPayload(
      clientId: 'c1', deviceId: 'd1', planId: 'plan_month', nonce: 'n1', createdAt: DateTime(2025)).toJson();
    final qr = await SignedQr.encode(payload, admin);
    final parsed = SignedQr.parse(qr)!;
    expect(parsed.type, 'pay');
    expect(await parsed.verifyWith(admin.publicKey), isTrue);
    expect(await parsed.verifyWith(attacker.publicKey), isFalse);

    // Manipular el payload invalida la firma.
    final parts = qr.split('.');
    final forged = await SignedQr.encode({...payload, 'p': 'plan_free'}, attacker);
    final mixed = '${parts[0]}.${forged.split('.')[1]}.${parts[2]}';
    expect(await SignedQr.parse(mixed)!.verifyWith(admin.publicKey), isFalse);
  });

  test('la clave persiste entre reinicios', () async {
    final store = MemorySecretStore();
    final a = KeyManager(store);
    await a.ensureKeys();
    final b = KeyManager(store);
    await b.ensureKeys();
    expect(a.publicKey, b.publicKey);
  });

  test('QR basura se rechaza', () {
    expect(SignedQr.parse('hola'), isNull);
    expect(SignedQr.parse('GPC1.xxx.yyy'), isNull);
  });
}

