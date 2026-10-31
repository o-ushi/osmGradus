import Flutter
import UIKit

/// シーン設定名。NSUserActivity の種別にも使われるので、逆引き DNS にする。
/// "flutter" のようにピリオドが無いと iOS 27 が例外で止める。
enum SceneConfiguration {
  static let name = "com.osamushikubo.osmGradus.scene"
}

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    // 接続のあと、画面の切り替えで状態保存が来る。種別が空のままだと
    // Flutter が設定名で NSUserActivity を作り、iPhone Duo で落ちる。
    if scene.userActivity == nil {
      scene.userActivity = NSUserActivity(activityType: SceneConfiguration.name)
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
    // 以前の起動で残った設定名が "flutter" のとき、親がそれを種別に使うと落ちる。
    if scene.userActivity == nil {
      let name = scene.session.configuration.name ?? ""
      if !name.contains(".") {
        return nil
      }
    }
    return super.stateRestorationActivity(for: scene)
  }
}
