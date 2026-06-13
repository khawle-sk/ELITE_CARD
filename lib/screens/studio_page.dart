import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/models.dart';

// ─────────────────────────────────────────────
//  CHAMP DYNAMIQUE
// ─────────────────────────────────────────────

class _CardField {
  String label;
  final TextEditingController ctrl;

  _CardField({required this.label, String value = ''})
      : ctrl = TextEditingController(text: value);

  void dispose() => ctrl.dispose();
}

// ─────────────────────────────────────────────
//  STUDIO PAGE
// ─────────────────────────────────────────────

class StudioPage extends StatefulWidget {
  final BusinessCard? existingCard;
  const StudioPage({super.key, this.existingCard});

  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> with TickerProviderStateMixin {
  // Champs fixes
  final _nameCtrl = TextEditingController();
  final _jobCtrl  = TextEditingController();

  // Photo
  String? _photoPath;

  // Champs dynamiques
  final List<_CardField> _extraFields = [];

  // Texture
  CardTexture _texture = CardTexture.gold;

  // Flip
  bool _isFlipped = false;
  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;

  // Shimmer (or)
  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmerAnim;

  // Gyroscope
  double _gyroX = 0;
  double _gyroY = 0;

  // États
  bool _saving = false;
  bool _downloading = false;

  // Clé pour la capture (téléchargement)
  final GlobalKey _cardRepaintKey = GlobalKey();

  final ImagePicker _picker = ImagePicker();

  final List<String> _quickLabels = [
    'Téléphone', 'Email', 'Entreprise', 'Site web',
    'LinkedIn', 'GitHub', 'Instagram', 'Adresse',
  ];

  // ─────────────────────────────────────────────
  //  INIT & DISPOSE
  // ─────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Pré-remplir si mode édition
    if (widget.existingCard != null) {
      final c = widget.existingCard!;
      _nameCtrl.text  = c.name;
      _jobCtrl.text   = c.jobTitle;
      _photoPath      = c.photoPath;
      _texture        = c.texture;
      if (c.email.isNotEmpty) {
        _extraFields.add(_CardField(label: 'Email', value: c.email));
      }
      if (c.phone.isNotEmpty) {
        _extraFields.add(_CardField(label: 'Téléphone', value: c.phone));
      }
      for (final f in c.extraFields) {
        if (f['label'] != 'Email' && f['label'] != 'Téléphone') {
          _extraFields.add(_CardField(label: f['label']!, value: f['value'] ?? ''));
        }
      }
    }

    // Shimmer
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _shimmerAnim = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );

