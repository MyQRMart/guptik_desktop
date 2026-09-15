import 'package:uuid/uuid.dart';

class Room {
  final String id;
  final String homeId;
  final String name;
  final String? description;
  final String icon;
  final int displayOrder;
  final Map<String, dynamic> metadata;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Room({
    String? id,
    required this.homeId,
    required this.name,
    this.description,
    this.icon = 'meeting_room',
    this.displayOrder = 0,
    Map<String, dynamic>? metadata,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        metadata = metadata ?? {},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      homeId: json['home_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String? ?? 'meeting_room',
      displayOrder: (json['display_order'] as int?) ?? 0,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'home_id': homeId,
      'name': name,
      'description': description,
      'icon': icon,
      'display_order': displayOrder,
      'metadata': metadata,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
