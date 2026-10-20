import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/luxe/tokens.dart';

enum SignatureMode { draw, type, upload }

/// State of the inline signature box. The screen owns it so the pinned
/// "Save" button (outside the scroll body) can read what was drawn / typed /
/// picked, like the mockup's sticky bar.
class SignatureDraft extends ChangeNotifier {
  SignatureMode mode = SignatureMode.draw;
  final List<List<Offset>> strokes = [];
  List<Offset> current = [];
  final TextEditingController text = TextEditingController();
  String? pickedPath;
  String? pickedName;

  SignatureDraft() {
    text.addListener(notifyListeners);
  }

  void setMode(SignatureMode m) {
    mode = m;
    notifyListeners();
  }

  void startStroke(Offset p) {
    current = [p];
    notifyListeners();
  }

  void extendStroke(Offset p) {
    current.add(p);
    notifyListeners();
  }

  void endStroke() {
    if (current.isNotEmpty) strokes.add(List.of(current));
    current = [];
    notifyListeners();
  }

  void pick(String path, String name) {
    pickedPath = path;
    pickedName = name;
    notifyListeners();
  }

  void clear() {
    strokes.clear();
    current = [];
    text.clear();
    pickedPath = null;
    pickedName = null;
    notifyListeners();
  }

  List<List<Offset>> get allStrokes => [...strokes, if (current.isNotEmpty) current];

  bool get canSave {
    switch (mode) {
      case SignatureMode.draw:
        return allStrokes.isNotEmpty;
      case SignatureMode.type:
        return text.text.trim().isNotEmpty;
      case SignatureMode.upload:
        return pickedPath != null;
    }
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }
}

/// The mockup's signature area: a Draw / Type / Upload segmented control and a
/// 150px pad with a baseline and a × mark.
class OnboardingSignaturePad extends StatelessWidget {
  final SignatureDraft draft;
  final VoidCallback onPickImage;
  final ValueChanged<bool> onDrawingChanged; // true while a finger is down
  const OnboardingSignaturePad({super.key, required this.draft, required this.onPickImage, required this.onDrawingChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(Lx.rPill), border: Border.all(color: Lx.line2)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final m in SignatureMode.values)
                InkWell(
                  key: ValueKey('sig-mode-${m.name}'),
                  borderRadius: BorderRadius.circular(Lx.rPill),
                  onTap: () => draft.setMode(m),
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: draft.mode == m ? const Color(0x14FFFFFF) : null,
                      borderRadius: BorderRadius.circular(Lx.rPill),
                    ),
                    child: Text(
                      m == SignatureMode.draw ? l10n.signature_drawMode : m == SignatureMode.type ? l10n.signature_textMode : l10n.onboardingSigUpload,
                      style: Lx.text(context, size: 12, color: draft.mode == m ? Lx.ink : Lx.muted),
                    ),
                  ),
                ),
            ]),
          ),
          Container(
            key: const ValueKey('sig-pad'),
            height: 150,
            margin: const EdgeInsets.fromLTRB(0, 14, 0, 16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Lx.line2)),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              const Positioned(left: 18, right: 18, bottom: 30, child: Divider(height: 1, thickness: 1, color: Lx.line2)),
              const Positioned(left: 20, bottom: 36, child: Text('×', style: TextStyle(color: Lx.faint, fontSize: 16))),
              if (draft.mode == SignatureMode.draw) ...[
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (e) {
                      onDrawingChanged(true);
                      draft.startStroke(e.localPosition);
                    },
                    onPointerMove: (e) => draft.extendStroke(e.localPosition),
                    onPointerUp: (_) {
                      draft.endStroke();
                      onDrawingChanged(false);
                    },
                    onPointerCancel: (_) {
                      draft.endStroke();
                      onDrawingChanged(false);
                    },
                    child: CustomPaint(painter: _InkPainter(draft.allStrokes), size: Size.infinite),
                  ),
                ),
                PositionedDirectional(
                  top: 6,
                  end: 8,
                  child: InkWell(
                    key: const ValueKey('sig-clear'),
                    onTap: draft.clear,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(l10n.signature_clear, style: Lx.text(context, size: 11.5, color: Lx.muted)),
                    ),
                  ),
                ),
              ] else if (draft.mode == SignatureMode.type)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      key: const ValueKey('sig-text'),
                      controller: draft.text,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: const TextStyle(fontFamily: Lx.serif, fontStyle: FontStyle.italic, fontSize: 38, color: Lx.ink),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        hintText: l10n.signature_typeYourName,
                        hintStyle: Lx.text(context, size: 16, color: Lx.faint),
                      ),
                    ),
                  ),
                )
              else
                Center(
                  child: InkWell(
                    key: const ValueKey('sig-pick'),
                    onTap: onPickImage,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.upload_outlined, size: 18, color: Lx.muted),
                        const SizedBox(height: 6),
                        Text(draft.pickedName ?? l10n.signature_orUploadImage, style: Lx.text(context, size: 12.5, color: draft.pickedName != null ? Lx.ink : Lx.muted)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ]);
      },
    );
  }
}

class _InkPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _InkPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Lx.ink
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.length < 2) {
        if (s.isNotEmpty) canvas.drawCircle(s.first, 1.4, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (var i = 1; i < s.length; i++) {
        path.lineTo(s[i].dx, s[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _InkPainter old) => true;
}
