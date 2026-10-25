import 'package:firebase_core/firebase_core.dart';

/// Firebase の接続設定。
///
/// 実際の値はリポジトリに含めず、`--dart-define-from-file` でビルド時に渡す
/// （キー名は firebase_env.example.json を参照）。
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
  );
}
