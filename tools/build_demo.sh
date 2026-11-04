#!/usr/bin/env bash
# デモ（お試し版。APP_ENV=demo）をリリースビルドする。
#
# デモは Firestore・Authentication を、テスト用の代わりのもの（fake_cloud_firestore・
# firebase_auth_mocks）に差し替えて動く。これらは plugin_platform_interface の
# 「テスト用の代わりのものはリリースビルドでは使えない」というチェックに止められるため、
# デモのビルドのときだけ、そのチェックを外した plugin_platform_interface の写しを使う。
# 写しへの差し替えは pubspec_overrides.yaml で行い、ビルドが終わったら元に戻す
# （本番・テスト環境のビルドには影響しない）。
#
# 使い方（リポジトリ直下で実行）:
#   ./tools/build_demo.sh [flutter build web に渡す追加の引数...]
#   例: ./tools/build_demo.sh --base-href /LivingManager/
# 出力先: app/build/web

set -euo pipefail

app_dir="$(cd "$(dirname "$0")/../app" && pwd)"
cd "$app_dir"

flutter pub get

# 使っている plugin_platform_interface の版と、pub のキャッシュの場所
version=$(grep -A8 '^  plugin_platform_interface:' pubspec.lock | sed -n 's/^    version: "\(.*\)"$/\1/p')
if [ -n "${PUB_CACHE:-}" ]; then
  cache="$PUB_CACHE"
elif [ -n "${LOCALAPPDATA:-}" ]; then
  cache="$LOCALAPPDATA/Pub/Cache"
else
  cache="$HOME/.pub-cache"
fi
src="$cache/hosted/pub.dev/plugin_platform_interface-$version"
if [ ! -d "$src" ]; then
  echo "plugin_platform_interface が見つかりません: $src" >&2
  exit 1
fi

# チェックを外した写しを作る（アサーションが有効なときと同じ扱いにする）
patched="$app_dir/build/demo_overrides/plugin_platform_interface"
rm -rf "$patched"
mkdir -p "$(dirname "$patched")"
cp -r "$src" "$patched"
target="$patched/lib/plugin_platform_interface.dart"
sed -i 's/bool assertionsEnabled = false;/bool assertionsEnabled = true;/' "$target"
if ! grep -q 'bool assertionsEnabled = true;' "$target"; then
  echo "plugin_platform_interface の書き換えに失敗しました（版が変わって中身が違う可能性があります）" >&2
  exit 1
fi

restore() {
  rm -f pubspec_overrides.yaml
  flutter pub get > /dev/null
}
trap restore EXIT

cat > pubspec_overrides.yaml <<EOF
dependency_overrides:
  plugin_platform_interface:
    path: build/demo_overrides/plugin_platform_interface
EOF
# flutter build は pubspec.yaml が変わっていないと依存を取り直さないため、明示的に取り直す
flutter pub get

flutter build web --dart-define-from-file=demo_env.json "$@"
