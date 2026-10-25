import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  // 電波が弱い場所でも、最後に取得した内容を表示・操作できるようにする
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    webPersistentTabManager: WebPersistentMultipleTabManager(),
  );
  runApp(const ProviderScope(child: LivingManagerApp()));
}
