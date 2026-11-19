// Bottom navigation material rebuilt on `liquid_glass_widgets`
// (`GlassTabBar.bottom`): the package owns the glass track, the jelly indicator,
// the press glow/scale and the sliding drag between lanes. fqapp keeps the
// archive geometry (compact capsule, item width, 4 lanes), the archive icons and
// the cost policy: pages, video streams and e-ink never run a live refraction
// shader — they get the shader-free solid/minimal material instead.
import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';

import 'src/app_haptics.dart';
import 'src/archive_icons.dart';
import 'src/dock_layout.dart';
import 'src/performance_preferences.dart';
import 'wenku_theme.dart';

class GlassDockItem {
  const GlassDockItem(
    this.icon,
    this.label, {
    this.semanticLabel,
    this.symbol,
    this.haptic = HapticCue.selection,
  });

  final IconData icon;
  final String label;
  final String? semanticLabel;
  final ArchiveSymbol? symbol;
  final HapticCue haptic;

  Object get identity => (icon, label);
}

/// The floating archive dock.
///
/// Selection is reported on release, like the previous implementation: the
/// package previews the finger's lane locally and only calls
/// [onSelected] once the gesture resolves. A tap on the selected lane reports
/// through [onReselected] when provided.
class GlassDock extends StatefulWidget {
  const GlassDock({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.onReselected,
    this.reduceMotion = false,
    this.animateInactiveIcons = false,
    this.itemWidth = DockLayout.itemWidth,
    this.staticMaterial = false,
    this.animating = false,
    this.items = const [
      GlassDockItem(CupertinoIcons.house, '发现'),
      GlassDockItem(CupertinoIcons.book, '书架', symbol: ArchiveSymbol.shelf),
      GlassDockItem(CupertinoIcons.settings, '设置'),
    ],
  }) : assert(items.length >= 2 && items.length <= 5),
       assert(itemWidth >= 48);

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// A deliberate tap on the selected item, not a drag ending in its lane.
  final ValueChanged<int>? onReselected;
  final bool reduceMotion;

  /// Action docks (previous/next chapter) can replay invoked icons without
  /// selecting their lane; navigation docks animate the selected icon only.
  final bool animateInactiveIcons;
  final List<GlassDockItem> items;

  /// Optional narrow-screen lane width; the capsule keeps its archive geometry.
  final double itemWidth;

  /// Behind each frame is a video stream (or OLED black): no live shader.
  final bool staticMaterial;

  /// Page transition in flight: the dock skips refraction until it settles.
  final bool animating;

  @override
  State<GlassDock> createState() => _GlassDockState();
}

class _GlassDockState extends State<GlassDock> {
  /// Replays the archive icon's contact animation when a lane is accepted.
  final Map<Object, int> _activations = {};

