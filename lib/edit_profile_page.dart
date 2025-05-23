import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

// ---!!! ✨ ضعي Client ID الخاص بكِ من Imgur هنا إذا لم يكن معرفًا بشكل عام ✨ !!!---
const String imgurClientId = '25493267ebab14e'; // استبدل هذا بالـ ID الحقيقي

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> initialProfileData;
  final List<dynamic> currentPositions; // يتم استقبالها ولكن لا يتم استخدامها حاليًا للتعديل
  const EditProfilePage({
    super.key,
    required this.initialProfileData,
    required this.currentPositions,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();
  final String _profileApiUrl = "http://localhost:3000/api/provider"; // أو 10.0.2.2

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _bioController;
  late TextEditingController _hourlyRateController;
  late TextEditingController _skillsController;
  late TextEditingController _facebookUrlController;
  late TextEditingController _zipCodeController;
  late TextEditingController _cityNameController;

  bool _isSaving = false;
  File? _pickedImageFile;
  String? _currentImageUrl; // لتخزين رابط الصورة الحالي من الـ API إذا لم يتم اختيار جديد

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.initialProfileData['first_name'] ?? '');
    _lastNameController = TextEditingController(text: widget.initialProfileData['last_name'] ?? '');
    _emailController = TextEditingController(text: widget.initialProfileData['email'] ?? '');
    _bioController = TextEditingController(text: widget.initialProfileData['bio'] ?? '');
    _hourlyRateController = TextEditingController(text: widget.initialProfileData['hourly_rate']?.toString() ?? '');
    _skillsController = TextEditingController(text: widget.initialProfileData['skills'] ?? '');
    _currentImageUrl = widget.initialProfileData['image_url'] as String?;
    _facebookUrlController = TextEditingController(text: widget.initialProfileData['facebook_url'] ?? '');
    _zipCodeController = TextEditingController(text: widget.initialProfileData['zip_code']?.toString() ?? '');
    _cityNameController = TextEditingController(text: widget.initialProfileData['city_name'] ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose(); _lastNameController.dispose(); _emailController.dispose();
    _bioController.dispose(); _hourlyRateController.dispose(); _skillsController.dispose();
    _facebookUrlController.dispose(); _zipCodeController.dispose(); _cityNameController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: isError ? Colors.redAccent.shade700 : Colors.green.shade700,
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 70, maxWidth: 800);
      if (pickedFile != null) {
        setState(() {
          _pickedImageFile = File(pickedFile.path);
          // لا نمسح _currentImageUrl هنا، سنستخدمه إذا فشل رفع الصورة الجديدة أو لم يتم اختيارها
        });
      }
    } catch (e) {
      _showMessage("Error picking image: $e", isError: true);
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(context: context, builder: (BuildContext bc) {
        return SafeArea(child: Wrap(children: <Widget>[
              ListTile(leading: const Icon(Icons.photo_library), title: const Text('Photo Library'), onTap: () { _pickImage(ImageSource.gallery); Navigator.of(context).pop(); }),
              ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Camera'), onTap: () { _pickImage(ImageSource.camera); Navigator.of(context).pop(); }),
            ],),);},);
  }

  Future<String?> _uploadImageToImgur(File imageFile) async {
    if (imgurClientId == 'YOUR_IMGUR_CLIENT_ID' || imgurClientId.isEmpty) {
       _showMessage('INTERNAL ERROR: Imgur Client ID is not set.', isError: true); return null;
    }
    print("Attempting to upload image to Imgur for profile update...");
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final response = await http.post(
        Uri.parse('https://api.imgur.com/3/image'),
        headers: {'Authorization': 'Client-ID $imgurClientId'},
        body: {'image': base64Image, 'type': 'base64'},
      ).timeout(const Duration(seconds: 60));

      if (!mounted) return null;
      print('Imgur Upload Response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data']?['link'] != null) {
          return data['data']['link'];
        } else { _showMessage('Imgur upload failed: Unexpected response.', isError: true); return null; }
      } else { _showMessage('Imgur upload failed (Status: ${response.statusCode}).', isError: true); return null; }
    } catch (error) {
       print("Error uploading image to Imgur: $error");
       if (error is SocketException) { _showMessage('Network error during image upload.', isError: true); }
       else if (error is TimeoutException) { _showMessage('Image upload timed out.', isError: true); }
       else { _showMessage('Unexpected error during image upload.', isError: true); }
       return null;
    }
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted || _isSaving) return;
    setState(() => _isSaving = true);

    String? token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      _showMessage("Authentication error. Please log in again.", isError: true);
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    String? imageUrlForApi = _currentImageUrl; // استخدم الرابط الحالي افتراضيًا

    if (_pickedImageFile != null) {
      _showMessage("Uploading new profile picture...", isError: false);
      String? uploadedUrl = await _uploadImageToImgur(_pickedImageFile!);
      if (uploadedUrl != null) {
        imageUrlForApi = uploadedUrl; // استخدم الرابط الجديد إذا نجح الرفع
      } else {
        // إذا فشل رفع الصورة الجديدة، استمر في استخدام الرابط القديم (إذا كان موجودًا) أو لا ترسل image_url
        // يمكنك أيضًا إيقاف العملية هنا إذا كان رفع الصورة إجباريًا عند تغييرها
        _showMessage("Failed to upload new image. Using previous image if available.", isError: true);
        // إذا كنت تريد إيقاف العملية إذا فشل رفع الصورة:
        // if (mounted) setState(() => _isSaving = false);
        // return;
      }
    }

    Map<String, dynamic> requestBodyMap = {
      "first_name": _firstNameController.text.trim(),
      "last_name": _lastNameController.text.trim(),
      "email": _emailController.text.trim(), // إرسال الإيميل
      "bio": _bioController.text.trim(),
      "hourly_rate": double.tryParse(_hourlyRateController.text.trim()),
      "skills": _skillsController.text.trim(),
      "image_url": imageUrlForApi, // هذا هو رابط الصورة (سواء من Imgur أو الرابط القديم)
      "facebook_url": _facebookUrlController.text.trim(),
      "zip_code": int.tryParse(_zipCodeController.text.trim()),
      "city_name": _cityNameController.text.trim(),
    };
    // إزالة القيم null من الـ map إذا كان الـ API لا يتوقعها
    requestBodyMap.removeWhere((key, value) => value == null);


    print("--- Sending Updated Profile Data (JSON) to $_profileApiUrl ---");
    print("--- Request Body: ${json.encode(requestBodyMap)} ---");

    try {
      final response = await http.put(
        Uri.parse(_profileApiUrl),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode(requestBodyMap),
      ).timeout(const Duration(seconds: 25));

      if (!mounted) return;
      print("Update Profile Response Status: ${response.statusCode}");
      print("Update Profile Response Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 204) {
        _showMessage("Profile updated successfully!", isError: false);
        Navigator.pop(context, true);
      } else {
        String serverMessage = "Failed to update profile (${response.statusCode}).";
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map) {
            if (errorData['message'] != null) { serverMessage += " ${errorData['message']}"; }
            else if (errorData['error'] != null) { serverMessage += " ${errorData['error']}"; }
            else if (errorData['errors'] is List && (errorData['errors'] as List).isNotEmpty) {
              var firstError = (errorData['errors'] as List)[0];
              if (firstError is Map && firstError.containsKey('msg')) { serverMessage += " ${firstError['msg']}"; }
              else { serverMessage += " Details: ${jsonEncode(errorData['errors'])}"; }
            } else if (response.body.isNotEmpty) { serverMessage += " Server response (first 150 chars): ${response.body.substring(0, response.body.length > 150 ? 150 : response.body.length)}${response.body.length > 150 ? "..." : ""}"; }
          } else if (response.body.isNotEmpty) { serverMessage += " Server response (first 150 chars): ${response.body.substring(0, response.body.length > 150 ? 150 : response.body.length)}${response.body.length > 150 ? "..." : ""}"; }
        } catch(_){ if (response.body.isNotEmpty) { serverMessage += " Server response (first 150 chars): ${response.body.substring(0, response.body.length > 150 ? 150 : response.body.length)}${response.body.length > 150 ? "..." : ""}"; } }
        _showMessage(serverMessage, isError: true);
      }
    } catch (e,s) {
      print("Update Profile Exception: $e\n$s");
      if (e is SocketException) _showMessage("Network error. Check connection.", isError: true);
      else if (e is TimeoutException) _showMessage("Request timed out.", isError: true);
      else _showMessage("An error occurred while updating profile.", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildTextFormField({required TextEditingController controller, required String label, TextInputType keyboardType = TextInputType.text, int maxLines = 1, String? Function(String?)? validator, Widget? prefixIcon, bool isOptional = false, bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        decoration: InputDecoration(labelText: label, prefixIcon: prefixIcon, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
        keyboardType: keyboardType, maxLines: maxLines,
        validator: validator ?? (value) {
          if (!isOptional && (value == null || value.trim().isEmpty)) return '$label is required';
          if (label == 'Email' && value != null && value.trim().isNotEmpty && !RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value.trim())) return 'Please enter a valid email.';
          if ((label == 'Hourly Rate (\$)' || label == 'Zip Code') && value != null && value.trim().isNotEmpty) {
            if (label == 'Hourly Rate (\$)' && double.tryParse(value.trim()) == null) return 'Invalid number for rate (e.g. 25.50)';
            if (label == 'Zip Code' && int.tryParse(value.trim()) == null) return 'Invalid number for zip code.';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Stack(children: [ CircleAvatar(radius: 60, backgroundColor: Colors.grey.shade300, backgroundImage: _pickedImageFile != null ? FileImage(_pickedImageFile!) : (_currentImageUrl != null && _currentImageUrl!.isNotEmpty ? NetworkImage(_currentImageUrl!) : null) as ImageProvider?, child: (_pickedImageFile == null && (_currentImageUrl == null || _currentImageUrl!.isEmpty)) ? Icon(Icons.person, size: 60, color: Colors.grey.shade700) : null), Positioned(bottom: 0, right: 0, child: Material(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(20), child: InkWell(borderRadius: BorderRadius.circular(20), onTap: _showImagePickerOptions, child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.camera_alt, color: Colors.white, size: 20)))))])),
                const SizedBox(height: 24),
                _buildTextFormField(controller: _firstNameController, label: 'First Name', prefixIcon: const Icon(Icons.person_outline)),
                _buildTextFormField(controller: _lastNameController, label: 'Last Name', prefixIcon: const Icon(Icons.person_outline)),
                _buildTextFormField(controller: _emailController, label: 'Email', prefixIcon: const Icon(Icons.email_outlined), keyboardType: TextInputType.emailAddress),
                _buildTextFormField(controller: _bioController, label: 'Bio', maxLines: 3, prefixIcon: const Icon(Icons.edit_note_outlined), isOptional: true),
                _buildTextFormField(controller: _hourlyRateController, label: 'Hourly Rate (\$)', keyboardType: TextInputType.numberWithOptions(decimal: true), prefixIcon: const Icon(Icons.attach_money), isOptional: true),
                _buildTextFormField(controller: _skillsController, label: 'Skills (comma separated)', prefixIcon: const Icon(Icons.construction_outlined), isOptional: true),
                _buildTextFormField(controller: _facebookUrlController, label: 'Facebook Profile URL', keyboardType: TextInputType.url, prefixIcon: const Icon(Icons.facebook_outlined), isOptional: true),
                Row(children: [
                    Expanded(child: _buildTextFormField(controller: _zipCodeController, label: 'Zip Code', keyboardType: TextInputType.number, prefixIcon: const Icon(Icons.pin_drop_outlined), isOptional: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextFormField(controller: _cityNameController, label: 'City Name', prefixIcon: const Icon(Icons.location_city_outlined), isOptional: true)),
                  ],),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: _isSaving ? const SizedBox(width:18, height:18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Icon(Icons.save_alt_outlined),
                  label: Text(_isSaving ? "Saving..." : "Save Changes"),
                  onPressed: _isSaving ? null : _submitProfile,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}