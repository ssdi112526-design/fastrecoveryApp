import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../Model_class/Proffile_model.dart';
import '../Service/SharedPreferenceService.dart';
import '../theme/app_theme.dart';

const List<String> _indianStates = [
  'Andhra Pradesh',
  'Arunachal Pradesh',
  'Assam',
  'Bihar',
  'Chhattisgarh',
  'Goa',
  'Gujarat',
  'Haryana',
  'Himachal Pradesh',
  'Jharkhand',
  'Karnataka',
  'Kerala',
  'Madhya Pradesh',
  'Maharashtra',
  'Manipur',
  'Meghalaya',
  'Mizoram',
  'Nagaland',
  'Odisha',
  'Punjab',
  'Rajasthan',
  'Sikkim',
  'Tamil Nadu',
  'Telangana',
  'Tripura',
  'Uttar Pradesh',
  'Uttarakhand',
  'West Bengal',
  'Andaman and Nicobar Islands',
  'Chandigarh',
  'Dadra and Nagar Haveli and Daman and Diu',
  'Delhi',
  'Jammu and Kashmir',
  'Ladakh',
  'Lakshadweep',
  'Puducherry',
];

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _profileUrl =
      'https://www.fastrecovery.in/api/auth/profile';

  static const String _photoUploadUrl =
      'https://www.fastrecovery.in/api/auth/profile/photo';

  static const String _baseUrl = 'https://www.fastrecovery.in';

  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  bool _isSaving = false;

  String? _error;

  // Typed model instead of raw Map<String, dynamic>.
  UserModel? _user;

  File? _pickedImage;

  final ImagePicker _imagePicker = ImagePicker();

  // ------------------------------------------------------------
  // Editable fields
  // ------------------------------------------------------------

  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _postController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();

  String? _selectedState;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _pincodeController.dispose();
    _postController.dispose();
    _dobController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  // ============================================================
  // API — GET profile
  // ============================================================

  Future<void> _fetchProfile() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = SharedPreferenceService.getToken();

      if (token == null || token.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'You are not logged in. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse(_profileUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      dynamic decodedBody;
      try {
        decodedBody = jsonDecode(response.body);
      } catch (_) {
        decodedBody = null;
      }

      final decodedMap =
      decodedBody is Map<String, dynamic> ? decodedBody : <String, dynamic>{};

      final profileResponse = ProfileResponse.fromJson(decodedMap);

      if (response.statusCode == 200 && profileResponse.success) {
        if (!mounted) return;

        final user = profileResponse.user;

        setState(() {
          _user = user;
          _isLoading = false;

          _addressController.text = user?.address ?? '';
          _pincodeController.text = user?.pincode ?? '';
          _postController.text = user?.post ?? '';
          _dobController.text = user?.dateOfBirth ?? '';
          _districtController.text = user?.district ?? '';

          final stateValue = (user?.state ?? '').trim();
          _selectedState = _indianStates.contains(stateValue) ? stateValue : null;

          // Once we've fetched from the server, drop any locally
          // picked image so the network photo (source of truth) shows.
          _pickedImage = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = profileResponse.message.isNotEmpty
              ? profileResponse.message
              : 'Failed to load profile (status ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Network error. Please try again.';
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // API — PUT profile (text fields only, no photo)
  // ============================================================

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final token = SharedPreferenceService.getToken();

      if (token == null || token.trim().isEmpty) {
        _showMessage('You are not logged in. Please log in again.');
        if (mounted) setState(() => _isSaving = false);
        return;
      }

      final body = {
        'address': _addressController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'post': _postController.text.trim(),
        'dateOfBirth': _dobController.text.trim(),
        'district': _districtController.text.trim(),
        'state': _selectedState ?? '',
      };

      final response = await http.patch(
        Uri.parse(_profileUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      // TEMP DEBUG — remove once the issue is confirmed fixed.
      // ignore: avoid_print
      print(
        'SAVE PROFILE url=$_profileUrl status=${response.statusCode} body=${response.body}',
      );

      dynamic decodedBody;
      try {
        decodedBody = jsonDecode(response.body);
      } catch (_) {
        decodedBody = null;
      }

      final decodedMap =
      decodedBody is Map<String, dynamic> ? decodedBody : <String, dynamic>{};

      final profileResponse = ProfileResponse.fromJson(decodedMap);

      if (response.statusCode == 200 && profileResponse.success) {
        if (!mounted) return;

        setState(() {
          // Prefer whatever the server sends back; fall back to an
          // optimistic local update built from what we just sent,
          // so we don't need a second GET round-trip.
          _user = profileResponse.user ??
              _user?.copyWith(
                address: body['address'],
                pincode: body['pincode'],
                post: body['post'],
                dateOfBirth: body['dateOfBirth'],
                district: body['district'],
                state: body['state'],
              );
        });

        _showMessage(
          profileResponse.message.isNotEmpty
              ? profileResponse.message
              : 'Profile updated successfully',
        );
      } else {
        // Show the raw status/body while we're still confirming the
        // right endpoint/method with the backend team.
        final snippet = response.body.length > 120
            ? response.body.substring(0, 120)
            : response.body;

        _showMessage(
          profileResponse.message.isNotEmpty
              ? profileResponse.message
              : 'Failed to update profile (status ${response.statusCode}) $snippet',
        );
      }
    } catch (_) {
      _showMessage('Network error. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ============================================================
  // Date picker
  // ============================================================

  Future<void> _pickDob() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(1950),
      lastDate: now,
    );

    if (picked != null && mounted) {
      final formatted = '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';

      setState(() {
        _dobController.text = formatted;
      });
    }
  }

  // ============================================================
  // Image picker
  // ============================================================

  Future<void> _showImageSourceSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.slate200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_outlined,
                  color: AppColors.blue600,
                ),
                title: Text(
                  'Take a photo',
                  style: AppTextStyles.body(size: 14, color: AppColors.ink),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.blue600,
                ),
                title: Text(
                  'Choose from gallery',
                  style: AppTextStyles.body(size: 14, color: AppColors.ink),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1000,
      );

      if (picked == null || !mounted) return;

      final file = File(picked.path);

      setState(() {
        _pickedImage = file;
      });

      await _uploadProfilePhoto(file);
    } catch (_) {
      _showMessage('Could not pick image. Please try again.');
    }
  }

  // ============================================================
  // API — Photo upload (multipart)
  //
  // Dedicated endpoint: POST /api/auth/profile/photo
  // File field name: "photo". Response shape same as profile GET
  // (success/message/data.user), with the new photoUrl included.
  // ============================================================
  Future<void> _uploadProfilePhoto(File file) async {
    if (_isUploadingPhoto) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final token = SharedPreferenceService.getToken();

      if (token == null || token.trim().isEmpty) {
        _showMessage('You are not logged in. Please log in again.');
        return;
      }

      final request = http.MultipartRequest('POST', Uri.parse(_photoUploadUrl));

      request.headers['Authorization'] = 'Bearer $token';

      // Explicitly set filename + contentType. image_picker files
      // (especially from camera) sometimes have no/odd extension,
      // which can make the backend fail to detect the file type.
      final extension = file.path.split('.').last.toLowerCase();
      final mimeSubtype = (extension == 'png') ? 'png' : 'jpeg';
      final safeFilename = 'photo.${mimeSubtype == 'png' ? 'png' : 'jpg'}';

      request.files.add(
        await http.MultipartFile.fromPath(
          'photo',
          file.path,
          filename: safeFilename,
          contentType: MediaType('image', mimeSubtype),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // TEMP DEBUG — remove once the issue is confirmed fixed.
      // ignore: avoid_print
      print(
        'PHOTO UPLOAD url=$_photoUploadUrl status=${response.statusCode} body=${response.body}',
      );

      dynamic decodedBody;
      try {
        decodedBody = jsonDecode(response.body);
      } catch (_) {
        decodedBody = null;
      }

      final decodedMap =
      decodedBody is Map<String, dynamic> ? decodedBody : <String, dynamic>{};

      final profileResponse = ProfileResponse.fromJson(decodedMap);

      if (response.statusCode == 200 && profileResponse.success) {
        if (!mounted) return;

        setState(() {
          // Use whatever the server returns; if it didn't send a
          // fresh user object, keep the current one — the network
          // image will simply lag until the next GET, which is fine
          // since the picked file still shows locally in the meantime.
          _user = profileResponse.user ?? _user;
          _pickedImage = null; // network photo is now the source of truth
        });

        _showMessage(
          profileResponse.message.isNotEmpty
              ? profileResponse.message
              : 'Photo updated successfully',
        );
      } else {
        final snippet = response.body.length > 120
            ? response.body.substring(0, 120)
            : response.body;

        _showMessage(
          profileResponse.message.isNotEmpty
              ? profileResponse.message
              : 'Failed to upload photo (status ${response.statusCode}) $snippet',
        );
      }
    } catch (e) {
      _showMessage('Network error while uploading photo. Please try again.');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // ============================================================
  // Helpers
  // ============================================================

  String _val(String? value) {
    if (value == null) return '-';
    final result = value.trim();
    return result.isEmpty ? '-' : result;
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';

    final parts = name.trim().split(RegExp(r'\s+'));

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return (parts.first.substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: AppTextStyles.body(size: 13, color: AppColors.white),
          ),
          backgroundColor: AppColors.navy950,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(color: AppColors.blue600),
              )
                  : _error != null
                  ? _buildError()
                  : RefreshIndicator(
                color: AppColors.blue600,
                backgroundColor: AppColors.white,
                onRefresh: _fetchProfile,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 22),
                      _sectionTitle('Personal Information'),
                      const SizedBox(height: 10),
                      _buildInfoCard([
                        ['Full Name', _val(_user?.name)],
                        ['Email', _val(_user?.email)],
                        ['Phone', _val(_user?.phone)],
                        [
                          'Second Agency Number',
                          _val(_user?.secondAgencyNumber),
                        ],
                        ["Father's Name", _val(_user?.fatherName)],
                        ['Blood Group', _val(_user?.bloodGroup)],
                        ['Role', _val(_user?.role)],
                        ['Agency Name', _val(_user?.agencyName)],
                        ['City', _val(_user?.city)],
                      ]),
                      const SizedBox(height: 22),
                      _sectionTitle('Update Details'),
                      const SizedBox(height: 10),
                      _buildEditableFields(),
                      const SizedBox(height: 18),
                      _buildSaveButton(),
                      if (_user?.company != null) ...[
                        const SizedBox(height: 26),
                        _sectionTitle('Company Information'),
                        const SizedBox(height: 10),
                        _buildInfoCard([
                          [
                            'Company Name',
                            _val(_user?.company?.companyName),
                          ],
                          [
                            'Company Code',
                            _val(_user?.company?.companyCode),
                          ],
                          ['Status', _val(_user?.company?.status)],
                          [
                            'Registration Source',
                            _val(_user?.company?.registrationSource),
                          ],
                          [
                            'Contact Person',
                            _val(_user?.company?.contactPersonName),
                          ],
                          ['Email', _val(_user?.company?.email)],
                          ['Phone', _val(_user?.company?.phone)],
                          [
                            'First Agency Number',
                            _val(_user?.company?.firstAgencyNumber),
                          ],
                          ['Address', _val(_user?.company?.address)],
                          [
                            'PAN Number',
                            _val(_user?.company?.panNumber),
                          ],
                          [
                            'GST Number',
                            _val(_user?.company?.gstNumber),
                          ],
                          [
                            'Aadhaar Number',
                            _val(_user?.company?.aadhaarNumber),
                          ],
                        ]),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.slate200),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navy900.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: AppColors.navy950,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Profile',
            style: AppTextStyles.display(
              size: 17,
              weight: FontWeight.w700,
              color: AppColors.navy950,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: AppColors.slate400,
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(size: 14, color: AppColors.slate600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy950,
                foregroundColor: AppColors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Retry',
                style: AppTextStyles.body(
                  size: 13.5,
                  weight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER CARD
  // ============================================================

  Widget _buildHeaderCard() {
    final userPhotoUrl = _user?.photoUrl;
    final companyPhotoUrl = _user?.company?.photoUrl;

    final resolvedPhotoUrl = (userPhotoUrl != null && userPhotoUrl.trim().isNotEmpty)
        ? userPhotoUrl
        : companyPhotoUrl;

    final hasNetworkPhoto = resolvedPhotoUrl != null && resolvedPhotoUrl.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.white.withOpacity(0.18),
                backgroundImage: _pickedImage != null
                    ? FileImage(_pickedImage!)
                    : hasNetworkPhoto
                    ? NetworkImage(
                  resolvedPhotoUrl!.startsWith('http')
                      ? resolvedPhotoUrl
                      : '$_baseUrl$resolvedPhotoUrl',
                )
                    : null,
                child: (_pickedImage == null && !hasNetworkPhoto)
                    ? Text(
                  _initials(_user?.name),
                  style: AppTextStyles.display(
                    size: 20,
                    weight: FontWeight.w800,
                    color: AppColors.white,
                  ),
                )
                    : null,
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: GestureDetector(
                  onTap: _isUploadingPhoto ? null : _showImageSourceSheet,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppColors.gold400,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                    child: _isUploadingPhoto
                        ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                        : const Icon(
                      Icons.camera_alt_rounded,
                      size: 12,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _val(_user?.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.display(
                    size: 18,
                    weight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _val(_user?.role),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.mono(
                    size: 11.5,
                    weight: FontWeight.w600,
                    color: AppColors.white.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _val(_user?.company?.companyCode),
                    style: AppTextStyles.mono(
                      size: 10.5,
                      weight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION TITLE / LABEL
  // ============================================================

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.display(
        size: 15,
        weight: FontWeight.w700,
        color: AppColors.navy950,
      ),
    );
  }

  Widget _inputLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: AppTextStyles.body(
        size: 10.5,
        weight: FontWeight.w700,
        color: AppColors.slate600,
      ).copyWith(letterSpacing: 0.7),
    );
  }

  // ============================================================
  // EDITABLE FIELDS
  // ============================================================

  Widget _buildEditableFields() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy900.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _inputLabel('Address'),
          const SizedBox(height: 6),
          _textField(_addressController, 'Enter your address', Icons.location_on_outlined),
          const SizedBox(height: 16),
          _inputLabel('Pincode'),
          const SizedBox(height: 6),
          _textField(
            _pincodeController,
            'e.g. 110095',
            Icons.pin_drop_outlined,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _inputLabel('Post / Designation'),
          const SizedBox(height: 6),
          _textField(_postController, 'e.g. Proprietor', Icons.badge_outlined),
          const SizedBox(height: 16),
          _inputLabel('Date of Birth'),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickDob,
            child: AbsorbPointer(
              child: _textField(_dobController, 'YYYY-MM-DD', Icons.cake_outlined),
            ),
          ),
          const SizedBox(height: 16),
          _inputLabel('District'),
          const SizedBox(height: 6),
          _textField(_districtController, 'e.g. Delhi', Icons.map_outlined),
          const SizedBox(height: 16),
          _inputLabel('State'),
          const SizedBox(height: 6),
          _buildStateDropdown(),
        ],
      ),
    );
  }

  // ============================================================
  // STATE DROPDOWN
  // ============================================================

  Widget _buildStateDropdown() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.slate200, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedState,
          isExpanded: true,
          dropdownColor: AppColors.white,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.slate600,
          ),
          hint: Text(
            'Select state',
            style: AppTextStyles.body(size: 13.5, color: AppColors.slate400),
          ),
          items: _indianStates.map((state) {
            return DropdownMenuItem<String>(
              value: state,
              child: Text(
                state,
                style: AppTextStyles.body(size: 13.5, color: AppColors.ink),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedState = value;
            });
          },
        ),
      ),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _textField(
      TextEditingController controller,
      String hint,
      IconData icon, {
        TextInputType? keyboardType,
      }) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border.all(color: AppColors.slate200, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.slate400),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              cursorColor: AppColors.blue600,
              style: AppTextStyles.body(size: 13.5, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTextStyles.body(size: 13.5, color: AppColors.slate400),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SAVE BUTTON
  // ============================================================

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy950,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.navy800,
          disabledForegroundColor: AppColors.slate400,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
        )
            : Text(
          'Save Profile',
          style: AppTextStyles.body(
            size: 14,
            weight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INFO CARD
  // ============================================================

  Widget _buildInfoCard(List<List<String>> rows) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy900.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: List.generate(rows.length, (index) {
          final row = rows[index];
          final isLast = index == rows.length - 1;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                bottom: BorderSide(
                  color: AppColors.slate200.withOpacity(0.7),
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    row[0],
                    style: AppTextStyles.body(
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: AppColors.slate600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    row[1],
                    style: AppTextStyles.body(
                      size: 13,
                      weight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}