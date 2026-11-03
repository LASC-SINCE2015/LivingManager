import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// アプリのルートウィジェット（テーマと画面遷移を束ねる）
class LivingManagerApp extends ConsumerWidget {
  const LivingManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppEnv.isDev ? 'おうちストック（テスト）' : 'おうちストック',
      theme: AppTheme.light,
      routerConfig: ref.watch(appRouterProvider),
      // テスト環境では、本番と取り違えないよう左上に「テスト」の帯を出す
      builder: AppEnv.isDev
          ? (context, child) => Banner(
                message: 'テスト',
                location: BannerLocation.topStart,
                color: Colors.deepOrange,
                child: child!,
              )
          : null,
    );
  }
}
