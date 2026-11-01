// Writes the embedded gateway helper libraries to a folder: dart run tool/gateway_test/dump.dart <dir>
import 'dart:io';
import '../../lib/services/external/gateway_sources.dart';

void main(List<String> args) {
  final dir = Directory(args.first)..createSync(recursive: true);
  File('${dir.path}/gateway_auth.dart').writeAsStringSync(kGatewayAuthDart);
  File('${dir.path}/gateway_account.dart').writeAsStringSync(kGatewayAccountDart);
}
