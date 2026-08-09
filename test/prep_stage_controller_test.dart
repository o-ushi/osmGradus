import 'package:flutter_test/flutter_test.dart';
import 'package:osm_gradus/controllers/prep_stage_controller.dart';

void main() {
  test('初期状態は結論', () {
    final controller = PrepStageController();
    expect(controller.stage, PrepStage.conclusion);
  });

  test('advance()で結論→理由→例示→doneの順に進む', () {
    final controller = PrepStageController();
    controller.advance();
    expect(controller.stage, PrepStage.reason);
    controller.advance();
    expect(controller.stage, PrepStage.example);
    controller.advance();
    expect(controller.stage, PrepStage.done);
  });

  test('done状態でさらにadvance()してもdoneのまま', () {
    final controller = PrepStageController();
    controller.advance();
    controller.advance();
    controller.advance();
    expect(controller.stage, PrepStage.done);
    controller.advance();
    expect(controller.stage, PrepStage.done);
  });

  test('start()/reset()はどの段階からでも結論に戻す', () {
    final controller = PrepStageController();
    controller.advance();
    controller.advance();
    expect(controller.stage, PrepStage.example);

    controller.start();
    expect(controller.stage, PrepStage.conclusion);

    controller.advance();
    controller.reset();
    expect(controller.stage, PrepStage.conclusion);
  });
}
