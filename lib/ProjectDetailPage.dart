// project_detail_page.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

// قم بإلغاء التعليق إذا كنت تحتاج لإعادة التوجيه لصفحة تسجيل الدخول عند خطأ المصادقة
// import 'login_screen.dart'; 

class ProjectDetailPage extends StatefulWidget {
  final String projectId;
  final String? initialProjectName;
  final String teamId;
  final String companyId;
  final String companyName; 

  const ProjectDetailPage({
    super.key,
    required this.projectId,
    this.initialProjectName,
    required this.teamId,
    required this.companyId,
    required this.companyName,
  });

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> with TickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  final String _baseDomain = Platform.isAndroid ? "http://10.0.2.2:3000" : "http://localhost:3000";
  
  late final String _projectDetailApiUrl;
  late final String _updateProjectApiUrl;
  late final String _addMilestoneApiUrl;

  Map<String, dynamic>? _projectData;
  List<dynamic> _milestones = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessingAction = false;

  // For Update Project Modal
  final _updateProjectFormKey = GlobalKey<FormState>();
  final TextEditingController _updateProjectNameController = TextEditingController();
  final TextEditingController _updateProjectEndDateController = TextEditingController();
  final TextEditingController _updateInitialPriceController = TextEditingController();
  final TextEditingController _updateMaxPriceController = TextEditingController();
  final TextEditingController _updateInitialTimeController = TextEditingController();
  final TextEditingController _updateFinalTimeController = TextEditingController();
  final TextEditingController _updateActualPriceController = TextEditingController();
  final TextEditingController _updateActualTimeController = TextEditingController();


  // For Add/Update Milestone Modal
  final _milestoneFormKey = GlobalKey<FormState>();
  final TextEditingController _milestoneNameController = TextEditingController();
  final TextEditingController _milestoneDescriptionController = TextEditingController();
  final TextEditingController _milestoneDueDateController = TextEditingController();
  bool _milestoneIsCompletedForForm = false;
  String? _editingMilestoneId;

  bool _isMilestoneDeleteMode = false;
  final Set<String> _selectedMilestoneIds = {};

  // UI Colors
  final Color _appBarBackgroundColor1 = const Color(0xFFa3b29f).withOpacity(0.9);
  final Color _appBarBackgroundColor2 = const Color(0xFF697C6B).withOpacity(0.98);
  final Color _pageBackgroundColor1 = const Color(0xFFE9F0EA); 
  final Color _pageBackgroundColor2 = const Color(0xFFB4CCB2); 
  final Color _appBarTextColor = Colors.white;
  final Color _fabColor = const Color(0xFF4A5D52); 
  final Color _cardColor = Colors.white.withOpacity(0.97); 
  final Color _cardTextColor = const Color(0xFF33475B); 
  final Color _cardSecondaryTextColor = Colors.grey.shade700;
  final Color _headerTextColor = const Color(0xFF4A5D52);
  final Color _milestoneCardDefaultBg = Colors.blueGrey.shade50.withOpacity(0.85);
  final Color _milestoneCardCompletedBg = Colors.green.shade50.withOpacity(0.85);


  @override
  void initState() {
    super.initState();
    _projectDetailApiUrl = "$_baseDomain/api/owner/projects/${widget.projectId}";
    _updateProjectApiUrl = "$_baseDomain/api/owner/projects/${widget.projectId}";
    _addMilestoneApiUrl = "$_baseDomain/api/milestones"; 
    _loadProjectDetails();
  }

  @override
  void dispose() {
    _updateProjectNameController.dispose();
    _updateProjectEndDateController.dispose();
    _updateInitialPriceController.dispose();
    _updateMaxPriceController.dispose();
    _updateInitialTimeController.dispose();
    _updateFinalTimeController.dispose();
    _updateActualPriceController.dispose();
    _updateActualTimeController.dispose();
    _milestoneNameController.dispose();
    _milestoneDescriptionController.dispose();
    _milestoneDueDateController.dispose();
    super.dispose();
  }

  Future<void> _handleAuthError({String message = 'Session expired. Please log in again.'}) async {
    if (!mounted) return;
    _showMessage(message, isError: true);
    await _storage.deleteAll();
    // if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false);
  }

  void _showMessage(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.lato(color: Colors.white)),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : (isSuccess ? Colors.green.shade600 : Colors.teal.shade700),
      duration: const Duration(seconds: 3), behavior: SnackBarBehavior.floating, elevation: 6.0, margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _loadProjectDetails({bool showLoadingIndicator = true}) async {
    if (showLoadingIndicator && mounted) setState(() { _isLoading = true; _errorMessage = null; });
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) { 
      if (mounted) setState(() { _isLoading = false; _errorMessage = "Authentication token missing."; }); 
      _handleAuthError(message: "Authentication token missing. Please log in again.");
      return; 
    }
    
