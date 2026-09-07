class CompanyModel {
  final String companyName;
  final String companyCode;
  final String status;
  final String registrationSource;
  final String contactPersonName;
  final String email;
  final String phone;
  final String firstAgencyNumber;
  final String address;
  final String panNumber;
  final String gstNumber;
  final String aadhaarNumber;
  final String photoUrl;

  const CompanyModel({
    this.companyName = '',
    this.companyCode = '',
    this.status = '',
    this.registrationSource = '',
    this.contactPersonName = '',
    this.email = '',
    this.phone = '',
    this.firstAgencyNumber = '',
    this.address = '',
    this.panNumber = '',
    this.gstNumber = '',
    this.aadhaarNumber = '',
    this.photoUrl = '',
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      companyName: (json['companyName'] ?? '').toString(),
      companyCode: (json['companyCode'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      registrationSource: (json['registrationSource'] ?? '').toString(),
      contactPersonName: (json['contactPersonName'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      firstAgencyNumber: (json['firstAgencyNumber'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      panNumber: (json['panNumber'] ?? '').toString(),
      gstNumber: (json['gstNumber'] ?? '').toString(),
      aadhaarNumber: (json['aadhaarNumber'] ?? '').toString(),
      photoUrl: (json['photoUrl'] ?? '').toString(),
    );
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String fatherName;
  final String bloodGroup;
  final String phone;
  final String secondAgencyNumber;
  final String dateOfBirth;
  final String role;
  final String companyId;
  final String district;
  final String pincode;
  final String post;
  final String agencyName;
  final String address;
  final String city;
  final String state;
  final String photoUrl;
  final CompanyModel? company;

  const UserModel({
    this.id = '',
    this.name = '',
    this.email = '',
    this.fatherName = '',
    this.bloodGroup = '',
    this.phone = '',
    this.secondAgencyNumber = '',
    this.dateOfBirth = '',
    this.role = '',
    this.companyId = '',
    this.district = '',
    this.pincode = '',
    this.post = '',
    this.agencyName = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.photoUrl = '',
    this.company,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final companyJson = json['company'];

    return UserModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      fatherName: (json['fatherName'] ?? '').toString(),
      bloodGroup: (json['bloodGroup'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      secondAgencyNumber: (json['secondAgencyNumber'] ?? '').toString(),
      dateOfBirth: (json['dateOfBirth'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      companyId: (json['companyId'] ?? '').toString(),
      district: (json['district'] ?? '').toString(),
      pincode: (json['pincode'] ?? '').toString(),
      post: (json['post'] ?? '').toString(),
      agencyName: (json['agencyName'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      photoUrl: (json['photoUrl'] ?? '').toString(),
      company: companyJson is Map<String, dynamic>
          ? CompanyModel.fromJson(companyJson)
          : null,
    );
  }

  /// Returns a copy of this user with the given fields replaced.
  /// Useful for optimistic UI updates (e.g. after a photo upload)
  /// without needing to refetch the whole profile.
  UserModel copyWith({
    String? photoUrl,
    String? address,
    String? pincode,
    String? post,
    String? dateOfBirth,
    String? district,
    String? state,
  }) {
    return UserModel(
      id: id,
      name: name,
      email: email,
      fatherName: fatherName,
      bloodGroup: bloodGroup,
      phone: phone,
      secondAgencyNumber: secondAgencyNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      role: role,
      companyId: companyId,
      district: district ?? this.district,
      pincode: pincode ?? this.pincode,
      post: post ?? this.post,
      agencyName: agencyName,
      address: address ?? this.address,
      city: city,
      state: state ?? this.state,
      photoUrl: photoUrl ?? this.photoUrl,
      company: company,
    );
  }
}

class ProfileResponse {
  final bool success;
  final String message;
  final UserModel? user;

  const ProfileResponse({
    required this.success,
    required this.message,
    this.user,
  });

  factory ProfileResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final userJson = data is Map<String, dynamic> ? data['user'] : null;

    return ProfileResponse(
      success: json['success'] == true,
      message: (json['message'] ?? '').toString(),
      user: userJson is Map<String, dynamic>
          ? UserModel.fromJson(userJson)
          : null,
    );
  }
}