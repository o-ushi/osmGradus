import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// iPhone の画面を組む論理幅。iPad ではこの幅で組んでから、窓の幅いっぱいに拡大する。
const double iphoneLayoutWidth = 390;

/// いちばん小さい iPad（mini）の短辺。これ未満は iPhone として、拡大しない。
const double ipadShortestSide = 744;

/// 横向きの iPad で左右に分けるときの、窓の短辺の下限。テストの 800×600 は含めない。
const double ipadSplitShortestSide = 700;

/// [shortestSide] が iPad の画面なら true。テストの 800×600 には反応しない。
bool isIpadShortestSide(double shortestSide) =>
    shortestSide >= ipadShortestSide;

/// 横向きの iPad。左にホーム、右にほかの画面を置く。縦の拡大はしない。
bool ipadLandscapeSplit(Size size) =>
    size.width > size.height && size.shortestSide >= ipadSplitShortestSide;

/// 窓の幅を [iphoneLayoutWidth] で割った拡大率。iPhone 幅以下なら 1。
double ipadScaleForWidth(double width) {
  if (width <= iphoneLayoutWidth) return 1;
  return width / iphoneLayoutWidth;
}

/// iPad では iPhone と同じ組立を、文字も余白もアイコンもまとめて拡大して窓を埋める。
///
/// iPhone では何もしない。レイアウトの論理幅は [iphoneLayoutWidth] のままなので、
/// 画面の並びは iPhone と同じで、表示だけ大きくなる。横向きは左右に分けるため拡大しない。
class IpadPhoneScale extends StatelessWidget {
  const IpadPhoneScale({super.key, required this.child, this.enabled});

  final Widget child;

  /// null なら画面の短辺で判断する。テストから固定できる。
  final bool? enabled;

  bool _enabled(BuildContext context) {
    final forced = enabled;
    if (forced != null) return forced;
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;
    var shortest = 0.0;
    for (final view in WidgetsBinding.instance.platformDispatcher.views) {
      final ratio = view.devicePixelRatio;
      if (ratio == 0) continue;
      final side = (view.physicalSize / ratio).shortestSide;
      if (side > shortest) shortest = side;
    }
    return isIpadShortestSide(shortest);
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled(context)) return child;
    final mq = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen =
            constraints.hasBoundedWidth && constraints.hasBoundedHeight
            ? Size(constraints.maxWidth, constraints.maxHeight)
            : mq.size;
        final scale = ipadScaleForWidth(screen.width);
        if (scale <= 1 || ipadLandscapeSplit(screen)) return child;
        final logical = Size(iphoneLayoutWidth, screen.height / scale);
        return FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: logical.width,
            height: logical.height,
            child: MediaQuery(
              data: mq.copyWith(
                size: logical,
                devicePixelRatio: mq.devicePixelRatio * scale,
                padding: mq.padding / scale,
                viewPadding: mq.viewPadding / scale,
                viewInsets: mq.viewInsets / scale,
                systemGestureInsets: mq.systemGestureInsets / scale,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// 左右に分けた片側。幅をその片側にし、画面の外側のセーフエリアだけ残す。
class IpadSplitPane extends StatelessWidget {
  const IpadSplitPane({
    super.key,
    required this.keepLeftInset,
    required this.child,
  });

  /// true なら左端のセーフエリアを残す。右のペインは分け目が左なので false。
  final bool keepLeftInset;
  final Widget child;

  EdgeInsets _side(EdgeInsets insets) => EdgeInsets.only(
    left: keepLeftInset ? insets.left : 0,
    right: keepLeftInset ? 0 : insets.right,
    top: insets.top,
    bottom: insets.bottom,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mq = MediaQuery.of(context);
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (!width.isFinite || !height.isFinite) return child;
        return MediaQuery(
          data: mq.copyWith(
            size: Size(width, height),
            padding: _side(mq.padding),
            viewPadding: _side(mq.viewPadding),
            systemGestureInsets: _side(mq.systemGestureInsets),
          ),
          child: child,
        );
      },
    );
  }
}

/// 横向きの iPad で左右に分けているあいだ、右ペインの場所を子孫へ伝える。
///
/// 左（ホーム・問題文一覧）から開く画面は、[takeRightPane] で得た context で
/// push すると、全画面ではなく右ペインに出る。
class IpadSplitScope extends InheritedWidget {
  const IpadSplitScope({
    super.key,
    required this.rightPaneKey,
    required this.leftPaneKey,
    required this.leftPane,
    required super.child,
  });

  /// 左ペインのナビゲータの、いちばん下のページに付けたキー。
  final GlobalKey leftPaneKey;

  /// 左ペインの context。右の画面から開く編集シートを左に出すときに使う。
  /// 分けていないときは null。
  static BuildContext? leftPaneContext(BuildContext context) => context
      .getInheritedWidgetOfExactType<IpadSplitScope>()
      ?.leftPaneKey
      .currentContext;

  /// 左ペインにホームの代わりに出す中身（各レイヤーの問題文一覧）。
  final IpadLeftPaneController leftPane;

  /// 左右に分けて表示中なら、左ペインの差し替え口を返す。
  static IpadLeftPaneController? leftPaneOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<IpadSplitScope>()?.leftPane;

