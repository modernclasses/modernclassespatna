enum UserRole { student, teacher, admin }

/// Core User Profile Model for Modern Classes Patna.
class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? avatarUrl;
  final List<String> enrolledBatchIds;
  final List<String> enrolledCourseIds;
  final List<String> assignedBatchIds; // For teachers
  final DateTime? joinedDate;
  final String? bio;
  final String targetExam;
  final String medium;
  final bool isActive;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.enrolledBatchIds = const [],
    this.enrolledCourseIds = const [],
    this.assignedBatchIds = const [],
    this.joinedDate,
    this.bio,
    this.targetExam = "BPSC 71st Civil Services",
    this.medium = "Bilingual (Hindi + English)",
    this.isActive = true,
  });

  static const UserModel guest = UserModel(
    id: '',
    name: 'Guest Aspirant',
    email: '',
    phone: '',
    role: UserRole.student,
  );

  /// Factory constructor to deserialize from Supabase `public.profiles` row.
  factory UserModel.fromMap(Map<String, dynamic> map) {
    UserRole parsedRole;
    switch (map['role']?.toString().toLowerCase()) {
      case 'teacher':
      case 'faculty':
        parsedRole = UserRole.teacher;
        break;
      case 'admin':
        parsedRole = UserRole.admin;
        break;
      default:
        parsedRole = UserRole.student;
    }

    return UserModel(
      id: map['id']?.toString() ?? '',
      name: map['full_name'] ?? map['name'] ?? 'Student Aspirant',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: parsedRole,
      avatarUrl: map['avatar_url'],
      bio: map['bio'],
      targetExam: map['target_exam'] ?? 'BPSC 71st Civil Services',
      medium: map['medium'] ?? 'Bilingual (Hindi + English)',
      isActive: map['is_active'] ?? true,
      joinedDate: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  /// Serialize to Supabase `public.profiles` format.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': name,
      'email': email,
      'phone': phone,
      'role': role.name,
      'avatar_url': avatarUrl,
      'bio': bio,
      'target_exam': targetExam,
      'medium': medium,
      'is_active': isActive,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? avatarUrl,
    List<String>? enrolledBatchIds,
    List<String>? enrolledCourseIds,
    List<String>? assignedBatchIds,
    DateTime? joinedDate,
    String? bio,
    String? targetExam,
    String? medium,
    bool? isActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      enrolledBatchIds: enrolledBatchIds ?? this.enrolledBatchIds,
      enrolledCourseIds: enrolledCourseIds ?? this.enrolledCourseIds,
      assignedBatchIds: assignedBatchIds ?? this.assignedBatchIds,
      joinedDate: joinedDate ?? this.joinedDate,
      bio: bio ?? this.bio,
      targetExam: targetExam ?? this.targetExam,
      medium: medium ?? this.medium,
      isActive: isActive ?? this.isActive,
    );
  }
}
