
// ignore_for_file: constant_identifier_names

enum UserRole { umat, katekumen, pastor, bruder, suster, katekis, unknown }

enum AccountStatus {
  unverified,
  pending,
  verified_catholic,
  verified_pastoral,
  rejected,
  unknown,
}

enum CounselorStatus { online, busy, offline, unknown }

class Profile {
  final String id;
  final String? fullName;
  final String? avatarUrl;
  final String? bannerUrl;


  // Enums for strict typing
  final UserRole userRole;
  final AccountStatus accountStatus;

  // Counselor Specific
  final CounselorStatus counselorStatus;
  final int ministryCount;

  final String? bio;

  // Location (Text)
  final String? country;
  final String? diocese;
  final String? parish;

  // Location IDs
  final String? countryId;
  final String? dioceseId;
  final String? churchId;

  // Demographics
  final DateTime? birthDate;
  final String? ethnicity;

  // Privacy
  final bool showAge;
  final bool showEthnicity;

  Profile({
    required this.id,
    this.fullName,
    this.avatarUrl,
    this.bannerUrl,
    this.userRole = UserRole.umat,
    this.accountStatus = AccountStatus.unverified,
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
    this.showAge = false,
    this.showEthnicity = false,
  });

  // --- LOGIC GETTERS ---

  // Backward Compatibility for 'role' String usage
  // Returns string representation suitable for display or logic
  String? get role => userRole != UserRole.unknown ? userRole.name : 'umat';

  // Backward Compatibility for 'verificationStatus'
  String? get verificationStatus => accountStatus.name;

  bool get isClergy {
    return [
      UserRole.pastor,
      UserRole.bruder,
      UserRole.suster,
      UserRole.katekis,
    ].contains(userRole);
  }

  bool get canReceiveMassInvite {
    return [UserRole.umat, UserRole.katekumen].contains(userRole);
  }

  bool get isVerified {
    return [
      AccountStatus.verified_catholic,
      AccountStatus.verified_pastoral,
    ].contains(accountStatus);
  }

  bool get isOnline => counselorStatus == CounselorStatus.online;

  String get roleLabel {
    switch (userRole) {
      case UserRole.pastor:
        return "Pastor";
      case UserRole.bruder:
        return "Bruder";
      case UserRole.suster:
        return "Suster";
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
    String? avatarUrl,
    String? bannerUrl,
    UserRole? userRole,
    AccountStatus? accountStatus,
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
    bool? showAge,
    bool? showEthnicity,
  }) {
    return Profile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      userRole: userRole ?? this.userRole,
      accountStatus: accountStatus ?? this.accountStatus,
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
      showAge: showAge ?? this.showAge,
      showEthnicity: showEthnicity ?? this.showEthnicity,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
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
      // Handle mapping old 'approved' to new 'verified_catholic' if needed
      if (val.toLowerCase() == 'approved') {
        return AccountStatus.verified_catholic;
      }

      try {
        return AccountStatus.values.firstWhere(
          (e) => e.name.toLowerCase() == val.toLowerCase(),
          orElse: () => AccountStatus.unverified,
        );
      } catch (_) {
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
      avatarUrl: json['avatar_url']?.toString(),
      bannerUrl: json['banner_url']?.toString(),

      // Parse Enums (Check new column names first, fall back to old)
      userRole: parseRole(
        json['user_role']?.toString() ?? json['role']?.toString(),
      ),
      accountStatus: parseStatus(
        json['account_status']?.toString() ??
            json['verification_status']?.toString(),
      ),
      counselorStatus: parseCounselorStatus(
        json['counselor_status']?.toString(),
      ),
      ministryCount: (json['ministry_count'] as num?)?.toInt() ?? 0,

      bio: json['bio']?.toString(),
      country: json['country']?.toString(),
      diocese: json['diocese']?.toString(),
      parish: json['parish']?.toString(),
      countryId: json['country_id']?.toString(),
      dioceseId: json['diocese_id']?.toString(),
      churchId: json['church_id']?.toString(),
      
      ethnicity: json['ethnicity']?.toString(),
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'].toString())
          : null,
      showAge: json['is_age_visible'] == true,
      showEthnicity: json['is_ethnicity_visible'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'banner_url': bannerUrl,
      'user_role': userRole.name,
      'role': userRole.name, // Keep for legacy
      'account_status': accountStatus.name,
      'verification_status': accountStatus.name, // Keep for legacy
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
      'is_age_visible': showAge,
      'is_ethnicity_visible': showEthnicity,
    };
  }
}
