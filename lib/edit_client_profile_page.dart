// edit_client_profile_page.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart'; // For picking images
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:animate_do/animate_do.dart'; // For animations
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // For icons like Facebook

// ---!!! ✨ نفس Client ID المستخدم في SignUpScreen ✨ !!!---
const String imgurClientIdForProfileEdit = '25493267ebab14e'; // تأكد أن هذا هو الـ ID الصحيح

// import 'login.dart'; // إذا كنت ستحتاج لإعادة التوجيه عند خطأ المصادقة

class EditClientProfilePage extends StatefulWidget {
  const EditClientProfilePage({super.key});

  @override
  State<EditClientProfilePage> createState() => _EditClientProfilePageState();
}

class _EditClientProfilePageState extends State<EditClientProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = Platform.isAndroid ? "http://10.0.2.2:3000" : "http://localhost:3000";
  late final String _profileApiUrl = "$_baseUrl/api/client/profile";

  bool _isLoadingData = true;
  bool _isSaving = false;
  String? _errorMessage;
  Map<String, dynamic>? _clientData;

  File? _selectedImageFile; // صورة جديدة تم اختيارها
  String? _currentImageUrl;  // رابط الصورة الحالي من الخادم

  final ImagePicker _picker = ImagePicker();

  // Controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController(); // عادة لا يتم تعديله
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _zipCodeController = TextEditingController();
  final TextEditingController _facebookUrlController = TextEditingController();
  // لا حاجة لـ _imageUrlController الآن، سنتعامل مع _selectedImageFile و _currentImageUrl

  // --- UI Colors (أخضر زيتوني وبيج) ---
  final Color _pageBackgroundColorTop = const Color(0xFFFAF3E0); 
  final Color _pageBackgroundColorBottom = const Color(0xFFA3B29F); 
  final Color _appBarColor = const Color(0xFF697C6B); 
  final Color _appBarTextColor = Colors.white;
  final Color _buttonColor = const Color(0xFF4A5D52); 
  final Color _iconColor = const Color(0xFF556B2F); 
  final Color _inputFillColor = Colors.white.withOpacity(0.92);
  final Color _primaryTextColor = const Color(0xFF3A3A3A);
  final Color _secondaryTextColor = Colors.grey.shade700;
  final Color _cardColor = Colors.white.withOpacity(0.95);


  @override
  void initState() {
    super.initState();
    _loadClientProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _zipCodeController.dispose();
    _facebookUrlController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.lato(color: Colors.white)),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : (isSuccess ? Colors.green.shade600 : _buttonColor),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating, elevation: 6.0, margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
  
  Future<void> _handleAuthError() async {
    _showMessage("Session expired or authentication failed. Please log in again.", isError: true);
    await _storage.deleteAll();
    // if(mounted) {
    //   Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
    // }
  }

  Future<void> _loadClientProfile() async {
    if (!mounted) return;
    setState(() => _isLoadingData = true);
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      if (mounted) setState(() { _isLoadingData = false; _errorMessage = "Authentication token missing."; });
      await _handleAuthError();
      return;
    }

    try {
      final response = await http.get(Uri.parse(_profileApiUrl), headers: {'Authorization': 'Bearer $token'});
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['client'] != null) {
          setState(() {
            _clientData = data['client'] as Map<String, dynamic>;
            _firstNameController.text = _clientData?['first_name'] ?? '';
            _lastNameController.text = _clientData?['last_name'] ?? '';
            _emailController.text = _clientData?['email'] ?? '';
            _phoneController.text = _clientData?['phone']?.toString() ?? '';
            _currentImageUrl = _clientData?['image_url']; // حفظ الرابط الحالي
            _cityController.text = _clientData?['city_name'] ?? _clientData?['city'] ?? '';
            _zipCodeController.text = _clientData?['zip_code']?.toString() ?? '';
            _facebookUrlController.text = _clientData?['facebook_url'] ?? '';
            _isLoadingData = false;
            _errorMessage = null;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to parse profile data.');
        }
      } else if (response.statusCode == 401) {
        await _handleAuthError();
      } else {
        throw Exception('Failed to load profile (${response.statusCode}) - ${response.body}');
      }
    } catch (e) {
      if (mounted) setState(() { _isLoadingData = false; _errorMessage = e.toString().replaceFirst("Exception: ", ""); });
    }
  }

  // --- دوال اختيار الصورة مشابهة لـ SignUpScreen ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 70, maxWidth: 800);
      if (pickedFile != null) {
        setState(() {
          _selectedImageFile = File(pickedFile.path);
          // _currentImageUrl = null; // Optional: clear current URL if new image is selected,
                                   // or let _updateClientProfile handle logic of which URL to send
        });
      }
    } catch (e) {
      _showMessage("Error picking image: ${e.toString()}", isError: true);
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
        context: context,
        backgroundColor: _pageBackgroundColorTop.withOpacity(0.98),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (BuildContext bc) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                    leading: Icon(Icons.photo_library_outlined, color: _iconColor),
                    title: Text('Photo Library', style: GoogleFonts.lato(color: _primaryTextColor)),
                    onTap: () { _pickImage(ImageSource.gallery); Navigator.of(context).pop(); }),
                ListTile(
                  leading: Icon(Icons.photo_camera_outlined, color: _iconColor),
                  title: Text('Camera', style: GoogleFonts.lato(color: _primaryTextColor)),
                  onTap: () { _pickImage(ImageSource.camera); Navigator.of(context).pop(); },
                ),
                // خيار إزالة الصورة (يجعل _currentImageUrl و _selectedImageFile كلاهما null)
                if (_selectedImageFile != null || (_currentImageUrl != null && _currentImageUrl!.isNotEmpty))
                   ListTile(
                     leading: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error),
                     title: Text('Remove Current Image', style: GoogleFonts.lato(color: Theme.of(context).colorScheme.error)),
                     onTap: () { 
                       setState(() {
                         _selectedImageFile = null; 
                         _currentImageUrl = null; // للإشارة بأن الصورة يجب أن تُحذف/تُفرّغ في الـ backend
                       });
                       Navigator.of(context).pop(); 
                     },
                   ),
              ],
            ),
          );
        });
  }
  
  // --- دالة رفع الصورة إلى Imgur (مشابهة لـ SignUpScreen) ---
  Future<String?> _uploadImageToImgur(File imageFile) async {
    if (imgurClientIdForProfileEdit == 'YOUR_IMGUR_CLIENT_ID' || imgurClientIdForProfileEdit.isEmpty) {
       _showMessage('INTERNAL ERROR: Imgur Client ID is not set for profile edit.', isError: true);
       return "ERROR_IMGUR_ID_NOT_SET";
    }
    // لا نغير _isSaving هنا مباشرة، بل من _updateClientProfile

    print("--- EditClientProfile: Attempting to upload image to Imgur... ---");
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final response = await http.post(
        Uri.parse('https://api.imgur.com/3/image'),
        headers: {'Authorization': 'Client-ID $imgurClientIdForProfileEdit'},
        body: {'image': base64Image, 'type': 'base64'},
      ).timeout(const Duration(seconds: 60));

      if (!mounted) return null;
      print('Imgur Upload Response (Profile Edit): ${response.statusCode}');
      // print('Imgur Upload Response Body: ${response.body}'); // For debugging if needed

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data']?['link'] != null) {
          return data['data']['link'];
        } else {
          _showMessage('Image upload to Imgur failed: Invalid response format.', isError: true); return null;
        }
      } else { 
        String imgurError = 'Image upload to Imgur failed (Status: ${response.statusCode}).';
        try { final errorData = jsonDecode(response.body); if (errorData?['data']?['error'] != null) imgurError = 'Imgur Error: ${errorData['data']['error']}'; } catch (_) {}
        _showMessage(imgurError, isError: true); return null; 
      }
    } catch (e) { 
      _showMessage('Error during image upload: $e', isError: true); 
      if (e is SocketException) _showMessage('Network error during image upload.', isError: true);
      else if (e is TimeoutException) _showMessage('Image upload timed out.', isError: true);
      return null; 
    }
  }

  Future<void> _updateClientProfile() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage("Please correct the errors in the form.", isError: true);
      return;
    }
    if (!mounted) return;
    setState(() => _isSaving = true);

    String? finalImageUrlToSend;

    if (_selectedImageFile != null) { // إذا تم اختيار صورة جديدة
      finalImageUrlToSend = await _uploadImageToImgur(_selectedImageFile!);
      if (finalImageUrlToSend == null) { // فشل الرفع 
        if(mounted && finalImageUrlToSend != "ERROR_IMGUR_ID_NOT_SET") {
           _showMessage("Failed to upload new image. Profile not updated with new image.", isError: true);
        }
        // قد تقرر إيقاف العملية كلها أو المتابعة بدون تحديث الصورة
        // للتبسيط، سنوقفها إذا فشل الرفع
        if(mounted) setState(() => _isSaving = false);
        return;
      }
    } else if (_currentImageUrl != null) {
      // لم يتم اختيار صورة جديدة، ولكن كانت هناك صورة قديمة
      finalImageUrlToSend = _currentImageUrl;
    } else {
      // لم يتم اختيار صورة جديدة، ولم تكن هناك صورة قديمة (أو تمت إزالتها)
      // أرسل "" للإشارة إلى أن الصورة يجب أن تكون فارغة/محذوفة في الـ backend
      // أو أرسل null إذا كان الـ API يتوقع ذلك لعدم وجود صورة
      finalImageUrlToSend = ""; 
    }


    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) { 
      _showMessage("Authentication token missing.", isError: true);
      if(mounted) setState(() => _isSaving = false);
      return; 
    }

    Map<String, dynamic> updatedData = {
      "first_name": _firstNameController.text.trim(),
      "last_name": _lastNameController.text.trim(),
      "email": _emailController.text.trim(),
      "phone": _phoneController.text.trim(),
      "city": _cityController.text.trim(),
      "zip_code": _zipCodeController.text.trim(),
      if (_facebookUrlController.text.trim().isNotEmpty)
        "facebook_url": _facebookUrlController.text.trim(),
      // إرسال image_url فقط إذا تغير أو إذا كان القصد حذفه
      // الـ API يتوقع "image_url": "" إذا أردت حذف الصورة الحالية
      // إذا لم يتغير شيء بخصوص الصورة، لا ترسله
      if (finalImageUrlToSend != _clientData?['image_url']) // _clientData?['image_url'] هي الصورة الأصلية قبل أي تغييرات
         "image_url": finalImageUrlToSend,
    };
    // إزالة الحقول التي لم تتغير قيمتها إذا كان الـ API لا يحب استقبالها (اختياري)
    // updatedData.removeWhere((key, value) => _clientData != null && _clientData![key] == value && key != 'image_url');


    print("--- Updating client profile with data: $updatedData ---");

    try {
      final response = await http.put( Uri.parse(_profileApiUrl),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode(updatedData),
      ).timeout(const Duration(seconds: 25)); // زيادة المهلة قليلاً

      if (!mounted) return;
      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && responseData['success'] == true) {
        _showMessage("Profile updated successfully!", isSuccess: true);
        // تحديث البيانات المحلية بالاستجابة إذا أرجعها الخادم أو إعادة التحميل
        if (responseData['client'] != null) {
          setState(() {
            _clientData = responseData['client'];
            _currentImageUrl = _clientData?['image_url']; // تحديث رابط الصورة الحالي
            _selectedImageFile = null; // مسح الصورة المختارة محليًا بعد الرفع الناجح
          });
        } else {
          await _loadClientProfile(); // إعادة تحميل كاملة إذا لم يرجع الخادم البيانات المحدثة
        }
        if(mounted) {
          // Navigator.of(context).pop(true); // أغلق الصفحة وأشر للنجاح
        }
      } else {
        _showMessage(responseData['message']?.toString() ?? "Failed to update profile. Status: ${response.statusCode}", isError: true);
      }
    } catch (e) {
      _showMessage("An error occurred: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _customInputDecoration(String label, IconData icon, {bool isOptional = false, IconData? faIcon}) {
    return InputDecoration(
      labelText: "$label ${isOptional ? '(Optional)' : '*'}",
      labelStyle: GoogleFonts.lato(color: _secondaryTextColor, fontSize: 14.5),
      prefixIcon: faIcon != null 
                  ? Padding(padding: const EdgeInsets.all(12.0), child: FaIcon(faIcon, color: _iconColor.withOpacity(0.7), size: 18))
                  : Icon(icon, color: _iconColor.withOpacity(0.7), size: 20),
      filled: true,
      fillColor: _inputFillColor,
      contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 15.0),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 0.8)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _buttonColor, width: 1.5)),
      floatingLabelStyle: GoogleFonts.lato(color: _buttonColor, fontWeight: FontWeight.w600),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Edit Profile", style: GoogleFonts.lora(color: _appBarTextColor, fontWeight: FontWeight.bold, fontSize: 22)),
        flexibleSpace: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [_appBarColor.withOpacity(0.85), _appBarColor], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        iconTheme: IconThemeData(color: _appBarTextColor),
        elevation: 3,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_pageBackgroundColorTop, _pageBackgroundColorBottom], begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.3, 0.9]),
        ),
        child: _isLoadingData
            ? Center(child: CircularProgressIndicator(color: _buttonColor))
            : _errorMessage != null && _clientData == null
                ? _buildErrorWidget()
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
                    child: FadeInUp(
                      duration: const Duration(milliseconds: 400),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 15),
                            InkWell(
                              onTap: _isSaving ? null : _showImagePickerOptions, // تعطيل النقر أثناء الحفظ
                              borderRadius: BorderRadius.circular(60),
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 60,
                                    backgroundColor: Colors.grey.shade300,
                                    backgroundImage: _selectedImageFile != null
                                        ? FileImage(_selectedImageFile!)
                                        : (_currentImageUrl != null && _currentImageUrl!.isNotEmpty && Uri.tryParse(_currentImageUrl!)?.hasAbsolutePath == true
                                            ? NetworkImage(_currentImageUrl!)
                                            : null) as ImageProvider?,
                                    child: (_selectedImageFile == null && (_currentImageUrl == null || _currentImageUrl!.isEmpty || Uri.tryParse(_currentImageUrl!)?.hasAbsolutePath != true))
                                        ? Icon(Icons.person, size: 60, color: Colors.grey.shade500)
                                        : null,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: _buttonColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                    child: const Icon(Icons.edit, color: Colors.white, size: 18),
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              (_firstNameController.text.isNotEmpty || _lastNameController.text.isNotEmpty)
                                  ? "${_firstNameController.text} ${_lastNameController.text}".trim()
                                  : (_clientData?['email'] ?? "Edit Profile"),
                              style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryTextColor),
                            ),
                            Text("Update your profile information", style: GoogleFonts.lato(fontSize: 15, color: _secondaryTextColor)),
                            const SizedBox(height: 35),

                            _buildProfileSectionCard([
                              Row(children: [
                                Expanded(child: TextFormField(controller: _firstNameController, decoration: _customInputDecoration("First Name", Icons.person_outline_rounded), validator: (v)=>(v==null||v.isEmpty)?'Required':null, enabled: !_isSaving)),
                                const SizedBox(width: 12),
                                Expanded(child: TextFormField(controller: _lastNameController, decoration: _customInputDecoration("Last Name", Icons.person_outline_rounded), validator: (v)=>(v==null||v.isEmpty)?'Required':null, enabled: !_isSaving)),
                              ]),
                              const SizedBox(height: 18),
                              TextFormField(enabled: false, controller: _emailController, decoration: _customInputDecoration("Email Address", Icons.email_outlined), keyboardType: TextInputType.emailAddress),
                            ]),
                            const SizedBox(height: 20),
                            _buildProfileSectionCard([
                              TextFormField(controller: _phoneController, decoration: _customInputDecoration("Phone Number", Icons.phone_iphone_rounded), keyboardType: TextInputType.phone, validator: (v)=>(v==null||v.isEmpty)?'Required':null, enabled: !_isSaving),
                              // لا نعرض حقل image_url هنا لأنه يتم التحكم به عبر اختيار الصورة
                              const SizedBox(height: 18),
                              TextFormField(controller: _facebookUrlController, decoration: _customInputDecoration("Facebook URL", FontAwesomeIcons.facebookF, isOptional: true), keyboardType: TextInputType.url, enabled: !_isSaving),
                            ]),
                             const SizedBox(height: 20),
                            _buildProfileSectionCard([
                               Row(children: [
                                Expanded(child: TextFormField(controller: _cityController, decoration: _customInputDecoration("City", Icons.location_city_rounded), validator: (v)=>(v==null||v.isEmpty)?'Required':null, enabled: !_isSaving)),
                                const SizedBox(width: 12),
                                Expanded(child: TextFormField(controller: _zipCodeController, decoration: _customInputDecoration("Zip Code", Icons.map_outlined), keyboardType: TextInputType.number, validator: (v)=>(v==null||v.isEmpty)?'Required':null, enabled: !_isSaving)),
                              ]),
                            ]),
                            
                            const SizedBox(height: 35),
                            _isSaving
                                ? Center(child: CircularProgressIndicator(color: _buttonColor))
                                : SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.save_alt_rounded, color: Colors.white),
                                      label: Text('Save Changes', style: GoogleFonts.lato(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                                      onPressed: _updateClientProfile,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _buttonColor,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        elevation: 5,
                                      ),
                                    ),
                                  ),
                            if (_errorMessage != null && !_isLoadingData)
                                Padding(
                                  padding: const EdgeInsets.only(top: 15.0),
                                  child: Text(_errorMessage!, style: GoogleFonts.lato(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
                                ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
          );
  }

  Widget _buildProfileSectionCard(List<Widget> children) {
    return Card(
      elevation: 2.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: _cardColor.withOpacity(0.98),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 22.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error.withOpacity(0.7), size: 60),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? "Failed to load profile data.",
              style: GoogleFonts.lato(color: Theme.of(context).colorScheme.error, fontSize: 17, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: Text("Try Again", style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _loadClientProfile,
              style: ElevatedButton.styleFrom(backgroundColor: _buttonColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            )
          ],
        ),
      ),
    );
  }
}

