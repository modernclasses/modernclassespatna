enum UserRole { student, teacher, admin }

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
  final DateTime joinedDate;
  final String? bio;

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
    required this.joinedDate,
    this.bio,
  });

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
    );
  }
}
