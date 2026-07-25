import 'package:flutter_test/flutter_test.dart';
import 'package:amass_engine/amass_engine.dart';

void main() {
  test('AmassEngine initialization test', () async {
    final engine = AmassEngine();
    await engine.initialize();
    expect(engine.isInitialized, true);
  });
}
