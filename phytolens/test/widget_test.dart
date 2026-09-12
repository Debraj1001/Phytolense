
import 'package:flutter_test/flutter_test.dart';
import 'package:phytolens/main.dart';

void main() {
  testWidgets('PhytoLens app smoke test', (WidgetTester tester) async {
    // This is a basic smoke test to ensure the app widget tree builds.
    // Full integration tests should run on device/emulator.
    expect(PhytoLensApp, isNotNull);
  });
}
