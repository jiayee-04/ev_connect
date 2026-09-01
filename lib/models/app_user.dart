enum AuthProvider { email, google, apple }

class AppUser {
  final String fullName;
  final String email;
  final String phone;
  final String? password;
  final AuthProvider provider;
  final String? photoPath;

  AppUser({
    required this.fullName,
    required this.email,
    required this.phone,
    this.password,
    this.provider = AuthProvider.email,
    this.photoPath,
  });

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'password': password,
        'provider': provider.name,
        'photoPath': photoPath,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        fullName: json['fullName'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'] ?? '',
        password: json['password'],
        provider: AuthProvider.values.firstWhere(
          (p) => p.name == json['provider'],
          orElse: () => AuthProvider.email,
        ),
        photoPath: json['photoPath'],
      );

  AppUser copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? photoPath,
    bool clearPhoto = false,
  }) {
    return AppUser(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      password: password,
      provider: provider,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    );
  }
}
