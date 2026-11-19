import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassQuality, GlassTabBar;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fqapp/services/app_theme.dart';
import 'package:fqapp/services/app_theme_style.dart';
import 'package:fqapp/widgets/shell_dock.dart';
import 'package:fqapp/widgets/wenku/glass_dock.dart';

/// 档案风格 GlassDock 的成本降级：页面切换动画期间与静态底板都不跑
/// liquid_glass_widgets 的着色器折射，胶囊换成无着色器（minimal）材质；
/// 动画结束自动恢复 premium；dock 本体与交互不受材质切换影响。
void main() {
  setUp(() {
    einkModeNotifier.value = false;
    oledModeNotifier.value = false;
  });
  tearDown(() {
    einkModeNotifier.value = false;
    oledModeNotifier.value = false;
  });

  GlassQuality qualityOf(WidgetTester tester) =>
      tester.widget<GlassTabBar>(find.byType(GlassTabBar)).quality!;

  Widget app(ValueNotifier<bool> animating, {bool staticMaterial = false}) =>
      MaterialApp(
        theme: AppTheme.createTheme(
          Brightness.light,
          style: AppThemeStyle.archive,
        ),
        themeAnimationDuration: Duration.zero,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          bottomNavigationBar: ValueListenableBuilder<bool>(
            valueListenable: animating,
            builder: (context, value, _) => ShellDock(
              selectedIndex: 0,
              onSelected: (_) {},
              overVideo: false,
              staticMaterial: staticMaterial,
              animating: value,
            ),
          ),
        ),
      );

  testWidgets('档案 dock 动画期间换成 minimal 材质，结束后恢复 premium', (tester) async {
    final animating = ValueNotifier<bool>(false);
    addTearDown(animating.dispose);
    await tester.pumpWidget(app(animating));
    await tester.pumpAndSettle();

    // 静止态：underlay 边缘模糊与实时折射（premium）都在。
    expect(find.byKey(const ValueKey('dock-underlay')), findsOneWidget);
    expect(find.byType(GlassDock), findsOneWidget);
    expect(qualityOf(tester), GlassQuality.premium);

    // 动画进行中：轻量预设关掉 underlay，GlassTabBar 降到 minimal，
    // 但 dock 本体保留（降级的是材质，不是导航）。
    animating.value = true;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dock-underlay')), findsNothing);
    expect(find.byType(GlassDock), findsOneWidget);
    expect(qualityOf(tester), GlassQuality.minimal);
    expect(find.text('书架'), findsWidgets);

    // 动画结束：实时效果自动恢复。
    animating.value = false;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dock-underlay')), findsOneWidget);
    expect(qualityOf(tester), GlassQuality.premium);
    expect(tester.takeException(), isNull);
  });

  testWidgets('档案 dock 动画期间仍可点按切换，staticMaterial 行为不变', (tester) async {
    final animating = ValueNotifier<bool>(true);
    addTearDown(animating.dispose);
    var selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.createTheme(
          Brightness.light,
          style: AppThemeStyle.archive,
        ),
        themeAnimationDuration: Duration.zero,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          bottomNavigationBar: ValueListenableBuilder<bool>(
            valueListenable: animating,
            builder: (context, value, _) => ShellDock(
              selectedIndex: 0,
              onSelected: (index) => selected = index,
              overVideo: false,
              staticMaterial: false,
              animating: value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 降级材质不拦交互：动画期间点「书架」照常回调。
    await tester.tap(find.text('书架').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(selected, 2);

    // staticMaterial 单独成立时（视频流 / OLED）同样没有 underlay，
    // 且材质是 minimal——与 animating 无关，既有契约不被本次改动破坏。
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.createTheme(
          Brightness.light,
          style: AppThemeStyle.archive,
        ),
        themeAnimationDuration: Duration.zero,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          bottomNavigationBar: ShellDock(
            selectedIndex: 0,
            onSelected: (_) {},
            overVideo: false,
            staticMaterial: true,
            animating: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dock-underlay')), findsNothing);
    expect(find.byType(GlassDock), findsOneWidget);
    expect(qualityOf(tester), GlassQuality.minimal);
    expect(tester.takeException(), isNull);
  });
}
