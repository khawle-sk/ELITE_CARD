import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/models.dart';

// ─────────────────────────────────────────────
//  MODÈLE D'UN CHAMP DYNAMIQUE
//  Chaque champ que l'utilisateur ajoute est
//  représenté par cet objet.
// ─────────────────────────────────────────────

class CardField {
  String label;   // ex: "Email", "LinkedIn", "Entreprise"
  String value;   // ce que l'utilisateur a tapé
  TextEditingController ctrl;

  CardField({required this.label, this.value = ''})
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

  // Champs fixes (toujours présents sur la carte)
  final _nameCtrl  = TextEditingController();
  final _jobCtrl   = TextEditingController();

  // Photo
  String? _photoPath;

  // Champs dynamiques (ajoutés par l'utilisateur)
  final List<CardField> _extraFields = [];

  // Texture de la carte
  CardTexture _texture = CardTexture.gold;

  // Flip
  bool _isFlipped = false;
  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;

  // Shimmer (Or)
  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmerAnim;

  // Gyroscope
  double _gyroX = 0;
  double _gyroY = 0;

  // Sauvegarde
  bool _saving = false;

  final ImagePicker _picker = ImagePicker();

  // Labels prédéfinis qu'on peut ajouter rapidement
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

    if (widget.existingCard != null) {
      _nameCtrl.text = widget.existingCard!.name;
      _jobCtrl.text  = widget.existingCard!.jobTitle;
      _photoPath     = widget.existingCard!.photoPath;
      _texture       = widget.existingCard!.texture;
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

  // Ajouter un champ depuis les suggestions rapides
  void _addQuickField(String label) {
    setState(() {
      _extraFields.add(CardField(label: label));
    });
  }

  // Ajouter un champ avec un label personnalisé
  void _addCustomField() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161622),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nom du champ',
                style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ex: WhatsApp, Skype...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF0D0D14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF252535)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFC8A84B)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  if (ctrl.text.trim().isNotEmpty) {
                    setState(() => _extraFields.add(CardField(label: ctrl.text.trim())));
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

  // Supprimer un champ dynamique
  void _removeField(int index) {
    setState(() {
      _extraFields[index].dispose();
      _extraFields.removeAt(index);
    });
  }

  // Choisir une photo
  Future<void> _pickImage() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) setState(() => _photoPath = file.path);
  }

  // Retourner la carte
  void _toggleFlip() {
    setState(() => _isFlipped = !_isFlipped);
    _isFlipped ? _flipCtrl.forward() : _flipCtrl.reverse();
  }

  // Sauvegarder
  Future<void> _saveCard() async {
    setState(() => _saving = true);
    HapticFeedback.lightImpact();

    final card = BusinessCard(
      name: _nameCtrl.text,
      jobTitle: _jobCtrl.text,
      email: _extraFields.firstWhere(
        (f) => f.label.toLowerCase() == 'email', orElse: () => CardField(label: '')).ctrl.text,
      phone: _extraFields.firstWhere(
        (f) => f.label.toLowerCase() == 'téléphone', orElse: () => CardField(label: '')).ctrl.text,
      photoPath: _photoPath,
      texture: _texture,
    );

    final box = Hive.box('cards');
    final key = widget.existingCard != null
        ? 'card_existante'
        : 'card_${DateTime.now().millisecondsSinceEpoch}';
    await box.put(key, card.toMap());

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, card);
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    //   backgroundColor: const Color(0xFF0A0A0F),
    backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildCardPreview(),
          _buildFlipButton(),
          const SizedBox(height: 4),
          Expanded(child: _buildEditorPanel()),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  APP BAR
  // ─────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1A1A1A),
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white54, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('STUDIO',
          style: TextStyle(
              color: Colors.white, fontSize: 13, letterSpacing: 4, fontWeight: FontWeight.w500)),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: _saving ? null : _saveCard,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFF5D060)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Sauver',
                      style: TextStyle(
                          color: Color(0xFF1A0A00), fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  PREVIEW CARTE (avec flip 3D + gyro)
  // ─────────────────────────────────────────────

  Widget _buildCardPreview() {
    return Container(
      height: 210,
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
              ..rotateX(_gyroX * 0.06)
              ..rotateZ(_gyroY * 0.03),
            child: showFront ? _buildCardFront() : _buildCardBack(),
          );
        },
      ),
    );
  }

  // ── Recto ──────────────────────────────────

  Widget _buildCardFront() {
    final name    = _nameCtrl.text;
    final job     = _jobCtrl.text;

    // On cherche le premier champ "entreprise" si il existe
    final entreprise = _extraFields
        .where((f) => f.label.toLowerCase().contains('entreprise'))
        .firstOrNull
        ?.ctrl.text ?? '';

    // On prend les 2 premiers champs de contact (email, tel, etc.)
    final contactLines = _extraFields
        .where((f) => !f.label.toLowerCase().contains('entreprise') && f.ctrl.text.isNotEmpty)
        .take(2)
        .map((f) => f.ctrl.text)
        .toList();

    return Container(
      width: 310,
      height: 180,
      decoration: _cardDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Shimmer (or uniquement)
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
                            Colors.white.withOpacity(0.18),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Effet holo
            Positioned.fill(
              child: CustomPaint(painter: HoloPainter(_gyroX, _gyroY, _texture)),
            ),

            // ── LAYOUT CARTE D'IDENTITÉ ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Photo côté gauche (style carte d'identité)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildPhotoOnCard(),
                    ],
                  ),

                  const SizedBox(width: 14),

                  // Séparateur vertical
                  Container(
                    width: 1,
                    height: double.infinity,
                    color: _cardTextColor().withOpacity(0.2),
                  ),

                  const SizedBox(width: 14),

                  // Infos côté droit
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LUX · STACK',
                            style: TextStyle(
                                fontSize: 8, letterSpacing: 3, color: _cardLabelColor())),
                        const Spacer(),

                        // Nom
                        Text(
                          name.isEmpty ? 'Votre Nom' : name,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _cardTextColor(),
                              letterSpacing: 0.3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Poste
                        if (job.isNotEmpty || _jobCtrl.text.isEmpty)
                          Text(
                            job.isEmpty ? 'Poste / Titre' : job,
                            style: TextStyle(
                                fontSize: 10,
                                color: _cardTextColor().withOpacity(0.75),
                                fontStyle: FontStyle.italic),
                            maxLines: 1,
                          ),

                        // Entreprise
                        if (entreprise.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(entreprise,
                                style: TextStyle(
                                    fontSize: 9,
                                    color: _cardTextColor().withOpacity(0.6),
                                    letterSpacing: 0.5)),
                          ),

                        const SizedBox(height: 8),

                        // Champs de contact dynamiques
                        ...contactLines.map((line) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                line,
                                style: TextStyle(
                                    fontSize: 9, color: _cardTextColor().withOpacity(0.55)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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

  // Photo sur la carte (style photo d'identité)
  Widget _buildPhotoOnCard() {
    return Container(
      width: 72,
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: _cardTextColor().withOpacity(0.08),
        border: Border.all(color: _cardTextColor().withOpacity(0.2), width: 1),
      ),
      child: _photoPath != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.file(File(_photoPath!), fit: BoxFit.cover),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_outline_rounded,
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

  // ── Verso (QR Code) ────────────────────────

  Widget _buildCardBack() {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(pi),
      child: Container(
        width: 310,
        height: 180,
        decoration: _cardDecoration(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              QrImageView(
                data: [
                  _nameCtrl.text,
                  _jobCtrl.text,
                  ..._extraFields.map((f) => '${f.label}: ${f.ctrl.text}'),
                ].join('\n'),
                size: 120,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: _texture == CardTexture.gold ? const Color(0xFF1A0A00) : Colors.white,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: _texture == CardTexture.gold ? const Color(0xFF1A0A00) : Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_nameCtrl.text.isEmpty ? '—' : _nameCtrl.text,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _cardTextColor())),
                  ..._extraFields.take(3).map((f) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          f.ctrl.text.isEmpty ? f.label : f.ctrl.text,
                          style: TextStyle(
                              fontSize: 9, color: _cardTextColor().withOpacity(0.6)),
                        ),
                      )),
                ],
              ),
            ],
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
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFB8860B), Color(0xFFDAA520), Color(0xFFF5D060), Color(0xFFDAA520), Color(0xFFB8860B)],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
          boxShadow: const [BoxShadow(color: Color(0x66DAA520), blurRadius: 24, offset: Offset(0, 8))],
        );
      case CardTexture.glass:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
          boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 8))],
        );
      case CardTexture.carbon:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: const Color(0xFF333333)),
          boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 20, offset: Offset(0, 8))],
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
  //  BOUTON FLIP
  // ─────────────────────────────────────────────

  Widget _buildFlipButton() {
    return GestureDetector(
      onTap: _toggleFlip,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF161622),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF252535)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flip_rounded, color: Colors.white38, size: 14),
            const SizedBox(width: 8),
            Text(
              _isFlipped ? 'Voir le recto' : 'Voir le QR Code',
              style: const TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  PANEL ÉDITEUR
  // ─────────────────────────────────────────────

  Widget _buildEditorPanel() {
    return Container(
      decoration: const BoxDecoration(
        // color: Color(0xFF0D0D14),
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFF1E1E2E))),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Photo ────────────────────────────
          _sectionLabel('Photo de profil'),
          _buildPhotoPicker(),
          _divider(),

          // ── Champs fixes ─────────────────────
          _sectionLabel('Identité'),
          _styledField('Nom complet', _nameCtrl, 'Ex: Amir Benali'),
          _styledField('Poste / Titre', _jobCtrl, 'Ex: Développeur Flutter'),
          _divider(),

          // ── Champs dynamiques ─────────────────
          _sectionLabel('Mes informations'),

          // Liste des champs ajoutés
          ..._extraFields.asMap().entries.map((entry) {
            final i = entry.key;
            final field = entry.value;
            return _dynamicFieldRow(i, field);
          }),

          // Suggestions rapides
          _buildQuickAddBar(),

          // Bouton champ personnalisé
          _buildCustomAddButton(),

          _divider(),

          // ── Texture ──────────────────────────
          _sectionLabel('Matière'),
          _buildTexturePicker(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Un champ dynamique (avec label + valeur + bouton supprimer) ──

  Widget _dynamicFieldRow(int index, CardField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Label du champ (petit, fixe)
          Container(
            width: 85,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF161622),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF252535)),
            ),
            child: Text(
              field.label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF888899)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // Champ de valeur (prend toute la place restante)
          Expanded(
            child: TextField(
              controller: field.ctrl,
              onChanged: (_) => _rebuild(),
              style: const TextStyle(color: Color(0xFFE0E0F0), fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Votre ${field.label.toLowerCase()}...',
                hintStyle: const TextStyle(color: Color(0xFF44445A), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF161622),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF252535)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF252535)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFC8A84B)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Bouton supprimer
          GestureDetector(
            onTap: () => _removeField(index),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1018),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF3A2030)),
              ),
              child: const Icon(Icons.close_rounded, color: Color(0xFF884466), size: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ── Suggestions rapides (chips horizontaux) ──

  Widget _buildQuickAddBar() {
    // On affiche seulement les labels pas encore ajoutés
    final usedLabels = _extraFields.map((f) => f.label).toSet();
    final available = _quickLabels.where((l) => !usedLabels.contains(l)).toList();

    if (available.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ajouter rapidement :',
              style: TextStyle(fontSize: 10, color: Color(0xFF555566))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: available.map((label) {
              return GestureDetector(
                onTap: () => _addQuickField(label),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161622),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF252535)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, color: Color(0xFF888899), size: 13),
                      const SizedBox(width: 4),
                      Text(label,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF888899))),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Bouton "Champ personnalisé" ──

  Widget _buildCustomAddButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: _addCustomField,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFF161622),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF252535), style: BorderStyle.solid),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.tune_rounded, color: Colors.white24, size: 15),
              SizedBox(width: 8),
              Text('Champ personnalisé',
                  style: TextStyle(color: Colors.white24, fontSize: 12)),
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
            color: _photoPath != null ? const Color(0xFFC8A84B) : const Color(0xFF333344),
          ),
        ),
        child: Row(
          children: [
            // Miniature de la photo (style carte d'identité)
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
                      child: Image.file(File(_photoPath!), fit: BoxFit.cover),
                    )
                  : const Icon(Icons.person_outline_rounded, color: Colors.white12, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _photoPath != null ? 'Photo sélectionnée' : 'Ajouter une photo',
                    style: TextStyle(
                      color: _photoPath != null ? const Color(0xFFC8A84B) : Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Apparaît à gauche de la carte',
                    style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11),
                  ),
                  if (_photoPath != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Appuyer pour changer',
                          style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10)),
                    ),
                ],
              ),
            ),
            Icon(
              _photoPath != null ? Icons.check_circle_outline_rounded : Icons.add_photo_alternate_outlined,
              color: _photoPath != null ? const Color(0xFFC8A84B) : Colors.white12,
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

  Widget _textureBtn(CardTexture texture, String label) {
    final isActive = _texture == texture;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _texture = texture),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: texture == CardTexture.gold
                ? const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFF5D060)])
                : null,
            color: texture == CardTexture.glass
                ? Colors.white.withOpacity(0.05)
                : texture == CardTexture.carbon
                    ? const Color(0xFF1A1A1A)
                    : null,
            border: Border.all(
              color: isActive ? const Color(0xFFC8A84B) : const Color(0xFF252535),
              width: isActive ? 2 : 1,
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
                      color: texture == CardTexture.gold
                          ? const Color(0xFF3A2500)
                          : Colors.white54)),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  HELPERS UI
  // ─────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 10, letterSpacing: 2,
                color: Color(0xFF555566), fontWeight: FontWeight.w500)),
      );

  Widget _divider() => Container(
        height: 1, color: const Color(0xFF1E1E2E),
        margin: const EdgeInsets.symmetric(vertical: 14));

  Widget _styledField(String label, TextEditingController ctrl, String hint,
      {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF666677))),
          const SizedBox(height: 5),
          TextField(
            controller: ctrl,
            onChanged: (_) => _rebuild(),
            keyboardType: keyboardType,
            style: const TextStyle(color: Color(0xFFE0E0F0), fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF44445A), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF161622),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF252535)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF252535)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFC8A84B)),
              ),
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

class HoloPainter extends CustomPainter {
  final double gyroX;
  final double gyroY;
  final CardTexture texture;

  HoloPainter(this.gyroX, this.gyroY, this.texture);

  @override
  void paint(Canvas canvas, Size size) {
    if (texture == CardTexture.carbon) return;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(gyroX - 0.5, gyroY - 0.5),
        end: Alignment(gyroX + 0.5, gyroY + 0.5),
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(texture == CardTexture.gold ? 0.08 : 0.12),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, paint);

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1.5;

    final x = size.width * (0.5 + gyroX * 0.4);
    canvas.drawLine(Offset(x, 0), Offset(x + 20, size.height), linePaint);
  }

  @override
  bool shouldRepaint(HoloPainter old) => old.gyroX != gyroX || old.gyroY != gyroY;
}