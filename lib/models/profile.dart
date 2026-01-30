// ignore_for_file: constant_identifier_names

enum UserRole {
  umat,
  pastor,
  suster,
  bruder,
  frater,
  katekis,
  katekumen,
  unknown
}

enum AccountStatus {
  unverified,
  pending,
  verified_catholic,
  verified_pastoral,
  rejected,
  banned,
  unknown,
}

enum CounselorStatus { online, busy, offline, unknown }

class Profile {
  final String id;
  
  // Basic Info
  final String? fullName;
  final String? email;
  final String? avatarUrl;
  final String? bannerUrl;
  
  // Status Enums
  final UserRole role;
  final AccountStatus verificationStatus;
  final CounselorStatus counselorStatus;
  
  // Counselor Metrics
  final int ministryCount;
  
  // Personal Info
  final String? bio;
  final DateTime? birthDate;
  final String? ethnicity;
  final String? gender;
  final String? baptismName; // NEW Field
  final String? maritalStatus; // NEW Field
  final bool isCatechumen;
  final bool profileFilled;
  final DateTime? termsAcceptedAt;
  final DateTime? updatedAt;
  
  // Location Text
  final String? country;
  final String? diocese;
  final String? parish;
  
  // Location IDs
  final String? countryId;
  final String? dioceseId;
  final String? churchId;
  
  // Privacy Settings
  final bool showAge;
  final bool showEthnicity;

  Profile({
    required this.id,
    this.fullName,
    this.email,
    this.avatarUrl,
    this.bannerUrl,
    this.role = UserRole.umat,
    this.verificationStatus = AccountStatus.unverified,
    this.counselorStatus = CounselorStatus.offline,
    this.ministryCount = 0,
    this.bio,
    this.country,
    this.diocese,
    this.parish,
    this.countryId,
    this.dioceseId,
    this.churchId,
    this.birthDate,
    this.ethnicity,
    this.gender,
    this.baptismName,
    this.maritalStatus,
    this.isCatechumen = false,
    this.profileFilled = false,
    this.termsAcceptedAt,
    this.updatedAt,
    this.showAge = false,
    this.showEthnicity = false,
  });

  // --- LOGIC GETTERS ---

  int? get age {
    if (birthDate == null) return null;
    final today = DateTime.now();
    int a = today.year - birthDate!.year;
    if (today.month < birthDate!.month ||
        (today.month == birthDate!.month && today.day < birthDate!.day)) {
      a--;
    }
    return a;
  }

  // Combine fullName + BaptismName for display
  String get fullNameWithBaptism {
    if (baptismName != null && baptismName!.isNotEmpty) {
      return "$fullName ($baptismName)";
    }
    return fullName ?? "User";
  }

  // ALIAS for consistent display name
  String get displayName => fullNameWithBaptism;

  // Phase 3 Rule: Show age ONLY if under 18.
  bool get shouldShowAge {
    final a = age;
    if (a == null) return false;
    return a < 18;
  }

  bool get isClergy {
    return [
      UserRole.pastor,
      UserRole.bruder,
      UserRole.suster,
      UserRole.frater,
      UserRole.katekis,
    ].contains(role);
  }

  bool get canReceiveMassInvite {
    return [UserRole.umat, UserRole.katekumen].contains(role);
  }

  bool get isVerified {
    return [
      AccountStatus.verified_catholic,
      AccountStatus.verified_pastoral,
    ].contains(verificationStatus);
  }

  bool get isOnline => counselorStatus == CounselorStatus.online;

  String get roleLabel {
    switch (role) {
      case UserRole.pastor:
        return "Pastor";
      case UserRole.bruder:
        return "Bruder";
      case UserRole.suster:
        return "Suster";
      case UserRole.frater:
        return "Frater";
      case UserRole.katekis:
        return "Katekis";
      case UserRole.katekumen:
        return "Katekumen";
      case UserRole.umat:
      default:
        return "Umat";
    }
  }

  // --- JSON SERIALIZATION ---

