class MessageModel {
  final String id;
  final String senderUid;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final String? imageUrl;
  final List<String>? readBy;

  MessageModel({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.imageUrl,
    this.readBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderUid': senderUid,
      'senderName': senderName,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'imageUrl': imageUrl,
      'readBy': readBy ?? [],
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] ?? '',
      senderUid: map['senderUid'] ?? '',
      senderName: map['senderName'] ?? '',
      content: map['content'] ?? '',
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      imageUrl: map['imageUrl'],
      readBy: List<String>.from(map['readBy'] ?? []),
    );
  }

  MessageModel copyWith({
    String? id,
    String? senderUid,
    String? senderName,
    String? content,
    DateTime? timestamp,
    String? imageUrl,
    List<String>? readBy,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderUid: senderUid ?? this.senderUid,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      readBy: readBy ?? this.readBy,
    );
  }
}
