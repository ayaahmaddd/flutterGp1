import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
// لا نحتاج path أو path_provider لرفع Imgur
import 'dart:async'; // لـ TimeoutException

// استيراد الشاشات الأخرى اللازمة
import 'login.dart'; // تأكد أن هذا هو اسم ملف شاشة تسجيل الدخول

// ---!!! ✨ ضعي Client ID الخاص بكِ من Imgur هنا ✨ !!!---
const String imgurClientId = '25493267ebab14e'; // <--- تم وضع الـ ID من الصورة

// تأكد من عدم وجود مسافات إضافية حول الـ ID

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  File? _selectedImage;
  String _selectedRole = "Client";
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  // Controllers
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController zipCodeController = TextEditingController();
  final TextEditingController facebookUrlController = TextEditingController();

  // --- عنوان URL للباكند (استخدم 10.0.2.2 للمحاكي) ---
  final String _baseAuthUrl = "http://localhost:3000/api/auth";

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    cityController.dispose();
    zipCodeController.dispose();
    facebookUrlController.dispose();
    super.dispose();
  }

  // --- دوال مساعدة ---
  void _showErrorDialog(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80, // تقليل الجودة لتصغير الحجم
        maxWidth: 1000, // تحديد عرض أقصى (Imgur له حدود)
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      } else {
        print("No image selected.");
      }
    } catch (e) {
      print("Error picking image: $e");
      _showErrorDialog("Error picking image: ${e.toString()}");
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('Photo Library'),
                    onTap: () {
                      _pickImage(ImageSource.gallery);
                      Navigator.of(context).pop();
                    }),
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Camera'),
                  onTap: () {
                    _pickImage(ImageSource.camera);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        });
  }

  InputDecoration _buildInputDecoration(
      {required String label, IconData? icon, IconData? faIcon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null
          ? Icon(icon)
          : (faIcon != null
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 13.0, vertical: 12.0),
                  child: FaIcon(faIcon, size: 18),
                )
              : null),
    ).applyDefaults(Theme.of(context).inputDecorationTheme);
  }

  // --- دالة التحقق المنفصلة (تبقى كما هي) ---
  bool _validateForm() {
    if (firstNameController.text.trim().isEmpty) { _showErrorDialog('First name is required.'); return false; }
    if (lastNameController.text.trim().isEmpty) { _showErrorDialog('Last name is required.'); return false; }
    final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    if (emailController.text.trim().isEmpty || !emailRegex.hasMatch(emailController.text.trim())) { _showErrorDialog('Please enter a valid email address.'); return false; }
    if (passwordController.text.length < 6) { _showErrorDialog('Password must be at least 6 characters long.'); return false; }
    if (cityController.text.trim().isEmpty) { _showErrorDialog('City is required.'); return false; }
    if (zipCodeController.text.trim().isEmpty) { _showErrorDialog('Zip code is required.'); return false; }
    if (int.tryParse(zipCodeController.text.trim()) == null) { _showErrorDialog('Zip code must be a valid number.'); return false; }
    // الصورة اختيارية، لا نتحقق منها هنا
    return true;
  }

  // --- دالة رفع الصورة إلى Imgur ---
  Future<String?> _uploadImageToImgur(File imageFile) async {
    // تأكد من أن Client ID ليس القيمة الافتراضية
    if (imgurClientId == 'YOUR_IMGUR_CLIENT_ID' || imgurClientId.isEmpty) {
       _showErrorDialog('INTERNAL ERROR: Imgur Client ID is not set.'); // رسالة للمطور
       return null;
    }

    print("Attempting to upload image to Imgur...");
    // لا نغير isLoading هنا لأن _handleSignUp تتحكم به بشكل عام

    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('https://api.imgur.com/3/image'),
        headers: {
          // المصادقة باستخدام Client ID
          'Authorization': 'Client-ID $imgurClientId',
        },
        body: {
          // Imgur API يتوقع الصورة كـ base64 أو رابط أو ملف ثنائي
          'image': base64Image, // إرسال الصورة كـ base64
          'type': 'base64',
        },
      ).timeout(const Duration(seconds: 60)); // مهلة أطول لرفع Imgur

      if (!mounted) return null; // تحقق بعد العملية الطويلة

      print('Imgur Upload Response Status: ${response.statusCode}');
      print('Imgur Upload Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // التحقق من بنية الاستجابة الناجحة من Imgur
        if (data != null && data['success'] == true && data['data']?['link'] != null) {
          print('Image uploaded to Imgur successfully. Link: ${data['data']['link']}');
          return data['data']['link']; // إرجاع رابط الصورة
        } else {
          print("Imgur upload failed: Unexpected response format or success=false.");
          _showErrorDialog('Image upload failed: Invalid response from Imgur.');
          return null;
        }
      } else { // فشل الرفع (خطأ من Imgur)
        print("Imgur upload failed with status ${response.statusCode}: ${response.body}");
         String imgurError = 'Image upload failed (Status: ${response.statusCode}).';
         try {
           final errorData = jsonDecode(response.body);
           // محاولة قراءة رسالة الخطأ المحددة من Imgur
           if (errorData?['data']?['error'] != null) {
             // قد تكون رسالة الخطأ معقدة، نعرضها كما هي
             imgurError = 'Imgur Error (${response.statusCode}): ${errorData['data']['error']}';
           }
         } catch (_) {} // تجاهل خطأ فك التشفير
        _showErrorDialog(imgurError);
        return null;
      }
    } catch (error) { // معالجة أخطاء الشبكة أو المهلة
       print("Error uploading image to Imgur: $error");
       if (error is SocketException) { _showErrorDialog('Network error uploading image. Check connection.'); }
       else if (error is TimeoutException) { _showErrorDialog('Image upload timed out.'); }
       else { _showErrorDialog('Unexpected error during image upload.'); }
       return null;
    }
  }

  // --- معالج إنشاء الحساب (يستخدم رفع Imgur) ---
  Future<void> _handleSignUp() async {
    if (!_validateForm()) {
      return; // إيقاف إذا فشل التحقق الأولي
    }

    setState(() { _isLoading = true; }); // بدء مؤشر التحميل العام

    String? imageUrl; // رابط الصورة من Imgur (سيبقى null إذا لم يتم اختيار صورة)

    // --- الخطوة 1 (اختيارية): رفع الصورة إلى Imgur إذا تم اختيارها ---
    if (_selectedImage != null) {
       print("Selected image detected. Attempting upload to Imgur...");
       imageUrl = await _uploadImageToImgur(_selectedImage!);

       // إذا فشل الرفع، توقف العملية
       if (imageUrl == null) {
         if (mounted) setState(() { _isLoading = false; }); // أوقف التحميل
         // رسالة الخطأ تم عرضها داخل _uploadImageToImgur
         return;
       }
    } else {
       print("No image selected, proceeding without image URL.");
       // imageUrl سيبقى null
    }

    // --- الخطوة 2: إرسال بيانات التسجيل (مع أو بدون رابط Imgur) ---
    final signupEndpoint = _selectedRole == "Client" ? '/signup/client' : '/signup/provider';
    final signupUrl = Uri.parse('$_baseAuthUrl$signupEndpoint');

    // قراءة باقي القيم
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final city = cityController.text.trim();
    final zipCode = zipCodeController.text.trim();
    final facebookUrl = facebookUrlController.text.trim();

    // بناء جسم طلب JSON
    Map<String, dynamic> requestBody = {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'password': password,
      'city': city,
      'zip_code': zipCode,
      // --- إضافة رابط Imgur (أو لا شيء إذا كان null) ---
      if (imageUrl != null) 'image_url': imageUrl,
    };
    if (facebookUrl.isNotEmpty) {
      requestBody['facebook_url'] = facebookUrl;
    }

    try {
       print("Sending final signup data (JSON) to: $signupUrl");
       print("Request Body: ${jsonEncode(requestBody)}");

       final response = await http.post(
         signupUrl,
         headers: { 'Content-Type': 'application/json; charset=UTF-8', },
         body: jsonEncode(requestBody),
       ).timeout(const Duration(seconds: 20));

       if (!mounted) return; // تحقق بعد العملية الطويلة

       print('Final Sign Up Response Status Code: ${response.statusCode}');
       print('Final Sign Up Response Body: ${response.body}');

       dynamic responseData;
       try { responseData = jsonDecode(response.body); }
       catch (e) { print("Error decoding JSON response: $e"); _showErrorDialog('Sign up failed. Invalid response from server (Status: ${response.statusCode}). Body: ${response.body}'); return; } // يجب إيقاف التحميل في finally

       if (response.statusCode == 201 || response.statusCode == 200) {
          print('Sign Up Successful: $responseData');
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar( const SnackBar( content: Text('Account created successfully! Please log in.'), backgroundColor: Colors.green,), );
           _clearSignUpFields();
           Navigator.pushReplacement( context, MaterialPageRoute(builder: (context) => const LoginScreen()), );
         }
       } else { // فشل التسجيل النهائي
          String errorMessage = "Sign up failed."; if (responseData is Map && responseData.containsKey('errors') && responseData['errors'] is List && responseData['errors'].isNotEmpty) { var firstError = responseData['errors'][0]; if (firstError is Map && firstError.containsKey('msg')) { errorMessage = firstError['msg']; } else { errorMessage = "Sign up failed. Errors: ${jsonEncode(responseData['errors'])}"; } } else if (responseData is Map && responseData.containsKey('message')) { errorMessage = responseData['message']; }
         _showErrorDialog(errorMessage);
       }

    } catch (error) { // معالجة أخطاء طلب التسجيل النهائي
       print("Final Sign Up Error: $error");
        if (error is SocketException) { _showErrorDialog('Network error during final signup. Check connection.'); }
        else if (error is TimeoutException) { _showErrorDialog('Final signup request timed out.'); }
        else { _showErrorDialog('An unexpected error occurred during final signup.'); }
    } finally {
      // إيقاف التحميل دائمًا في النهاية
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  // --- مسح حقول إنشاء الحساب ---
  void _clearSignUpFields() {
    firstNameController.clear();
    lastNameController.clear();
    emailController.clear();
    passwordController.clear();
    cityController.clear();
    zipCodeController.clear();
    facebookUrlController.clear();
    if (mounted) {
      setState(() {
        _selectedImage = null;
        _selectedRole = "Client";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- واجهة المستخدم تبقى كما هي ---
    return Scaffold(
      appBar: AppBar(title: const Text("Create Account")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- العنوان والعنوان الفرعي ---
              Text(
                'Fill in the details below to get started.',
                textAlign: TextAlign.center,
                style: GoogleFonts.lora(
                  fontSize: 16,
                  color: Theme.of(context).primaryColor.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 20),

              // --- اختيار وعرض الصورة ---
              InkWell(
                onTap: _showImagePickerOptions,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage:
                      _selectedImage != null ? FileImage(_selectedImage!) : null,
                  child: _selectedImage == null
                      ? Icon(Icons.add_a_photo,
                          size: 50, color: Colors.grey.shade400)
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                icon: const Icon(Icons.image_search),
                label: const Text("Choose Profile Image (Optional)"),
                onPressed: _showImagePickerOptions,
              ),
              const SizedBox(height: 20),

              // --- باقي حقول النموذج ---
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: TextField(
                          controller: firstNameController,
                          decoration: _buildInputDecoration(
                              label: 'First Name', icon: Icons.person_outline),
                          textCapitalization: TextCapitalization.words,
                        )),
                        const SizedBox(width: 10),
                        Expanded(
                            child: TextField(
                          controller: lastNameController,
                          decoration: _buildInputDecoration(
                              label: 'Last Name', icon: Icons.person_outline),
                          textCapitalization: TextCapitalization.words,
                        )),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _buildInputDecoration(
                          label: 'Email', icon: Icons.email_outlined),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: _buildInputDecoration(
                          label: 'Password', icon: Icons.lock_outline),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                            child: TextField(
                          controller: cityController,
                          decoration: _buildInputDecoration(
                              label: 'City', icon: Icons.location_city_outlined),
                          textCapitalization: TextCapitalization.words,
                        )),
                        const SizedBox(width: 10),
                        Expanded(
                            child: TextField(
                          controller: zipCodeController,
                          keyboardType: TextInputType.number,
                          decoration: _buildInputDecoration(
                              label: 'Zip Code',
                              icon: Icons.local_post_office_outlined),
                        )),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: facebookUrlController,
                      keyboardType: TextInputType.url,
                      decoration: _buildInputDecoration(
                          label: 'Facebook URL (Optional)',
                          faIcon: FontAwesomeIcons.facebook),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Register as:",
                      style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Radio<String>(
                          value: "Client",
                          groupValue: _selectedRole,
                          onChanged: (value) {
                            setState(() {
                              _selectedRole = value!;
                            });
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                        const Text('Client'),
                        const SizedBox(width: 20),
                        Radio<String>(
                          value: "Provider",
                          groupValue: _selectedRole,
                          onChanged: (value) {
                            setState(() {
                              _selectedRole = value!;
                            });
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                        const Text('Provider'),
                      ],
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSignUp,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 3))
                            : const Text('CREATE ACCOUNT'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // --- زر الانتقال لتسجيل الدخول ---
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    children: <TextSpan>[
                      const TextSpan(text: "Already have an account? "),
                      TextSpan(
                          text: 'Login',
                          style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}