import 'package:uuid/uuid.dart';

class Board {
  final String id;
  final String? homeId;
  final String? roomId;
  final String ownerId;
  final String name;
  final String? description;
  final String? location;
  final String? macAddress;
  final String status; // online, offline, maintenance
  final String? firmwareVersion;
  final DateTime? lastOnline;
  final Map<String, dynamic> connectionInfo;
  final Map<String, dynamic> metadata;
  final bool isActive;
  final bool isClaimed;
  final DateTime createdAt;
  final DateTime updatedAt;

  Board({
    String? id,
    this.homeId,
    this.roomId,
    required this.ownerId,
    required this.name,
    this.description,
    this.location,
    this.macAddress,
    this.status = 'offline',
    this.firmwareVersion,
    this.lastOnline,
    Map<String, dynamic>? connectionInfo,
    Map<String, dynamic>? metadata,
    this.isActive = true,
    this.isClaimed = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        connectionInfo = connectionInfo ?? {},
        metadata = metadata ?? {},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      id: json['id'] as String,
      homeId: json['home_id'] as String?,
      roomId: json['room_id'] as String?,
      ownerId: json['owner_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      macAddress: json['mac_address'] as String?,
      status: json['status'] as String? ?? 'offline',
      firmwareVersion: json['firmware_version'] as String?,
      lastOnline: json['last_online'] != null ? DateTime.parse(json['last_online'] as String) : null,
      connectionInfo: (json['connection_info'] as Map<String, dynamic>?) ?? {},
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      isActive: (json['is_active'] as bool?) ?? true,
      isClaimed: (json['is_claimed'] as bool?) ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'home_id': homeId,
      'room_id': roomId,
      'owner_id': ownerId,
      'name': name,
      'description': description,
      'location': location,
      'mac_address': macAddress,
      'status': status,
      'firmware_version': firmwareVersion,
      'last_online': lastOnline?.toIso8601String(),
      'connection_info': connectionInfo,
      'metadata': metadata,
      'is_active': isActive,
      'is_claimed': isClaimed,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isOnline => status == 'online';
}
