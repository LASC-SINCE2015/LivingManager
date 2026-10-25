import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/presentation/auth_providers.dart';

/// Firestore のデータがキャッシュから来ているか（サーバーとつながっていないか）
final _isFromCacheProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(currentUserProvider.select((user) => user?.uid));
  if (uid == null) return Stream.value(false);
  return ref
      .watch(firestoreProvider)
      .collection('items')
      .limit(1)
      .snapshots(includeMetadataChanges: true)
      .map((snap) => snap.metadata.isFromCache);
});

/// オフライン表示を出すか。
///
/// 起動直後や一瞬の切断で表示がちらつかないよう、キャッシュからの状態が
/// 3 秒続いたときだけ true にする。
class OfflineNotifier extends Notifier<bool> {
  static const _delay = Duration(seconds: 3);

  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    ref.listen<AsyncValue<bool>>(_isFromCacheProvider, (previous, next) {
      _timer?.cancel();
      if (next.value != true) {
        state = false;
        return;
      }
      _timer = Timer(_delay, () => state = true);
    });
    return false;
  }
}

final isOfflineProvider = NotifierProvider<OfflineNotifier, bool>(
  OfflineNotifier.new,
);
