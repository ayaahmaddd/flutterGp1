// create_task_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:animate_do/animate_do.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CreateTaskPage extends StatefulWidget {
  final String baseUrl;
  final FlutterSecureStorage storage;
  final int? prefilledProviderId; // <-- تمت إضافته هنا

  const CreateTaskPage({
    super.key,
    required this.baseUrl,
    required this.storage,
    this.prefilledProviderId, // <-- تمت إضافته هنا
  });

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _providerIdController; // تم التعديل لـ late
  late TextEditingController _descriptionController;
  late TextEditingController _estimatedDistanceController;
  late TextEditingController _estimatedTimingController;
  late TextEditingController _initialPriceController;
  late TextEditingController _maxPriceController;
  late TextEditingController _notesController;

  bool _isLoading = false;

  final Color _pageBackgroundColorTop = const Color(0xFFFAF3E0); 
  final Color _pageBackgroundColorBottom = const Color(0xFFA3B29F); 
  final Color _appBarColor = Colors.white; 
  final Color _appBarItemColor = const Color(0xFF4A5D52); 
  final Color _iconColor = const Color(0xFF4A5D52); 
  final Color _primaryTextColor = const Color(0xFF3A3A3A);
  final Color _buttonColor = const Color(0xFF4A5D52);

  @override
  void initState() {
    super.initState();
    // تهيئة الـ Controllers هنا
    _providerIdController = TextEditingController(text: widget.prefilledProviderId?.toString() ?? '');
    _descriptionController = TextEditingController();
    _estimatedDistanceController = TextEditingController();
    _estimatedTimingController = TextEditingController();
    _initialPriceController = TextEditingController();
    _maxPriceController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _providerIdController.dispose();
    _descriptionController.dispose();
    _estimatedDistanceController.dispose();
    _estimatedTimingController.dispose();
    _initialPriceController.dispose();
    _maxPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.lato(color: Colors.white)),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : (isSuccess ? Colors.green.shade600 : _iconColor),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating, elevation: 6.0, margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _submitTask() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage("Please fill all required fields correctly.", isError: true);
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = true);

    final token = await widget.storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      _showMessage("Authentication error. Please log in again.", isError: true);
      if (mounted) setState(() => _isLoading = false);
      // Potentially navigate to login
      return;
    }

    final body = {
      "provider_id": int.tryParse(_providerIdController.text),
      "description": _descriptionController.text,
      "estimated_distance": _estimatedDistanceController.text.isNotEmpty ? double.tryParse(_estimatedDistanceController.text) : null,
      "estimated_timing": _estimatedTimingController.text.isNotEmpty ? _estimatedTimingController.text : null,
      "initial_price": int.tryParse(_initialPriceController.text),
      "max_price": int.tryParse(_maxPriceController.text),
      "notes": _notesController.text.isNotEmpty ? _notesController.text : null,
    };
    
    body.removeWhere((key, value) => value == null); 
     if (body['provider_id'] == null || body['description'] == null || body['initial_price'] == null || body['max_price'] == null) {
         _showMessage("Provider ID, Description, Initial Price, and Max Price are required.", isError: true);
         if (mounted) setState(() => _isLoading = false);
         return;
    }


    final url = Uri.parse("${widget.baseUrl}/api/client/tasks");
    print("--- Creating Task: $url with body: ${json.encode(body)} ---");

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (!mounted) return;
      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 201 && responseData['success'] == true) {
        _showMessage(responseData['message'] ?? "Task created successfully!", isSuccess: true);
        Navigator.pop(context, true); 
      } else {
        throw Exception(responseData['message'] ?? "Failed to create task (${response.statusCode})");
      }
    } catch (e) {
      if (mounted) {
        _showMessage(e.toString().replaceFirst("Exception: ", ""), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  InputDecoration _customInputDecoration(String label, IconData icon, {String? hint, bool readOnly = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.lato(color: _primaryTextColor.withOpacity(0.8), fontSize: 15),
      hintText: hint,
      hintStyle: GoogleFonts.lato(color: Colors.grey.shade500, fontSize: 14),
      prefixIcon: Icon(icon, color: _iconColor.withOpacity(0.7), size: 20),
      filled: true,
      fillColor: readOnly ? Colors.grey.shade200.withOpacity(0.7) : Colors.white.withOpacity(0.9) , // لون مختلف إذا كان للقراءة فقط
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300.withOpacity(0.7))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300.withOpacity(0.7))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _iconColor, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 1.2)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 1.5)),
    );
  }


  @override
  Widget build(BuildContext context) {
    bool isProviderIdReadOnly = widget.prefilledProviderId != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Create New Task', style: GoogleFonts.lato(color: _appBarItemColor, fontWeight: FontWeight.bold)),
        backgroundColor: _appBarColor,
        elevation: 1,
        iconTheme: IconThemeData(color: _appBarItemColor),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_pageBackgroundColorTop, _pageBackgroundColorBottom],
            begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.1, 0.9],
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20.0),
            children: <Widget>[
              FadeInDown(delay: const Duration(milliseconds: 100), child: Text("Service Request Details", style: GoogleFonts.lato(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryTextColor))),
              const SizedBox(height: 10),
              FadeInDown(delay: const Duration(milliseconds: 200), child: Text("Fill in the information below to submit your request.", style: GoogleFonts.lato(fontSize: 15, color: _primaryTextColor.withOpacity(0.7)))),
              const SizedBox(height: 25),

              _buildTextField(
                _providerIdController, 
                "Provider ID*", 
                FontAwesomeIcons.userCheck, 
                TextInputType.number, 
                "Enter ID of the service provider", 
                delay: 300, 
                validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null) ? "Provider ID is required and must be a number." : null,
                readOnly: isProviderIdReadOnly, // تم إضافة هذا
              ),
              _buildTextField(_descriptionController, "Description*", FontAwesomeIcons.fileLines, TextInputType.multiline, "Describe the task or service needed...", maxLines: 3, delay: 400, validator: (v) => (v == null || v.isEmpty) ? "Description is required." : null),
              _buildTextField(_initialPriceController, "Your Initial Offer (\$)*", FontAwesomeIcons.dollarSign, TextInputType.number, "e.g., 100", delay: 500, validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null) ? "Initial price is required and must be a number." : null),
              _buildTextField(_maxPriceController, "Your Maximum Budget (\$)*", FontAwesomeIcons.coins, TextInputType.number, "e.g., 200", delay: 600, validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null) ? "Max price is required and must be a number." : (int.tryParse(_initialPriceController.text) != null && int.parse(v) < int.parse(_initialPriceController.text) ? "Max price cannot be less than initial." : null)),
              
              const SizedBox(height: 20),
              FadeInUp(delay: const Duration(milliseconds: 700), child: Text("Optional Details", style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w600, color: _primaryTextColor.withOpacity(0.9)))),
              const SizedBox(height: 15),

              _buildTextField(_estimatedDistanceController, "Estimated Distance (km)", FontAwesomeIcons.route, TextInputType.numberWithOptions(decimal: true), "e.g., 10.5", delay: 800, isOptional: true, validator: (v){
                if (v == null || v.isEmpty) return null;
                if (double.tryParse(v) == null) return "Must be a valid number.";
                return null;
              }),
              _buildTextField(_estimatedTimingController, "Estimated Timing (HH:MM:SS)", FontAwesomeIcons.clock, TextInputType.text, "e.g., 02:30:00", delay: 900, isOptional: true, validator: (v) {
                if (v == null || v.isEmpty) return null;
                final RegExp timeRegex = RegExp(r'^\d{2}:\d{2}:\d{2}$');
                if (!timeRegex.hasMatch(v)) return "Format must be HH:MM:SS (e.g., 01:00:00)";
                return null;
              }),
              _buildTextField(_notesController, "Additional Notes", FontAwesomeIcons.solidNoteSticky, TextInputType.multiline, "Any preferences, specific instructions, etc.", maxLines: 2, delay: 1000, isOptional: true),
              
              const SizedBox(height: 30),
              FadeInUp(
                delay: const Duration(milliseconds: 1100),
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: _buttonColor))
                    : ElevatedButton.icon(
                        icon: const Icon(FontAwesomeIcons.paperPlane, color: Colors.white, size: 18),
                        label: Text('Submit Request', style: GoogleFonts.lato(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                        onPressed: _submitTask,
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

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, TextInputType inputType, String hint, {int maxLines = 1, required int delay, String? Function(String?)? validator, bool isOptional = false, bool readOnly = false}) {
    return FadeInUp(
      delay: Duration(milliseconds: delay),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9.0),
        child: TextFormField(
          controller: controller,
          decoration: _customInputDecoration(label, icon, hint: hint, readOnly: readOnly), // تم تمرير readOnly
          keyboardType: inputType,
          maxLines: maxLines,
          style: GoogleFonts.lato(color: _primaryTextColor, fontSize: 15),
          validator: validator ?? (isOptional ? null : (v) => (v == null || v.isEmpty) ? "${label.replaceAll('*', '').trim()} is required." : null),
          textInputAction: maxLines > 1 ? TextInputAction.newline : (isOptional ? TextInputAction.done : TextInputAction.next),
          readOnly: readOnly, // تم إضافة هذا
        ),
      ),
    );
  }
}