import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../core/luxe/tokens.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';
import '../../core/widgets/signature_pad_screen.dart';
import '../../providers/client_provider.dart';
import '../../providers/signature_provider.dart';

/// The client's signature page body, shared by the dashboard's "More →
/// Signature" page ([SignatureTab]) and the standalone `/signature` route
/// ([SignaturePage], opened from the "signature required" dialog).
///
/// Mockup `pSig` (client-mobile-mockup.html): title, lead, "Saved
/// signature" + `.sigbox`, then Draw / Type / Upload / Delete as small
/// buttons. Draw opens the full-screen pad, Upload the image picker, Type
/// opens a `.pad` box with the name in italic serif and a Save button.
class SignatureEditor extends StatefulWidget {
  final ClientProvider clientProvider;
  final SignatureProvider signatureProvider;
  final ApiClient api;

  /// Called after a signature was saved (any of the three ways).
  final VoidCallback? onSaved;

  const SignatureEditor({
    super.key,
    required this.clientProvider,
    required this.signatureProvider,
    required this.api,
    this.onSaved,
  });

  @override
  State<SignatureEditor> createState() => _SignatureEditorState();
}

class _SignatureEditorState extends State<SignatureEditor> {
  final _textController = TextEditingController();
  bool _saving = false;
  bool _typing = false;
  bool _loaded = false;

  String? _existingSigUrl;
  String? _existingSigText;

  bool get _hasSignature => _existingSigUrl != null || _existingSigText != null;

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

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _loadExisting() async {
    try {
      final cid = widget.api.userId;
      if (cid == null) return;
      final data = await widget.clientProvider.fetchClientRaw(cid);
      final client = data['client'] as Map<String, dynamic>?;
      final sigData = client?['signature_data'] as String?;
      if (!mounted) return;
      setState(() {
        _existingSigUrl = null;
        _existingSigText = null;
        if (sigData != null && sigData.isNotEmpty) {
          if (sigData.startsWith('http') || sigData.startsWith('/')) {
            // signature_url: the backend's signed link - /storage/... doesn't
            // exist in production (23 Sept 2026).
            _existingSigUrl = (client?['signature_url'] as String?) ?? widget.api.resolveFileUrl(sigData);
          } else {
            _existingSigText = sigData;
          }
        }
      });
    } catch (e, s) {
      AppLog.error('signature_editor._loadExisting', e, s);
      if (mounted) _snack(AppLocalizations.of(context)!.signature_loadFailed('$e'));
    } finally {
      if (mounted) setState(() => _loaded = true);
    }
  }

  void _afterSave() {
    _snack(AppLocalizations.of(context)!.signature_saved);
    setState(() {
      _typing = false;
      _textController.clear();
    });
    _loadExisting();
    widget.onSaved?.call();
  }

