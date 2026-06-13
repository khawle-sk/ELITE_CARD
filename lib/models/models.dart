
enum CardTexture { gold, glass, carbon }

class BusinessCard {
  final String id;
  final String name;
  final String jobTitle;
  final String email;
  final String phone;
  final String? photoPath;
  final String? qrData;
  final CardTexture texture;
  final List<Map<String, String>> extraFields;
  final DateTime createdAt;

  BusinessCard({
    required this.id,
    required this.name,
    required this.jobTitle,
    this.email = '',
    this.phone = '',
    this.photoPath,
    this.qrData,
    this.texture = CardTexture.gold,
    this.extraFields = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // ── vCard 3.0 — reconnu par tous les scanners ──
  String get qrContent {
    // Chercher email et phone dans extraFields aussi
    final emailVal = email.isNotEmpty
        ? email
        : extraFields
            .where((f) => f['label']!.toLowerCase().contains('email'))
            .firstOrNull?['value'] ?? '';

    final phoneVal = phone.isNotEmpty
        ? phone
        : extraFields
            .where((f) =>
                f['label']!.toLowerCase().contains('téléphone') ||
                f['label']!.toLowerCase().contains('telephone') ||
                f['label']!.toLowerCase().contains('phone') ||
                f['label']!.toLowerCase().contains('tél') ||
                f['label']!.toLowerCase().contains('tel'))
            .firstOrNull?['value'] ?? '';

    // Champs extra (sans email/phone déjà traités)
    final extras = extraFields.where((f) {
      final l = f['label']!.toLowerCase();
      return !l.contains('email') &&
          !l.contains('téléphone') &&
          !l.contains('telephone') &&
          !l.contains('phone') &&
          !l.contains('tél') &&
          !l.contains('tel');
    }).toList();

    // Construire le vCard
    final buf = StringBuffer();
    buf.writeln('BEGIN:VCARD');
    buf.writeln('VERSION:3.0');

    // Nom
    final nameParts = name.trim().split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    buf.writeln('N:$lastName;$firstName;;;');
    buf.writeln('FN:$name');

    // Poste / Titre
    if (jobTitle.isNotEmpty) buf.writeln('TITLE:$jobTitle');

    // Email
    if (emailVal.isNotEmpty) buf.writeln('EMAIL:$emailVal');

    // Téléphone
    if (phoneVal.isNotEmpty) buf.writeln('TEL:$phoneVal');

    // Site web
    final website = extras
        .where((f) =>
            f['label']!.toLowerCase().contains('site') ||
            f['label']!.toLowerCase().contains('web') ||
            f['label']!.toLowerCase().contains('url'))
        .firstOrNull?['value'] ?? '';
    if (website.isNotEmpty) buf.writeln('URL:$website');

    // Entreprise
    final company = extras
        .where((f) => f['label']!.toLowerCase().contains('entreprise') ||
            f['label']!.toLowerCase().contains('company'))
        .firstOrNull?['value'] ?? '';
    if (company.isNotEmpty) buf.writeln('ORG:$company');

    // Adresse
    final address = extras
        .where((f) => f['label']!.toLowerCase().contains('adresse') ||
            f['label']!.toLowerCase().contains('address'))
        .firstOrNull?['value'] ?? '';
    if (address.isNotEmpty) buf.writeln('ADR:;;$address;;;;');

    // Autres champs → NOTE
    final others = extras.where((f) {
      final l = f['label']!.toLowerCase();
      return !l.contains('site') &&
          !l.contains('web') &&
          !l.contains('url') &&
          !l.contains('entreprise') &&
          !l.contains('company') &&
          !l.contains('adresse') &&
          !l.contains('address');
    }).toList();

    if (others.isNotEmpty) {
      final note = others
          .where((f) => f['value']?.isNotEmpty == true)
          .map((f) => '${f['label']}: ${f['value']}')
          .join(' | ');
      if (note.isNotEmpty) buf.writeln('NOTE:$note');
    }

    buf.write('END:VCARD');
    return buf.toString();
  }

  // ── Sérialisation ────────────────────────────

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'jobTitle': jobTitle,
        'email': email,
        'phone': phone,
        'photoPath': photoPath,
        'qrData': qrData,
        'texture': texture.index,
        'extraFields': extraFields,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BusinessCard.fromMap(Map<dynamic, dynamic> map) => BusinessCard(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        jobTitle: map['jobTitle'] as String? ?? '',
        email: map['email'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        photoPath: map['photoPath'] as String?,
        qrData: map['qrData'] as String?,
        texture: CardTexture.values[(map['texture'] as int?) ?? 0],
        extraFields: (map['extraFields'] as List<dynamic>? ?? [])
            .map((e) => Map<String, String>.from(e as Map))
            .toList(),
        createdAt:
            DateTime.tryParse(map['createdAt'] as String? ?? '') ??
                DateTime.now(),
      );

  BusinessCard copyWith({
    String? id,
    String? name,
    String? jobTitle,
    String? email,
    String? phone,
    String? photoPath,
    String? qrData,
    CardTexture? texture,
    List<Map<String, String>>? extraFields,
    DateTime? createdAt,
  }) =>
      BusinessCard(
        id: id ?? this.id,
        name: name ?? this.name,
        jobTitle: jobTitle ?? this.jobTitle,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        photoPath: photoPath ?? this.photoPath,
        qrData: qrData ?? this.qrData,
        texture: texture ?? this.texture,
        extraFields: extraFields ?? this.extraFields,
        createdAt: createdAt ?? this.createdAt,
      );
}