// --- ClientHomePage (الكود الذي قدمته أنت مع تعديلات طفيفة للانتقال الصحيح) ---
class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  final Color _iconColor = const Color(0xFF4A5D52); // لون الأيقونة كما حددته
  final Color _pageBackgroundColor = const Color(0xFFF2DEC5); // لون الخلفية كما حددته

  final _storage = const FlutterSecureStorage();
  final String _baseUrl = Platform.isAndroid ? "http://10.0.2.2:3000" : "http://localhost:3000";
  Map<String, dynamic>? _clientDataForAvatar; // بيانات لعرض الصورة الرمزية فقط
  bool _isLoadingAvatar = true;

  @override
  void initState() {
    super.initState();
    _loadClientProfileForAvatar();
  }

  Future<void> _loadClientProfileForAvatar() async {
    if(!mounted) return;
    setState(() => _isLoadingAvatar = true);
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _isLoadingAvatar = false);
      // قد تحتاج لمعالجة خطأ المصادقة هنا أيضًا
      return;
    }
    final url = Uri.parse("$_baseUrl/api/client/profile");
    try {
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['client'] != null) {
          setState(() {
            _clientDataForAvatar = data['client'];
            _isLoadingAvatar = false;
          });
        } else {
           if (mounted) setState(() => _isLoadingAvatar = false);
        }
      } else {
        if (mounted) setState(() => _isLoadingAvatar = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAvatar = false);
    }
  }

  void _navigateToEditProfile() async {
    // عند الانتقال، توقع نتيجة. إذا كانت true، أعد تحميل بيانات الصورة الرمزية
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditClientProfilePage()),
    );
    if (result == true && mounted) {
      _loadClientProfileForAvatar();
    }
  }
  
  // دالة تسجيل الخروج (يمكنك نسخها من EditClientProfilePage أو MyCompaniesPage)
  Future<void> _logout() async {
    // ... (منطق تسجيل الخروج ومسح التخزين والانتقال لـ LoginScreen)
    await _storage.deleteAll();
    if(mounted){
      // Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logged out! (Navigation to Login commented)")));
    }
  }


  @override
  Widget build(BuildContext context) {
    String? avatarUrl = _clientDataForAvatar?["image_url"];
    String clientName = _clientDataForAvatar?["first_name"] ?? "Client";

    return Scaffold(
      backgroundColor: _pageBackgroundColor, // استخدام لون الخلفية المحدد
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A5D52), // لون AppBar كما طلبته
        elevation: 2,
        title: Text("Welcome, $clientName", style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () { /* TODO: Implement drawer or menu */ },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: GestureDetector(
              onTap: _navigateToEditProfile, // استخدام الدالة المحدثة
              child: Hero(
                tag: 'client-profile-avatar-home', // Tag مختلف إذا كنت تستخدم Hero في EditProfile أيضًا
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty && Uri.tryParse(avatarUrl)?.hasAbsolutePath == true)
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: (_isLoadingAvatar)
                      ? const SizedBox(width:20, height:20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,))
                      : ((avatarUrl == null || avatarUrl.isEmpty || Uri.tryParse(avatarUrl)?.hasAbsolutePath != true)
                          ? Icon(Icons.person_outline_rounded, color: Colors.white.withOpacity(0.8), size: 22,)
                          : null),
                ),
              ),
            ),
          ),
          IconButton(icon: Icon(Icons.logout_rounded, color: Colors.white), onPressed: _logout, tooltip: "Logout")
        ],
      ),
      body: Center( // مجرد محتوى مبدئي للصفحة الرئيسية
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeInDown(child: Icon(Icons.home_repair_service_outlined, size: 100, color: _iconColor.withOpacity(0.8))),
              const SizedBox(height: 20),
              FadeInUp(child: Text("Client Home Page", style: GoogleFonts.lato(fontSize: 28, fontWeight: FontWeight.bold, ))),
              const SizedBox(height: 15),
              FadeInUp(delay: Duration(milliseconds: 200), child: Text("Find services, manage your requests, and connect with providers.", textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 16, color: Colors.grey[700] // أو أي درجة رمادي خفيف تفضلها
))),
            ],
          ),
        ),
      ),
      // يمكنك تعديل BottomNavigationBar ليتضمن "Profile" وينقلك إلى _navigateToEditProfile
      // bottomNavigationBar: BottomNavigationBar(
      //   currentIndex: 0, // عدل هذا حسب الصفحة النشطة
      //   selectedItemColor: _iconColor,
      //   onTap: (index) {
      //     if (index == 1) { // افترض أن "Profile" هو العنصر الثاني
      //       _navigateToEditProfile();
      //     }
      //     // يمكنك إضافة منطق لبقية الأزرار
      //   },
      //   items: const [
      //     BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
      //     BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "Profile"),
      //     BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: "History"),
      //   ],
      // ),
    );
  }
}