class ChatModel {
  final String id;
  final String name;
  final String? description;
  final String? photoUrl;
  final List<String> members;
  final String createdBy;
  final DateTime createdAt;
  final String lastMessage;
  final DateTime lastMessageTime;
  final bool isPrivate;

  ChatModel({
    required this.id,
    required this.name,
    this.description,
    this.photoUrl,
    required this.members,
    required this.createdBy,
    required this.createdAt,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.isPrivate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'photoUrl': photoUrl,
      'members': members,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'isPrivate': isPrivate,
    };
  }

  factory ChatModel.fromMap(Map<String, dynamic> map) {
    return ChatModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      photoUrl: map['photoUrl'],
      members: List<String>.from(map['members'] ?? []),
      createdBy: map['createdBy'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: DateTime.parse(map['lastMessageTime'] ?? DateTime.now().toIso8601String()),
      isPrivate: map['isPrivate'] ?? false,
    );
  }

  ChatModel copyWith({
    String? id,
    String? name,
    String? description,
    String? photoUrl,
    List<String>? members,
    String? createdBy,
    DateTime? createdAt,
    String? lastMessage,
    DateTime? lastMessageTime,
    bool? isPrivate,
  }) {
    return ChatModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      members: members ?? this.members,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }
}
