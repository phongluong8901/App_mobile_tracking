class UserModel {
  final String userId;
  final String name;
  final List<double>? faceEmbedding;
  final String? registeredAt;

  UserModel({
    required this.userId,
    required this.name,
    this.faceEmbedding,
    this.registeredAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      faceEmbedding: json['faceEmbedding'] != null
          ? List<double>.from(
              (json['faceEmbedding'] as List).map((e) => (e as num).toDouble()),
            )
          : null,
      registeredAt: json['registeredAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      if (faceEmbedding != null) 'embedding': faceEmbedding,
      if (registeredAt != null) 'registeredAt': registeredAt,
    };
  }
}

