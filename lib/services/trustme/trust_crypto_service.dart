import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TrustCryptoService {
  static final TrustCryptoService _instance = TrustCryptoService._internal();
  factory TrustCryptoService() => _instance;
  TrustCryptoService._internal();

  final _secureStorage = const FlutterSecureStorage();

  // Algorithms defined by the Trust Me Architecture
  final _identityAlgo = Ed25519();
  final _preKeyAlgo = X25519();

  // ===========================================================================
  // 1. INITIAL SETUP: GENERATE AND STORE ALL KEYS
  // ===========================================================================
  Future<Map<String, dynamic>> generateInitialKeyBundle() async {
    print("🔐 Generating Trust Me Cryptographic Keys...");

    // 1. Generate Permanent Identity Key Pair
    final identityKeyPair = await _identityAlgo.newKeyPair();
    final identityPubKey = await identityKeyPair.extractPublicKey();

    // 2. Generate Signed Pre-Key
    final signedPreKeyPair = await _preKeyAlgo.newKeyPair();
    final signedPreKeyPub = await signedPreKeyPair.extractPublicKey();

    // 3. Sign the Pre-Key with the Identity Key
    final signature = await _identityAlgo.sign(
      signedPreKeyPub.bytes,
      keyPair: identityKeyPair,
    );

    // 4. Generate 100 One-Time Pre-Keys
    List<Map<String, dynamic>> oneTimePreKeys = [];
    for (int i = 0; i < 100; i++) {
      final otpk = await _preKeyAlgo.newKeyPair();
      final otpkPub = await otpk.extractPublicKey();

      await _secureStorage.write(
        key: 'otpk_private_$i',
        value: base64Encode(await otpk.extractPrivateKeyBytes()),
      );

      oneTimePreKeys.add({'id': i, 'public_key': base64Encode(otpkPub.bytes)});
    }

    // 5. Save permanent private keys securely to device storage
    await _secureStorage.write(
      key: 'identity_private_key',
      value: base64Encode(await identityKeyPair.extractPrivateKeyBytes()),
    );
    await _secureStorage.write(
      key: 'signed_prekey_private_1',
      value: base64Encode(await signedPreKeyPair.extractPrivateKeyBytes()),
    );

    print("✅ Key Generation Complete.");

    // Return the PUBLIC bundle to be sent to the Desktop Postgres DB
    return {
      'identity_public_key': base64Encode(identityPubKey.bytes),
      'signed_prekey_public': base64Encode(signedPreKeyPub.bytes),
      'signed_prekey_id': 1,
      'signed_prekey_signature': base64Encode(signature.bytes),
      'one_time_prekeys': oneTimePreKeys,
    };
  }

  // ===========================================================================
  // 2. X3DH KEY AGREEMENT (HANDSHAKE COMPLETION)
  // ===========================================================================
  Future<String> performX3DH({
    required String theirIdentityPubBase64,
    required String theirSignedPreKeyPubBase64,
    required String theirSignedPreKeySignatureBase64,
  }) async {
    final theirIdentityPub = SimplePublicKey(
      base64Decode(theirIdentityPubBase64),
      type: KeyPairType.ed25519,
    );
    final theirSignedPreKeyBytes = base64Decode(theirSignedPreKeyPubBase64);
    final signatureBytes = base64Decode(theirSignedPreKeySignatureBase64);

    final isValid = await _identityAlgo.verify(
      theirSignedPreKeyBytes,
      signature: Signature(signatureBytes, publicKey: theirIdentityPub),
    );

    if (!isValid) {
      throw Exception(
        "🚨 SECURITY ALERT: Invalid signature. Handshake aborted.",
      );
    }

    final ephemeralKeyPair = await _preKeyAlgo.newKeyPair();
    final ephemeralPub = await ephemeralKeyPair.extractPublicKey();

    // The shared secret math would execute here in production.
    return base64Encode(ephemeralPub.bytes);
  }

  // ===========================================================================
  // 3. SIGNATURE VERIFICATION
  // ===========================================================================
  Future<String> signPayload(String payload) async {
    final myIdentityPrivateBytes = base64Decode(
      (await _secureStorage.read(key: 'identity_private_key'))!,
    );
    final keyPair = await _identityAlgo.newKeyPairFromSeed(
      myIdentityPrivateBytes,
    );

    final signature = await _identityAlgo.sign(
      utf8.encode(payload),
      keyPair: keyPair,
    );

    return base64Encode(signature.bytes);
  }
}




//hbuyguygugyu