// create_project_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // لـ DateFormat و _selectDate
import 'package:animate_do/animate_do.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CreateProjectPage extends StatefulWidget {
  final String teamId;
  final String companyId; // قد لا تحتاجها مباشرة في الـ payload ولكن جيد أن تكون موجودة للسياق
  final String baseUrl;
  final FlutterSecureStorage storage;

  const CreateProjectPage({
    super.key,
    required this.teamId,
    required this.companyId,
    required this.baseUrl,
    required this.storage,
  });

  @override
  State<CreateProjectPage> createState() => _CreateProjectPageState();
}

class _CreateProjectPageState extends State<CreateProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _initialPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  // لا يوجد Initial_time_s و final_time_s في API إنشاء المشروع الذي أرسلته

  bool _isLoading = false;

  // ألوان مشابهة لباقي التطبيق
  final Color _pageBackgroundColorTop = const Color(0xFFFAF3E0);
  final Color _pageBackgroundColorBottom = const Color(0xFFA3B29F);
  final Color _appBarColor = Colors.white;
  final Color _appBarTextColor = const Color(0xFF4A5D52);
  final Color _iconColor = const Color(0xFF4A5D52);
  final Color _primaryTextColor = const Color(0xFF3A3A3A);
  final Color _buttonColor = const Color(0xFF4A5D52);

  @override
  void dispose() {
    _nameController.dispose();
    _initialPriceController.dispose();
    _maxPriceController.dispose();
    _descriptionController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.lato(color: Colors.white)),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : (isSuccess ? Colors.green.shade600 : _iconColor),
    ));
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)), // يمكن البدء من سنة سابقة
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)), // لخمس سنوات قادمة
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: _iconColor, onPrimary: Colors.white),
            textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: _iconColor)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _submitCreateProject() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage("Please fill all required fields.", isError: true);
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = true);

    final token = await widget.storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      _showMessage("Authentication error.", isError: true);
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final body = {
      "name": _nameController.text.trim(),
      "team_id": int.tryParse(widget.teamId), // team_id يتم تمريره من الصفحة السابقة
      "initial_price": num.tryParse(_initialPriceController.text.trim()),
      "max_price": num.tryParse(_maxPriceController.text.trim()),
      "description": _descriptionController.text.trim(),
      "start_date": _startDateController.text.trim(),
      "end_date": _endDateController.text.trim(),
      // "company_id": int.tryParse(widget.companyId), // إذا كان الـ API يطلبه
    };
    // إزالة القيم الفارغة إذا كان الـ API لا يقبلها أو يتجاهلها
    body.removeWhere((key, value) => value == null || (value is String && value.isEmpty));


    final url = Uri.parse("${widget.baseUrl}/api/client/projects");
    print("--- Creating Project: $url with body: ${json.encode(body)} ---");

    try {
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (!mounted) return;
      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 201 && responseData['success'] == true) { // 201 Created
        _showMessage(responseData['message'] ?? "Project created successfully!", isSuccess: true);
        Navigator.pop(context, true); // العودة بنجاح لتحديث قائمة المشاريع
      } else {
        throw Exception(responseData['message'] ?? "Failed to create project (${response.statusCode})");
      }
    } catch (e) {
      if (mounted) {
        _showMessage(e.toString().replaceFirst("Exception: ", ""), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _customInputDecoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.lato(color: _primaryTextColor.withOpacity(0.8), fontSize: 15),
      hintText: hint,
      hintStyle: GoogleFonts.lato(color: Colors.grey.shade500, fontSize: 14),
      prefixIcon: Icon(icon, color: _iconColor.withOpacity(0.7), size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300.withOpacity(0.7))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300.withOpacity(0.7))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _iconColor, width: 1.5)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, TextInputType inputType, {String? hint, int maxLines = 1, String? Function(String?)? validator, bool readOnly = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9.0),
      child: TextFormField(
        controller: controller,
        decoration: _customInputDecoration(label, icon, hint: hint),
        keyboardType: inputType,
        maxLines: maxLines,
        style: GoogleFonts.lato(color: _primaryTextColor, fontSize: 15),
        validator: validator ?? (v) => (v == null || v.isEmpty) ? "$label is required." : null,
        textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
        readOnly: readOnly,
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Project for Team #${widget.teamId}', style: GoogleFonts.lato(color: _appBarTextColor, fontWeight: FontWeight.bold)),
        backgroundColor: _appBarColor,
        elevation: 1,
        iconTheme: IconThemeData(color: _appBarTextColor),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_pageBackgroundColorTop, _pageBackgroundColorBottom],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20.0),
            children: <Widget>[
              FadeInDown(delay: const Duration(milliseconds: 100), child: Text("New Project Details", style: GoogleFonts.lato(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryTextColor))),
              const SizedBox(height: 25),

              _buildTextField(_nameController, "Project Name *", Icons.title_rounded, TextInputType.text),
              _buildTextField(_descriptionController, "Description *", Icons.description_rounded, TextInputType.multiline, maxLines: 3),
              _buildTextField(_initialPriceController, "Initial Price (\$)", Icons.attach_money_rounded, TextInputType.number, validator: (v){ if(v!=null && v.isNotEmpty && num.tryParse(v) == null) return "Must be a number"; return null;}),
              _buildTextField(_maxPriceController, "Max Price (\$)", Icons.money_off_csred_rounded, TextInputType.number, validator: (v){ if(v!=null && v.isNotEmpty && num.tryParse(v) == null) return "Must be a number"; return null;}),
              _buildTextField(_startDateController, "Start Date (YYYY-MM-DD) *", Icons.play_arrow_rounded, TextInputType.none, readOnly: true, onTap: () => _selectDate(context, _startDateController)),
              _buildTextField(_endDateController, "End Date (YYYY-MM-DD) *", Icons.event_busy_rounded, TextInputType.none, readOnly: true, onTap: () => _selectDate(context, _endDateController)),
              
              const SizedBox(height: 30),
              FadeInUp(
                delay: const Duration(milliseconds: 500), // تعديل بسيط للتأخير
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: _buttonColor))
                    : ElevatedButton.icon(
                        icon: const Icon(FontAwesomeIcons.folderPlus, color: Colors.white, size: 18),
                        label: Text('Create Project', style: GoogleFonts.lato(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                        onPressed: _submitCreateProject,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _buttonColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
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