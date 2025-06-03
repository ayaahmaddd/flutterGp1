// update_task_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:animate_do/animate_do.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Helper extension for String capitalization
extension StringExtensionUpdate on String {
    String capitalizeFirst() {
      if (isEmpty) return this;
      return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
    }
}

class UpdateTaskPage extends StatefulWidget {
  final String baseUrl;
  
  final FlutterSecureStorage storage;
  final Map<String, dynamic> task;

  const UpdateTaskPage({
    super.key,
    required this.baseUrl,
    required this.storage,
    required this.task,
  });

  @override
  State<UpdateTaskPage> createState() => _UpdateTaskPageState();
}

class _UpdateTaskPageState extends State<UpdateTaskPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  
  bool _isLoading = false;

  final Color _pageBackgroundColorTop = const Color(0xFFFAF3E0); 
  final Color _pageBackgroundColorBottom = const Color(0xFFA3B29F); 
  final Color _appBarColor = Colors.white; 
  final Color _appBarItemColor = const Color(0xFF4A5D52); 
  final Color _iconColor = const Color(0xFF4A5D52); 
  final Color _primaryTextColor = const Color(0xFF3A3A3A);
  final Color _buttonColor = const Color(0xFF4A5D52);
  final Color _secondaryTextColor = Colors.grey.shade700;


  String? _selectedStatus;
  // قائمة الحالات المسموح للعميل بتحديثها (تم تعديلها)
  // العميل يمكنه فقط نقلها إلى "in progress" أو "cancelled"
  // بافتراض أن المهمة ليست مكتملة أو مرفوضة بالفعل.
  // الـ Backend يجب أن يتحقق من صحة الانتقالات.
  final List<String> _clientAllowedStatusUpdates = ['in progress', 'cancelled'];


  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.task['description']?.toString() ?? '');
    _selectedStatus = widget.task['status']?.toString().toLowerCase();

    // إذا كانت الحالة الحالية ليست ضمن الحالات المسموح بتغييرها إليها من قبل العميل،
    // قد نعرضها كقيمة ابتدائية ولكن لا نسمح بتغييرها أو نجبره على اختيار من المسموح.
    // للتبسيط، سنسمح بعرضها، والـ Dropdown سيعرض فقط الخيارات المسموحة.
    // إذا كانت الحالة الحالية مثلاً 'pending' أو 'approved'، ولا يمكن للعميل اختيارها مجدداً،
    // يجب على الـ Dropdown أن يعرض الخيارات الجديدة فقط.
  }

  @override
  void dispose() {
    _descriptionController.dispose();
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

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage("Please fill all required fields correctly.", isError: true);
      return;
    }
    if (_selectedStatus == null || _selectedStatus!.isEmpty) {
      _showMessage("Please select a status for the task.", isError: true);
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = true);

    final token = await widget.storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      _showMessage("Authentication error. Please log in again.", isError: true);
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final body = {
      "description": _descriptionController.text,
      "status": _selectedStatus, // سيتم إرسال الحالة المختارة
    };
    // body.removeWhere((key, value) => value == null || value.toString().isEmpty); // ليس ضرورياً هنا لأننا نتحقق من _selectedStatus

    final url = Uri.parse("${widget.baseUrl}/api/client/tasks/${widget.task['id']}");
    print("--- Updating Task: $url with body: ${json.encode(body)} ---");

    try {
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (!mounted) return;
      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && responseData['success'] == true) {
        _showMessage(responseData['message'] ?? "Task updated successfully!", isSuccess: true);
        Navigator.pop(context, true); 
      } else {
        throw Exception(responseData['message'] ?? "Failed to update task (${response.statusCode})");
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


  @override
  Widget build(BuildContext context) {
    // قائمة الخيارات التي ستظهر في الـ Dropdown
    // هي فقط الحالات المسموح للعميل بتحديثها
    List<String> dropdownStatusOptions = List.from(_clientAllowedStatusUpdates);

    // الحالة الحالية للمهمة
    String currentTaskStatus = widget.task['status']?.toString().toLowerCase() ?? 'unknown';

    // إذا كانت الحالة الحالية للمهمة ليست ضمن الخيارات المسموح بتحديثها إليها
    // (مثلاً، إذا كانت المهمة 'pending' أو 'approved' وتريد أن يختار العميل 'in progress' أو 'cancelled' فقط)،
    // يجب أن يكون _selectedStatus مضبوطًا بشكل مناسب.
    // إذا كانت الحالة الحالية ضمن الخيارات المسموحة (مثلاً in progress وتريد أن يغيرها إلى cancelled أو تبقى in progress)
    // فإن _selectedStatus سيعمل كقيمة ابتدائية.
    
    // التأكد من أن _selectedStatus هو أحد الخيارات المعروضة أو null إذا كانت الحالة الحالية غير مسموح باختيارها
    if (_selectedStatus != null && !dropdownStatusOptions.contains(_selectedStatus!)) {
      // إذا كانت الحالة الحالية مثلاً 'pending' وتريد أن يختار العميل فقط من 'in progress' أو 'cancelled',
      // يمكنك تعيين _selectedStatus إلى null أو أول عنصر في dropdownStatusOptions
      // _selectedStatus = null; // أو
      // _selectedStatus = dropdownStatusOptions.isNotEmpty ? dropdownStatusOptions.first : null;
      // لكن إذا كنت تريد عرض الحالة الحالية دائماً إذا لم يتم تغييرها، فهذا السلوك جيد
    }


    // لا تسمح بتغيير الحالة إذا كانت المهمة مكتملة، مرفوضة، أو ملغاة بالفعل
    bool canChangeStatus = currentTaskStatus != 'completed' && 
                           currentTaskStatus != 'rejected' &&
                           currentTaskStatus != 'cancelled';


    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Update Task #${widget.task['id']}', style: GoogleFonts.lato(color: _appBarItemColor, fontWeight: FontWeight.bold)),
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
              FadeInDown(delay: const Duration(milliseconds: 100), child: Text("Modify Task Details", style: GoogleFonts.lato(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryTextColor))),
              const SizedBox(height: 20),

              _buildTextField(_descriptionController, "Description*", FontAwesomeIcons.fileLines, TextInputType.multiline, "Update the task description...", maxLines: 3, delay: 200, validator: (v) => (v == null || v.isEmpty) ? "Description is required." : null),
              
              const SizedBox(height: 15),
              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9.0),
                  child: DropdownButtonFormField<String>(
                    decoration: _customInputDecoration("Status*", FontAwesomeIcons.sliders, hint: "Select task status"),
                    value: (_selectedStatus != null && dropdownStatusOptions.contains(_selectedStatus)) ? _selectedStatus : null, // تأكد أن القيمة المختارة ضمن الخيارات
                    // عرض الخيارات المسموحة فقط
                    items: dropdownStatusOptions.map((String value) { 
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value.capitalizeFirst(), style: GoogleFonts.lato(color: _primaryTextColor, fontSize: 15)),
                      );
                    }).toList(),
                    onChanged: canChangeStatus // اسمح بالتغيير فقط إذا كانت الحالة الحالية تسمح بذلك
                        ? (newValue) {
                            setState(() {
                              _selectedStatus = newValue;
                            });
                          }
                        : null, // تعطيل الـ Dropdown إذا كانت الحالة لا يمكن تغييرها
                    validator: (value) {
                      if (!canChangeStatus && value == currentTaskStatus) return null; // إذا لم يتم تغيير الحالة وهي غير قابلة للتغيير، فلا مشكلة
                      if (value == null) return 'Please select a status';
                      return null;
                    },
                    hint: canChangeStatus ? null : Text(currentTaskStatus.capitalizeFirst(), style: GoogleFonts.lato(color: _secondaryTextColor, fontSize: 15)), // عرض الحالة الحالية إذا كانت غير قابلة للتغيير
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: _buttonColor))
                    : ElevatedButton.icon(
                        icon: const Icon(FontAwesomeIcons.floppyDisk, color: Colors.white, size: 18),
                        label: Text('Save Changes', style: GoogleFonts.lato(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                        onPressed: (!canChangeStatus && _descriptionController.text == (widget.task['description']?.toString() ?? ''))
                          ? null // عطّل الزر إذا لم يتم تغيير أي شيء وكانت الحالة غير قابلة للتغيير
                          : _submitUpdate,
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

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, TextInputType inputType, String hint, {int maxLines = 1, required int delay, String? Function(String?)? validator}) {
    return FadeInUp(
      delay: Duration(milliseconds: delay),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9.0),
        child: TextFormField(
          controller: controller,
          decoration: _customInputDecoration(label, icon, hint: hint),
          keyboardType: inputType,
          maxLines: maxLines,
          style: GoogleFonts.lato(color: _primaryTextColor, fontSize: 15),
          validator: validator ?? ((v) => (v == null || v.isEmpty) ? "${label.replaceAll('*', '').trim()} is required." : null),
          textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
        ),
      ),
    );
  }
}