class UserProfile {
  final String name;
  final String phone;
  final String location;
  final String role; // 'Farmer' or 'Customer'

  UserProfile({
    required this.name,
    required this.phone,
    required this.location,
    required this.role,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'location': location,
        'role': role,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        name: j['name'] ?? 'Farmer',
        phone: j['phone'] ?? '',
        location: j['location'] ?? 'Telangana & Andhra Pradesh, India',
        role: j['role'] ?? 'Farmer',
      );

  factory UserProfile.defaultProfile() => UserProfile(
        name: 'Farmer',
        phone: '',
        location: 'Telangana & Andhra Pradesh, India',
        role: 'Farmer',
      );
}