  void _select(int index) {
    final item = widget.items[index];
    AppHaptics.play(context, item.haptic);
    if (index == widget.selectedIndex) {
      setState(() {
        _activations[item.identity] = (_activations[item.identity] ?? 0) + 1;
      });
      (widget.onReselected ?? widget.onSelected)(index);
      return;
    }
    setState(() {
      _activations[item.identity] = (_activations[item.identity] ?? 0) + 1;
    });
    widget.onSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scheme = Theme.of(context).colorScheme;
    final eink = WenkuTheme.isEinkOf(context);
    final performance = PerformanceScope.of(context);
    final height = DockLayout.heightOf(context);
    final reduceMotion =
        widget.reduceMotion || PerformanceScope.reduceMotionOf(context);

    // Cost policy, unchanged from the liquid_glass_easy dock: e-ink, high
    // contrast, a static backdrop or an in-flight page transition render the
    // shader-free material; only a settled, live page gets real refraction.
    final lightweight =
        eink ||
        widget.staticMaterial ||
        widget.animating ||
        media.highContrast ||
        !performance.glass;

    final selectedColor = eink ? scheme.onSurface : scheme.primary;
    final unselectedColor = eink
        ? scheme.onSurface.withValues(alpha: .72)
        : scheme.onSurfaceVariant;

    final tabs = <GlassTab>[
      for (final (index, item) in widget.items.indexed)
        GlassTab(
          icon: ArchiveIcon(
            item.icon,
            symbol: item.symbol,
            size: DockLayout.iconSize,
            active: index == widget.selectedIndex,
            animate:
                !reduceMotion &&
                (widget.animateInactiveIcons || index == widget.selectedIndex),
            trigger: _activations[item.identity],
          ),
          label: item.label,
          semanticLabel: item.semanticLabel ?? item.label,
        ),
    ];

    final bar = GlassTabBar.bottom(
      tabs: tabs,
      selectedIndex: widget.selectedIndex,
      onTabSelected: _select,
      barHeight: height,
      barBorderRadius: height / 2,
      // The archive capsule hugs its lanes: no package padding around the
      // glass track, so the outer geometry stays DockLayout's.
      horizontalPadding: 0,
      verticalPadding: 0,
      spacing: 0,
      tabPadding: EdgeInsets.zero,
      iconSize: DockLayout.iconSize,
      labelFontSize: DockLayout.labelFontSize,
      iconLabelSpacing: DockLayout.labelGap,
      selectedIconColor: selectedColor,
      unselectedIconColor: unselectedColor,
      selectedLabelColor: selectedColor,
      unselectedLabelColor: unselectedColor,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
      indicatorColor: lightweight
          ? scheme.onSurface.withValues(alpha: eink ? .10 : .08)
          : null,
      settings: lightweight ? _solidMaterial(context, scheme) : null,
      indicatorSettings: lightweight ? _solidIndicator(context, scheme) : null,
      quality: lightweight ? GlassQuality.minimal : GlassQuality.premium,
      backgroundQuality: lightweight
          ? GlassQuality.minimal
          : GlassQuality.premium,
      enableBlend: !lightweight,
      groupBackdrop: !lightweight,
      maskingQuality: lightweight ? MaskingQuality.off : MaskingQuality.high,
      interactionBehavior: lightweight
          ? GlassInteractionBehavior.none
          : GlassInteractionBehavior.full,
    );

    final width =
        widget.items.length * widget.itemWidth + DockLayout.horizontalInset * 2;
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        key: const ValueKey('liquid-dock-surface'),
        width: constraints.hasBoundedWidth
            ? math.min(width, constraints.maxWidth)
            : width,
        height: height,
        // The package already honours Reduce Motion / Reduce Transparency;
        // the e-ink toggle is fqapp-only and must disable motion here too.
        child: reduceMotion
            ? MediaQuery(
                data: media.copyWith(disableAnimations: true),
                child: bar,
              )
            : bar,
      ),
    );
  }

  /// Shader-free material for video / e-ink / page transitions: a flat tinted
  /// capsule with no backdrop filter (blur 0 skips the BackdropFilter).
  LiquidGlassSettings _solidMaterial(BuildContext context, ColorScheme scheme) {
    final eink = WenkuTheme.isEinkOf(context);
    final surface = eink
        ? Colors.white
        : Theme.of(context).brightness == Brightness.dark
        ? scheme.surfaceContainerHigh
        : scheme.surface;
    return LiquidGlassSettings(
      glassColor: surface.withValues(alpha: eink ? 1 : .94),
      blur: 0,
      frost: 0,
      thickness: 8,
      lightIntensity: 0,
      ambientStrength: 0,
      fresnelStrength: 0,
      chromaticAberration: 0,
      saturation: 1,
      refractiveIndex: 1,
      shadowElevation: 0,
      whitenStrength: 0,
    );
  }

  /// The sliding lane for the solid material: a tint, no blur and no shader.
  LiquidGlassSettings _solidIndicator(
    BuildContext context,
    ColorScheme scheme,
  ) => LiquidGlassSettings(
    glassColor: scheme.onSurface.withValues(alpha: .08),
    blur: 0,
    frost: 0,
    thickness: 4,
    lightIntensity: 0,
    ambientStrength: 0,
    fresnelStrength: 0,
    chromaticAberration: 0,
    saturation: 1,
    refractiveIndex: 1,
    shadowElevation: 0,
    whitenStrength: 0,
  );
}
