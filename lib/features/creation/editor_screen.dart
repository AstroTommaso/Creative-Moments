import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/catalog.dart';
import '../../core/services/l10n_ext.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/drawing_view.dart';
import '../../shared/widgets/signed_image.dart';
import '../../shared/widgets/ui.dart';
import '../drawing/drawing_editor.dart';
import 'draft.dart';

/// Hosts the right editor for the moment's type and owns leave / continue rules.
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});
  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  bool _focus = false;

  Future<void> _close() async {
    final s = ref.read(draftProvider);
    final n = ref.read(draftProvider.notifier);
    if (s.unsaved) {
      final l10n = context.l10n;
      final errorDetail = s.status == SaveStatus.error ? (s.error ?? l10n.editorConnectionProblemFallback) : null;
      final leave = await confirmDialog(
        context,
        title: l10n.editorLeaveDialogTitle,
        message: errorDetail != null ? l10n.editorLeaveDialogMessageWithError(errorDetail) : l10n.editorLeaveDialogMessage,
        confirmLabel: l10n.editorLeaveAnywayLabel,
        destructive: true,
      );
      if (!leave || !mounted) return;
    }
    if (s.hasContent && s.persisted && !s.isEditing) {
      await n.syncList();
    }
    n.clear();
    if (mounted) context.canPop() ? context.pop() : context.go('/home');
  }

  void _continue() {
    ref.read(draftProvider.notifier).save();
    context.push('/create/details');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(draftProvider);
    if (!s.active) return const AtmoScaffold(body: SizedBox.shrink(), intensity: 0); // draft was just closed
    final bar = _EditorBar(onClose: _close, onContinue: _continue, isEditing: s.isEditing);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: s.type == CreationType.drawing
          ? Scaffold(
              body: DrawingCanvasEditor(
                initial: s.drawing,
                onChanged: (d) => ref.read(draftProvider.notifier).setDrawing(d),
                topBar: (fullscreen, toggle) => bar,
              ),
            )
          : AtmoScaffold(
              intensity: 0,
              body: SafeArea(
                child: Column(
                  children: [
                    AnimatedSize(
                      duration: Mo.base,
                      curve: Mo.soft,
                      child: _focus ? const SizedBox(width: double.infinity) : bar,
                    ),
                    Expanded(
                      child: WritingEditor(
                        focus: _focus,
                        onFocusChanged: (v) {
                          setState(() => _focus = v);
                          SystemChrome.setEnabledSystemUIMode(v ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
}

class _EditorBar extends ConsumerWidget {
  const _EditorBar({required this.onClose, required this.onContinue, required this.isEditing});
  final VoidCallback onClose, onContinue;
  final bool isEditing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(draftProvider);
    final c = context.cm;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: Sp.xs),
      child: Row(
        children: [
          IconButton(
            tooltip: context.l10n.editorCloseTooltip,
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: c.text),
          ),
          const SizedBox(width: Sp.xs),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: SaveChip(state: s, onRetry: () => ref.read(draftProvider.notifier).save()),
            ),
          ),
          PrimaryButton(label: isEditing ? context.l10n.editorNextLabel : context.l10n.editorContinueLabel, expand: false, onPressed: onContinue),
          const SizedBox(width: Sp.sm),
        ],
      ),
    );
  }
}

/// Honest save state: never says "Saved" unless the server confirmed it.
class SaveChip extends StatelessWidget {
  const SaveChip({super.key, required this.state, required this.onRetry});
  final DraftState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.cm;
    final (text, color, icon) = switch (state.status) {
      SaveStatus.saved => (context.l10n.editorSavedLabel, c.muted, Icons.check_rounded),
      SaveStatus.saving => (context.l10n.editorSavingLabel, c.muted, Icons.cloud_upload_outlined),
      SaveStatus.dirty => (state.hasContent ? context.l10n.editorNotSavedYetLabel : '', c.muted, Icons.edit_outlined),
      SaveStatus.error => (context.l10n.editorNotSavedRetryLabel, c.danger, Icons.cloud_off_rounded),
      SaveStatus.idle => ('', c.muted, Icons.check_rounded),
    };
    if (text.isEmpty) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      label: text,
      child: InkWell(
        borderRadius: Rd.pill,
        onTap: state.status == SaveStatus.error ? onRetry : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: Sp.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: Sp.xs),
              Flexible(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.ui(12, weight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The writing surface: calm, typographic, focus mode, undo/redo, autosave.
class WritingEditor extends ConsumerStatefulWidget {
  const WritingEditor({super.key, required this.focus, required this.onFocusChanged});
  final bool focus;
  final ValueChanged<bool> onFocusChanged;
  @override
  ConsumerState<WritingEditor> createState() => _WritingEditorState();
}

class _WritingEditorState extends ConsumerState<WritingEditor> {
  late final TextEditingController _title, _body;
  final _undo = UndoHistoryController();
  final _bodyFocus = FocusNode();
  bool _showCount = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(draftProvider);
    _title = TextEditingController(text: s.title);
    _body = TextEditingController(text: s.body);
    _undo.addListener(() => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _undo.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final f = await ImagePicker().pickImage(source: source, maxWidth: 1800, imageQuality: 82);
      if (f == null) return;
      final Uint8List bytes = await f.readAsBytes();
      final lower = f.name.toLowerCase();
      final png = lower.endsWith('.png');
      ref
          .read(draftProvider.notifier)
          .addImage(PendingImage(id: const Uuid().v4(), bytes: bytes, ext: png ? 'png' : 'jpg', contentType: png ? 'image/png' : 'image/jpeg'));
    } catch (e) {
      if (mounted) showSnack(context, context.l10n.editorPhotoAddFailedMessage);
    }
  }

  void _photoSheet() {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.editorChooseFromLibraryLabel),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.editorTakePhotoLabel),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(draftProvider);
    final n = ref.read(draftProvider.notifier);
    final c = context.cm;
    final isPhoto = s.type == CreationType.photo;
    final isFree = s.type == CreationType.freeform;
    final hint = switch (s.type) {
      CreationType.letter => context.l10n.editorHintLetter,
      CreationType.story => context.l10n.editorHintStory,
      CreationType.idea => context.l10n.editorHintIdea,
      CreationType.photo => context.l10n.editorHintPhoto,
      _ => context.l10n.editorHintDefault,
    };
    final bodyStyle = AppType.display(23, color: c.text, height: 1.55, weight: FontWeight.w500);
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _bodyFocus.requestFocus(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.md, Sp.xl, 120),
            children: [
              TextField(
                controller: _title,
                onChanged: n.setTitle,
                textCapitalization: TextCapitalization.sentences,
                style: AppType.display(36, weight: FontWeight.w700, color: c.text, height: 1.1),
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: context.l10n.editorTitleHint,
                  hintStyle: AppType.display(36, weight: FontWeight.w700, color: c.muted.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _bodyFocus.requestFocus(),
              ),
              const SizedBox(height: Sp.md),
              if (isPhoto || s.images.isNotEmpty || s.pendingImages.isNotEmpty || s.hasDrawing || isFree) _MediaStrip(onAddPhoto: _photoSheet, big: isPhoto),
              TextField(
                controller: _body,
                focusNode: _bodyFocus,
                undoController: _undo,
                onChanged: n.setBody,
                maxLines: null,
                minLines: 12,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: bodyStyle,
                cursorColor: c.accent,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: bodyStyle.copyWith(color: c.muted.withValues(alpha: 0.5), fontStyle: FontStyle.italic),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: Sp.md,
          right: Sp.md,
          bottom: Sp.md,
          child: AnimatedOpacity(
            duration: Mo.base,
            opacity: widget.focus ? 0.0 : 1,
            child: IgnorePointer(
              ignoring: widget.focus,
              child: Glass(
                opacity: c.isDark ? 0.10 : 0.7,
                padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: Sp.xs),
                child: Row(
                  children: [
                    IconButton(tooltip: context.l10n.editorUndoTooltip, onPressed: _undo.value.canUndo ? _undo.undo : null, icon: const Icon(Icons.undo_rounded)),
                    IconButton(tooltip: context.l10n.editorRedoTooltip, onPressed: _undo.value.canRedo ? _undo.redo : null, icon: const Icon(Icons.redo_rounded)),
                    IconButton(tooltip: context.l10n.editorAddPhotoTooltip, onPressed: _photoSheet, icon: const Icon(Icons.add_photo_alternate_outlined)),
                    if (isFree)
                      IconButton(
                        tooltip: context.l10n.editorAddDrawingTooltip,
                        onPressed: () => context.push('/create/draw'),
                        icon: const Icon(Icons.gesture_rounded),
                      ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _showCount = !_showCount),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
                        child: Text(
                          _showCount ? context.l10n.editorWordCount(s.wordCount) : context.l10n.editorWordsLabel,
                          style: AppType.ui(12, weight: FontWeight.w700, color: c.muted),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.editorFocusModeTooltip,
                      onPressed: () => widget.onFocusChanged(true),
                      icon: const Icon(Icons.center_focus_strong_outlined),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.focus)
          Positioned(
            top: Sp.sm,
            right: Sp.sm,
            child: Opacity(
              opacity: 0.55,
              child: IconButton(
                tooltip: context.l10n.editorExitFocusModeTooltip,
                onPressed: () => widget.onFocusChanged(false),
                icon: const Icon(Icons.close_fullscreen_rounded),
              ),
            ),
          ),
      ],
    );
  }
}

class _MediaStrip extends ConsumerWidget {
  const _MediaStrip({required this.onAddPhoto, required this.big});
  final VoidCallback onAddPhoto;
  final bool big;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(draftProvider);
    final n = ref.read(draftProvider.notifier);
    final c = context.cm;
    final size = big ? 140.0 : 92.0;
    Widget tile(Widget child, VoidCallback onRemove, String label) => Padding(
      padding: const EdgeInsets.only(right: Sp.sm),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Rd.md),
            child: SizedBox(width: size, height: size, child: child),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Semantics(
              button: true,
              label: label,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.lg),
      child: SizedBox(
        height: size,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            if (s.hasDrawing)
              Padding(
                padding: const EdgeInsets.only(right: Sp.sm),
                child: GestureDetector(
                  onTap: () => context.push('/create/draw'),
                  child: Semantics(
                    button: true,
                    label: context.l10n.editorEditDrawingLabel,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Rd.md),
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: 200,
                            height: 200 * s.drawing!.height / s.drawing!.width,
                            child: CustomPaint(painter: DrawingPainter(s.drawing!)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            for (final m in s.images) tile(SignedImage(url: m.url, cacheWidth: 400), () => n.removeSavedImage(m), context.l10n.editorRemovePhotoLabel),
            for (final p in s.pendingImages)
              tile(Image.memory(p.bytes, fit: BoxFit.cover, cacheWidth: 400), () => n.removePendingImage(p.id), context.l10n.editorRemovePhotoLabel),
            GestureDetector(
              onTap: onAddPhoto,
              child: Semantics(
                button: true,
                label: context.l10n.editorAddPhotoTooltip,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Rd.md),
                    border: Border.all(color: c.border),
                    color: c.text.withValues(alpha: 0.04),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: c.muted),
                      const SizedBox(height: Sp.xs),
                      Text(context.l10n.editorPhotoLabel, style: context.tt.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen drawing surface pushed from a freeform moment.
class DrawScreen extends ConsumerWidget {
  const DrawScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(draftProvider);
    return Scaffold(
      body: DrawingCanvasEditor(
        initial: s.drawing,
        onChanged: (d) => ref.read(draftProvider.notifier).setDrawing(d),
        topBar: (fullscreen, toggle) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: Sp.xs),
          child: Row(
            children: [
              const Spacer(),
              PrimaryButton(label: context.l10n.editorDoneLabel, expand: false, onPressed: () => context.pop()),
              const SizedBox(width: Sp.sm),
            ],
          ),
        ),
      ),
    );
  }
}
