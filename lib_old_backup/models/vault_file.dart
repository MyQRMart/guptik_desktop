import 'package:uuid/uuid.dart';

class VaultFile {
  final String id;
  final String userId;
  final String fileName;
  final String filePath;
  final String? fileType;
  final String? mimeType;
  final BigInt? sizeBytes;
  bool isFavorite;
  final DateTime syncedAt;
  final DateTime createdAt;
  final String? publicAccessLink;

  VaultFile({
    String? id,
    required this.userId,
    required this.fileName,
    required this.filePath,
    this.fileType,
    this.mimeType,
    this.sizeBytes,
    this.isFavorite = false,
    DateTime? syncedAt,
    DateTime? createdAt,
    this.publicAccessLink,
  })  : id = id ?? const Uuid().v4(),
        syncedAt = syncedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  factory VaultFile.fromJson(Map<String, dynamic> json) {
    return VaultFile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      fileName: json['file_name'] as String,
      filePath: json['file_path'] as String,
      fileType: json['file_type'] as String?,
      mimeType: json['mime_type'] as String?,
      sizeBytes: json['size_bytes'] != null ? BigInt.from(json['size_bytes'] as int) : null,
      isFavorite: (json['is_favorite'] as bool?) ?? false,
      syncedAt: json['synced_at'] != null ? DateTime.parse(json['synced_at'] as String) : DateTime.now(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      publicAccessLink: json['public_access_link'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'file_name': fileName,
      'file_path': filePath,
      'file_type': fileType,
      'mime_type': mimeType,
      'size_bytes': sizeBytes?.toInt(),
      'is_favorite': isFavorite,
      'synced_at': syncedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'public_access_link': publicAccessLink,
    };
  }

  String get fileSizeFormatted {
    if (sizeBytes == null) return 'Unknown';
    final bytes = sizeBytes!.toInt();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
