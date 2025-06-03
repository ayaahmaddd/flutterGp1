// client_project_detail_page.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'login.dart'; // لمعالجة خطأ المصادقة


class ClientProjectDetailPage extends StatefulWidget {
  final String projectId;
  final String? initialProjectName;
  final String teamId;         
  final String companyId;      
  final String companyName; 

  const ClientProjectDetailPage({
    super.key,
    required this.projectId,
    this.initialProjectName,
    required this.teamId,      
    required this.companyId,   
    required this.companyName,
  });

  @override
  State<ClientProjectDetailPage> createState() => _ClientProjectDetailPageState();
}

class _ClientProjectDetailPageState extends State<ClientProjectDetailPage> with TickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  final String _baseDomain = Platform.isAndroid ? "http://10.0.2.2:3000" : "http://localhost:3000";
  
  late final String _projectDetailApiUrl;
  late final String _updateProjectApiUrl;

  Map<String, dynamic>? _projectData;
  List<dynamic> _milestones = [];
  List<dynamic> _members = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessingAction = false;

  final _updateProjectFormKey = GlobalKey<FormState>();
  final TextEditingController _updateProjectDescriptionController = TextEditingController();
  final TextEditingController _updateStartDateController = TextEditingController();
  final TextEditingController _updateEndDateController = TextEditingController();
  final TextEditingController _updateInitialPriceController = TextEditingController();
  final TextEditingController _updateMaxPriceController = TextEditingController();
  final TextEditingController _updateInitialTimeController = TextEditingController(); 
  final TextEditingController _updateFinalTimeController = TextEditingController();   
  final TextEditingController _updateActualPriceController = TextEditingController();
  final TextEditingController _updateActualTimeController = TextEditingController();  

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
final Color _secondaryTextColor = Colors.grey.shade700;


  @override
  void initState() {
    super.initState();
    _projectDetailApiUrl = "$_baseDomain/api/client/projects/${widget.projectId}";
    _updateProjectApiUrl = "$_baseDomain/api/client/projects/${widget.projectId}";
    _loadProjectDetails();
  }

  @override
  void dispose() {
    _updateProjectDescriptionController.dispose();
    _updateStartDateController.dispose();
    _updateEndDateController.dispose();
    _updateInitialPriceController.dispose();
    _updateMaxPriceController.dispose();
    _updateInitialTimeController.dispose();
    _updateFinalTimeController.dispose();
    _updateActualPriceController.dispose();
    _updateActualTimeController.dispose();
    super.dispose();
  }

  Future<void> _handleAuthError({String message = 'Session expired. Please log in again.'}) async {
    if (!mounted) return;
    _showMessage(message, isError: true);
    await _storage.deleteAll();
    if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false);
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
    
    print("--- ClientProjectDetailPage: Fetching project details from $_projectDetailApiUrl ---");
    try {
      final response = await http.get(Uri.parse(_projectDetailApiUrl), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && data['success'] == true && data['project'] != null) {
        if (mounted) {
          setState(() {
          _projectData = data['project'] as Map<String, dynamic>;
          _milestones = _projectData?['milestones'] as List<dynamic>? ?? [];
          _members = _projectData?['members'] as List<dynamic>? ?? [];
          _isLoading = false; _errorMessage = null;
        });
        }
      } else { 
        if (response.statusCode == 401) _handleAuthError();
        final String apiMessage = data['message']?.toString() ?? 'Failed to load project details';
        throw Exception('$apiMessage (${response.statusCode})');
      }
    } catch (e) {
      print("!!! ClientProjectDetailPage: LoadProjectDetails Exception: $e");
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
        if ((label == "Actual Price" || label == "Actual Time" || label == "Initial Price" || label == "Max Price") && (value == "0" || value == "0.0" || value == "0.00")) {
            // لا تفعل شيئًا، اسمح بعرض الصفر لهذه الحقول
        } else if ((label == "Initial Time" || label == "Final Time" || label == "Actual Time") && value == "00:00") {
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
    if (totalSeconds == null || totalSeconds < 0) return 'N/A';
    if (totalSeconds == 0 && secondsValue.toString() != "0") return 'N/A';
    
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

  void _showUpdateProjectDialogForClient() {
    if (_projectData == null) return;
    _updateProjectDescriptionController.text = _projectData!['description'] ?? '';
    _updateStartDateController.text = _projectData!['start_date'] != null ? _projectData!['start_date'].toString().split('T')[0] : '';
    _updateEndDateController.text = _projectData!['end_date'] != null ? _projectData!['end_date'].toString().split('T')[0] : ''; 
    
    bool isInitialPriceReadOnly = _projectData!['Initial_price'] != null && _projectData!['Initial_price'].toString().isNotEmpty && _projectData!['Initial_price'].toString() != '0';
    _updateInitialPriceController.text = _projectData!['Initial_price']?.toString() ?? '';

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
            title: Text("Update Project Details", style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: _fabColor)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            backgroundColor: _pageBackgroundColor1,
            content: SingleChildScrollView(
              child: Form(
                key: _updateProjectFormKey,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TextFormField(controller: _updateProjectDescriptionController, decoration: _customInputDecoration("Description *", Icons.description_rounded), maxLines: 3, validator: (v)=>(v==null||v.isEmpty)?'Description is required':null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _updateStartDateController, decoration: _customInputDecoration("New Start Date (YYYY-MM-DD) *", Icons.play_arrow_rounded), readOnly: true, onTap: () => _selectDate(dialogContext, _updateStartDateController, initialDate: DateTime.tryParse(_projectData!['start_date']?.toString().split('T')[0] ?? '')), validator: (v)=>(v==null||v.isEmpty)?'Start Date is required':null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _updateEndDateController, decoration: _customInputDecoration("New End Date (YYYY-MM-DD) *", Icons.event_busy_rounded), readOnly: true, onTap: () => _selectDate(dialogContext, _updateEndDateController, initialDate: DateTime.tryParse(_projectData!['end_date']?.toString().split('T')[0] ?? '')), validator: (v)=>(v==null||v.isEmpty)?'End Date is required':null),
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
                  _buildDividerWithLabel("Actuals (Update if not set)"),
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
                    await _updateProjectForClient(
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

  Future<void> _updateProjectForClient({
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
      "description": _updateProjectDescriptionController.text.trim(),
      "start_date": _updateStartDateController.text.trim(),
      "end_date": _updateEndDateController.text.trim(),
    };

    if(!isInitialPriceReadOnly && _updateInitialPriceController.text.trim().isNotEmpty) payload["Initial_price"] = num.tryParse(_updateInitialPriceController.text.trim());
    if(!isMaxPriceReadOnly && _updateMaxPriceController.text.trim().isNotEmpty) payload["max_price"] = num.tryParse(_updateMaxPriceController.text.trim());
    
    // فقط أرسل actual_price إذا لم يكن للقراءة فقط (يعني كان فارغًا في الأصل) وتم إدخال قيمة
    if(!isActualPriceReadOnly && _updateActualPriceController.text.trim().isNotEmpty) {
      payload["actual_price"] = num.tryParse(_updateActualPriceController.text.trim());
    }

    if(!isInitialTimeReadOnly && _updateInitialTimeController.text.trim().isNotEmpty && _updateInitialTimeController.text.trim().toLowerCase() != 'n/a') {
        int? initialTimeSeconds = _parseHHMMToSeconds(_updateInitialTimeController.text.trim());
        if (initialTimeSeconds != null) payload["Initial_time_s"] = initialTimeSeconds;
    }
    if(!isFinalTimeReadOnly && _updateFinalTimeController.text.trim().isNotEmpty && _updateFinalTimeController.text.trim().toLowerCase() != 'n/a') {
        int? finalTimeSeconds = _parseHHMMToSeconds(_updateFinalTimeController.text.trim());
        if (finalTimeSeconds != null) payload["final_time_s"] = finalTimeSeconds;
    }
    // فقط أرسل actual_time إذا لم يكن للقراءة فقط (يعني كان فارغًا في الأصل) وتم إدخال قيمة
    if(!isActualTimeReadOnly && _updateActualTimeController.text.trim().isNotEmpty && _updateActualTimeController.text.trim().toLowerCase() != 'n/a') {
        int? actualTimeSeconds = _parseHHMMToSeconds(_updateActualTimeController.text.trim());
        if (actualTimeSeconds != null) payload["actual_time"] = actualTimeSeconds;
    }
    
    payload.removeWhere((key, value) => value == null);

    print("--- Updating project (Client) $_updateProjectApiUrl with payload: $payload ---");
    try {
      final response = await http.put(Uri.parse(_updateProjectApiUrl), headers: {'Authorization': 'Bearer $token', 'Content-Type':'application/json; charset=UTF-8'}, body: json.encode(payload));
      if(!mounted) return;
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      if(response.statusCode == 200 && responseData['success'] == true){
        _showMessage("Project details updated successfully!", isSuccess: true);
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
            IconButton(icon: Icon(Icons.edit_note_rounded, color: _appBarTextColor), onPressed: _isProcessingAction ? null : _showUpdateProjectDialogForClient, tooltip: "Update Project Details"),
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
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildProjectInfoCard(),
                                  const SizedBox(height: 24),
                                  _buildTeamMembersSection(),
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
    );
  }

  Widget _buildProjectInfoCard() {
    if (_projectData == null) return const SizedBox.shrink();
    String companyNameDisplay = _projectData!['company_name']?.toString() ?? widget.companyName;
    String teamNameDisplay = _projectData!['team_name']?.toString() ?? "Team ID: ${widget.teamId}";


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
              _buildInfoRow(Icons.business_rounded, "Company", companyNameDisplay, iconColor: Colors.blueGrey),
              _buildInfoRow(Icons.groups_2_rounded, "Team", teamNameDisplay, iconColor: Colors.orange.shade700),
              _buildInfoRow(Icons.attach_money_rounded, "Initial Price", _projectData!['Initial_price']?.toString(), iconColor: Colors.green.shade600),
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

  Widget _buildTeamMembersSection() {
    if (_members.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top:10.0),
          child: Text("Team Members (${_members.length})", style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: _headerTextColor)),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _members.length,
          itemBuilder: (context, index) {
            final member = _members[index] as Map<String, dynamic>;
            String? memberImageUrl = member['image_url']?.toString();
            String memberName = "${member['first_name'] ?? ''} ${member['last_name'] ?? ''}".trim();
            String memberPosition = member['position']?.toString() ?? 'N/A';

            return FadeInUp(
              delay: Duration(milliseconds: 100 * index),
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 5),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                color: _cardColor.withOpacity(0.95),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundImage: (memberImageUrl != null && memberImageUrl.isNotEmpty) ? NetworkImage(memberImageUrl) : null,
                    child: (memberImageUrl == null || memberImageUrl.isEmpty) ? Icon(Icons.person_outline_rounded, size: 22, color: _secondaryTextColor) : null,
                    backgroundColor: Colors.grey.shade200,
                  ),
                  title: Text(memberName, style: GoogleFonts.lato(fontWeight: FontWeight.w600, fontSize: 15, color: _cardTextColor)),
                  subtitle: Text(memberPosition, style: GoogleFonts.lato(fontSize: 13, color: _cardSecondaryTextColor)),
                ),
              ),
            );
          },
        )
      ],
    );
  }


  Widget _buildMilestonesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top:10.0),
          child: Text("Milestones (${_milestones.length})", style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: _headerTextColor)),
        ),
        if (_milestones.isEmpty && _errorMessage == null && !_isLoading)
          Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text("No milestones for this project.", style: GoogleFonts.lato(color: _headerTextColor.withOpacity(0.7), fontSize: 15), textAlign: TextAlign.center,))),
        if (_errorMessage != null && _milestones.isEmpty && !_isLoading)
           Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text("Could not load milestones.", style: GoogleFonts.lato(color: Theme.of(context).colorScheme.error, fontSize: 15), textAlign: TextAlign.center))),
        
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _milestones.length,
          itemBuilder: (context, index) {
            return _buildMilestoneCardReadOnly(_milestones[index] as Map<String, dynamic>, index);
          },
        )
      ],
    );
  }

  Widget _buildMilestoneCardReadOnly(Map<String, dynamic> milestone, int index) {
    bool isCompleted = milestone['completed'] == 1 || milestone['completed'] == true;

    return FadeInUp(
      delay: Duration(milliseconds: 100 * index),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: isCompleted ? _milestoneCardCompletedBg : _milestoneCardDefaultBg,
        child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                 Icon(
                      isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: isCompleted ? Colors.green.shade700 : Colors.orange.shade700,
                      size: 28,
                    ),
                const SizedBox(width: 12),
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
              ],
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