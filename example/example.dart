import 'package:amass_engine/amass_engine.dart';

void main() async {
  final engine = AmassEngine();
  await engine.initialize();
  print('AmassEngine is ready for tactical operations.');
}
