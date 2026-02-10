import 'package:uuid/uuid.dart';

class Home {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final String? wallpaperPath;
  final String? address;
  final String? city;
  final String? country;
  final String? location;
  final String timezone;
  final bool isPrimary;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Home({
    String? id,
    required this.userId,
    required this.name,
    this.description,
    this.wallpaperPath,
    this.address,
    this.city,
    this.country,
    this.location,
    this.timezone = 'UTC',
    this.isPrimary = false,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Home.fromJson(Map<String, dynamic> json) {
    return Home(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      wallpaperPath: json['wallpaper_path'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      location: json['location'] as String?,
      timezone: json['timezone'] as String? ?? 'UTC',
      isPrimary: (json['is_primary'] as bool?) ?? false,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'wallpaper_path': wallpaperPath,
      'address': address,
      'city': city,
      'country': country,
      'location': location,
      'timezone': timezone,
      'is_primary': isPrimary,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
