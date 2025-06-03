// team_projects_page.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

// --- افترض أنك ستقوم بإنشاء هذه الصفحة لاحقًا ---
 import 'ProjectDetailPage.dart'; 
// import 'login_screen.dart'; // Import if needed for _handleAuthError

class TeamProjectsPage extends StatefulWidget {
  final String teamId;
  final String? teamName;
  
  final dynamic companyName;
  
  final dynamic companyId;
  // final String companyId; // Not directly used in this page's API calls but kept if needed for ProjectDetailPage
  // final String companyName;

  const TeamProjectsPage({
    super.key,
    required this.teamId,
    this.teamName,
    required this.companyId, // Kept for potential use in ProjectDetailPage navigation
    required this.companyName, // Kept for potential use in ProjectDetailPage navigation
  });

  @override
  State<TeamProjectsPage> createState() => _TeamProjectsPageState();
}

class _TeamProjectsPageState extends State<TeamProjectsPage> {
  final _storage = const FlutterSecureStorage();
  final String _baseDomain = Platform.isAndroid ? "http://10.0.2.2:3000" : "http://localhost:3000";
  late final String _projectsApiUrl;
  late final String _addProjectApiUrl;

  List<dynamic> _projects = [];
  bool _isLoading = true;
  String? _errorMessage;

  final _addProjectFormKey = GlobalKey<FormState>();
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _clientIdController = TextEditingController();
  final TextEditingController _initialPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  bool _isAddingProjectDialogActive = false; // To manage dialog button state

  final IconData _defaultProjectIcon = Icons.assessment_outlined;
  final Color _cardBackgroundColor = Colors.white.withOpacity(0.96);
  final Color _cardTitleColor = const Color(0xFF2E3D4E);
  final Color _cardSubtitleColor = Colors.black.withOpacity(0.75);
  final Color _cardIconColor = Colors.deepPurple.shade400;
  final Color _cardDateColor = Colors.grey.shade700;
  final Color _cardPriceColor = Colors.green.shade800;
  final Color _cardArrowColor = Colors.grey.shade400;
  final Color _fabColor = const Color(0xFF4A5D52);
  final Color _appBarTextColor = Colors.white;
  final Color _pageBackgroundColor1 = const Color(0xFFF2DEC5);
  final Color _pageBackgroundColor2 = const Color(0xFF697C6B);
  final Color _appBarBg1 = const Color(0xFFa3b29f).withOpacity(0.9);
  final Color _appBarBg2 = const Color(0xFF697C6B).withOpacity(0.98);

