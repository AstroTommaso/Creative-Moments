import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/l10n_ext.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/drawing.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/drawing_view.dart';
import '../../shared/widgets/ui.dart';

final paperColors = <(String Function(AppLocalizations l10n) label, int color)>[
  ((l10n) => l10n.drawingPaperNight, 0xFF12142A),
  ((l10n) => l10n.drawingPaperInk, 0xFF000000),
  ((l10n) => l10n.drawingPaperBlueprint, 0xFF14335C),
  ((l10n) => l10n.drawingPaperChalkboard, 0xFF1E2E24),
  ((l10n) => l10n.drawingPaperCream, 0xFFF6F1E9),
  ((l10n) => l10n.drawingPaperSnow, 0xFFFFFFFF),
  ((l10n) => l10n.drawingPaperKraft, 0xFFDCC9A3),
  ((l10n) => l10n.drawingPaperBlush, 0xFFF4D9DF),
  ((l10n) => l10n.drawingPaperMint, 0xFFDCEFE7),
];

/// A paper is "light" when the toolbar chrome needs dark ink to stay
/// readable on it — used for both the default stroke colour and the
/// toolbar's own contrast, independent of the app's day/night theme.
bool isLightPaper(int color) => Color(color).computeLuminance() > 0.5;

const inkColors = <int>[
  0xFFF3EFE8,
  0xFF1B1A2E,
  0xFFE9C98F,
  0xFFFF8A5B,
  0xFFE88BA6,
  0xFFB59CFF,
  0xFF78B8FF,
  0xFF7FD1B0,
  0xFF6FA36B,
  0xFFFFCF6B,
  0xFFC4452B,
  0xFF8E8AA8,
];

/// Owns the strokes while drawing; the widget tree repaints from this.
class DrawingController extends ChangeNotifier {
  DrawingController(DrawingData initial)
    : _strokes = [...initial.strokes],
      width = initial.width,
      height = initial.height,
      background = initial.background,
      color = isLightPaper(initial.background) ? 0xFF1B1A2E : 0xFFF3EFE8;

  final List<Stroke> _strokes;
  final List<Stroke> _redo = [];
  double width, height;
  int background;
  Stroke? live;
  BrushTool tool = BrushTool.pencil;
  int color;
  double size = 4;

  List<Stroke> get strokes => List.unmodifiable(_strokes);
  bool get canUndo => _strokes.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  DrawingData get data => DrawingData(width: width, height: height, background: background, strokes: List.of(_strokes));

  double get effectiveWidth => switch (tool) {
    BrushTool.pencil => size * 0.6,
    BrushTool.brush => size * 2.2,
    BrushTool.eraser => size * 3,
  };

  void begin(Offset p) {
    live = Stroke(tool: tool, color: color, width: effectiveWidth, points: [p]);
    notifyListeners();
  }

  void extend(Offset p) {
    final s = live;
    if (s == null) return;
    if ((s.points.last - p).distance < 0.8) return;
    s.points.add(p);
    notifyListeners();
  }

  /// Returns true when a stroke was committed.
  bool end() {
    final s = live;
    if (s == null) return false;
    _strokes.add(s);
    _redo.clear();
    live = null;
    notifyListeners();
    return true;
  }

  void undo() {
    if (!canUndo) return;
    _redo.add(_strokes.removeLast());
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _strokes.add(_redo.removeLast());
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    _redo.clear();
    notifyListeners();
  }

  void setBackground(int c) {
    background = c;
    // keep the default ink readable on the new paper
    final light = isLightPaper(c);
    if (light && color == 0xFFF3EFE8) color = 0xFF1B1A2E;
    if (!light && color == 0xFF1B1A2E) color = 0xFFF3EFE8;
    notifyListeners();
  }

  void set({BrushTool? tool, int? color, double? size}) {
    this.tool = tool ?? this.tool;
    this.color = color ?? this.color;
    this.size = size ?? this.size;
    notifyListeners();
  }
}

/// The drawing tool itself: canvas + tools. [onChanged] fires after every
/// committed stroke so the caller can autosave.
class DrawingCanvasEditor extends ConsumerStatefulWidget {
  const DrawingCanvasEditor({super.key, required this.initial, required this.onChanged, this.topBar});
  final DrawingData? initial;
  final void Function(DrawingData) onChanged;
  final Widget Function(bool fullscreen, VoidCallback toggleFullscreen)? topBar;

  @override
  ConsumerState<DrawingCanvasEditor> createState() => _DrawingCanvasEditorState();
}

class _DrawingCanvasEditorState extends ConsumerState<DrawingCanvasEditor> {
  DrawingController? _ctl;
  bool _fullscreen = false;
  bool _showSize = false;
  bool _showPaper = false;

