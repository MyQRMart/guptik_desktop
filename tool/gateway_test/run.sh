#!/usr/bin/env bash
# Extracts the embedded gateway libraries and runs their tests in a scratch Dart project.
# Needs `dart` on PATH and network access for `dart pub get`.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="${1:-/tmp/gateway_test_work}"
rm -rf "$WORK" && mkdir -p "$WORK/lib" "$WORK/test"
(cd "$ROOT" && dart run tool/gateway_test/dump.dart "$WORK/lib")
cp "$ROOT/tool/gateway_test/gateway_auth_test.dart" "$WORK/test/"
sed -i "s#'../lib/gateway_auth.dart'#'package:gwtest/gateway_auth.dart'#" "$WORK/test/gateway_auth_test.dart"
cat > "$WORK/pubspec.yaml" <<'YAML'
name: gwtest
environment: {sdk: '>=3.0.0 <4.0.0'}
dependencies: {shelf: ^1.4.0, shelf_router: ^1.1.0, http: ^1.1.0, mime: ^1.0.4, postgres: ^3.4.0, uuid: ^4.3.3, crypto: ^3.0.3}
dev_dependencies: {test: ^1.24.0}
YAML
python3 "$ROOT/tool/gateway_test/extract_server.py" "$WORK/lib/server.dart"
cd "$WORK" && dart pub get >/dev/null && dart analyze --no-fatal-warnings lib | tee analyze.txt && ! grep -E "^\s*error" analyze.txt && dart test
