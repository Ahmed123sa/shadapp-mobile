import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../providers/client_provider.dart';
import '../../providers/signature_provider.dart';
import 'render_signature.dart';
import '../../core/theme.dart';

class SignatureTab extends StatefulWidget {
  // Optional so this screen can be pumped in a widget test with mocked
  // providers instead of hitting the network.
  final ClientProvider? clientProvider;
  final SignatureProvider? signatureProvider;
  final ApiClient? api;
  const SignatureTab({super.key, this.clientProvider, this.signatureProvider, this.api});

  @override
  State<SignatureTab> createState() => _SignatureTabState();
}

class _SignatureTabState extends State<SignatureTab> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final ClientProvider _clientProvider = widget.clientProvider ?? ClientProvider();
  late final SignatureProvider _signatureProvider = widget.signatureProvider ?? SignatureProvider();
  final _textController = TextEditingController();
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  bool _saving = false;
  String _mode = 'draw';

  final _boundaryKey = GlobalKey();
  String? _existingSigUrl;
  String? _existingSigText;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final cid = _api.userId;
      if (cid == null) return;
      final data = await _clientProvider.fetchClientRaw(cid);
      final client = data['client'] as Map<String, dynamic>?;
      final sigData = client?['signature_data'] as String?;
      setState(() {
        _existingSigUrl = null;
        _existingSigText = null;
      });
      if (sigData != null && sigData.isNotEmpty) {
        if (sigData.startsWith('http') || sigData.startsWith('/')) {
          setState(() => _existingSigUrl = _api.resolveFileUrl(sigData));
        } else {
          setState(() => _existingSigText = sigData);
        }
      }
    } catch (e) {
      debugPrint('Failed to load existing signature: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.signature_loadFailed('$e'))),
        );
      }
    }
  }

  void _clear() => setState(() {
        _strokes.clear();
        _currentStroke.clear();
      });

  Future<void> _deleteSignature() async {
    try {
      final cid = _api.userId;
      if (cid == null) return;
      await _signatureProvider.deleteSignature(cid);
      setState(() {
        _existingSigUrl = null;
        _existingSigText = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.signature_deleted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.signature_deleteFailed)),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      try {
        final file = File(result.files.single.path!);
        final cid = _api.userId;
        if (cid == null) return;
        await _signatureProvider.uploadImage(cid, file);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.signature_saved)),
          );
          _loadExisting();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.signature_saveFailed)),
          );
        }
      }
    }
  }

  Future<void> _saveDrawing() async {
    if (_strokes.isEmpty && _currentStroke.isEmpty) return;
    setState(() => _saving = true);
    try {
      final renderBox =
          _boundaryKey.currentContext?.findRenderObject() as RenderBox?;
      final size = renderBox?.size ?? const Size(400, 200);
      final pngBytes = await renderSignatureAsPng(
          strokes: _strokes, currentStroke: _currentStroke, size: size);
      final cid = _api.userId;
      if (cid == null) throw Exception('User ID not found');
      final dir = Directory.systemTemp;
      final file = File(
          '${dir.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);
      await _signatureProvider.uploadImage(cid, file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.signature_saved)),
        );
        _loadExisting();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.signature_saveFailed)),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _saveText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      final cid = _api.userId;
      if (cid == null) throw Exception('User ID not found');
      await _signatureProvider.saveText(cid, text);
      if (mounted) {
        _textController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.signature_saved)),
        );
        _loadExisting();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.signature_saveFailed)),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_existingSigUrl != null || _existingSigText != null) ...[
              _buildExistingSignature(),
              const SizedBox(height: 20),
            ],
            _buildModeSelector(),
            const SizedBox(height: 20),
            if (_mode == 'draw')
              _buildDrawArea()
            else
              _buildTextArea(),
            const SizedBox(height: 20),
            _buildActionButtons(),
            const SizedBox(height: 12),
            _buildUploadButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingSignature() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ShadColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShadColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: ShadColors.gold.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check,
                    size: 16, color: ShadColors.gold),
              ),
              const SizedBox(width: 10),
              Text(l10n.signature_currentSignature,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ShadColors.textPrimary,
                      fontFamily: 'Tajawal')),
            ],
          ),
          const SizedBox(height: 12),
          if (_existingSigUrl != null)
            Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ShadColors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ShadColors.cardBorder),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(_existingSigUrl!,
                      height: 60,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.error, size: 30, color: ShadColors.error)),
                ),
              ),
            ),
          if (_existingSigText != null)
            Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ShadColors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ShadColors.cardBorder),
                ),
                child: Text(_existingSigText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w400,
                        color: ShadColors.gold,
                        fontFamily: 'Tajawal')),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _deleteSignature,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: Text(l10n.signature_deleteSignature,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: 'Tajawal')),
              style: OutlinedButton.styleFrom(
                foregroundColor: ShadColors.error,
                side: const BorderSide(color: ShadColors.error),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ShadColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShadColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeTab('draw', l10n.signature_drawMode, Icons.brush_outlined),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildModeTab('text', l10n.signature_textMode, Icons.text_fields_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab(String value, String label, IconData icon) {
    final selected = _mode == value;
    return GestureDetector(
      onTap: () => setState(() => _mode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? ShadColors.crimson : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: selected
                    ? ShadColors.textOnCrimson
                    : ShadColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? ShadColors.textOnCrimson
                        : ShadColors.textSecondary,
                    fontFamily: 'Tajawal')),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawArea() {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: ShadColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShadColors.cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onPanStart: (_) => setState(() => _currentStroke = []),
          onPanUpdate: (details) {
            setState(() => _currentStroke.add(details.localPosition));
          },
          onPanEnd: (_) => setState(() {
            _strokes.add(List.from(_currentStroke));
            _currentStroke = [];
          }),
          child: RepaintBoundary(
            key: _boundaryKey,
            child: CustomPaint(
              painter: _SignaturePainter(
                  strokes: _strokes, currentStroke: _currentStroke),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextArea() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: ShadColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShadColors.cardBorder),
      ),
      child: TextField(
        controller: _textController,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w400,
            color: ShadColors.gold,
            fontFamily: 'Tajawal'),
        decoration: InputDecoration(
          hintText: l10n.signature_typeYourName,
          hintStyle: TextStyle(
              color: ShadColors.textDisabled.withValues(alpha: 0.5),
              fontSize: 20,
              fontFamily: 'Tajawal'),
          border: InputBorder.none,
        ),
        maxLines: 1,
      ),
    );
  }

  Widget _buildActionButtons() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _clear,
            style: OutlinedButton.styleFrom(
              foregroundColor: ShadColors.textSecondary,
              side: const BorderSide(color: ShadColors.cardBorder),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.all(12),
            ),
            child: Text(l10n.signature_clear,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: 'Tajawal')),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : (_mode == 'draw' ? _saveDrawing : _saveText),
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, size: 18),
            label: Text(_saving ? l10n.signature_saving : l10n.signature_saveSignature,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
            style: ElevatedButton.styleFrom(
              backgroundColor: ShadColors.crimson,
              foregroundColor: ShadColors.textOnCrimson,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.all(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadButton() {
    final l10n = AppLocalizations.of(context)!;
    return OutlinedButton.icon(
      onPressed: _pickImage,
      icon: const Icon(Icons.attach_file, size: 18),
      label: Text(l10n.signature_orUploadImage,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: 'Tajawal')),
      style: OutlinedButton.styleFrom(
        foregroundColor: ShadColors.gold,
        side: const BorderSide(color: ShadColors.gold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.all(12),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;

  _SignaturePainter({required this.strokes, required this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = ShadColors.signatureOverlay;
    for (double x = 12; x < size.width; x += 24) {
      for (double y = 12; y < size.height; y += 24) {
        canvas.drawCircle(Offset(x, y), 1, bgPaint);
      }
    }

    final linePaint = Paint()
      ..color = ShadColors.signatureOverlaySoft
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.75), linePaint);

    final paint = Paint()
      ..color = ShadColors.gold
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, paint);
    }
    _drawStroke(canvas, currentStroke, paint);
  }

  void _drawStroke(Canvas canvas, List<Offset> points, Paint paint) {
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => true;
}