  @override
  void initState() {
    super.initState();
    _projectsApiUrl = "$_baseDomain/api/owner/teams/${widget.teamId}/projects";
    _addProjectApiUrl = "$_baseDomain/api/owner/projects";
    _loadProjects();
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _clientIdController.dispose();
    _initialPriceController.dispose();
    _maxPriceController.dispose();
    _descriptionController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _handleAuthError({String message = 'Session expired. Please log in again.'}) async {
    if (!mounted) return;
    _showMessage(message, isError: true);
    await _storage.deleteAll();
    // if (mounted) {
    //   Navigator.of(context).pushAndRemoveUntil(
    //       MaterialPageRoute(builder: (context) => const LoginScreen()), 
    //       (Route<dynamic> route) => false);
    // }
  }

  void _showMessage(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.lato(color: Colors.white)),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : (isSuccess ? Colors.green.shade600 : Colors.teal.shade700),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating, elevation: 6.0, margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _loadProjects({bool showLoadingIndicator = true}) async {
    if (!mounted) return;
    if (showLoadingIndicator) {
      setState(() { _isLoading = true; _errorMessage = null; });
    }
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = "Authentication token missing."; });
      return;
    }
    print("--- TeamProjectsPage: Fetching projects from $_projectsApiUrl for team ${widget.teamId} ---");
    try {
      final response = await http.get(Uri.parse(_projectsApiUrl), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) setState(() { 
          _projects = data['projects'] as List<dynamic>? ?? []; 
          _isLoading = false; 
          _errorMessage = _projects.isEmpty ? "No projects found for this team yet." : null; 
        });
      } else if (response.statusCode == 401) { await _handleAuthError(); if(mounted) setState(()=> _isLoading = false);
      } else {
        String errorMsg = "Failed to load projects (${response.statusCode})";
        try { final errorData = jsonDecode(utf8.decode(response.bodyBytes)); if (errorData is Map && errorData['message'] != null) errorMsg = errorData['message'] as String; } catch(_){}
        if(mounted) setState(() { _errorMessage = errorMsg; _isLoading = false; _projects = []; });
      }
    } catch (e) {
      print("!!! TeamProjectsPage: LoadProjects Exception: $e");
      if (mounted) setState(() { _errorMessage = "Error loading projects: ${e.toString().replaceFirst("Exception: ", "")}"; _isLoading = false; _projects = []; });
    }
  }

  Future<void> _addNewProject(StateSetter setDialogState) async {
    if (!_addProjectFormKey.currentState!.validate()) {
      setDialogState(() => _isAddingProjectDialogActive = false);
      return;
    }
    if (!mounted) return;

    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      _showMessage("Authentication error.", isError: true);
      setDialogState(() => _isAddingProjectDialogActive = false);
      return;
    }
    final Map<String, dynamic> newProjectData = {
      "name": _projectNameController.text.trim(),
      "client_id": int.tryParse(_clientIdController.text.trim()),
      "team_id": int.tryParse(widget.teamId),
      "Initial_price": double.tryParse(_initialPriceController.text.trim()),
      "max_price": double.tryParse(_maxPriceController.text.trim()),
      "description": _descriptionController.text.trim(),
      "start_date": _startDateController.text.trim(),
      "end_date": _endDateController.text.trim(),
    };
    newProjectData.removeWhere((key, value) => value == null);

    print("--- TeamProjectsPage: Adding new project: $newProjectData to $_addProjectApiUrl ---");
    try {
      final response = await http.post(
        Uri.parse(_addProjectApiUrl),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode(newProjectData),
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;
      final responseBodyString = utf8.decode(response.bodyBytes);
      print("Add Project Response Status: ${response.statusCode}");
      print("Add Project Response Body (Raw): $responseBodyString");
      final responseData = jsonDecode(responseBodyString);

      if (response.statusCode == 201) {
        _showMessage(responseData['message'] ?? "New project added successfully!", isSuccess: true);
        _projectNameController.clear(); _clientIdController.clear(); _initialPriceController.clear();
        _maxPriceController.clear(); _descriptionController.clear(); _startDateController.clear(); _endDateController.clear();
        
        if (Navigator.canPop(context)) Navigator.of(context).pop();
        await _loadProjects(showLoadingIndicator: false);
      } else {
        _showMessage(responseData['message'] ?? "Failed to add project (${response.statusCode})", isError: true);
      }
    } catch (e) {
      print("!!! TeamProjectsPage: AddNewProject Exception: $e");
      _showMessage("An error occurred: $e", isError: true);
    } finally {
      if (mounted) {
         setDialogState(() => _isAddingProjectDialogActive = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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

  void _showAddProjectDialog() {
    _projectNameController.clear(); _clientIdController.clear(); _initialPriceController.clear();
    _maxPriceController.clear(); _descriptionController.clear(); _startDateController.clear(); _endDateController.clear();
    
    _isAddingProjectDialogActive = false; // Reset before showing

    showModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      backgroundColor: Colors.white.withOpacity(0.98),
      builder: (BuildContext dialogContext) { 
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
                left: 20, right: 20, top: 25
              ),
              child: Form(
                key: _addProjectFormKey,
                child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    Text("Add New Project", style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: _fabColor)),
                    const SizedBox(height: 20),
                    TextFormField(controller: _projectNameController, decoration: _inputDecoration("Project Name *", Icons.title_rounded), validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                    const SizedBox(height: 15),
                    TextFormField(controller: _clientIdController, decoration: _inputDecoration("Client ID *", Icons.person_pin_circle_outlined), keyboardType: TextInputType.number, validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null) ? 'Valid Client ID Required' : null),
                    const SizedBox(height: 15),
                    Row(children: [
                        Expanded(child: TextFormField(controller: _initialPriceController, decoration: _inputDecoration("Initial Price *", Icons.price_check_rounded), keyboardType: TextInputType.number, validator: (v) => (v == null || v.isEmpty || double.tryParse(v) == null) ? 'Valid Price Required' : null)),
                        const SizedBox(width: 10),
                        Expanded(child: TextFormField(controller: _maxPriceController, decoration: _inputDecoration("Max Price *", Icons.price_change_outlined), keyboardType: TextInputType.number, validator: (v) => (v == null || v.isEmpty || double.tryParse(v) == null) ? 'Valid Price Required' : null)),
                    ]),
                    const SizedBox(height: 15),
                    TextFormField(controller: _descriptionController, decoration: _inputDecoration("Description *", Icons.description_outlined, alignLabel: true), maxLines: 3, validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                    const SizedBox(height: 15),
                    Row(children: [
                        Expanded(child: TextFormField(controller: _startDateController, decoration: _inputDecoration("Start Date (YYYY-MM-DD) *", Icons.calendar_today_rounded), onTap: () async { FocusScope.of(context).requestFocus(FocusNode()); await _selectDate(context, _startDateController); }, readOnly: true, validator: (v) => (v == null || v.isEmpty) ? 'Required' : null)),
                        const SizedBox(width: 10),
                        Expanded(child: TextFormField(controller: _endDateController, decoration: _inputDecoration("End Date (YYYY-MM-DD) *", Icons.event_available_rounded), onTap: () async { FocusScope.of(context).requestFocus(FocusNode()); await _selectDate(context, _endDateController); }, readOnly: true, validator: (v) => (v == null || v.isEmpty) ? 'Required' : null)),
                    ]),
                    const SizedBox(height: 25),
                    ElevatedButton.icon(
                      icon: _isAddingProjectDialogActive ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add_task_rounded, size: 20),
                      label: Text(_isAddingProjectDialogActive ? "Adding..." : "Add Project", style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
                      onPressed: _isAddingProjectDialogActive ? null : () async { 
                        if (_addProjectFormKey.currentState!.validate()) { 
                          setDialogState(() => _isAddingProjectDialogActive = true); 
                          await _addNewProject(setDialogState);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: _fabColor, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                    const SizedBox(height: 15),
                  ]),
                ),
              ),
            );
          });
      },
    ).then((_){
      if(mounted && _isAddingProjectDialogActive){ // If dialog was dismissed while its button was loading
         setState(() => _isAddingProjectDialogActive = false ); // Reset the dialog loading state if needed
      }
    });
  }

  InputDecoration _inputDecoration(String label, IconData icon, {bool alignLabel = false}) {
    return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _fabColor.withOpacity(0.7)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _fabColor, width: 1.5)),
        alignLabelWithHint: alignLabel,
        filled: true,
        fillColor: Colors.white.withOpacity(0.8)
    );
  }

  String _formatDisplayDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try { return DateFormat('dd MMM yyyy').format(DateTime.parse(dateString).toLocal()); }
    catch (_) { return dateString.length > 10 ? dateString.substring(0, 10) : dateString; }
  }

  Widget _buildProjectCard(Map<String, dynamic> project, int index) {
    IconData projectIcon = _defaultProjectIcon;
    final String currentProjectId = project['id']?.toString() ?? '';
    final String currentProjectName = project['name']?.toString() ?? 'Untitled Project';
    final String clientName = project['client_name']?.toString() ?? 'N/A'; // From get team projects API

    return FadeInUp(
      delay: Duration(milliseconds: 120 * (index + 1)), duration: const Duration(milliseconds: 450),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 4,
        margin: const EdgeInsets.symmetric(vertical: 9, horizontal: 8), color: _cardBackgroundColor,
        child: InkWell(
          onTap: () {
            if (currentProjectId.isNotEmpty) {
              
               Navigator.push(context, MaterialPageRoute(builder: (context) => ProjectDetailPage(projectId: currentProjectId, teamId: widget.teamId, companyId: widget.companyId, companyName: widget.companyName )));
             
            } else { _showMessage("Error: Project ID is missing.", isError: true); }
          },
          borderRadius: BorderRadius.circular(15), splashColor: _cardIconColor.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _cardIconColor.withOpacity(0.12), shape: BoxShape.circle), child: Icon(projectIcon, size: 28, color: _cardIconColor)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(currentProjectName, style: GoogleFonts.lato(fontSize: 17, fontWeight: FontWeight.w600, color: _cardTitleColor))),
                  Icon(Icons.arrow_forward_ios_rounded, size: 18, color: _cardArrowColor),
                ]),
                const SizedBox(height: 10),
                if (project['description'] != null && project['description'].toString().isNotEmpty) ...[
                  Text(project['description'].toString(), style: GoogleFonts.lato(fontSize: 14, color: _cardSubtitleColor, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                ],
                Row(children: [Icon(Icons.person_pin_rounded, size: 16, color: _cardDateColor), const SizedBox(width: 6), Text("Client: $clientName", style: GoogleFonts.lato(fontSize: 12.5, color: _cardDateColor))]),
                const SizedBox(height: 4),
                Row(children: [
                    Icon(Icons.attach_money_rounded, size: 16, color: _cardPriceColor), const SizedBox(width: 6),
                    Text("Price: ${project['Initial_price'] ?? 'N/A'} - ${project['max_price'] ?? 'N/A'}", style: GoogleFonts.lato(fontSize: 12.5, color: _cardPriceColor, fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text("Start: ${_formatDisplayDate(project['start_date']?.toString())}", style: GoogleFonts.lato(fontSize: 11.5, color: _cardDateColor)),
                    Text("End: ${_formatDisplayDate(project['end_date']?.toString())}", style: GoogleFonts.lato(fontSize: 11.5, color: _cardDateColor)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.teamName ?? 'Team'} - Projects", style: GoogleFonts.lato(color: _appBarTextColor, fontWeight: FontWeight.w700, fontSize: 22), overflow: TextOverflow.ellipsis),
        flexibleSpace: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [_appBarBg1, _appBarBg2], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        elevation: 2, iconTheme: IconThemeData(color: _appBarTextColor),
        actions: [IconButton(icon: Icon(Icons.refresh_rounded, color: _appBarTextColor), onPressed: _isLoading ? null : _loadProjects, tooltip: "Refresh Projects")],
      ),
      body: Container(
        decoration: BoxDecoration( // Beige/Green gradient background
          gradient: LinearGradient(colors: [_pageBackgroundColor1, _pageBackgroundColor2.withOpacity(0.85), _pageBackgroundColor2], begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.0, 0.35, 1.0]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_appBarTextColor.withOpacity(0.8))))
                    : _errorMessage != null && _projects.isEmpty
                        ? _buildErrorWidget(_fabColor)
                        : RefreshIndicator(
                            onRefresh: () => _loadProjects(showLoadingIndicator: true),
                            color: Colors.white, backgroundColor: _fabColor.withOpacity(0.9),
                            child: _projects.isEmpty && _errorMessage == null
                                ? _buildEmptyStateWidget(_fabColor)
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(10, 15, 10, 80), // Space for FAB
                                    itemCount: _projects.length,
                                    itemBuilder: (context, index) => _buildProjectCard(_projects[index], index),
                                  ),
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _showAddProjectDialog, // Disable FAB while page is loading
        label: Text("Add Project", style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: Colors.white)),
        icon: const Icon(Icons.add_task_rounded, color: Colors.white),
        backgroundColor: _fabColor,
        elevation: 8,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildErrorWidget(Color textColor) {
    return Center(child: Padding(padding: const EdgeInsets.all(30.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline_rounded, color: Colors.orange.shade300, size: 70), const SizedBox(height: 20),
          Text(_errorMessage ?? "An error occurred.", style: GoogleFonts.lato(color: textColor, fontSize: 18, fontWeight: FontWeight.w500), textAlign: TextAlign.center), const SizedBox(height: 25),
          ElevatedButton.icon(icon: Icon(Icons.refresh_rounded, color: _fabColor), label: Text("Try Again", style: GoogleFonts.lato(color: _fabColor, fontWeight: FontWeight.bold)), onPressed: () => _loadProjects(showLoadingIndicator: true), style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.9), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))
    ])));
  }
  Widget _buildEmptyStateWidget(Color textColor) {
    return Center(child: Padding(padding: const EdgeInsets.all(30.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.folder_off_outlined, color: textColor.withOpacity(0.7), size: 75), const SizedBox(height: 22),
          Text("No projects found for this team yet.", style: GoogleFonts.lato(color: textColor.withOpacity(0.9), fontSize: 18.5, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TextButton.icon(
            icon: Icon(Icons.refresh_rounded, color: textColor.withOpacity(0.8)),
            label: Text("Tap to refresh", style: GoogleFonts.lato(color: textColor.withOpacity(0.8))),
            onPressed: () => _loadProjects(showLoadingIndicator: true),
          )
    ])));
  }
}