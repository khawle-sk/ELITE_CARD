import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/models.dart';
import 'studio_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  String _searchQuery = '';
  int _activeIndex = 0;
  double _dragDy = 0;
  bool _isDragging = false;

  late AnimationController _swipeCtrl;
  late Animation<double> _swipeAnim;
  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();

    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _shimmerAnim = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );

    _swipeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _swipeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _swipeCtrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _swipeCtrl.dispose();
    super.dispose();
  }

  List<BusinessCard> _loadCards() {
    final box = Hive.box('cards');
    return box.values
        .map((e) => BusinessCard.fromMap(e as Map))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<BusinessCard> _filtered(List<BusinessCard> all) {
    if (_searchQuery.isEmpty) return all;
    return all
        .where((c) =>
            c.name.toLowerCase().startsWith(_searchQuery.toLowerCase()))
        .toList();
  }

  void _onDragStart(DragStartDetails d) {
    if (_swipeCtrl.isAnimating) return;
    setState(() {
      _isDragging = true;
      _dragDy = 0;
    });
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_isDragging) return;
    setState(() {
      _dragDy = (_dragDy + d.delta.dy).clamp(-300, 40);
    });
  }

  void _onDragEnd(DragEndDetails d, List<BusinessCard> cards) {
    if (!_isDragging) return;
    _isDragging = false;
    final velocity = d.velocity.pixelsPerSecond.dy;
    if (_dragDy < -100 || velocity < -800) {
      _animateSwipe(cards);
    } else {
      setState(() => _dragDy = 0);
    }
  }

  Future<void> _animateSwipe(List<BusinessCard> cards) async {
    HapticFeedback.lightImpact();
    _swipeCtrl.reset();
    await _swipeCtrl.forward();
    setState(() {
      _activeIndex = (_activeIndex + 1) % cards.length;
      _dragDy = 0;
    });
    _swipeCtrl.reset();
  }

  void _openCardView(BusinessCard card) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.88),
        pageBuilder: (_, a, __) => _CardDetailView(
          card: card,
          shimmerAnim: _shimmerAnim,
          onEdit: () {
            Navigator.pop(context);
            _goToStudio(existing: card);
          },
          onDelete: () async {
            Navigator.pop(context);
            await _deleteCard(card);
          },
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOut),
            ),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 260),
      ),
    );
  }

  Future<void> _goToStudio({BusinessCard? existing}) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => StudioPage(existingCard: existing),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
                    begin: const Offset(0, 0.05), end: Offset.zero)
                .animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    setState(() {});
  }

  Future<void> _deleteCard(BusinessCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161622),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer cette carte ?',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        content: Text('"${card.name}" sera supprimée définitivement.',
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white38))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer',
                  style: TextStyle(
                      color: Color(0xFFE24B4A),
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirmed == true) {
      await Hive.box('cards').delete(card.id);
      setState(() {
        _activeIndex = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('cards').listenable(),
      builder: (context, box, _) {
        final allCards = _loadCards();
        final cards = _filtered(allCards);

        if (cards.isNotEmpty && _activeIndex >= cards.length) {
          _activeIndex = 0;
        }

        return Scaffold(
          body: Stack(
            children: [
              _buildBg(),
              _buildGlow(
                  top: -100,
                  right: -60,
                  color: const Color(0xFFDAA520),
                  opacity: 0.07),
              _buildGlow(
                  bottom: -120,
                  left: -80,
                  color: Colors.blue,
                  opacity: 0.04),
              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(cards.length),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                    Expanded(
                      child: cards.isEmpty
                          ? _buildEmptyState()
                          : _buildPileArea(cards),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              Positioned(
                bottom: 30,
                right: 24,
                child: _buildFab(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPileArea(List<BusinessCard> cards) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            '${_activeIndex + 1} / ${cards.length}',
            style: const TextStyle(
                color: Color(0xFFDAA520), fontSize: 11, letterSpacing: 2),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onVerticalDragStart: _onDragStart,
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: (d) => _onDragEnd(d, cards),
              child: AnimatedBuilder(
                animation: _swipeCtrl,
                builder: (context, _) => _buildStack(cards),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.keyboard_arrow_up,
                  color: Colors.white24, size: 16),
              const SizedBox(width: 4),
              Text(
                cards.length > 1
                    ? 'Glisser vers le haut pour la suivante'
                    : 'Appuyer pour voir la carte',
                style: const TextStyle(
                    color: Colors.white24, fontSize: 11, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStack(List<BusinessCard> cards) {
    final n = cards.length;
    final visibleCount = n.clamp(1, 3);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (int behind = visibleCount - 1; behind >= 1; behind--)
          _buildBehindCard(cards, behind, n),
        _buildActiveCard(cards),
      ],
    );
  }

  Widget _buildBehindCard(List<BusinessCard> cards, int behind, int n) {
    final idx = (_activeIndex + behind) % n;
    final card = cards[idx];
    final baseOffset = behind * 14.0;
    final scale = 1.0 - behind * 0.06;
    final opacity = 1.0 - behind * 0.25;
    final dragProgress = (_dragDy.abs() / 120).clamp(0.0, 1.0);
    final animatedOffset = baseOffset * (1 - dragProgress * 0.4);

    return Positioned.fill(
      child: Align(
        alignment: Alignment.topCenter,
        child: Transform.translate(
          offset: Offset(0, animatedOffset),
          child: Transform.scale(
            scale: scale + dragProgress * 0.03,
            child: Opacity(
              opacity: opacity,
              child: _LuxCardWidget(
                card: card,
                isActive: false,
                shimmerAnim: _shimmerAnim,
                onTap: null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCard(List<BusinessCard> cards) {
    final card = cards[_activeIndex];
    final swipeProgress = _swipeCtrl.value;
    final dragProgress = (_dragDy / -300).clamp(0.0, 1.0);
    final totalProgress = (dragProgress + swipeProgress).clamp(0.0, 1.0);
    final translateY = _dragDy - swipeProgress * 400;
    final opacity = (1.0 - totalProgress * 1.4).clamp(0.0, 1.0);
    final rotate = _dragDy * 0.0008;

    return Transform.translate(
      offset: Offset(0, translateY),
      child: Transform.rotate(
        angle: rotate,
        child: Opacity(
          opacity: opacity,
          child: GestureDetector(
            onTap: () => _openCardView(card),
            child: _LuxCardWidget(
              card: card,
              isActive: true,
              shimmerAnim: _shimmerAnim,
              onTap: () => _openCardView(card),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 22,
          height: 2,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Colors.transparent, Color(0xFFDAA520)]),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Column(
          children: [
            const Text('LUX STACK',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 5)),
            if (count > 0)
              Text('$count carte${count > 1 ? 's' : ''}',
                  style: const TextStyle(
                      color: Color(0xFFDAA520),
                      fontSize: 10,
                      letterSpacing: 2)),
          ],
        ),
        Container(
          width: 22,
          height: 2,
          margin: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFDAA520), Colors.transparent]),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TextField(
        onChanged: (q) => setState(() {
          _searchQuery = q;
          _activeIndex = 0;
        }),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Rechercher une carte...',
          hintStyle:
              TextStyle(color: Colors.grey.shade600, fontSize: 13),
          prefixIcon:
              const Icon(Icons.search, color: Colors.white38, size: 20),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide(
                color: const Color(0xFFDAA520).withOpacity(0.4), width: 1),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFFDAA520).withOpacity(0.3),
                  width: 1.5),
              color: const Color(0xFFDAA520).withOpacity(0.06),
            ),
            child: const Icon(Icons.style,
                color: Color(0xFFDAA520), size: 30),
          ),
          const SizedBox(height: 20),
          const Text('Aucune carte',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(
            'Appuyez sur "+" pour créer\nvotre première carte de luxe',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.grey.shade600, fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () => _goToStudio(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFB8860B), Color(0xFFF5D060)]),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text('Créer une carte',
                  style: TextStyle(
                      color: Color(0xFF1A0A00),
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFab() {
    return GestureDetector(
      onTap: () => _goToStudio(),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFB8860B), Color(0xFFF5D060)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFDAA520).withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6)),
          ],
        ),
        child: const Icon(Icons.add, color: Color(0xFF1A0A00), size: 28),
      ),
    );
  }

  Widget _buildBg() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF030712), Color(0xFF0D1117)],
          ),
        ),
      );

  Widget _buildGlow({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required Color color,
    required double opacity,
  }) =>
      Positioned(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: color.withOpacity(opacity)),
        ),
      );
}

// ═════════════════════════════════════════════
//  VUE DÉTAIL CARTE (plein écran avec flip)
// ═════════════════════════════════════════════

class _CardDetailView extends StatefulWidget {
  final BusinessCard card;
  final Animation<double> shimmerAnim;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CardDetailView({
    required this.card,
    required this.shimmerAnim,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_CardDetailView> createState() => _CardDetailViewState();
}

class _CardDetailViewState extends State<_CardDetailView>
    with SingleTickerProviderStateMixin {
  bool _isFlipped = false;
  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _flipAnim = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    setState(() => _isFlipped = !_isFlipped);
    _isFlipped ? _flipCtrl.forward() : _flipCtrl.reverse();
  }

  Color get _textColor {
    switch (widget.card.texture) {
      case CardTexture.gold:
        return const Color(0xFF1A0A00);
      case CardTexture.glass:
        return Colors.white;
      case CardTexture.carbon:
        return const Color(0xFFE0E0E0);
    }
  }

  Color get _labelColor {
    switch (widget.card.texture) {
      case CardTexture.gold:
        return const Color(0xFF3A2500);
      case CardTexture.glass:
        return Colors.white60;
      case CardTexture.carbon:
        return Colors.white30;
    }
  }

  BoxDecoration get _cardDecoration {
    switch (widget.card.texture) {
      case CardTexture.gold:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFB8860B),
              Color(0xFFDAA520),
              Color(0xFFF5D060),
              Color(0xFFDAA520),
              Color(0xFFB8860B)
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFDAA520).withOpacity(0.5),
                blurRadius: 40,
                offset: const Offset(0, 16))
          ],
        );
      case CardTexture.glass:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
                color: Colors.blue.withOpacity(0.2),
                blurRadius: 40,
                offset: const Offset(0, 16))
          ],
        );
      case CardTexture.carbon:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: const Color(0xFF2E2E2E)),
          boxShadow: const [
            BoxShadow(
                color: Color(0xBB000000),
                blurRadius: 36,
                offset: Offset(0, 14))
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final contactLines = <String>[];
    if (card.email.isNotEmpty) contactLines.add(card.email);
    if (card.phone.isNotEmpty) contactLines.add(card.phone);
    for (final f in card.extraFields) {
      if (f['value']?.isNotEmpty == true && contactLines.length < 3) {
        contactLines.add(f['value']!);
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Text(
                  card.name.isEmpty ? 'Carte' : card.name,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13, letterSpacing: 3),
                ),
              ),

              // Carte flip
              GestureDetector(
                onTap: _toggleFlip,
                child: AnimatedBuilder(
                  animation: _flipAnim,
                  builder: (_, __) {
                    final showFront = _flipAnim.value <= pi / 2;
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(2, 2, 0.001)
                        ..rotateY(_flipAnim.value),
                      child: showFront
                          ? _buildFront(card, contactLines, context)
                          : _buildBack(card, context),
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _isFlipped
                      ? 'Toucher pour voir le recto'
                      : 'Toucher la carte pour scanner le QR',
                  style: const TextStyle(
                      color: Colors.white30,
                      fontSize: 11,
                      letterSpacing: 0.8),
                ),
              ),

              const SizedBox(height: 32),

              // Boutons Supprimer / Modifier
              GestureDetector(
                onTap: () {},
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: widget.onDelete,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E0808),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                              color:
                                  const Color(0xFFE24B4A).withOpacity(0.3)),
                        ),
                        child: const Row(children: [
                          Icon(Icons.delete_outline,
                              color: Color(0xFFE24B4A), size: 17),
                          SizedBox(width: 7),
                          Text('Supprimer',
                              style: TextStyle(
                                  color: Color(0xFFE24B4A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: widget.onEdit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 13),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFB8860B), Color(0xFFF5D060)]),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                                color:
                                    const Color(0xFFDAA520).withOpacity(0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 5)),
                          ],
                        ),
                        child: const Row(children: [
                          Icon(Icons.edit,
                              color: Color(0xFF1A0A00), size: 17),
                          SizedBox(width: 7),
                          Text('Modifier',
                              style: TextStyle(
                                  color: Color(0xFF1A0A00),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFront(
      BusinessCard card, List<String> contactLines, BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width - 48;
    final entreprise = card.extraFields
            .where((f) => f['label']!.toLowerCase().contains('entreprise'))
            .firstOrNull?['value'] ??
        '';

    return Container(
      width: w,
      height: 210,
      decoration: _cardDecoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(children: [
          if (card.texture == CardTexture.gold)
            AnimatedBuilder(
              animation: widget.shimmerAnim,
              builder: (_, __) => Positioned.fill(
                child: FractionalTranslation(
                  translation: Offset(widget.shimmerAnim.value, 0),
                  child: Transform.rotate(
                    angle: -0.3,
                    child: Container(
                      width: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.2),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPhoto(card, width: 80, height: 100),
                const SizedBox(width: 16),
                Container(
                    width: 1,
                    height: double.infinity,
                    color: _textColor.withOpacity(0.2)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LUX · STACK',
                          style: TextStyle(
                              fontSize: 8,
                              letterSpacing: 3,
                              color: _labelColor)),
                      const Spacer(),
                      Text(
                          card.name.isEmpty ? 'Sans nom' : card.name,
                          style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: _textColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(card.jobTitle.isEmpty ? '—' : card.jobTitle,
                          style: TextStyle(
                              fontSize: 11,
                              color: _textColor.withOpacity(0.7),
                              fontStyle: FontStyle.italic)),
                      if (entreprise.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(entreprise,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: _textColor.withOpacity(0.55))),
                        ),
                      const SizedBox(height: 10),
                      Container(
                          height: 1,
                          color: _textColor.withOpacity(0.12),
                          margin: const EdgeInsets.only(bottom: 8)),
                      ...contactLines.take(3).map((l) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(l,
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: _textColor.withOpacity(0.6)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  VERSO — VRAI QR CODE SCANNABLE
  // ─────────────────────────────────────────────
  Widget _buildBack(BusinessCard card, BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width - 48;

    // Couleur du QR selon la texture
    final qrColor = card.texture == CardTexture.gold
        ? const Color(0xFF1A0A00)
        : card.texture == CardTexture.carbon
            ? const Color(0xFFE0E0E0)
            : Colors.white;

    // Fond QR (contraste) : blanc pour gold/carbon, sombre pour glass
    final qrBg = card.texture == CardTexture.gold
        ? Colors.transparent
        : card.texture == CardTexture.carbon
            ? Colors.transparent
            : Colors.white.withOpacity(0.08);

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(pi),
      child: Container(
        width: w,
        height: 210,
        decoration: _cardDecoration,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Vrai QR Code ──
              Container(
                width: 130,
                height: 130,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: qrBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: QrImageView(
                  data: card.qrContent,
                  version: QrVersions.auto,
                  backgroundColor: Colors.transparent,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: qrColor,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: qrColor,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Infos à droite du QR
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name.isEmpty ? '—' : card.name,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textColor),
                    ),
                    if (card.jobTitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(card.jobTitle,
                            style: TextStyle(
                                fontSize: 10,
                                color: _textColor.withOpacity(0.6),
                                fontStyle: FontStyle.italic)),
                      ),
                    const SizedBox(height: 8),
                    if (card.email.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(card.email,
                            style: TextStyle(
                                fontSize: 9,
                                color: _textColor.withOpacity(0.55)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    if (card.phone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(card.phone,
                            style: TextStyle(
                                fontSize: 9,
                                color: _textColor.withOpacity(0.55)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ...card.extraFields.take(2).map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            f['value']?.isNotEmpty == true
                                ? f['value']!
                                : f['label']!,
                            style: TextStyle(
                                fontSize: 9,
                                color: _textColor.withOpacity(0.55)),
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

  Widget _buildPhoto(BusinessCard card,
      {required double width, required double height}) {
    final hasPhoto = card.photoPath != null &&
        card.photoPath!.isNotEmpty &&
        File(card.photoPath!).existsSync();
    if (hasPhoto) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _textColor.withOpacity(0.2))),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.file(File(card.photoPath!), fit: BoxFit.cover)),
      );
    }
    final initials = card.name.isNotEmpty
        ? card.name
            .trim()
            .split(' ')
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase()
        : '?';
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: _textColor.withOpacity(0.08),
          border: Border.all(color: _textColor.withOpacity(0.2))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(initials,
            style: TextStyle(
                color: _textColor,
                fontSize: 24,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text('PHOTO',
            style: TextStyle(
                color: _textColor.withOpacity(0.3),
                fontSize: 7,
                letterSpacing: 1.5)),
      ]),
    );
  }
}

// ═════════════════════════════════════════════
//  WIDGET CARTE DANS LA PILE
// ═════════════════════════════════════════════

class _LuxCardWidget extends StatelessWidget {
  final BusinessCard card;
  final bool isActive;
  final Animation<double> shimmerAnim;
  final VoidCallback? onTap;

  const _LuxCardWidget({
    required this.card,
    required this.isActive,
    required this.shimmerAnim,
    required this.onTap,
  });

  Color get _textColor {
    switch (card.texture) {
      case CardTexture.gold:
        return const Color(0xFF1A0A00);
      case CardTexture.glass:
        return Colors.white;
      case CardTexture.carbon:
        return const Color(0xFFE0E0E0);
    }
  }

  Color get _labelColor {
    switch (card.texture) {
      case CardTexture.gold:
        return const Color(0xFF3A2500);
      case CardTexture.glass:
        return Colors.white60;
      case CardTexture.carbon:
        return Colors.white30;
    }
  }

  BoxDecoration get _decoration {
    switch (card.texture) {
      case CardTexture.gold:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFB8860B),
              Color(0xFFDAA520),
              Color(0xFFF5D060),
              Color(0xFFDAA520),
              Color(0xFFB8860B)
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFDAA520).withOpacity(0.35),
                blurRadius: 28,
                offset: const Offset(0, 10))
          ],
        );
      case CardTexture.glass:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white.withOpacity(0.07),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
                color: Colors.blue.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 8))
          ],
        );
      case CardTexture.carbon:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: const Color(0xFF2E2E2E)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x99000000),
                blurRadius: 20,
                offset: Offset(0, 8))
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactLines = <String>[];
    if (card.email.isNotEmpty) contactLines.add(card.email);
    if (card.phone.isNotEmpty) contactLines.add(card.phone);
    for (final f in card.extraFields) {
      if (!f['label']!.toLowerCase().contains('entreprise') &&
          f['value']?.isNotEmpty == true &&
          contactLines.length < 2) {
        contactLines.add(f['value']!);
      }
    }
    final entreprise = card.extraFields
            .where((f) => f['label']!.toLowerCase().contains('entreprise'))
            .firstOrNull?['value'] ??
        '';

    return Container(
      decoration: _decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(children: [
          if (card.texture == CardTexture.gold)
            AnimatedBuilder(
              animation: shimmerAnim,
              builder: (_, __) => Positioned.fill(
                child: FractionalTranslation(
                  translation: Offset(shimmerAnim.value, 0),
                  child: Transform.rotate(
                    angle: -0.3,
                    child: Container(
                      width: 70,
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
          Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPhoto(),
                const SizedBox(width: 14),
                Container(
                    width: 1,
                    height: double.infinity,
                    color: _textColor.withOpacity(0.18)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LUX · STACK',
                          style: TextStyle(
                              fontSize: 7.5,
                              letterSpacing: 3,
                              color: _labelColor)),
                      const Spacer(),
                      Text(
                          card.name.isEmpty ? 'Sans nom' : card.name,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _textColor,
                              letterSpacing: 0.2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(card.jobTitle.isEmpty ? '—' : card.jobTitle,
                          style: TextStyle(
                              fontSize: 11,
                              color: _textColor.withOpacity(0.7),
                              fontStyle: FontStyle.italic),
                          maxLines: 1),
                      if (entreprise.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(entreprise,
                              style: TextStyle(
                                  fontSize: 9.5,
                                  color: _textColor.withOpacity(0.55))),
                        ),
                      const SizedBox(height: 10),
                      Container(
                          height: 1,
                          color: _textColor.withOpacity(0.12),
                          margin: const EdgeInsets.only(bottom: 8)),
                      ...contactLines.map((l) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(l,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: _textColor.withOpacity(0.55)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isActive)
            Positioned(
              bottom: 12,
              right: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _textColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: _textColor.withOpacity(0.15)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.touch_app,
                      size: 11, color: _textColor.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text('Toucher pour voir',
                      style: TextStyle(
                          fontSize: 9, color: _textColor.withOpacity(0.5))),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildPhoto() {
    final hasPhoto = card.photoPath != null &&
        card.photoPath!.isNotEmpty &&
        File(card.photoPath!).existsSync();
    if (hasPhoto) {
      return Container(
        width: 74,
        height: 92,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border:
                Border.all(color: _textColor.withOpacity(0.2), width: 1)),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(File(card.photoPath!), fit: BoxFit.cover)),
      );
    }
    final initials = card.name.isNotEmpty
        ? card.name
            .trim()
            .split(' ')
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase()
        : '?';
    return Container(
      width: 74,
      height: 92,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          color: _textColor.withOpacity(0.08),
          border:
              Border.all(color: _textColor.withOpacity(0.2), width: 1)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(initials,
            style: TextStyle(
                color: _textColor,
                fontSize: 22,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text('PHOTO',
            style: TextStyle(
                color: _textColor.withOpacity(0.3),
                fontSize: 7,
                letterSpacing: 1.5)),
      ]),
    );
  }
}