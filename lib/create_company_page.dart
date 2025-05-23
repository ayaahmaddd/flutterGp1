import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:animate_do/animate_do.dart';

// افترض أن imgurClientId معرف في مكان ما (مثل ملف constants أو مباشرة هنا)
const String imgurClientId = '25493267ebab14e'; // استبدل هذا بالـ ID الصحيح

class CreateCompanyPage extends StatefulWidget {
  const CreateCompanyPage({super.key});

  @override
  State<CreateCompanyPage> createState() => _CreateCompanyPageState();
}

class _CreateCompanyPageState extends State<CreateCompanyPage> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();
  final String _baseDomain = "http://localhost:3000"; // أو 10.0.2.2
  late final String _createCompanyApiUrl = "$_baseDomain/api/owner/companies";

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _imageDisplayController = TextEditingController(text: "Optional: Tap to add company logo");
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _zipCodeController = TextEditingController();

  File? _pickedImageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isCreating = false;
  String? _uploadedImageUrl;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _imageDisplayController.dispose();
    _cityController.dispose();
    _zipCodeController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: isError ? Colors.redAccent.shade700 : Colors.green.shade700,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 70, maxWidth: 800);
      if (pickedFile != null) {
        setState(() {
          _pickedImageFile = File(pickedFile.path);
          _imageDisplayController.text = pickedFile.path.split('/').last;
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
    _showMessage('Uploading company logo...', isError: false);
    try {
      final bytes = await imageFile.readAsBytes(); final base64Image = base64Encode(bytes);
      final response = await http.post(Uri.parse('https://api.imgur.com/3/image'), headers: {'Authorization': 'Client-ID $imgurClientId'}, body: {'image': base64Image, 'type': 'base64'}).timeout(const Duration(seconds: 60));
      if (!mounted) return null;
      print('Imgur Upload Response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) { final data = jsonDecode(response.body); if (data['success'] == true && data['data']?['link'] != null) { print('Image uploaded successfully: ${data['data']['link']}'); return data['data']['link']; } else { _showMessage('Imgur upload failed: Unexpected response.', isError: true); return null; }
      } else { _showMessage('Imgur upload error (Status: ${response.statusCode}).', isError: true); return null; }
    } catch (error) {
       print("Error uploading image to Imgur: $error");
       if (error is SocketException) { _showMessage('Network error during image upload.', isError: true); }
       else if (error is TimeoutException) { _showMessage('Image upload timed out.', isError: true); }
       else { _showMessage('Unexpected error during image upload.', isError: true); }
       return null;
    }
  }

  Future<void> _handleCreateCompany() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted || _isCreating) return;
    setState(() => _isCreating = true);

    String? token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      _showMessage("Authentication error. Please log in again.", isError: true);
      if (mounted) setState(() => _isCreating = false);
      return;
    }

    String? finalImageUrl; // سيخزن رابط الصورة النهائي سواء من Imgur أو المدخل يدويًا
    if (_pickedImageFile != null) {
      finalImageUrl = await _uploadImageToImgur(_pickedImageFile!);
      if (finalImageUrl == null) {
        if (mounted) setState(() => _isCreating = false);
        return;
      }
    } else {
      final manuallyEnteredUrl = _imageDisplayController.text.trim();
      if (manuallyEnteredUrl.isNotEmpty && manuallyEnteredUrl != 'Optional: Tap to add company logo') {
        if (Uri.tryParse(manuallyEnteredUrl)?.hasAbsolutePath == true) {
          finalImageUrl = manuallyEnteredUrl;
        } else {
          _showMessage("Invalid Image URL provided.", isError: true);
          if (mounted) setState(() => _isCreating = false);
          return;
        }
      }
    }

    Map<String, dynamic> companyData = {
      "name": _nameController.text.trim(),
      "description": _descriptionController.text.trim(),
      "image_url": finalImageUrl, // قد يكون null إذا لم يتم توفير صورة
      "city": _cityController.text.trim(),
      "zip_code": _zipCodeController.text.trim(),
    };
    companyData.removeWhere((key, value) => value == null || (value is String && value.isEmpty));

    print("--- Creating Company. Body: ${json.encode(companyData)} ---");

    try {
      final response = await http.post(
        Uri.parse(_createCompanyApiUrl),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode(companyData),
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;
      print("Create Company Response: ${response.statusCode} - ${response.body}");

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 201 && responseData['success'] == true) {
        _showMessage("Company created successfully! ID: ${responseData['companyId']}", isError: false);
        Navigator.pop(context, true);
      } else {
        String errorMsg = responseData['message'] ?? "Failed to create company (${response.statusCode})";
        if (responseData['errors'] is List && responseData['errors'].isNotEmpty){
            errorMsg = responseData['errors'][0]['msg'] ?? errorMsg;
        }
        _showMessage(errorMsg, isError: true);
      }
    } catch (e, s) {
      print("Create Company Exception: $e\n$s");
      _showMessage("An unexpected error occurred.", isError: true);
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Widget _buildTextFormField({required TextEditingController controller, required String label, required IconData icon, TextInputType keyboardType = TextInputType.text, int maxLines = 1, bool isOptional = false, bool readOnly = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: FadeInLeft(
        delay: const Duration(milliseconds: 200),
        child: TextFormField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: Theme.of(context).primaryColor.withOpacity(0.7)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Theme.of(context).cardColor.withOpacity(0.8), // لون خلفية الحقل
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          ),
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: (value) {
            if (!isOptional && (value == null || value.trim().isEmpty)) {
              return '$label is required';
            }
            if (label == "Zip Code" && value != null && value.trim().isNotEmpty && int.tryParse(value.trim()) == null) {
              return 'Please enter a valid zip code (numbers only).';
            }
            // التحقق من صحة الـ URL فقط إذا لم يتم اختيار ملف وكان النص ليس النص الافتراضي
            if (label == "Company Logo" && _pickedImageFile == null && value != null && value.trim().isNotEmpty && value.trim() != 'Optional: Tap to add company logo' && Uri.tryParse(value.trim())?.hasAbsolutePath != true) {
                return 'Please enter a valid URL or pick an image.';
            }
            return null;
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // الحصول على الألوان من الثيم
    final Color primaryThemeColor = Theme.of(context).primaryColor;
    final Color secondaryThemeColor = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Create New Company", style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            // استخدام تدرجات من اللون الأساسي والثانوي للثيم
            colors: [
              primaryThemeColor.withOpacity(0.85),
              primaryThemeColor.withOpacity(0.7),
              secondaryThemeColor.withOpacity(0.65),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: FadeInUp(
              duration: const Duration(milliseconds: 500),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ZoomIn(
                          delay: const Duration(milliseconds: 100),
                          child: Text("Enter Company Details", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: primaryThemeColor)),
                        ),
                        const SizedBox(height: 25),
                        _buildTextFormField(controller: _nameController, label: "Company Name", icon: Icons.business_outlined),
                        _buildTextFormField(controller: _descriptionController, label: "Description", icon: Icons.description_outlined, maxLines: 3, isOptional: true),
                        _buildTextFormField(controller: _cityController, label: "City", icon: Icons.location_city_outlined),
                        _buildTextFormField(controller: _zipCodeController, label: "Zip Code", icon: Icons.pin_drop_outlined, keyboardType: TextInputType.number),
                        const SizedBox(height: 15),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _buildTextFormField(
                                controller: _imageDisplayController,
                                label: "Company Logo URL or Pick",
                                icon: Icons.image_outlined,
                                keyboardType: TextInputType.url,
                                isOptional: true,
                                readOnly: _pickedImageFile != null,
                                onTap: _pickedImageFile != null ? null : _showImagePickerOptions,
                              ),
                            ),
                            if (_pickedImageFile == null)
                              IconButton(
                                icon: Icon(Icons.add_a_photo_outlined, color: primaryThemeColor, size: 30),
                                onPressed: _showImagePickerOptions,
                                tooltip: "Pick Image from Device",
                              ),
                            if (_pickedImageFile != null)
                               IconButton(
                                icon: Icon(Icons.clear_rounded, color: Colors.red.shade700, size: 28),
                                onPressed: () {
                                  setState(() {
                                    _pickedImageFile = null;
                                    _imageDisplayController.text = "Optional: Tap to add company logo";
                                  });
                                },
                                tooltip: "Remove Selected Image",
                              )
                          ],
                        ),
                        const SizedBox(height: 30),
                        ElasticIn(
                          delay: const Duration(milliseconds: 300),
                          child: ElevatedButton.icon(
                            icon: _isCreating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Icon(Icons.add_business_rounded),
                            label: Text(_isCreating ? "Creating..." : "Create Company", style: const TextStyle(fontSize: 16)),
                            onPressed: _isCreating ? null : _handleCreateCompany,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              backgroundColor: primaryThemeColor,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}