    // Flip
    _flipCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _flipAnim = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut),
    );

    // Gyroscope
    accelerometerEventStream().listen((e) {
      if (!mounted) return;
      setState(() {
        _gyroX = (e.x / 10).clamp(-1.0, 1.0);
        _gyroY = (e.y / 10).clamp(-1.0, 1.0);
      });
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _jobCtrl.dispose();
    for (final f in _extraFields) f.dispose();
    _shimmerCtrl.dispose();
    _flipCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  //  ACTIONS
  // ─────────────────────────────────────────────

  void _rebuild() => setState(() {});

  void _addQuickField(String label) =>
      setState(() => _extraFields.add(_CardField(label: label)));

  void _removeField(int i) => setState(() {
        _extraFields[i].dispose();
        _extraFields.removeAt(i);
      });

  Future<void> _pickImage() async {
    final XFile? file =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) setState(() => _photoPath = file.path);
  }

  void _toggleFlip() {
    setState(() => _isFlipped = !_isFlipped);
    _isFlipped ? _flipCtrl.forward() : _flipCtrl.reverse();
  }

  // ── Sauvegarde Hive ──────────────────────────

  Future<void> _saveCard() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showSnack('Entrez au moins un nom pour la carte', isError: true);
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.lightImpact();

    // final emailField = _extraFields.where((f) => f.label == 'Email').firstOrNull;
    // final phoneField = _extraFields.where((f) => f.label == 'Téléphone').firstOrNull;

    final emailField = _extraFields
    .where((f) => f.label.toLowerCase().contains('email'))
    .firstOrNull;
final phoneField = _extraFields
    .where((f) => f.label.toLowerCase().contains('téléphone') || 
                  f.label.toLowerCase().contains('telephone') ||
                  f.label.toLowerCase().contains('phone'))
    .firstOrNull;

    final extra = _extraFields
        .where((f) => f.label != 'Email' && f.label != 'Téléphone')
        .map((f) => {'label': f.label, 'value': f.ctrl.text})
        .toList();

    final id = widget.existingCard?.id ??
        'card_${DateTime.now().millisecondsSinceEpoch}';

    final card = BusinessCard(
      id: id,
      name: _nameCtrl.text.trim(),
      jobTitle: _jobCtrl.text.trim(),
      email: emailField?.ctrl.text ?? '',
      phone: phoneField?.ctrl.text ?? '',
      photoPath: _photoPath,
      texture: _texture,
      extraFields: extra,
      createdAt: widget.existingCard?.createdAt ?? DateTime.now(),
    );

    final box = Hive.box('cards');
    await box.put(id, card.toMap());

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    setState(() => _saving = false);
    _showSnack(widget.existingCard != null ? 'Carte mise à jour ✓' : 'Carte créée ✓');

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) Navigator.pop(context, card);
  }

  // ── Téléchargement carte en image ────────────

  Future<void> _downloadCard() async {
    setState(() => _downloading = true);
    HapticFeedback.mediumImpact();

    try {
      // Capturer le widget carte dans un RenderRepaintBoundary
      final boundary = _cardRepaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        _showSnack('Erreur : impossible de capturer la carte', isError: true);
        setState(() => _downloading = false);
        return;
      }

      // Rendu haute résolution (3x)
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        _showSnack('Erreur lors de la capture', isError: true);
        setState(() => _downloading = false);
        return;
      }

      // Sauvegarder dans le dossier Documents/Downloads
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'luxstack_${_nameCtrl.text.trim().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      setState(() => _downloading = false);
      _showSnack('Carte sauvegardée dans Documents/$fileName');
    } catch (e) {
      setState(() => _downloading = false);
      _showSnack('Erreur : $e', isError: true);
    }
  }

  // Supprimer la carte (mode édition seulement)
  Future<void> _deleteCard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161622),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer cette carte ?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text(
          'Cette action est irréversible.',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer',
                style: TextStyle(color: Color(0xFFE24B4A))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Hive.box('cards').delete(widget.existingCard!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        backgroundColor:
            isError ? const Color(0xFF3A1010) : const Color(0xFF1A2A0A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Ajouter un champ personnalisé (bottom sheet)
  void _addCustomField() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161622),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nom du champ',
                style: TextStyle(
                    color: Colors.white54, fontSize: 11, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ex : WhatsApp, Skype...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF0D0D14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFF252535))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFFC8A84B))),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  if (ctrl.text.trim().isNotEmpty) {
                    setState(() =>
                        _extraFields.add(_CardField(label: ctrl.text.trim())));
                  }
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFB8860B), Color(0xFFF5D060)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text('Ajouter',
                      style: TextStyle(
                          color: Color(0xFF1A0A00),
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingCard != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: _buildAppBar(isEdit),
      body: Column(
        children: [
          _buildCardPreview(),
          _buildActionRow(),
          const SizedBox(height: 4),
          Expanded(child: _buildEditorPanel()),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  APP BAR
  // ─────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(bool isEdit) {
    return AppBar(
      backgroundColor: const Color(0xFF0A0A0F),
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back,
            color: Colors.white54, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        isEdit ? 'MODIFIER' : 'STUDIO',
        style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            letterSpacing: 4,
            fontWeight: FontWeight.w500),
      ),
      actions: [
        // Bouton supprimer (mode édition)
        if (isEdit)
          IconButton(
            icon: const Icon(( Icons.delete ),
                color: Color(0xFF884466), size: 20),
            onPressed: _deleteCard,
            tooltip: 'Supprimer',
          ),
        // Bouton Sauver
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: _saving ? null : _saveCard,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFB8860B), Color(0xFFF5D060)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : Text(
                      isEdit ? 'Mettre à jour' : 'Sauver',
                      style: const TextStyle(
                          color: Color(0xFF1A0A00),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  PREVIEW CARTE (Flip 3D + Gyro)
  // ─────────────────────────────────────────────

  Widget _buildCardPreview() {
    return Container(
      height: 220,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedBuilder(
        animation: _flipAnim,
        builder: (context, _) {
          final showFront = _flipAnim.value <= pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(_flipAnim.value)
              ..rotateX(_gyroX * 0.05)
              ..rotateZ(_gyroY * 0.025),
            child: RepaintBoundary(
              key: showFront ? _cardRepaintKey : null,
              child: showFront ? _buildCardFront() : _buildCardBack(),
            ),
          );
        },
      ),
    );
  }

  // ── Recto ──────────────────────────────────

  Widget _buildCardFront() {
    final name = _nameCtrl.text;
    final job  = _jobCtrl.text;
    final entreprise = _extraFields
        .where((f) => f.label.toLowerCase().contains('entreprise'))
        .firstOrNull
        ?.ctrl.text ?? '';
    final contactLines = _extraFields
        .where((f) =>
            !f.label.toLowerCase().contains('entreprise') &&
            f.ctrl.text.isNotEmpty)
        .take(2)
        .map((f) => f.ctrl.text)
        .toList();

    return Container(
      width: 320,
      height: 190,
      decoration: _cardDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Shimmer or
            if (_texture == CardTexture.gold)
              AnimatedBuilder(
                animation: _shimmerAnim,
                builder: (_, __) => Positioned.fill(
                  child: FractionalTranslation(
                    translation: Offset(_shimmerAnim.value, 0),
                    child: Transform.rotate(
                      angle: -0.3,
                      child: Container(
                        width: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.16),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Holo
            Positioned.fill(
              child: CustomPaint(
                  painter: _HoloPainter(_gyroX, _gyroY, _texture)),
            ),

            // Contenu
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo
                  _buildPhotoOnCard(),
                  const SizedBox(width: 14),
                  // Séparateur
                  Container(
                    width: 1,
                    height: double.infinity,
                    color: _cardTextColor().withOpacity(0.18),
                  ),
                  const SizedBox(width: 14),
                  // Infos
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LUX · STACK',
                            style: TextStyle(
                                fontSize: 7.5,
                                letterSpacing: 3,
                                color: _cardLabelColor())),
                        const Spacer(),
                        Text(
                          name.isEmpty ? 'Votre Nom' : name,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _cardTextColor(),
                              letterSpacing: 0.2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          job.isEmpty ? 'Poste / Titre' : job,
                          style: TextStyle(
                              fontSize: 10,
                              color: _cardTextColor().withOpacity(0.7),
                              fontStyle: FontStyle.italic),
                          maxLines: 1,
                        ),
                        if (entreprise.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(entreprise,
                                style: TextStyle(
                                    fontSize: 9,
                                    color:
                                        _cardTextColor().withOpacity(0.55),
                                    letterSpacing: 0.5)),
                          ),
                        const SizedBox(height: 8),
                        ...contactLines.map((l) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(l,
                                  style: TextStyle(
                                      fontSize: 9,
                                      color:
                                          _cardTextColor().withOpacity(0.5)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoOnCard() {
    return Container(
      width: 70,
      height: 88,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: _cardTextColor().withOpacity(0.08),
        border: Border.all(
            color: _cardTextColor().withOpacity(0.2), width: 1),
      ),
      child: _photoPath != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.file(File(_photoPath!), fit: BoxFit.cover),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person,
                    color: _cardTextColor().withOpacity(0.3), size: 28),
                const SizedBox(height: 4),
                Text('Photo',
                    style: TextStyle(
                        fontSize: 8,
                        color: _cardTextColor().withOpacity(0.3),
                        letterSpacing: 1)),
              ],
            ),
    );
  }

  // ── Verso (QR Code) ──────────────────────────

  Widget _buildCardBack() {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(pi),
      child: Container(
        width: 320,
        height: 190,
        decoration: _cardDecoration(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              QrImageView(
                data: [
                  _nameCtrl.text,
                  _jobCtrl.text,
                  ..._extraFields
                      .map((f) => '${f.label}: ${f.ctrl.text}'),
                ].join('\n'),
                size: 110,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: _texture == CardTexture.gold
                      ? const Color(0xFF1A0A00)
                      : Colors.white,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: _texture == CardTexture.gold
                      ? const Color(0xFF1A0A00)
                      : Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameCtrl.text.isEmpty ? '—' : _nameCtrl.text,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _cardTextColor()),
                    ),
                    ..._extraFields.take(3).map((f) => Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            f.ctrl.text.isEmpty
                                ? f.label
                                : f.ctrl.text,
                            style: TextStyle(
                                fontSize: 9,
                                color:
                                    _cardTextColor().withOpacity(0.6)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  LIGNE D'ACTIONS (Flip + Télécharger)
  // ─────────────────────────────────────────────

  Widget _buildActionRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          // Flip
          Expanded(
            child: GestureDetector(
              onTap: _toggleFlip,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF161622),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF252535)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.flip_rounded,
                        color: Colors.white38, size: 14),
                    const SizedBox(width: 7),
                    Text(
                      _isFlipped ? 'Voir recto' : 'Voir QR Code',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Télécharger
          GestureDetector(
            onTap: _downloading ? null : _downloadCard,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _downloading
                        ? const Color(0xFFDAA520).withOpacity(0.3)
                        : const Color(0xFF252535)),
              ),
              child: _downloading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFDAA520)))
                  : const Row(
                      children: [
                        Icon(Icons.download_rounded,
                            color: Color(0xFFDAA520), size: 16),
                        SizedBox(width: 6),
                        Text('Télécharger',
                            style: TextStyle(
                                color: Color(0xFFDAA520),
                                fontSize: 11,
                                letterSpacing: 0.5)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  PANEL ÉDITEUR
  // ─────────────────────────────────────────────

  Widget _buildEditorPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D14),
        border: Border(top: BorderSide(color: Color(0xFF1E1E2E))),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // ── Photo ──
          _sectionLabel('Photo de profil'),
          _buildPhotoPicker(),
          _divider(),

          // ── Identité ──
          _sectionLabel('Identité'),
          _styledField('Nom complet', _nameCtrl, ''),
          _styledField('Poste / Titre', _jobCtrl, ''),
          _divider(),

          // ── Champs dynamiques ──
          _sectionLabel('Informations de contact'),
          ..._extraFields.asMap().entries.map((e) => _dynamicRow(e.key, e.value)),
          _buildQuickAddBar(),
          _buildCustomAddBtn(),
          _divider(),

          // ── Texture ──
          _sectionLabel('Matière de la carte'),
          _buildTexturePicker(),
        ],
      ),
    );
  }

  // ── Champ dynamique ──

  Widget _dynamicRow(int i, _CardField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 88,
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF161622),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF252535)),
            ),
            child: Text(field.label,
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF888899)),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: field.ctrl,
              onChanged: (_) => _rebuild(),
              style: const TextStyle(
                  color: Color(0xFFE0E0F0), fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Votre ${field.label.toLowerCase()}...',
                hintStyle: const TextStyle(
                    color: Color(0xFF44445A), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF161622),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFF252535))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFF252535))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFFC8A84B))),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _removeField(i),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1018),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF3A2030)),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Color(0xFF884466), size: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ── Suggestions rapides ──

  Widget _buildQuickAddBar() {
    final used = _extraFields.map((f) => f.label).toSet();
    final available =
        _quickLabels.where((l) => !used.contains(l)).toList();
    if (available.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ajouter rapidement :',
              style: TextStyle(
                  fontSize: 10, color: Color(0xFF555566))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: available
                .map((label) => GestureDetector(
                      onTap: () => _addQuickField(label),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161622),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF252535)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_rounded,
                                color: Color(0xFF888899), size: 13),
                            const SizedBox(width: 4),
                            Text(label,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF888899))),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomAddBtn() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: _addCustomField,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFF161622),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF252535)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.settings, color: Colors.white24, size: 15),
              SizedBox(width: 8),
              Text('Champ personnalisé',
                  style: TextStyle(
                      color: Colors.white24, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  PHOTO PICKER
  // ─────────────────────────────────────────────

  Widget _buildPhotoPicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF161622),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _photoPath != null
                ? const Color(0xFFC8A84B)
                : const Color(0xFF333344),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 65,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: const Color(0xFF0D0D14),
                border: Border.all(color: const Color(0xFF252535)),
              ),
              child: _photoPath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(File(_photoPath!),
                          fit: BoxFit.cover),
                    )
                  : const Icon(Icons.person_outline_rounded,
                      color: Colors.white12, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _photoPath != null
                        ? 'Photo sélectionnée'
                        : 'Ajouter une photo',
                    style: TextStyle(
                      color: _photoPath != null
                          ? const Color(0xFFC8A84B)
                          : Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text('Apparaît sur la carte',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.2),
                          fontSize: 11)),
                  if (_photoPath != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Appuyer pour changer',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.2),
                              fontSize: 10)),
                    ),
                ],
              ),
            ),
            Icon(
              _photoPath != null
                  ? Icons.check_circle_outline_rounded
                  : Icons.add_photo_alternate_outlined,
              color: _photoPath != null
                  ? const Color(0xFFC8A84B)
                  : Colors.white12,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  TEXTURE PICKER
  // ─────────────────────────────────────────────

  Widget _buildTexturePicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          _textureBtn(CardTexture.gold, 'Or Pur'),
          const SizedBox(width: 10),
          _textureBtn(CardTexture.glass, 'Verre'),
          const SizedBox(width: 10),
          _textureBtn(CardTexture.carbon, 'Carbone'),
        ],
      ),
    );
  }

  Widget _textureBtn(CardTexture t, String label) {
    final active = _texture == t;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _texture = t),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: t == CardTexture.gold
                ? const LinearGradient(
                    colors: [Color(0xFFB8860B), Color(0xFFF5D060)])
                : null,
            color: t == CardTexture.glass
                ? Colors.white.withOpacity(0.05)
                : t == CardTexture.carbon
                    ? const Color(0xFF1A1A1A)
                    : null,
            border: Border.all(
              color: active
                  ? const Color(0xFFC8A84B)
                  : const Color(0xFF252535),
              width: active ? 2 : 1,
            ),
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: t == CardTexture.gold
                          ? const Color(0xFF3A2500)
                          : Colors.white54)),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  HELPERS VISUELS CARTE
  // ─────────────────────────────────────────────

  BoxDecoration _cardDecoration() {
    switch (_texture) {
      case CardTexture.gold:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFB8860B),
              Color(0xFFDAA520),
              Color(0xFFF5D060),
              Color(0xFFDAA520),
              Color(0xFFB8860B),
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
          boxShadow: const [
            BoxShadow(
                color: Color(0x66DAA520),
                blurRadius: 24,
                offset: Offset(0, 8))
          ],
        );
      case CardTexture.glass:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
          boxShadow: [
            BoxShadow(
                color: Colors.blue.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 8))
          ],
        );
      case CardTexture.carbon:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: const Color(0xFF333333)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x99000000),
                blurRadius: 20,
                offset: Offset(0, 8))
          ],
        );
    }
  }

  Color _cardTextColor() {
    switch (_texture) {
      case CardTexture.gold:   return const Color(0xFF1A0A00);
      case CardTexture.glass:  return Colors.white;
      case CardTexture.carbon: return const Color(0xFFE0E0E0);
    }
  }

  Color _cardLabelColor() {
    switch (_texture) {
      case CardTexture.gold:   return const Color(0xFF3A2500);
      case CardTexture.glass:  return Colors.white70;
      case CardTexture.carbon: return Colors.white38;
    }
  }

  // ─────────────────────────────────────────────
  //  HELPERS UI
  // ─────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                letterSpacing: 2,
                color: Color(0xFF555566),
                fontWeight: FontWeight.w500)),
      );

  Widget _divider() => Container(
        height: 1,
        color: const Color(0xFF1E1E2E),
        margin: const EdgeInsets.symmetric(vertical: 14));

  Widget _styledField(String label, TextEditingController ctrl, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF666677))),
          const SizedBox(height: 5),
          TextField(
            controller: ctrl,
            onChanged: (_) => _rebuild(),
            style: const TextStyle(
                color: Color(0xFFE0E0F0), fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                  color: Color(0xFF44445A), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF161622),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF252535))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF252535))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFFC8A84B))),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  HOLOGRAPHIC PAINTER
// ─────────────────────────────────────────────

class _HoloPainter extends CustomPainter {
  final double gyroX;
  final double gyroY;
  final CardTexture texture;

  _HoloPainter(this.gyroX, this.gyroY, this.texture);

  @override
  void paint(Canvas canvas, Size size) {
    if (texture == CardTexture.carbon) return;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(gyroX - 0.5, gyroY - 0.5),
        end: Alignment(gyroX + 0.5, gyroY + 0.5),
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(
              texture == CardTexture.gold ? 0.07 : 0.11),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, paint);

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 1.5;

    final x = size.width * (0.5 + gyroX * 0.4);
    canvas.drawLine(Offset(x, 0), Offset(x + 20, size.height), linePaint);
  }

  @override
  bool shouldRepaint(_HoloPainter old) =>
      old.gyroX != gyroX || old.gyroY != gyroY;
}
