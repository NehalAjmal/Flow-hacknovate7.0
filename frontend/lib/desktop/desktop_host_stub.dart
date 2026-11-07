import 'desktop_host.dart';

DesktopHost createHost() => const NoopDesktopHost();
Future<void> prepare(List<String> args) async {}