    print("--- ProjectDetailPage: Fetching project details from $_projectDetailApiUrl ---");
    try {
      final response = await http.get(Uri.parse(_projectDetailApiUrl), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && data['success'] == true && data['project'] != null) {
        if (mounted) {
          setState(() {
          _projectData = data['project'] as Map<String, dynamic>;
          _milestones = _projectData?['milestones'] as List<dynamic>? ?? [];
          _isLoading = false; _errorMessage = null;
        });
        }
      } else { 
        if (response.statusCode == 401) _handleAuthError();
        final String apiMessage = data['message']?.toString() ?? 'Failed to load project details';
        throw Exception('$apiMessage (${response.statusCode})');
      }
    } catch (e) {
      print("!!! ProjectDetailPage: LoadProjectDetails Exception: $e");
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString().replaceFirst("Exception: ", ""); });
    }
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller, {DateTime? initialDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.tryParse(controller.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: _fabColor, onPrimary: Colors.white),
            textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: _fabColor)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  String _formatDisplayDate(String? dateString, {String format = 'dd MMM yyyy'}) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try { return DateFormat(format).format(DateTime.parse(dateString).toLocal()); }
    catch (_) { 
      try {
        return DateFormat(format).format(DateFormat("yyyy-MM-ddTHH:mm:ss.SSS'Z'").parse(dateString, true).toLocal());
      } catch (e) {
        return dateString.split('T')[0]; 
      }
    } 
  }

  Widget _buildInfoRow(IconData icon, String label, String? value, {Color? iconColor, Color? labelColor, Color? valueColor, bool isMonospace = false}) {
    if (value == null || value.isEmpty || value.trim().toLowerCase() == "n/a" || value.trim().toLowerCase() == "null") {
        if ((label == "Actual Price" || label == "Actual Time") && value == "0") {
            // لا تفعل شيئًا، اسمح بعرض الصفر لهذه الحقول
        } else if (label == "Initial Time" && value == "00:00") { // اسمح بعرض 00:00 للوقت
        } else if (label == "Final Time" && value == "00:00") {
        } else if (label == "Actual Time" && value == "00:00") {
        }
        else {
            return const SizedBox.shrink();
        }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 19, color: iconColor ?? _fabColor.withOpacity(0.7)), const SizedBox(width: 10),
          Text("$label: ", style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w600, color: labelColor ?? _cardTextColor.withOpacity(0.9))),
         Expanded(
            child: Text(
              value!,
              style: GoogleFonts.lato(
                fontSize: 15,
                color: valueColor ?? _cardTextColor.withOpacity(0.75),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ]),
    );
  }
  
  String _formatSecondsToHHMM(dynamic secondsValue) {
    if (secondsValue == null) return 'N/A';
    int? totalSeconds = int.tryParse(secondsValue.toString());
    if (totalSeconds == null || totalSeconds < 0) return 'N/A'; // إذا كانت القيمة 0 بالضبط، لا يزال من الممكن أن تكون "N/A" إذا كان هذا هو السلوك المرغوب لعدم التعيين
    if (totalSeconds == 0 && secondsValue.toString() != "0") return 'N/A'; // إذا كانت القيمة الأصلية ليست "0" ولكن التحويل أدى لـ 0 ثواني بسبب قيمة غير صالحة مثل "N/A"
    
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}";
  }

  int? _parseHHMMToSeconds(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty || hhmm.trim().toLowerCase() == 'n/a') return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null; 
    
    final int? hours = int.tryParse(parts[0]);
    final int? minutes = int.tryParse(parts[1]);
    
    if (hours == null || minutes == null || hours < 0 || minutes < 0 || minutes >= 60) return null; 
    
    return (hours * 3600) + (minutes * 60);
  }

  String? _validateHHMMFormat(String? value) {
    if (value == null || value.isEmpty || value.trim().toLowerCase() == 'n/a') return null; 
    final parts = value.split(':');
    if (parts.length != 2) return 'Use HH:MM format (e.g., 02:30)';
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || m < 0 || m >= 60) return 'Invalid HH:MM values';
    return null;
  }

  void _showUpdateProjectDialog() {
    if (_projectData == null) return;
    _updateProjectNameController.text = _projectData!['name'] ?? '';
    _updateProjectEndDateController.text = _projectData!['end_date'] != null ? _projectData!['end_date'].toString().split('T')[0] : ''; 
    
    bool isInitialPriceReadOnly = _projectData!['initial_price'] != null && _projectData!['initial_price'].toString().isNotEmpty && _projectData!['initial_price'].toString() != '0';
    _updateInitialPriceController.text = _projectData!['initial_price']?.toString() ?? '';

    bool isMaxPriceReadOnly = _projectData!['max_price'] != null && _projectData!['max_price'].toString().isNotEmpty && _projectData!['max_price'].toString() != '0';
    _updateMaxPriceController.text = _projectData!['max_price']?.toString() ?? '';
    
    bool isActualPriceReadOnly = _projectData!['actual_price'] != null && _projectData!['actual_price'].toString().isNotEmpty && _projectData!['actual_price'].toString() != '0';
    _updateActualPriceController.text = _projectData!['actual_price']?.toString() ?? '';

    bool isInitialTimeReadOnly = _projectData!['Initial_time_s'] != null && _projectData!['Initial_time_s'].toString().isNotEmpty && _projectData!['Initial_time_s'].toString() != '0';
    _updateInitialTimeController.text = _formatSecondsToHHMM(_projectData!['Initial_time_s']);

    bool isFinalTimeReadOnly = _projectData!['final_time_s'] != null && _projectData!['final_time_s'].toString().isNotEmpty && _projectData!['final_time_s'].toString() != '0';
    _updateFinalTimeController.text = _formatSecondsToHHMM(_projectData!['final_time_s']);

    bool isActualTimeReadOnly = _projectData!['actual_time'] != null && _projectData!['actual_time'].toString().isNotEmpty && _projectData!['actual_time'].toString() != '0';
    _updateActualTimeController.text = _formatSecondsToHHMM(_projectData!['actual_time']);


    showDialog(
      context: context, barrierDismissible: !_isProcessingAction,
      builder: (BuildContext dialogContext) {
        bool isDialogProcessing = false;
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text("Update Project", style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: _fabColor)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            backgroundColor: _pageBackgroundColor1,
            content: SingleChildScrollView(
              child: Form(
                key: _updateProjectFormKey,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TextFormField(controller: _updateProjectNameController, decoration: _customInputDecoration("Project Name *", Icons.title_rounded), validator: (v)=>(v==null||v.isEmpty)?'Required':null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _updateProjectEndDateController, decoration: _customInputDecoration("New End Date (YYYY-MM-DD) *", Icons.calendar_today_rounded), readOnly: true, onTap: () => _selectDate(dialogContext, _updateProjectEndDateController, initialDate: DateTime.tryParse(_projectData!['end_date']?.toString().split('T')[0] ?? '')), validator: (v)=>(v==null||v.isEmpty)?'Required':null),
                  const SizedBox(height: 12),
                  _buildDividerWithLabel("Price Updates"),
                  TextFormField(controller: _updateInitialPriceController, decoration: _customInputDecoration("Initial Price", Icons.attach_money_rounded, isReadOnly: isInitialPriceReadOnly), keyboardType: TextInputType.number, readOnly: isInitialPriceReadOnly),
                  const SizedBox(height: 12),
                  TextFormField(controller: _updateMaxPriceController, decoration: _customInputDecoration("Max Price", Icons.money_off_csred_rounded, isReadOnly: isMaxPriceReadOnly), keyboardType: TextInputType.number, readOnly: isMaxPriceReadOnly),
                  const SizedBox(height: 12),
                  _buildDividerWithLabel("Time Updates (HH:MM)"),
                  TextFormField(controller: _updateInitialTimeController, decoration: _customInputDecoration("Initial Time (HH:MM)", Icons.hourglass_top_rounded, isReadOnly: isInitialTimeReadOnly), keyboardType: TextInputType.datetime, validator: _validateHHMMFormat, readOnly: isInitialTimeReadOnly),
                  const SizedBox(height: 12),
                  TextFormField(controller: _updateFinalTimeController, decoration: _customInputDecoration("Final Time (HH:MM)", Icons.hourglass_bottom_rounded, isReadOnly: isFinalTimeReadOnly), keyboardType: TextInputType.datetime, validator: _validateHHMMFormat, readOnly: isFinalTimeReadOnly),
                  const SizedBox(height: 12),
                  _buildDividerWithLabel("Actuals"),
                  TextFormField(controller: _updateActualPriceController, decoration: _customInputDecoration("Actual Price", Icons.payments_rounded, isReadOnly: isActualPriceReadOnly), keyboardType: TextInputType.number, readOnly: isActualPriceReadOnly),
                  const SizedBox(height: 12),
                  TextFormField(controller: _updateActualTimeController, decoration: _customInputDecoration("Actual Time (HH:MM)", Icons.timer_rounded, isReadOnly: isActualTimeReadOnly), keyboardType: TextInputType.datetime, validator: _validateHHMMFormat, readOnly: isActualTimeReadOnly),
                ]),
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: const EdgeInsets.only(bottom: 15, left: 15, right: 15),
            actions: [
              TextButton(child: Text("Cancel", style: GoogleFonts.lato(color: Colors.grey.shade700, fontWeight: FontWeight.w600)), onPressed: isDialogProcessing ? null : () => Navigator.of(dialogContext).pop()),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                icon: isDialogProcessing ? const SizedBox(height:18, width:18, child: CircularProgressIndicator(strokeWidth:2, color: Colors.white)) : const Icon(Icons.save_as_rounded, color: Colors.white, size: 20),
                label: Text(isDialogProcessing ? "Saving..." : "Save Changes", style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: isDialogProcessing ? null : () async {
                  if(_updateProjectFormKey.currentState!.validate()){
                    setDialogState(()=> isDialogProcessing = true);
                    await _updateProject(
                      isInitialPriceReadOnly: isInitialPriceReadOnly,
                      isMaxPriceReadOnly: isMaxPriceReadOnly,
                      isInitialTimeReadOnly: isInitialTimeReadOnly,
                      isFinalTimeReadOnly: isFinalTimeReadOnly,
                      isActualPriceReadOnly: isActualPriceReadOnly,
                      isActualTimeReadOnly: isActualTimeReadOnly,
                    );
                    if(mounted && isDialogProcessing) setDialogState(()=> isDialogProcessing = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _fabColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              ),
            ],
          );
        });
      }
    ).then((_){ if(mounted && _isProcessingAction) setState(()=> _isProcessingAction = false);});
  }

  Widget _buildDividerWithLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(children: <Widget>[
        Expanded(child: Divider(color: _fabColor.withOpacity(0.3))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(label, style: GoogleFonts.lato(color: _fabColor, fontWeight: FontWeight.w500, fontSize: 13)),
        ),
        Expanded(child: Divider(color: _fabColor.withOpacity(0.3))),
      ]),
    );
  }

  InputDecoration _customInputDecoration(String labelText, IconData prefixIcon, {bool isReadOnly = false}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: GoogleFonts.lato(color: _fabColor.withOpacity(0.9)),
      prefixIcon: Icon(prefixIcon, color: _fabColor.withOpacity(0.7), size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _fabColor.withOpacity(0.5))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _fabColor.withOpacity(0.5))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _fabColor, width: 1.5)),
      filled: true,
      fillColor: isReadOnly ? Colors.grey.shade300.withOpacity(0.5) : Colors.white.withOpacity(0.8),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    );
  }

  Future<void> _updateProject({
    required bool isInitialPriceReadOnly,
    required bool isMaxPriceReadOnly,
    required bool isInitialTimeReadOnly,
    required bool isFinalTimeReadOnly,
    required bool isActualPriceReadOnly,
    required bool isActualTimeReadOnly,
  }) async {
    setState(() => _isProcessingAction = true);
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) { _showMessage("Auth token missing", isError: true); if(mounted) setState(()=>_isProcessingAction=false); return;}

    Map<String, dynamic> payload = {
      "name": _updateProjectNameController.text.trim(),
      "end_date": _updateProjectEndDateController.text.trim(),
    };

    if(!isInitialPriceReadOnly && _updateInitialPriceController.text.trim().isNotEmpty) payload["initial_price"] = num.tryParse(_updateInitialPriceController.text.trim());
    if(!isMaxPriceReadOnly && _updateMaxPriceController.text.trim().isNotEmpty) payload["max_price"] = num.tryParse(_updateMaxPriceController.text.trim());
    if(!isActualPriceReadOnly && _updateActualPriceController.text.trim().isNotEmpty) payload["actual_price"] = num.tryParse(_updateActualPriceController.text.trim());

    if(!isInitialTimeReadOnly && _updateInitialTimeController.text.trim().isNotEmpty && _updateInitialTimeController.text.trim().toLowerCase() != 'n/a') {
        int? initialTimeSeconds = _parseHHMMToSeconds(_updateInitialTimeController.text.trim());
        if (initialTimeSeconds != null) payload["Initial_time_s"] = initialTimeSeconds;
    }
    if(!isFinalTimeReadOnly && _updateFinalTimeController.text.trim().isNotEmpty && _updateFinalTimeController.text.trim().toLowerCase() != 'n/a') {
        int? finalTimeSeconds = _parseHHMMToSeconds(_updateFinalTimeController.text.trim());
        if (finalTimeSeconds != null) payload["final_time_s"] = finalTimeSeconds;
    }
    if(!isActualTimeReadOnly && _updateActualTimeController.text.trim().isNotEmpty && _updateActualTimeController.text.trim().toLowerCase() != 'n/a') {
        int? actualTimeSeconds = _parseHHMMToSeconds(_updateActualTimeController.text.trim());
        if (actualTimeSeconds != null) payload["actual_time"] = actualTimeSeconds;
    }
    
    payload.removeWhere((key, value) => value == null && key != "name" && key != "end_date");

    print("--- Updating project $_updateProjectApiUrl with payload: $payload ---");
    try {
      final response = await http.put(Uri.parse(_updateProjectApiUrl), headers: {'Authorization': 'Bearer $token', 'Content-Type':'application/json; charset=UTF-8'}, body: json.encode(payload));
      if(!mounted) return;
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      if(response.statusCode == 200 && responseData['success'] == true){
        _showMessage("Project updated successfully!", isSuccess: true);
        if(Navigator.canPop(context)) Navigator.pop(context); 
        _loadProjectDetails(showLoadingIndicator: false);
      } else {
        if (response.statusCode == 401) _handleAuthError();
        _showMessage(responseData['message'] ?? "Failed to update project (${response.statusCode})", isError: true);
      }
    } catch(e){
      _showMessage("Error updating project: $e", isError: true);
    } finally {
      if(mounted) setState(() => _isProcessingAction = false);
    }
  }

  void _showMilestoneFormDialog({Map<String, dynamic>? milestoneToUpdate}) {
    _editingMilestoneId = milestoneToUpdate?['id']?.toString();
    _milestoneNameController.text = milestoneToUpdate?['name'] ?? '';
    _milestoneDescriptionController.text = milestoneToUpdate?['description'] ?? '';
    _milestoneDueDateController.text = milestoneToUpdate?['due_date'] != null ? milestoneToUpdate!['due_date'].toString().split('T')[0] : '';
    _milestoneIsCompletedForForm = milestoneToUpdate?['completed'] == 1 || milestoneToUpdate?['completed'] == true;

    bool isDialogProcessing = false;

    showDialog(
      context: context, barrierDismissible: !isDialogProcessing,
      builder: (BuildContext dialogContext){
        return StatefulBuilder(builder: (context, setDialogState){
          return AlertDialog(
            title: Text(_editingMilestoneId == null ? "Add Milestone" : "Update Milestone", style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: _fabColor)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            backgroundColor: _cardColor,
            content: SingleChildScrollView(child: Form(key: _milestoneFormKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: _milestoneNameController, decoration: InputDecoration(labelText: "Milestone Name *", prefixIcon: Icon(Icons.flag_outlined, color: _fabColor.withOpacity(0.7))), validator: (v)=>(v==null||v.isEmpty)?'Required':null),
              const SizedBox(height:10),
              TextFormField(controller: _milestoneDescriptionController, decoration: InputDecoration(labelText: "Description *", prefixIcon: Icon(Icons.notes_rounded, color: _fabColor.withOpacity(0.7))), maxLines: 2, validator: (v)=>(v==null||v.isEmpty)?'Required':null),
              const SizedBox(height:10),
              TextFormField(controller: _milestoneDueDateController, decoration: InputDecoration(labelText: "Due Date (YYYY-MM-DD) *", prefixIcon: Icon(Icons.date_range_rounded, color: _fabColor.withOpacity(0.7))), readOnly: true, onTap: ()=>_selectDate(dialogContext, _milestoneDueDateController, initialDate: DateTime.tryParse(milestoneToUpdate?['due_date']?.toString().split('T')[0]??'')), validator: (v)=>(v==null||v.isEmpty)?'Required':null),
              if(_editingMilestoneId != null)
                SwitchListTile(
                  title: Text("Completed", style: GoogleFonts.lato(color: _cardTextColor)),
                  value: _milestoneIsCompletedForForm,
                  onChanged: (bool? value) { setDialogState(() => _milestoneIsCompletedForForm = value ?? false); },
                  activeColor: _fabColor,
                  contentPadding: EdgeInsets.zero,
                ),
            ]))),
            actions: [
              TextButton(child: Text("Cancel", style: GoogleFonts.lato(color: Colors.grey.shade700)), onPressed: isDialogProcessing ? null : ()=>Navigator.of(dialogContext).pop()),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _fabColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: isDialogProcessing ? null : () async {
                  if(_milestoneFormKey.currentState!.validate()){
                    setDialogState(()=> isDialogProcessing = true);
                    if(_editingMilestoneId == null) await _addMilestone(setDialogState);
                    else await _updateMilestone(setDialogState);
                  }
                },
                child: Text(isDialogProcessing ? "Saving..." : (_editingMilestoneId==null ? "Add" : "Update"), style: GoogleFonts.lato(fontWeight: FontWeight.bold))
              )
            ],
          );
        });
      }
    ).then((_){ if(mounted && _isProcessingAction) setState(()=> _isProcessingAction = false);});
  }

  Future<void> _addMilestone(StateSetter setDialogState) async {
    setState(() => _isProcessingAction = true); 
    final token = await _storage.read(key: 'auth_token');
    Map<String, dynamic> payload = {
      "project_id": int.tryParse(widget.projectId),
      "name": _milestoneNameController.text.trim(),
      "description": _milestoneDescriptionController.text.trim(),
      "due_date": _milestoneDueDateController.text.trim(),
    };
    try {
      final response = await http.post(Uri.parse(_addMilestoneApiUrl), headers: {'Authorization':'Bearer $token', 'Content-Type':'application/json; charset=UTF-8'}, body: json.encode(payload));
      if(!mounted) return;
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      if(response.statusCode == 201){
        _showMessage(responseData['message'] ?? "Milestone added successfully!", isSuccess: true);
        if(Navigator.canPop(context)) Navigator.pop(context);
        _loadProjectDetails(showLoadingIndicator: false);
      } else {
        if (response.statusCode == 401) _handleAuthError();
        _showMessage(responseData['message'] ?? "Failed to add milestone (${response.statusCode})", isError: true);
      }
    } catch(e){ _showMessage("Error adding milestone: $e", isError: true); }
    finally{ if(mounted) setDialogState(()=> _isProcessingAction = false); } 
  }
  
  Future<void> _updateMilestone(StateSetter setDialogState) async {
    setState(() => _isProcessingAction = true);
    final token = await _storage.read(key: 'auth_token');
    Map<String, dynamic> payload = {
      "name": _milestoneNameController.text.trim(),
      "description": _milestoneDescriptionController.text.trim(),
      "due_date": _milestoneDueDateController.text.trim(),
      "completed": _milestoneIsCompletedForForm ? 1 : 0,
    };
    if(_milestoneIsCompletedForForm) {
         payload["completion_date"] = DateFormat('yyyy-MM-ddTHH:mm:ss').format(DateTime.now().toUtc()) + '.000Z';
    } else {
      payload["completion_date"] = null; 
    }
    payload.removeWhere((key, value) => value == null && key != "completion_date");


    final String updateUrl = "$_baseDomain/api/milestones/${_editingMilestoneId!}";
    print("--- Updating milestone $updateUrl with payload: $payload");
    try {
      final response = await http.put(Uri.parse(updateUrl), headers: {'Authorization':'Bearer $token', 'Content-Type':'application/json; charset=UTF-8'}, body: json.encode(payload));
      if(!mounted) return;
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      if(response.statusCode == 200 && responseData['success'] == true){
        _showMessage(responseData['message'] ?? "Milestone updated successfully!", isSuccess: true);
        if(Navigator.canPop(context)) Navigator.pop(context);
        _loadProjectDetails(showLoadingIndicator: false);
      } else {
        if (response.statusCode == 401) _handleAuthError();
        _showMessage(responseData['message'] ?? "Failed to update milestone (${response.statusCode})", isError: true);
      }
    } catch(e){ _showMessage("Error updating milestone: $e", isError: true); }
    finally{ if(mounted) setDialogState(()=> _isProcessingAction = false); }
  }

  void _toggleMilestoneDeleteMode() { setState(() { _isMilestoneDeleteMode = !_isMilestoneDeleteMode; if(!_isMilestoneDeleteMode) _selectedMilestoneIds.clear(); }); }

  Future<void> _deleteSelectedMilestones() async {
    if (_selectedMilestoneIds.isEmpty) { _showMessage("No milestones selected for deletion.", isError:true); return; }
    final bool? confirm = await showDialog<bool>(context: context, builder: (ctx)=>AlertDialog(title: Text("Confirm Delete"), content: Text("Are you sure you want to delete ${_selectedMilestoneIds.length} selected milestone(s)?"), actions: [TextButton(child:Text("Cancel"), onPressed:()=>Navigator.pop(ctx,false)), TextButton(child:Text("Delete", style: TextStyle(color: Theme.of(context).colorScheme.error)), onPressed:()=>Navigator.pop(ctx,true))]));
    if(confirm != true || !mounted) return;

    setState(()=> _isProcessingAction = true);
    final token = await _storage.read(key: 'auth_token');
    int successCount = 0;
    List<String> errorMessages = [];
    for(String idStr in _selectedMilestoneIds){
      if(!mounted) break;
      try{
        final response = await http.delete(Uri.parse("$_baseDomain/api/milestones/$idStr"), headers: {'Authorization':'Bearer $token'});
        if(response.statusCode == 200 || response.statusCode == 204) { 
            successCount++;
        } else {
            if (response.statusCode == 401) { _handleAuthError(); break; }
            final rBody = jsonDecode(utf8.decode(response.bodyBytes));
            errorMessages.add("ID $idStr: ${rBody['message'] ?? response.statusCode}");
        }
      } catch(e) { errorMessages.add("ID $idStr error: $e");}
    }
    if(!mounted) return;
    if(successCount > 0) _showMessage("$successCount milestone(s) deleted.", isSuccess: true);
    if(errorMessages.isNotEmpty) _showMessage("Some deletions failed: ${errorMessages.join('; ')}", isError: true);
    
    setState(() { _isProcessingAction = false; _isMilestoneDeleteMode = false; _selectedMilestoneIds.clear(); });
    _loadProjectDetails(showLoadingIndicator: false);
  }

  Future<void> _toggleMilestoneCompletion(Map<String, dynamic> milestone) async {
    if (!mounted) return;
    setState(() => _isProcessingAction = true);

    final token = await _storage.read(key: 'auth_token');
    final String milestoneId = milestone['id'].toString();
    final bool currentCompletedStatus = milestone['completed'] == 1 || milestone['completed'] == true;
    final Map<String, dynamic> payload = {
      "completed": currentCompletedStatus ? 0 : 1,
      "name": milestone['name'], 
      "description": milestone['description'],
      "due_date": milestone['due_date']?.toString().split('T')[0],
    };
    if (payload["completed"] == 1) {
      payload["completion_date"] = DateFormat('yyyy-MM-ddTHH:mm:ss').format(DateTime.now().toUtc()) + '.000Z';
    } else {
      payload["completion_date"] = null; 
    }
    payload.removeWhere((key, value) => value == null && key != "completion_date");


    final String updateUrl = "$_baseDomain/api/milestones/$milestoneId";
    print("--- Toggling milestone $milestoneId completion to ${payload['completed']} --- Payload: $payload");

    try {
      final response = await http.put(Uri.parse(updateUrl), headers: {'Authorization':'Bearer $token', 'Content-Type':'application/json; charset=UTF-8'}, body: json.encode(payload));
      if(!mounted) return;
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      if(response.statusCode == 200 && responseData['success'] == true){
        _showMessage(responseData['message'] ?? "Milestone status updated!", isSuccess: true);
        _loadProjectDetails(showLoadingIndicator: false);
      } else {
        if (response.statusCode == 401) _handleAuthError();
        _showMessage(responseData['message'] ?? "Failed to update milestone status (${response.statusCode})", isError: true);
      }
    } catch(e){ 
      print("Error toggling milestone completion: $e");
      _showMessage("Error updating status: $e", isError: true); 
    } finally {
      if(mounted) setState(() => _isProcessingAction = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    String displayProjectName = _isLoading ? (widget.initialProjectName ?? "Loading Project...") : (_projectData?['name']?.toString() ?? "Project Details");

    return Scaffold(
      appBar: AppBar(
        title: Text(displayProjectName, style: GoogleFonts.lato(color: _appBarTextColor, fontWeight: FontWeight.bold, fontSize: 20), overflow: TextOverflow.ellipsis),
        flexibleSpace: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [_appBarBackgroundColor1, _appBarBackgroundColor2], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        elevation: 2, iconTheme: IconThemeData(color: _appBarTextColor),
        actions: [
          if(!_isLoading && _projectData != null)
            IconButton(icon: Icon(Icons.edit_note_rounded, color: _appBarTextColor), onPressed: _isProcessingAction ? null : _showUpdateProjectDialog, tooltip: "Update Project Details"),
          IconButton(icon: Icon(Icons.refresh_rounded, color: _appBarTextColor), onPressed: _isLoading || _isProcessingAction ? null : _loadProjectDetails, tooltip: "Refresh Details"),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [_pageBackgroundColor1, _pageBackgroundColor2.withOpacity(0.85), _pageBackgroundColor2], begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.0, 0.35, 1.0])),
        child: SafeArea(
          child: _isLoading 
            ? Center(child: CircularProgressIndicator(color: _appBarTextColor.withOpacity(0.8)))
            : _errorMessage != null && _projectData == null 
                ? _buildErrorWidget(_headerTextColor) 
                : _projectData == null 
                    ? Center(child: Text("No project data found.", style: GoogleFonts.lato(fontSize: 18, color: _headerTextColor.withOpacity(0.7))))
                    : Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildProjectInfoCard(),
                                  const SizedBox(height: 24),
                                  _buildMilestonesSection(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading || _projectData == null || _isProcessingAction ? null : () => _showMilestoneFormDialog(),
        label: Text("Add Milestone", style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: Colors.white)),
        icon: const Icon(Icons.add_task_rounded, color: Colors.white),
        backgroundColor: _fabColor,
        elevation: 8,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildProjectInfoCard() {
    if (_projectData == null) return const SizedBox.shrink();
    String? companyName = _projectData!['company_name']?.toString();
    String? teamName = _projectData!['team_name']?.toString();
    String? clientName = _projectData!['client_name']?.toString();
    String? clientEmail = _projectData!['client_email']?.toString();

    return FadeInDown(
      duration: const Duration(milliseconds: 400),
      child: Card(
        elevation: 6, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), color: _cardColor,
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_projectData!['name'] ?? 'Project Name', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: _cardTextColor)),
              const SizedBox(height: 10),
              Divider(color: Colors.grey.shade300),
              const SizedBox(height: 10),
              Text(_projectData!['description'] ?? 'No description.', style: GoogleFonts.lato(fontSize: 15.5, color: _cardTextColor.withOpacity(0.8), height: 1.4)),
              const SizedBox(height: 18),
              if(companyName != null) _buildInfoRow(Icons.business_rounded, "Company", companyName, iconColor: Colors.blueGrey),
              if(teamName != null) _buildInfoRow(Icons.groups_2_rounded, "Team", teamName, iconColor: Colors.orange.shade700),
              if(clientName != null) _buildInfoRow(Icons.person_pin_rounded, "Client", clientName, iconColor: Colors.purple.shade400),
              if(clientEmail != null) _buildInfoRow(Icons.email_outlined, "Client Email", clientEmail, iconColor: Colors.red.shade400),
              _buildInfoRow(Icons.attach_money_rounded, "Initial Price", _projectData!['initial_price']?.toString(), iconColor: Colors.green.shade600),
              _buildInfoRow(Icons.money_off_csred_rounded, "Max Price", _projectData!['max_price']?.toString(), iconColor: Colors.green.shade700),
              _buildInfoRow(Icons.payments_rounded, "Actual Price", _projectData!['actual_price']?.toString(), iconColor: Colors.green.shade800),
              _buildInfoRow(Icons.hourglass_top_rounded, "Initial Time", _formatSecondsToHHMM(_projectData!['Initial_time_s']), iconColor: Colors.cyan.shade600),
              _buildInfoRow(Icons.hourglass_bottom_rounded, "Final Time", _formatSecondsToHHMM(_projectData!['final_time_s']), iconColor: Colors.cyan.shade700),
              _buildInfoRow(Icons.timer_rounded, "Actual Time", _formatSecondsToHHMM(_projectData!['actual_time']), iconColor: Colors.cyan.shade800),
              _buildInfoRow(Icons.play_circle_fill_rounded, "Start Date", _formatDisplayDate(_projectData!['start_date']?.toString()), iconColor: Colors.lightBlue.shade500),
              _buildInfoRow(Icons.pause_circle_filled_rounded, "End Date", _formatDisplayDate(_projectData!['end_date']?.toString()), iconColor: Colors.red.shade500),
              _buildInfoRow(Icons.calendar_today_rounded, "Created", _formatDisplayDate(_projectData!['created']?.toString(), format: 'dd MMM yyyy, hh:mm a'), iconColor: Colors.grey.shade500),
              _buildInfoRow(Icons.update_rounded, "Updated", _formatDisplayDate(_projectData!['updated']?.toString(), format: 'dd MMM yyyy, hh:mm a'), iconColor: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMilestonesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top:10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Milestones (${_milestones.length})", style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: _headerTextColor)),
              if (_milestones.isNotEmpty)
                IconButton(
                  icon: Icon(_isMilestoneDeleteMode ? Icons.check_circle_outline_rounded : Icons.delete_sweep_outlined, color: _isMilestoneDeleteMode ? Colors.redAccent : _headerTextColor.withOpacity(0.8)),
                  tooltip: _isMilestoneDeleteMode ? "Done Deleting" : "Delete Milestones",
                  onPressed: _toggleMilestoneDeleteMode,
                ),
            ],
          ),
        ),
        if(_isMilestoneDeleteMode && _selectedMilestoneIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
              icon: Icon(Icons.delete_forever_rounded, color: Colors.white), 
              label: Text("Delete Selected (${_selectedMilestoneIds.length})", style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold)), 
              onPressed: _isProcessingAction ? null : _deleteSelectedMilestones, 
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.shade200, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))
            )),
          ),
        if (_milestones.isEmpty && _errorMessage == null && !_isLoading)
          Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text("No milestones yet. Tap 'Add Milestone' below to create one!", style: GoogleFonts.lato(color: _headerTextColor.withOpacity(0.7), fontSize: 15), textAlign: TextAlign.center,))),
        if (_errorMessage != null && _milestones.isEmpty && !_isLoading)
           Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text("Could not load milestones: $_errorMessage", style: GoogleFonts.lato(color: Theme.of(context).colorScheme.error, fontSize: 15), textAlign: TextAlign.center))),
        
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _milestones.length,
          itemBuilder: (context, index) {
            return _buildMilestoneCard(_milestones[index] as Map<String, dynamic>, index);
          },
        )
      ],
    );
  }

  Widget _buildMilestoneCard(Map<String, dynamic> milestone, int index) {
    bool isSelected = _selectedMilestoneIds.contains(milestone['id']?.toString() ?? '');
    bool isCompleted = milestone['completed'] == 1 || milestone['completed'] == true;

    return FadeInUp(
      delay: Duration(milliseconds: 100 * index),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: isCompleted ? _milestoneCardCompletedBg : _milestoneCardDefaultBg,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isMilestoneDeleteMode 
            ? () { setState(() { 
                final idStr = milestone['id']?.toString();
                if(idStr != null){
                  if(isSelected) _selectedMilestoneIds.remove(idStr); else _selectedMilestoneIds.add(idStr); 
                }
              }); } 
            : () { _showMessage("Milestone: ${milestone['name']}"); },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                if (_isMilestoneDeleteMode)
                  Checkbox(
                    value: isSelected, 
                    onChanged: (val) { setState(() { 
                      final idStr = milestone['id']?.toString();
                      if(idStr != null){
                        if(val == true) _selectedMilestoneIds.add(idStr); else _selectedMilestoneIds.remove(idStr); 
                      }
                    }); },
                    activeColor: Colors.redAccent,
                  ),
                if (!_isMilestoneDeleteMode)
                  IconButton(
                    icon: Icon(
                      isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: isCompleted ? Colors.green.shade700 : Colors.orange.shade700,
                      size: 28,
                    ),
                    tooltip: isCompleted ? "Mark as Incomplete" : "Mark as Complete",
                    onPressed: _isProcessingAction ? null : () => _toggleMilestoneCompletion(milestone),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(milestone['name'] ?? 'Milestone', style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16, color: _cardTextColor)),
                      if(milestone['description'] != null && milestone['description'].isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(milestone['description'], style: GoogleFonts.lato(fontSize: 13.5, color: _cardTextColor.withOpacity(0.8)), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                      const SizedBox(height: 6),
                      Text("Due: ${_formatDisplayDate(milestone['due_date'])}", style: GoogleFonts.lato(fontSize: 12, color: _cardSecondaryTextColor)),
                      if (isCompleted && milestone['completion_date'] != null)
                        Text("Completed: ${_formatDisplayDate(milestone['completion_date'])}", style: GoogleFonts.lato(fontSize: 12, color: Colors.green.shade800)),
                    ],
                  ),
                ),
                if (!_isMilestoneDeleteMode)
                  IconButton(icon: Icon(Icons.edit_outlined, color: _fabColor.withOpacity(0.7), size: 22), onPressed: _isProcessingAction ? null : () => _showMilestoneFormDialog(milestoneToUpdate: milestone) ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(Color textColor) {
    return Center(child: Padding(padding: const EdgeInsets.all(30.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline_rounded, color: Colors.red.shade200, size: 70), const SizedBox(height: 20),
      Text("Error Loading Details", style: GoogleFonts.lato(color: textColor, fontSize: 19, fontWeight: FontWeight.bold), textAlign: TextAlign.center), const SizedBox(height: 10),
      Text(_errorMessage ?? "An unknown error occurred.", style: GoogleFonts.lato(color: textColor.withOpacity(0.8), fontSize: 16), textAlign: TextAlign.center), const SizedBox(height: 25),
      ElevatedButton.icon(icon: Icon(Icons.refresh_rounded, color: Colors.teal.shade800), label: Text("Try Again", style: GoogleFonts.lato(color: Colors.teal.shade800, fontWeight: FontWeight.bold, fontSize: 15)), onPressed: _loadProjectDetails, style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.85), padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))
    ])));
  }
}