  @override
  void dispose() {
    _ctl?.dispose();
    if (_fullscreen) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() => _fullscreen = !_fullscreen);
    SystemChrome.setEnabledSystemUIMode(_fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  Future<void> _confirmClear() async {
    final ok = await confirmDialog(
      context,
      title: context.l10n.drawingClearCanvasTitle,
      message: context.l10n.drawingClearCanvasMessage,
      confirmLabel: context.l10n.drawingClearLabel,
      destructive: true,
    );
    if (ok) {
      _ctl!.clear();
      widget.onChanged(_ctl!.data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cm;
    return LayoutBuilder(
      builder: (context, box) {
        _ctl ??= DrawingController(widget.initial ?? DrawingData(width: box.maxWidth, height: box.maxHeight, background: paperColors.first.$2));
        final ctl = _ctl!;
        // Canvas keeps the stored aspect ratio and fits inside the space we have.
        final ratio = ctl.width / ctl.height;
        var cw = box.maxWidth, ch = cw / ratio;
        if (ch > box.maxHeight) {
          ch = box.maxHeight;
          cw = ch * ratio;
        }
        final scale = cw / ctl.width;
        return Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: c.bg)),
            Center(
              child: SizedBox(
                width: cw,
                height: ch,
                child: ListenableBuilder(
                  listenable: ctl,
                  builder: (_, _) => Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (e) {
                      if (_showSize) setState(() => _showSize = false);
                      ctl.begin(e.localPosition / scale);
                    },
                    onPointerMove: (e) => ctl.extend(e.localPosition / scale),
                    onPointerUp: (_) {
                      if (ctl.end()) widget.onChanged(ctl.data);
                    },
                    onPointerCancel: (_) {
                      if (ctl.end()) widget.onChanged(ctl.data);
                    },
                    child: Semantics(
                      label: context.l10n.drawingCanvasLabel,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: Size(cw, ch),
                          painter: DrawingPainter(ctl.data, live: ctl.live, repaint: ctl),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.topBar != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedSlide(
                  offset: _fullscreen ? const Offset(0, -1.2) : Offset.zero,
                  duration: Mo.base,
                  curve: Mo.soft,
                  child: SafeArea(bottom: false, child: widget.topBar!(_fullscreen, _toggleFullscreen)),
                ),
              ),
            Positioned(
              left: Sp.md,
              right: Sp.md,
              bottom: Sp.md,
              child: SafeArea(
                top: false,
                child: ListenableBuilder(
                  listenable: ctl,
                  builder: (_, _) => _Toolbar(
                    ctl: ctl,
                    fullscreen: _fullscreen,
                    showSize: _showSize,
                    showPaper: _showPaper,
                    onToggleSize: () => setState(() {
                      _showSize = !_showSize;
                      _showPaper = false;
                    }),
                    onTogglePaper: () => setState(() {
                      _showPaper = !_showPaper;
                      _showSize = false;
                    }),
                    onToggleFullscreen: _toggleFullscreen,
                    onClear: _confirmClear,
                    onEdit: () => widget.onChanged(ctl.data),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.ctl,
    required this.fullscreen,
    required this.showSize,
    required this.showPaper,
    required this.onToggleSize,
    required this.onTogglePaper,
    required this.onToggleFullscreen,
    required this.onClear,
    required this.onEdit,
  });
  final DrawingController ctl;
  final bool fullscreen, showSize, showPaper;
  final VoidCallback onToggleSize, onTogglePaper, onToggleFullscreen, onClear, onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = context.cm.accent;
    // The toolbar's own chrome follows the chosen paper's lightness, not the
    // app's day/night theme — a dark theme with a bright paper (or the
    // reverse) would otherwise wash the whole toolbar out.
    final paperLight = isLightPaper(ctl.background);
    final fg = paperLight ? const Color(0xFF1B1A2E) : const Color(0xFFF3EFE8);
    Color tone({bool enabled = true, bool active = false}) => !enabled ? fg.withValues(alpha: 0.28) : (active ? accent : fg);

    Widget tool(BrushTool t, Widget Function(Color) icon, String label) => _IconBtn(
      icon: icon,
      label: label,
      active: ctl.tool == t,
      color: tone(active: ctl.tool == t),
      accentBg: accent,
      onTap: () => ctl.set(tool: t),
    );

    return Glass(
      radius: Rd.lg,
      opacity: paperLight ? 0.55 : 0.14,
      onLightBackdrop: paperLight,
      padding: const EdgeInsets.symmetric(horizontal: Sp.xs, vertical: Sp.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSize)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.md),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 6, color: tone(active: false)),
                  Expanded(
                    child: Slider(value: ctl.size, min: 1, max: 24, onChanged: (v) => ctl.set(size: v), activeColor: accent),
                  ),
                  Icon(Icons.circle, size: 20, color: tone(active: false)),
                ],
              ),
            ),
          if (showPaper)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final p in paperColors)
                    Semantics(
                      button: true,
                      label: p.$1(l10n),
                      selected: ctl.background == p.$2,
                      child: GestureDetector(
                        onTap: () {
                          ctl.setBackground(p.$2);
                          onEdit();
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          child: AnimatedContainer(
                            duration: Mo.fast,
                            width: ctl.background == p.$2 ? 36 : 28,
                            height: ctl.background == p.$2 ? 36 : 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(p.$2),
                              border: Border.all(color: ctl.background == p.$2 ? accent : fg.withValues(alpha: 0.35), width: 2),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6)],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final col in inkColors)
                  Semantics(
                    button: true,
                    label: l10n.drawingColourLabel,
                    selected: ctl.color == col,
                    child: GestureDetector(
                      onTap: () => ctl.set(color: col, tool: ctl.tool == BrushTool.eraser ? BrushTool.pencil : ctl.tool),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        child: AnimatedContainer(
                          duration: Mo.fast,
                          width: ctl.color == col && ctl.tool != BrushTool.eraser ? 32 : 26,
                          height: ctl.color == col && ctl.tool != BrushTool.eraser ? 32 : 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(col),
                            border: Border.all(color: ctl.color == col && ctl.tool != BrushTool.eraser ? accent : fg.withValues(alpha: 0.35), width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Sp.xs),
          Row(
            children: [
              for (final w in <Widget>[
                tool(BrushTool.pencil, (c) => Icon(Icons.edit_outlined, size: 22, color: c), l10n.drawingPencilLabel),
                tool(BrushTool.brush, (c) => Icon(Icons.brush_outlined, size: 22, color: c), l10n.drawingBrushLabel),
                tool(BrushTool.eraser, (c) => _EraserIcon(color: c), l10n.drawingEraserLabel),
                _IconBtn(
                  icon: (c) => Icon(Icons.line_weight_rounded, size: 22, color: c),
                  label: l10n.drawingBrushSizeLabel,
                  active: showSize,
                  color: tone(active: showSize),
                  accentBg: accent,
                  onTap: onToggleSize,
                ),
                _IconBtn(
                  icon: (c) => Icon(Icons.undo_rounded, size: 22, color: c),
                  label: l10n.drawingUndoLabel,
                  color: tone(enabled: ctl.canUndo),
                  accentBg: accent,
                  onTap: ctl.canUndo
                      ? () {
                          ctl.undo();
                          onEdit();
                        }
                      : null,
                ),
                _IconBtn(
                  icon: (c) => Icon(Icons.redo_rounded, size: 22, color: c),
                  label: l10n.drawingRedoLabel,
                  color: tone(enabled: ctl.canRedo),
                  accentBg: accent,
                  onTap: ctl.canRedo
                      ? () {
                          ctl.redo();
                          onEdit();
                        }
                      : null,
                ),
                _IconBtn(
                  icon: (c) => Icon(Icons.texture_rounded, size: 22, color: c),
                  label: l10n.drawingPaperTooltip,
                  active: showPaper,
                  color: tone(active: showPaper),
                  accentBg: accent,
                  onTap: onTogglePaper,
                ),
                _IconBtn(
                  icon: (c) => Icon(Icons.delete_outline_rounded, size: 22, color: c),
                  label: l10n.drawingClearButtonLabel,
                  color: tone(enabled: ctl.strokes.isNotEmpty),
                  accentBg: accent,
                  onTap: ctl.strokes.isEmpty ? null : onClear,
                ),
                _IconBtn(
                  icon: (c) => Icon(fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, size: 22, color: c),
                  label: fullscreen ? l10n.drawingExitFullScreenLabel : l10n.drawingFullScreenLabel,
                  color: tone(),
                  accentBg: accent,
                  onTap: onToggleFullscreen,
                ),
              ])
                Expanded(child: Center(child: w)),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.label, required this.onTap, required this.color, required this.accentBg, this.active = false});
  final Widget Function(Color color) icon;
  final String label;
  final VoidCallback? onTap;
  final Color color, accentBg;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      selected: active,
      enabled: onTap != null,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(shape: BoxShape.circle, color: active ? accentBg.withValues(alpha: 0.22) : Colors.transparent),
          child: Center(child: icon(color)),
        ),
      ),
    );
  }
}

/// A hand-drawn-looking eraser mark (tilted rounded block with a worn edge)
/// — more distinctive here than a generic cleaning/backspace icon.
class _EraserIcon extends StatelessWidget {
  const _EraserIcon({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(width: 22, height: 22, child: CustomPaint(painter: _EraserPainter(color)));
}

class _EraserPainter extends CustomPainter {
  _EraserPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.5);
    final w = size.width * 0.82, h = size.height * 0.52;
    final rrect = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: h), Radius.circular(h * 0.3));
    canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.16));
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(Rect.fromLTWH(w / 2 - w * 0.3, -h / 2, w * 0.3, h), Paint()..color = color.withValues(alpha: 0.3));
    canvas.restore();
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EraserPainter old) => old.color != color;
}
