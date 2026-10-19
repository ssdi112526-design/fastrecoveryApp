class VehicleItem {
  final String id;
  final String searchRowId;
  final String uploadBatchId;
  final String companyId;
  final String bankName;
  final String branchName;
  final String customerName;
  final String mobileNumber;
  final String alternateMobileNumber;
  final String loanAccountNumber;
  final String referenceNumber;
  final String vehicleNumber;
  final String chassisNumber;
  final String engineNumber;
  final String vehicleBrand;
  final String vehicleModel;
  final String addressLine1;
  final String city;
  final String state;
  final String emiAmount;
  final String dueAmount;
  final String totalOutstandingAmount;
  final String bucket;
  final String contactPerson1Name;
  final String contactPerson1Phone;
  final String contactPerson2Name;
  final String contactPerson2Phone;
  final String contactPerson3Name;
  final String contactPerson3Phone;
  final String bankNotifyEmail1;
  final String bankNotifyEmail2;
  final String repoStatus;
  final String confirmationStatus;
  final String source;
  final String createdAt;
  final String updatedAt;

  VehicleItem({
    required this.id,
    required this.searchRowId,
    required this.uploadBatchId,
    required this.companyId,
    required this.bankName,
    required this.branchName,
    required this.customerName,
    required this.mobileNumber,
    required this.alternateMobileNumber,
    required this.loanAccountNumber,
    required this.referenceNumber,
    required this.vehicleNumber,
    required this.chassisNumber,
    required this.engineNumber,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.addressLine1,
    required this.city,
    required this.state,
    required this.emiAmount,
    required this.dueAmount,
    required this.totalOutstandingAmount,
    required this.bucket,
    required this.contactPerson1Name,
    required this.contactPerson1Phone,
    required this.contactPerson2Name,
    required this.contactPerson2Phone,
    required this.contactPerson3Name,
    required this.contactPerson3Phone,
    required this.bankNotifyEmail1,
    required this.bankNotifyEmail2,
    required this.repoStatus,
    required this.confirmationStatus,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  static String _s(dynamic value) {
    if (value == null) return '-';
    final text = value.toString();
    if (text.isEmpty || text == 'null') return '-';
    return text;
  }

  factory VehicleItem.fromJson(Map<String, dynamic> json) {
    return VehicleItem(
      id: _s(json['_id']),
      searchRowId: _s(json['searchRowId']),
      uploadBatchId: _s(json['uploadBatchId']),
      companyId: _s(json['companyId']),
      bankName: _s(json['bankName']),
      branchName: _s(json['branchName']),
      customerName: _s(json['customerName']),
      mobileNumber: _s(json['mobileNumber']),
      alternateMobileNumber: _s(json['alternateMobileNumber']),
      loanAccountNumber: _s(json['loanAccountNumber']),
      referenceNumber: _s(json['referenceNumber']),
      vehicleNumber: _s(json['vehicleNumber']),
      chassisNumber: _s(json['chassisNumber']),
      engineNumber: _s(json['engineNumber']),
      vehicleBrand: _s(json['vehicleBrand']),
      vehicleModel: _s(json['vehicleModel']),
      addressLine1: _s(json['addressLine1']),
      city: _s(json['city']),
      state: _s(json['state']),
      emiAmount: _s(json['emiAmount']),
      dueAmount: _s(json['dueAmount']),
      totalOutstandingAmount: _s(json['totalOutstandingAmount']),
      bucket: _s(json['bucket']),
      contactPerson1Name: _s(json['contactPerson1Name']),
      contactPerson1Phone: _s(json['contactPerson1Phone']),
      contactPerson2Name: _s(json['contactPerson2Name']),
      contactPerson2Phone: _s(json['contactPerson2Phone']),
      contactPerson3Name: _s(json['contactPerson3Name']),
      contactPerson3Phone: _s(json['contactPerson3Phone']),
      bankNotifyEmail1: _s(json['bankNotifyEmail1']),
      bankNotifyEmail2: _s(json['bankNotifyEmail2']),
      repoStatus: _s(json['repoStatus']),
      confirmationStatus: _s(json['confirmationStatus']),
      source: _s(json['source']),
      createdAt: _s(json['createdAt']),
      updatedAt: _s(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'searchRowId': searchRowId,
      'uploadBatchId': uploadBatchId,
      'companyId': companyId,
      'bankName': bankName,
      'branchName': branchName,
      'customerName': customerName,
      'mobileNumber': mobileNumber,
      'alternateMobileNumber': alternateMobileNumber,
      'loanAccountNumber': loanAccountNumber,
      'referenceNumber': referenceNumber,
      'vehicleNumber': vehicleNumber,
      'chassisNumber': chassisNumber,
      'engineNumber': engineNumber,
      'vehicleBrand': vehicleBrand,
      'vehicleModel': vehicleModel,
      'addressLine1': addressLine1,
      'city': city,
      'state': state,
      'emiAmount': emiAmount,
      'dueAmount': dueAmount,
      'totalOutstandingAmount': totalOutstandingAmount,
      'bucket': bucket,
      'contactPerson1Name': contactPerson1Name,
      'contactPerson1Phone': contactPerson1Phone,
      'contactPerson2Name': contactPerson2Name,
      'contactPerson2Phone': contactPerson2Phone,
      'contactPerson3Name': contactPerson3Name,
      'contactPerson3Phone': contactPerson3Phone,
      'bankNotifyEmail1': bankNotifyEmail1,
      'bankNotifyEmail2': bankNotifyEmail2,
      'repoStatus': repoStatus,
      'confirmationStatus': confirmationStatus,
      'source': source,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class VehicleSearchResponse {
  final bool success;
  final List<VehicleItem> items;
  final int page;
  final int limit;
  final int total;
  final bool hasNext;
  final bool hasPrevious;

  VehicleSearchResponse({
    required this.success,
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.hasNext,
    required this.hasPrevious,
  });

  factory VehicleSearchResponse.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>? ?? [])
        .map((e) => VehicleItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return VehicleSearchResponse(
      success: json['success'] == true,
      items: itemsList,
      page: json['page'] is int ? json['page'] as int : int.tryParse('${json['page']}') ?? 1,
      limit: json['limit'] is int ? json['limit'] as int : int.tryParse('${json['limit']}') ?? 100,
      total: json['total'] is int ? json['total'] as int : int.tryParse('${json['total']}') ?? 0,
      hasNext: json['hasNext'] == true,
      hasPrevious: json['hasPrevious'] == true,
    );
  }
}