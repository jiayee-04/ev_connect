enum AuthProvider { email, google, apple }

class AppUser {
  final String fullName;
  final String email;
  final String phone;
  final String? password; // null for Google/Apple accounts - no local password
  final AuthProvider provider;

  AppUser({
    required this.fullName,
    required this.email,
    required this.phone,
    this.password,
    this.provider = AuthProvider.email,
  });

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'password': password,
        'provider': provider.name,
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
      );

  AppUser copyWith({String? fullName, String? email, String? phone}) {
    return AppUser(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      password: password,
      provider: provider,
    );
  }
}
