// models.dart
// Ce fichier contient le modèle de données de la carte de visite.
// Il est importé dans studio_page.dart et dans les autres pages qui en ont besoin.

enum CardTexture { gold, glass, carbon }

class BusinessCard {
  String name;
  String jobTitle;
  String email;
  String phone;
  String? photoPath;
  CardTexture texture;

  BusinessCard({
    this.name = '',
    this.jobTitle = '',
    this.email = '',
    this.phone = '',
    this.photoPath,
    this.texture = CardTexture.gold,
  });

  // Convertir la carte en Map pour la sauvegarder dans Hive
  Map<String, dynamic> toMap() => {
        'name': name,
        'jobTitle': jobTitle,
        'email': email,
        'phone': phone,
        'photoPath': photoPath,
        'texture': texture.index, // on sauvegarde le numéro (0, 1, ou 2)
      };

  // Recréer une carte depuis les données sauvegardées
  factory BusinessCard.fromMap(Map<String, dynamic> map) => BusinessCard(
        name: map['name'] ?? '',
        jobTitle: map['jobTitle'] ?? '',
        email: map['email'] ?? '',
        phone: map['phone'] ?? '',
        photoPath: map['photoPath'],
        texture: CardTexture.values[map['texture'] ?? 0],
      );
}