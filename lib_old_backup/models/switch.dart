import 'package:uuid/uuid.dart';

class Switch {
  final String id;
  final String boardId;
  final String name;
  final String type; // light, fan, ac, heater, plug, other
  final String? icon;
  final int position;
  final bool state;
  final bool isEnabled;
  final DateTime lastStateChange;
  final double? powerRating;
  final String location;
  final String? description;
  final bool alexaEnabled;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  Switch({
    String? id,
    required this.boardId,
    required this.name,
    this.type = 'light',
    this.icon,
    this.position = 0,
    this.state = false,
    this.isEnabled = true,
    DateTime? lastStateChange,
    this.powerRating,
    this.location = '',
    this.description,
    this.alexaEnabled = true,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        lastStateChange = lastStateChange ?? DateTime.now(),
        metadata = metadata ?? {},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Switch.fromJson(Map<String, dynamic> json) {
    return Switch(
      id: json['id'] as String,
      boardId: json['board_id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'light',
      icon: json['icon'] as String?,
      position: (json['position'] as int?) ?? 0,
      state: (json['state'] as bool?) ?? false,
      isEnabled: (json['is_enabled'] as bool?) ?? true,
      lastStateChange: json['last_state_change'] != null ? DateTime.parse(json['last_state_change'] as String) : DateTime.now(),
      powerRating: (json['power_rating'] as num?)?.toDouble(),
      location: json['location'] as String? ?? '',
      description: json['description'] as String?,
      alexaEnabled: (json['alexa_enabled'] as bool?) ?? true,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'board_id': boardId,
      'name': name,
      'type': type,
      'icon': icon,
      'position': position,
      'state': state,
      'is_enabled': isEnabled,
      'last_state_change': lastStateChange.toIso8601String(),
      'power_rating': powerRating,
      'location': location,
      'description': description,
      'alexa_enabled': alexaEnabled,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get typeLabel {
    switch (type) {
      case 'light':
        return '💡 Light';
      case 'fan':
        return '🌀 Fan';
      case 'ac':
        return '❄️ AC';
      case 'heater':
        return '🔥 Heater';
      case 'plug':
        return '🔌 Plug';
      default:
        return '⚙️ Device';
    }
  }
}