  /// 右ペインのナビゲータの、いちばん下のページに付けたキー。
  final GlobalKey rightPaneKey;

  /// 左右に分けて表示中なら true。
  static bool isActive(BuildContext context) =>
      context.getInheritedWidgetOfExactType<IpadSplitScope>() != null;

  /// 右ペインに積まれた画面を閉じてから、右ペインの context を返す。
  /// 分けていないときは null（呼び出し元の context をそのまま使う）。
  static BuildContext? takeRightPane(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<IpadSplitScope>();
    final paneContext = scope?.rightPaneKey.currentContext;
    if (paneContext == null) return null;
    Navigator.of(paneContext).popUntil((route) => route.isFirst);
    return paneContext;
  }

  @override
  bool updateShouldNotify(IpadSplitScope oldWidget) =>
      rightPaneKey != oldWidget.rightPaneKey ||
      leftPaneKey != oldWidget.leftPaneKey;
}

/// 左ペインに出す中身の持ち主。持ち主（右ペイン側の画面）が build のたびに
/// [show] を呼び、離れるときに [hide] を呼ぶ。通知は次のフレームでまとめて送る。
class IpadLeftPaneController extends ChangeNotifier {
  Object? _owner;
  WidgetBuilder? _builder;
  bool _scheduled = false;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  WidgetBuilder? get builder => _builder;

  void show(Object owner, WidgetBuilder builder) {
    _owner = owner;
    _builder = builder;
    _schedule();
  }

  void hide(Object owner) {
    if (_owner != owner) return;
    _owner = null;
    _builder = null;
    _schedule();
  }

  void _schedule() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_disposed) notifyListeners();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }
}

/// 右ペインのこの部分が今見えている（表示中のレイヤー）かどうか。
///
/// [TickerMode] は右ペインで詳細画面が上に重なると切れてしまうため、
/// 左ペインの一覧を出し続けるかどうかはこちらで判断する。祖先の値とも掛け合わせる。
class IpadPaneVisibility extends StatelessWidget {
  const IpadPaneVisibility({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_IpadPaneVisibilityScope>()
          ?.visible ??
      true;

  @override
  Widget build(BuildContext context) =>
      _IpadPaneVisibilityScope(visible: visible && of(context), child: child);
}

class _IpadPaneVisibilityScope extends InheritedWidget {
  const _IpadPaneVisibilityScope({required this.visible, required super.child});

  final bool visible;

  @override
  bool updateShouldNotify(_IpadPaneVisibilityScope oldWidget) =>
      visible != oldWidget.visible;
}

// ---------------------------------------------------------------------------
// iPad横の振り分けポリシー
//
// 右ペイン：学習行為そのもの（各レイヤー・問題の詳細・単語帳・語彙テスト・
//   長文読解・Podcast再生）と、ホームから開く設定・ヘルプ・ダッシュボード・
//   トランスクリプト（とその中から開くもの）。
// 左ペイン：それ以外すべて（一覧・絞り込み・追加・編集・取り込み・履歴・
//   操作方法・確認ダイアログなど）。
//
// 左に出すものは、シート・ダイアログ・画面の `show`／`push` 側で
// [sidePaneContext] を通す。呼び出し側は場所を気にしなくてよい。
// ---------------------------------------------------------------------------

/// 左ペインに出す補助のシート・ダイアログ・画面に使う context。
/// 左右に分けていないときは [context] をそのまま返す。
BuildContext sidePaneContext(BuildContext context) =>
    IpadSplitScope.leftPaneContext(context) ?? context;

/// [showDialog] の `useRootNavigator` に渡す。左右に分けている間は
/// 画面全体ではなく左ペインのナビゲータに出す。
bool sidePaneUsesRootNavigator(BuildContext context) =>
    !IpadSplitScope.isActive(context);

/// 右ペイン（レイヤー内）にある一覧を、iPad横では左ペインに出すための共通処理。
///
/// [buildIntoLeftPane] を build から呼ぶ。左右に分けていなければ一覧をそのまま返し、
/// 分けていれば一覧は左ペインに出して、右には [placeholder] を置く。
/// dispose では [hideFromLeftPane] を呼ぶこと。
mixin IpadLeftPaneListMixin<T extends StatefulWidget> on State<T> {
  IpadLeftPaneController? _leftPaneController;
  BuildContext? _leftPaneBuildContext;

  /// 左ペインに描いている一覧の context。分けていない・未表示なら null。
  BuildContext? get leftPaneListContext {
    final left = _leftPaneBuildContext;
    return left != null && left.mounted ? left : null;
  }

  Widget buildIntoLeftPane(
    BuildContext context, {
    required WidgetBuilder content,
    required Widget placeholder,
  }) {
    final controller = IpadSplitScope.leftPaneOf(context);
    if (controller != _leftPaneController) {
      _leftPaneController?.hide(this);
      _leftPaneController = controller;
    }
    if (controller == null) {
      _leftPaneBuildContext = null;
      return content(context);
    }
    if (IpadPaneVisibility.of(context)) {
      controller.show(this, (leftContext) {
        _leftPaneBuildContext = leftContext;
        return content(leftContext);
      });
    } else {
      controller.hide(this);
    }
    return placeholder;
  }

  void hideFromLeftPane() => _leftPaneController?.hide(this);
}