  Future<void> _deleteSignature() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final cid = widget.api.userId;
      if (cid == null) return;
      await widget.signatureProvider.deleteSignature(cid);
      if (!mounted) return;
      setState(() {
        _existingSigUrl = null;
        _existingSigText = null;
      });
      _snack(l10n.signature_deleted);
    } catch (e) {
      _snack(l10n.signature_deleteFailed);
    }
  }

  Future<void> _draw() async {
    final l10n = AppLocalizations.of(context)!;
    final bytes = await SignaturePadScreen.show(context);
    if (bytes == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final cid = widget.api.userId;
      if (cid == null) throw Exception('User ID not found');
      final file = File('${Directory.systemTemp.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await widget.signatureProvider.uploadImage(cid, file);
      if (mounted) _afterSave();
    } catch (e) {
      _snack('${l10n.signature_saveFailed}: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _upload() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    setState(() => _saving = true);
    try {
      final cid = widget.api.userId;
      if (cid == null) return;
      await widget.signatureProvider.uploadImage(cid, File(result.files.single.path!));
      if (mounted) _afterSave();
    } catch (e) {
      _snack(l10n.signature_saveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveText() async {
    final l10n = AppLocalizations.of(context)!;
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      final cid = widget.api.userId;
      if (cid == null) throw Exception('User ID not found');
      await widget.signatureProvider.saveText(cid, text);
      if (mounted) _afterSave();
    } catch (e) {
      _snack(l10n.signature_saveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LuxePageTitle(l10n.signature),
        Text(l10n.signatureLead, style: Lx.text(context, size: 13.5, color: Lx.muted, height: 1.5)),
        const SizedBox(height: 18),
        LuxeKind(l10n.signature_currentSignature),
        _sigBox(),
        Wrap(spacing: 8, runSpacing: 8, children: [
          LuxeButton(
            key: const ValueKey('signature-draw'),
            label: l10n.signature_drawMode,
            lxIcon: 'sign',
            size: LuxeButtonSize.sm,
            onPressed: _saving ? null : _draw,
          ),
          LuxeButton(
            key: const ValueKey('signature-type'),
            label: l10n.signature_textMode,
            size: LuxeButtonSize.sm,
            onPressed: _saving ? null : () => setState(() => _typing = !_typing),
          ),
          LuxeButton(
            key: const ValueKey('signature-upload'),
            label: l10n.onboardingSigUpload,
            lxIcon: 'up',
            size: LuxeButtonSize.sm,
            onPressed: _saving ? null : _upload,
          ),
          if (_hasSignature)
            LuxeButton(
              key: const ValueKey('signature-delete'),
              label: l10n.delete,
              lxIcon: 'trash',
              kind: LuxeButtonKind.danger,
              size: LuxeButtonSize.sm,
              onPressed: _saving ? null : _deleteSignature,
            ),
        ]),
        if (_typing) ..._typePanel(),
        if (_saving && !_typing)
          const Padding(
            padding: EdgeInsets.only(top: 18),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Lx.crimsonInk))),
          ),
      ]),
    );
  }

  /// Mockup `.sigbox`: 110px bordered box, the signature in italic serif
  /// (text) or as the saved image shown in white ink.
  Widget _sigBox() {
    final l10n = AppLocalizations.of(context)!;
    Widget child;
    if (_existingSigUrl != null) {
      child = LuxeSignatureInk(
        child: Image.network(
          _existingSigUrl!,
          height: 70,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text(l10n.signature_loadFailed(''), style: Lx.text(context, size: 12, color: Lx.danger)),
        ),
      );
    } else if (_existingSigText != null) {
      child = FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(_existingSigText!, style: Lx.display(context, size: 36).copyWith(fontStyle: FontStyle.italic)),
      );
    } else {
      child = Text(_loaded ? l10n.signatureNone : '', style: Lx.text(context, size: 13, color: Lx.faint));
    }
    return Container(
      key: const ValueKey('signature-box'),
      height: 110,
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Lx.line2)),
      child: child,
    );
  }

  /// Mockup `.pad` with the `.typed` name, a "Clear" link top-end and the
  /// Save button under it.
  List<Widget> _typePanel() {
    final l10n = AppLocalizations.of(context)!;
    return [
      Container(
        key: const ValueKey('signature-type-pad'),
        height: 150,
        margin: const EdgeInsets.fromLTRB(0, 16, 0, 14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Lx.line2)),
        child: Stack(children: [
          const Positioned(left: 18, right: 18, bottom: 30, child: Divider(height: 1, thickness: 1, color: Lx.line2)),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _textController,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: Lx.display(context, size: 38).copyWith(fontStyle: FontStyle.italic),
                decoration: InputDecoration(
                  hintText: l10n.signature_typeYourName,
                  hintStyle: Lx.text(context, size: 16, color: Lx.faint),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 6,
            end: 8,
            child: InkWell(
              key: const ValueKey('signature-clear'),
              onTap: _textController.clear,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(l10n.signature_clear, style: Lx.text(context, size: 11.5, color: Lx.muted)),
              ),
            ),
          ),
        ]),
      ),
      ElevatedButton(
        key: const ValueKey('signature-save-text'),
        onPressed: _saving ? null : _saveText, // _saveText ignores an empty name
        style: ElevatedButton.styleFrom(
          backgroundColor: Lx.crimson,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF2A2827),
          disabledForegroundColor: Lx.faint,
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: _saving
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(l10n.signature_saveSignature),
      ),
    ];
  }
}
