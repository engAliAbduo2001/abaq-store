class AbaqUser {
  const AbaqUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    this.role = 'customer',
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String role;

  bool get isAdmin => role == 'admin';

  Map<String, String> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'address': address,
    'role': role,
  };

  factory AbaqUser.fromJson(Map<String, dynamic> json) {
    return AbaqUser(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      email: _requiredString(json, 'email'),
      phone: _requiredString(json, 'phone'),
      address: _requiredString(json, 'address'),
      role: json['role'] is String ? json['role'] as String : 'customer',
    );
  }
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AbaqUser user;

  Map<String, Object> toJson() => {'token': token, 'user': user.toJson()};

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    if (user is! Map) {
      throw const FormatException('The account response is invalid.');
    }

    return AuthSession(
      token: _requiredString(json, 'token'),
      user: AbaqUser.fromJson(Map<String, dynamic>.from(user)),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Account field "$key" is missing or invalid.');
  }
  return value;
}
