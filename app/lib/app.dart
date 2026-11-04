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
      title: switch (AppEnv.current) {
        AppEnv.dev => 'おうちストック（テスト）',
        AppEnv.demo => 'おうちストック（デモ）',
        AppEnv.prod => 'おうちストック',
      },
      theme: AppTheme.light,
      routerConfig: ref.watch(appRouterProvider),
      // テスト環境・デモでは、本番と取り違えないよう左上に帯を出す
      builder: switch (AppEnv.current) {
        AppEnv.dev => (context, child) => Banner(
          message: 'テスト',
          location: BannerLocation.topStart,
          color: Colors.deepOrange,
          child: child!,
        ),
        AppEnv.demo => (context, child) => Banner(
          message: 'デモ',
          location: BannerLocation.topStart,
          color: Colors.indigo,
          child: child!,
        ),
        AppEnv.prod => null,
      },
    );
  }
}