  Profile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? baptismName,
    String? maritalStatus,
    String? avatarUrl,
    String? bannerUrl,
    UserRole? role,
    AccountStatus? verificationStatus,
    CounselorStatus? counselorStatus,
    int? ministryCount,
    String? bio,
    String? country,
    String? diocese,
    String? parish,
    String? countryId,
    String? dioceseId,
    String? churchId,
    DateTime? birthDate,
    String? ethnicity,
    String? gender,
    bool? isCatechumen,
    bool? profileFilled,
    DateTime? termsAcceptedAt,
    DateTime? updatedAt,
    bool? showAge,
    bool? showEthnicity,
  }) {
    return Profile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      baptismName: baptismName ?? this.baptismName,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      role: role ?? this.role,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      counselorStatus: counselorStatus ?? this.counselorStatus,
      ministryCount: ministryCount ?? this.ministryCount,
      bio: bio ?? this.bio,
      country: country ?? this.country,
      diocese: diocese ?? this.diocese,
      parish: parish ?? this.parish,
      countryId: countryId ?? this.countryId,
      dioceseId: dioceseId ?? this.dioceseId,
      churchId: churchId ?? this.churchId,
      birthDate: birthDate ?? this.birthDate,
      ethnicity: ethnicity ?? this.ethnicity,
      gender: gender ?? this.gender,
      isCatechumen: isCatechumen ?? this.isCatechumen,
      profileFilled: profileFilled ?? this.profileFilled,
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      showAge: showAge ?? this.showAge,
      showEthnicity: showEthnicity ?? this.showEthnicity,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic val) {
      if (val is bool) return val;
      if (val is num) return val != 0;
      if (val is String) return val.toLowerCase() == 'true';
      return false;
    }
    // Helper to parse Enums
    UserRole parseRole(String? val) {
      if (val == null) return UserRole.umat;
      try {
        return UserRole.values.firstWhere(
          (e) => e.name.toLowerCase() == val.toLowerCase(),
          orElse: () => UserRole.umat,
        );
      } catch (_) {
        return UserRole.umat;
      }
    }

    AccountStatus parseStatus(String? val) {
      if (val == null) return AccountStatus.unverified;
      final v = val.toLowerCase();
      
      switch (v) {
        case 'verified':
        case 'verified_catholic':
        case 'approved': // legacy support
          return AccountStatus.verified_catholic;
        case 'verified_pastoral':
          return AccountStatus.verified_pastoral;
        case 'pending':
          return AccountStatus.pending;
        case 'rejected':
          return AccountStatus.rejected;
        case 'banned':
          return AccountStatus.banned;
        default:
          return AccountStatus.unverified;
      }
    }

    CounselorStatus parseCounselorStatus(String? val) {
      if (val == null) return CounselorStatus.offline;
      try {
        return CounselorStatus.values.firstWhere(
          (e) => e.name.toLowerCase() == val.toLowerCase(),
          orElse: () => CounselorStatus.offline,
        );
      } catch (_) {
        return CounselorStatus.offline;
      }
    }

    return Profile(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString(),
      email: json['email']?.toString(),
      baptismName: json['baptism_name']?.toString(),
      maritalStatus: json['marital_status']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      bannerUrl: json['banner_url']?.toString(),
      role: parseRole(json['role']?.toString()),
      verificationStatus: parseStatus(json['verification_status']?.toString()),
      counselorStatus: parseCounselorStatus(
        json['counselor_status']?.toString(),
      ),
      ministryCount: (json['ministry_count'] as num?)?.toInt() ?? 0,
      bio: json['bio']?.toString(),
      country: (json['countries'] != null && json['countries'] is Map && json['countries']['name'] != null)
          ? json['countries']['name']
          : json['country']?.toString(),
      diocese: (json['dioceses'] != null && json['dioceses'] is Map && json['dioceses']['name'] != null)
          ? json['dioceses']['name']
          : json['diocese']?.toString(),
      parish: (json['churches'] != null && json['churches'] is Map && json['churches']['name'] != null)
          ? json['churches']['name']
          : json['parish']?.toString(),
      countryId: json['country_id']?.toString(),
      dioceseId: json['diocese_id']?.toString(),
      churchId: json['church_id']?.toString(),
      ethnicity: json['ethnicity']?.toString(),
      gender: json['gender']?.toString(),
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'].toString())
          : null,
      isCatechumen: parseBool(json['is_catechumen']),
      profileFilled: parseBool(json['profile_filled']),
      termsAcceptedAt: json['terms_accepted_at'] != null
          ? DateTime.tryParse(json['terms_accepted_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      showAge: json['is_age_visible'] == true,
      showEthnicity: json['is_ethnicity_visible'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'baptism_name': baptismName,
      'marital_status': maritalStatus,
      'avatar_url': avatarUrl,
      'banner_url': bannerUrl,
      'role': role.name,
      'verification_status': verificationStatus.name,
      'counselor_status': counselorStatus.name,
      'ministry_count': ministryCount,
      'bio': bio,
      'country': country,
      'diocese': diocese,
      'parish': parish,
      'country_id': countryId,
      'diocese_id': dioceseId,
      'church_id': churchId,
      'birth_date': birthDate != null
          ? "${birthDate!.year}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}"
          : null,
      'ethnicity': ethnicity,
      'gender': gender,
      'is_catechumen': isCatechumen,
      'profile_filled': profileFilled,
      'terms_accepted_at': termsAcceptedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_age_visible': showAge,
      'is_ethnicity_visible': showEthnicity,
    };
  }
}
