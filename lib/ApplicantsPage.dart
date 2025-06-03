// applicants_page.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

// import 'login_screen.dart'; // قم بإلغاء التعليق إذا كنت ستستخدم إعادة التوجيه

class ApplicantsPage extends StatefulWidget {
  final String jobId;
  final String jobName;
  final String companyId; // مطلوب لجلب فرق الشركة

  const ApplicantsPage({
    super.key,
    required this.jobId,
    required this.jobName,
    required this.companyId,
  });

  @override
  State<ApplicantsPage> createState() => _ApplicantsPageState();
}

class _ApplicantsPageState extends State<ApplicantsPage> {
  final _storage = const FlutterSecureStorage();
  final List<Map<String, dynamic>> _applicants = [];
  bool _isHiringMode = false;
  bool _isDeleteMode = false;
  final Set<int> _selectedApplicantIndicesForHiring = {};
  final Set<int> _selectedApplicantIndicesForDeleting = {};
  
  List<dynamic> _companyTeams = [];
  bool _isLoadingTeams = false;
  int? _selectedTeamIdForHiring;

  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessingAction = false; // عام للأزرار التي تقوم بعمليات طويلة

  String get _baseUrl => Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000';
  late String _fetchApplicantsUrl;
  late String _addApplicantUrl;
  late String _companyTeamsApiUrl;

  final Color _appBarBackgroundColor1 = const Color(0xFFa3b29f).withOpacity(0.9);
  final Color _appBarBackgroundColor2 = const Color(0xFF697C6B).withOpacity(0.98);
  final Color _pageBackgroundColor1 = const Color(0xFFF2DEC5);
  final Color _pageBackgroundColor2 = const Color(0xFF697C6B);
  final Color _appBarTextColor = Colors.white;
  final Color _fabColor = const Color(0xFF4A5D52);
  final Color _cardColor = Colors.white.withOpacity(0.95);
  final Color _cardTextColor = const Color(0xFF33475B);
  final Color _cardSecondaryTextColor = Colors.grey.shade700;
  final Color _selectedTeamCardColor = Colors.teal.shade100.withOpacity(0.7);

  @override
  void initState() {
    super.initState();
    _fetchApplicantsUrl = "$_baseUrl/api/owner/jobs/${widget.jobId}/applicants";
    _addApplicantUrl = "$_baseUrl/api/owner/jobs/${widget.jobId}/applicants";
    _companyTeamsApiUrl = "$_baseUrl/api/owner/companies/${widget.companyId}/teams";
    _fetchApplicants();
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

  Future<void> _fetchApplicants({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() { _isLoading = true; _errorMessage = null; });
    
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = "Authentication token missing.";});
      return;
    }
    debugPrint("--- ApplicantsPage: Fetching applicants from $_fetchApplicantsUrl ---");
    try {
      final response = await http.get(Uri.parse(_fetchApplicantsUrl), headers: {
        'Authorization': 'Bearer $token', 'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      final String responseBodyString = utf8.decode(response.bodyBytes);
      debugPrint("Fetch Applicants Response Status: ${response.statusCode}");
      // debugPrint("Fetch Applicants Response Body (Raw): $responseBodyString");

      if (response.statusCode == 200) {
        final body = jsonDecode(responseBodyString);
        final List<dynamic> data = body['applicants'] as List<dynamic>? ?? [];
        setState(() {
          _applicants.clear();
          for (var app in data) {
            _applicants.add({
              'id': app['id'],
              'provider_id': app['provider_id'],
              'name': app['provider_name'],
              'email': app['provider_email'],
              'image': app['provider_image'],
              'position': app['position'],
            });
          }
          _isLoading = false;
          if (_applicants.isEmpty) _errorMessage = "No applicants found for this job yet."; else _errorMessage = null;
        });
      } else if (response.statusCode == 401) {
        await _handleAuthError();
      } else {
        String errorMsg = "Failed to fetch applicants (${response.statusCode})";
        try{
          final errorBody = jsonDecode(responseBodyString);
          if (errorBody is Map && errorBody['message'] != null) errorMsg = errorBody['message'];
        } catch(_){}
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint("❌ Exception in _fetchApplicants: $e");
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString().replaceFirst("Exception: ", ""); });
    }
  }

  Future<void> _addApplicant(String providerIdStr, StateSetter setDialogState) async {
    final int? providerId = int.tryParse(providerIdStr);
    if (providerId == null) {
      _showMessage("Invalid Provider ID. Please enter a number.", isError: true);
      setDialogState(() => _isProcessingAction = false); 
      return;
    }

    if(!mounted) return;
    setDialogState(() => _isProcessingAction = true); 
    
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      _showMessage("Authentication error.", isError: true);
      setDialogState(() => _isProcessingAction = false);
      return;
    }

    final requestBody = {'provider_id': providerId};
    debugPrint("--- ApplicantsPage: Adding applicant. URL: $_addApplicantUrl, Body: $requestBody ---");

    try {
      final response = await http.post(
        Uri.parse(_addApplicantUrl),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      
      final String responseBodyString = utf8.decode(response.bodyBytes);
      debugPrint("Add Applicant Response Status: ${response.statusCode}");
      debugPrint("Add Applicant Response Body (Raw): $responseBodyString");

      if (response.statusCode == 201) {
        try {
          final responseBody = jsonDecode(responseBodyString);
          _showMessage(responseBody['message'] ?? "Applicant added successfully", isSuccess: true);
        } catch (e) {
           _showMessage("Applicant added (unexpected server response format).", isSuccess: true);
           debugPrint("⚠️ Add applicant: Status 201 but non-JSON response: $responseBodyString");
        }
        if (Navigator.canPop(context)) Navigator.pop(context);
        await _fetchApplicants(showLoading: false);
      } else {
        try {
          final responseBody = jsonDecode(responseBodyString);
          debugPrint("❌ Add applicant error from server: ${responseBody.toString()}");
          _showMessage(responseBody['message']?.toString() ?? "Failed to add applicant (${response.statusCode})", isError: true);
        } catch (e) {
          debugPrint("❌ Error parsing server error message: $e. Raw response: $responseBodyString");
          _showMessage("Failed to add applicant (${response.statusCode}). Server sent an unexpected response format.", isError: true);
        }
      }
    } catch (e) {
      debugPrint("❌ Exception in _addApplicant: $e");
      _showMessage("An error occurred while adding applicant: $e", isError: true);
    } finally {
      if(mounted) {
        setDialogState(() => _isProcessingAction = false);
      }
    }
  }

  Future<void> _deleteSelectedApplicants() async {
    if (_selectedApplicantIndicesForDeleting.isEmpty) {
      _showMessage("No applicants selected for deletion.", isError: true);
      return;
    }
    
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Confirm Deletion', style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete ${_selectedApplicantIndicesForDeleting.length} selected applicant(s)? This action cannot be undone.', style: GoogleFonts.lato()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(child: Text('Cancel', style: GoogleFonts.lato(color: Colors.grey.shade700)), onPressed: () => Navigator.of(context).pop(false)),
          TextButton(child: Text('Delete', style: GoogleFonts.lato(color: Colors.red, fontWeight: FontWeight.bold)), onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );

    if (confirmDelete != true || !mounted) return;

    setState(() => _isProcessingAction = true);

    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      _showMessage("Authentication error.", isError: true);
      if(mounted) setState(() => _isProcessingAction = false);
      return;
    }

    List<int> applicantsToDeleteIds = _selectedApplicantIndicesForDeleting.map((index) => _applicants[index]['id'] as int).toList();
    
    int successCount = 0;
    List<String> errorMessages = [];

    for (var jobApplicationId in applicantsToDeleteIds) {
      if(!mounted) break;
      final url = Uri.parse("$_baseUrl/api/owner/applications/$jobApplicationId");
      debugPrint("--- ApplicantsPage: Deleting applicant application ID: $jobApplicationId from $url ---");
      try {
        final response = await http.delete(url, headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds:10));
        if (!mounted) break;
        if (response.statusCode == 200 || response.statusCode == 204) {
          successCount++;
        } else {
          final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
          final msg = "Failed for ID $jobApplicationId: ${responseBody['message'] ?? response.statusCode}";
          errorMessages.add(msg);
          debugPrint(msg);
        }
      } catch (e) {
         final msg = "Error for ID $jobApplicationId: $e";
         errorMessages.add(msg);
        debugPrint(msg);
      }
    }

    if (!mounted) return;

    if (successCount > 0) {
      _showMessage("$successCount applicant(s) deleted successfully.", isSuccess: true);
    }
    if (errorMessages.isNotEmpty) {
       _showMessage("Some deletions failed: ${errorMessages.join('; ')}", isError: true);
    }
    
    setState(() {
      _selectedApplicantIndicesForDeleting.clear();
      _isDeleteMode = false;
      _isProcessingAction = false;
    });
    await _fetchApplicants(showLoading: false);
  }

  void _showAddApplicantCard() {
    String providerIdInput = "";
    final GlobalKey<FormState> dialogFormKey = GlobalKey<FormState>();
    bool isDialogButtonLoading = false; 

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      backgroundColor: Colors.white.withOpacity(0.98),
      builder: (builderContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(builderContext).viewInsets.bottom,
                left: 20, right: 20, top: 25,
              ),
              child: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Add New Applicant", style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: _fabColor)),
                    const SizedBox(height: 20),
                    TextFormField(
                      onChanged: (val) => providerIdInput = val,
                      decoration: InputDecoration(
                        labelText: "Provider ID *", hintText: "Enter the provider's user ID",
                        prefixIcon: Icon(Icons.person_add_alt_1_rounded, color: _fabColor.withOpacity(0.7)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _fabColor, width: 1.5)),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return "Provider ID is required.";
                        if (int.tryParse(value) == null) return "Please enter a valid number.";
                        return null;
                      },
                    ),
                    const SizedBox(height: 25),
                    ElevatedButton.icon(
                      onPressed: isDialogButtonLoading ? null : () async {
                        if (dialogFormKey.currentState!.validate()) {
                           setDialogState(() => isDialogButtonLoading = true);
                           await _addApplicant(providerIdInput, setDialogState); 
                        }
                      },
                      icon: isDialogButtonLoading 
                          ? const SizedBox(width:18, height:18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                          : const Icon(Icons.send_rounded, color: Colors.white),
                      label: Text(isDialogButtonLoading ? "Submitting..." : "Submit", style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _fabColor,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  void _toggleDeleteMode() {
    setState(() {
      _isDeleteMode = !_isDeleteMode;
      _isHiringMode = false;
      _selectedApplicantIndicesForHiring.clear();
      _selectedApplicantIndicesForDeleting.clear();
      _companyTeams = [];
      _selectedTeamIdForHiring = null;
    });
  }
  
  void _toggleHiringMode() {
    setState(() {
      _isHiringMode = !_isHiringMode;
      _isDeleteMode = false;
      _selectedApplicantIndicesForDeleting.clear();
      if (!_isHiringMode) {
        _selectedApplicantIndicesForHiring.clear();
        _companyTeams = [];
        _selectedTeamIdForHiring = null;
      } else if (_selectedApplicantIndicesForHiring.isNotEmpty) {
        _fetchCompanyTeams();
      }
    });
  }

  Future<void> _fetchCompanyTeams() async {
    if (!_isHiringMode || _selectedApplicantIndicesForHiring.isEmpty) {
      if(mounted) setState(() { _companyTeams = []; _selectedTeamIdForHiring = null; });
      return;
    }
    if (mounted) setState(() => _isLoadingTeams = true);
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      if (mounted) setState(() { _isLoadingTeams = false; _showMessage("Auth token missing.", isError: true); });
      return;
    }
    print("--- ApplicantsPage: Fetching company teams from $_companyTeamsApiUrl ---");
    try {
      final response = await http.get(Uri.parse(_companyTeamsApiUrl), headers: {'Authorization': 'Bearer $token'});
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() { _companyTeams = data['teams'] as List<dynamic>? ?? []; _isLoadingTeams = false; });
      } else { throw Exception('Failed to load company teams (${response.statusCode})'); }
    } catch (e) {
      if (mounted) setState(() { _isLoadingTeams = false; _showMessage("Error fetching teams: $e", isError: true); });
    }
  }

  Future<void> _hireSelectedApplicantsToTeam(int teamId) async {
    if (_selectedApplicantIndicesForHiring.isEmpty) {
      _showMessage("No applicants selected to hire.", isError: true); return;
    }
    final bool? confirmHire = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Confirm Hiring', style: GoogleFonts.lato(fontWeight:FontWeight.bold)),
        content: Text('Hire ${_selectedApplicantIndicesForHiring.length} applicant(s) to this team? They will be removed from this job\'s applicant list.', style: GoogleFonts.lato()),
        actions: [
          TextButton(child: Text('Cancel', style: GoogleFonts.lato()), onPressed: () => Navigator.of(context).pop(false)),
          TextButton(child: Text('Confirm Hire', style: GoogleFonts.lato(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)), onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );

    if (confirmHire != true || !mounted) return;

    setState(() => _isProcessingAction = true);
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      _showMessage("Authentication error.", isError: true);
      if(mounted) setState(() => _isProcessingAction = false);
      return;
    }

    List<Map<String,dynamic>> applicantsToProcess = _selectedApplicantIndicesForHiring.map((index) => _applicants[index]).toList();
    int hireSuccessCount = 0;
    int deleteSuccessCount = 0;
    List<String> processErrorMessages = [];

    for (var applicantData in applicantsToProcess) {
      if (!mounted) break;
      final String providerId = applicantData['provider_id'].toString();
      final String jobApplicationId = applicantData['id'].toString();
      bool hiredSuccessfully = false;

      final addMemberUrl = "$_baseUrl/api/owner/teams/$teamId/members";
      try {
        print("--- Hiring: Adding provider $providerId to team $teamId ---");
        final responseAdd = await http.post(Uri.parse(addMemberUrl), headers: {'Authorization': 'Bearer $token', 'Content-Type':'application/json; charset=UTF-8'}, body: jsonEncode({'providerId': int.parse(providerId)}));
        if (responseAdd.statusCode == 201 || responseAdd.statusCode == 200) {
          hiredSuccessfully = true;
          hireSuccessCount++;
        } else {
          final body = jsonDecode(utf8.decode(responseAdd.bodyBytes));
          processErrorMessages.add("Add to team (${applicantData['name']}): ${body['message'] ?? responseAdd.statusCode}");
        }
      } catch (e) { processErrorMessages.add("Add to team (${applicantData['name']}): $e"); }

      if (hiredSuccessfully) {
        final deleteApplicantUrl = "$_baseUrl/api/owner/applications/$jobApplicationId";
        try {
          print("--- Hiring: Deleting applicant $jobApplicationId from job ---");
          final responseDelete = await http.delete(Uri.parse(deleteApplicantUrl), headers: {'Authorization': 'Bearer $token'});
          if (responseDelete.statusCode == 200 || responseDelete.statusCode == 204) {
            deleteSuccessCount++;
          } else {
             final body = jsonDecode(utf8.decode(responseDelete.bodyBytes));
            processErrorMessages.add("Delete from job (${applicantData['name']}): ${body['message'] ?? responseDelete.statusCode}");
          }
        } catch (e) { processErrorMessages.add("Delete from job (${applicantData['name']}): $e"); }
      }
    }

    if (!mounted) return;

    String finalMessage = "";
    if (hireSuccessCount > 0) finalMessage += "$hireSuccessCount applicant(s) hired. ";
    if (deleteSuccessCount > 0) finalMessage += "$deleteSuccessCount removed from applicants. ";
    
    if (processErrorMessages.isNotEmpty) {
      _showMessage("Process completed with errors: ${processErrorMessages.join('; ')} ${finalMessage.isNotEmpty ? '\nPartial success: $finalMessage' : ''}", isError: true);
    } else if (finalMessage.isNotEmpty) {
      _showMessage(finalMessage.trim(), isSuccess: true);
    } else {
      _showMessage("Hiring process finished, but no changes were made or all operations failed.", isError: true);
    }

    setState(() {
      _isProcessingAction = false;
      _isHiringMode = false;
      _selectedApplicantIndicesForHiring.clear();
      _companyTeams = [];
      _selectedTeamIdForHiring = null;
    });
    await _fetchApplicants(showLoading: false);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Applicants for ${widget.jobName}", style: GoogleFonts.lato(color: _appBarTextColor, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1,),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_appBarBackgroundColor1, _appBarBackgroundColor2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
        elevation: 2,
        iconTheme: IconThemeData(color: _appBarTextColor),
        actions: [
          if (_applicants.isNotEmpty && !_isLoading) ...[
            if (!_isDeleteMode)
              IconButton(
                icon: Icon(_isHiringMode ? Icons.cancel_outlined : Icons.how_to_reg_outlined, color: _appBarTextColor),
                tooltip: _isHiringMode ? "Cancel Hiring" : "Start Hiring Process",
                onPressed: _toggleHiringMode,
              ),
            if (!_isHiringMode)
              IconButton(
                icon: Icon(_isDeleteMode ? Icons.cancel_outlined : Icons.delete_sweep_outlined, color: _appBarTextColor),
                tooltip: _isDeleteMode ? "Cancel Delete" : "Delete Applicants",
                onPressed: _toggleDeleteMode,
              ),
          ],
          if (_isDeleteMode && _selectedApplicantIndicesForDeleting.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              tooltip: "Delete Selected",
              onPressed: _isProcessingAction ? null : _deleteSelectedApplicants,
            ),
        ],
      ),
      floatingActionButton: !_isHiringMode && !_isDeleteMode ? FloatingActionButton.extended(
        onPressed: _isLoading ? null : _showAddApplicantCard, // Disable if page is loading
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: Text("Add Applicant", style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: _fabColor, elevation: 8,
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [_pageBackgroundColor1, _pageBackgroundColor2.withOpacity(0.8), _pageBackgroundColor2], begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.0, 0.4, 1.0])),
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: _fabColor.withOpacity(0.8)))
                  : _errorMessage != null && _applicants.isEmpty
                      ? _buildErrorWidget()
                      : _applicants.isEmpty
                          ? _buildEmptyStateWidget()
                          : _buildApplicantsGrid(),
            ),
            if (_isHiringMode && _selectedApplicantIndicesForHiring.isNotEmpty)
              _buildCompanyTeamsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicantsGrid() {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, _isHiringMode && _selectedApplicantIndicesForHiring.isNotEmpty ? 10 : 80.0), // Adjust padding based on teams section
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.82,
      ),
      itemCount: _applicants.length,
      itemBuilder: (context, index) {
        final applicant = _applicants[index];
        final bool isSelectedForHiring = _isHiringMode && _selectedApplicantIndicesForHiring.contains(index);
        final bool isSelectedForDeleting = _isDeleteMode && _selectedApplicantIndicesForDeleting.contains(index);
        final String imageUrl = applicant['image']?.toString() ?? 'https://via.placeholder.com/120/E0E0E0/B0B0B0?Text=No+Img';

        return BounceInUp(
          delay: Duration(milliseconds: 100 * (index % (MediaQuery.of(context).size.width > 600 ? 9 : 6))),
          duration: const Duration(milliseconds: 400),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Card(
                elevation: (isSelectedForHiring || isSelectedForDeleting) ? 7 : 3.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: (isSelectedForHiring || isSelectedForDeleting)
                      ? BorderSide(color: isSelectedForHiring ? Colors.blueAccent.shade200 : Colors.redAccent, width: 2.5)
                      : BorderSide(color: Colors.grey.shade300, width: 0.5),
                ),
                color: _cardColor,
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () {
                    if (_isHiringMode) {
                      setState(() {
                        isSelectedForHiring 
                          ? _selectedApplicantIndicesForHiring.remove(index) 
                          : _selectedApplicantIndicesForHiring.add(index);
                        if(_selectedApplicantIndicesForHiring.isNotEmpty && _companyTeams.isEmpty && !_isLoadingTeams){
                           _fetchCompanyTeams();
                        } else if (_selectedApplicantIndicesForHiring.isEmpty){
                           setState(() { _companyTeams = []; _selectedTeamIdForHiring = null; });
                        }
                      });
                    } else if (_isDeleteMode) {
                      setState(() { isSelectedForDeleting ? _selectedApplicantIndicesForDeleting.remove(index) : _selectedApplicantIndicesForDeleting.add(index); });
                    } else {
                      _showMessage("Viewing details for ${applicant['name']} (TODO: Navigate to profile)");
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundImage: NetworkImage(imageUrl),
                          radius: 36, backgroundColor: Colors.grey.shade200,
                          onBackgroundImageError: (e,s) { print("Error loading image $imageUrl: $e");},
                          child: imageUrl.contains("placeholder.com") ? Icon(Icons.person_outline_rounded, size: 30, color: Colors.grey.shade500) : null,
                        ),
                        const SizedBox(height: 10),
                        Text(applicant['name']?.toString() ?? 'N/A', style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 15.5, color: _cardTextColor), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                         if (applicant['position'] != null && applicant['position'].toString().isNotEmpty) ...[
                          Text(applicant['position'].toString(), style: GoogleFonts.lato(fontSize: 13, color: Colors.teal.shade700, fontWeight: FontWeight.w500), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                        ],
                        Text(applicant['email']?.toString() ?? 'N/A', style: GoogleFonts.lato(fontSize: 12, color: _cardSecondaryTextColor), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ),
              if (_isHiringMode || _isDeleteMode)
                Positioned(
                  top: 5, right: 5,
                  child: GestureDetector(
                    onTap: () { setState(() { 
                      if(_isHiringMode) isSelectedForHiring ? _selectedApplicantIndicesForHiring.remove(index) : _selectedApplicantIndicesForHiring.add(index);
                      else if(_isDeleteMode) isSelectedForDeleting ? _selectedApplicantIndicesForDeleting.remove(index) : _selectedApplicantIndicesForDeleting.add(index);
                    }); },
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: (isSelectedForHiring || isSelectedForDeleting) ? (_isHiringMode ? Colors.blueAccent.shade200 : Colors.redAccent) : Colors.black.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon( (isSelectedForHiring || isSelectedForDeleting) ? Icons.check_circle_rounded : Icons.circle_outlined, color: Colors.white, size: 22),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildCompanyTeamsSection() {
    if (_isLoadingTeams) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: Center(child: CircularProgressIndicator()));
    }
    if (_companyTeams.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          _selectedApplicantIndicesForHiring.isNotEmpty ? "No teams found for this company to assign applicants." : "Select applicants to see available teams.",
          textAlign: TextAlign.center, style: GoogleFonts.lato(color: _fabColor.withOpacity(0.8), fontSize: 15),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.only(bottom: 10, left:8, right:8),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(12)),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.28), // Max height for teams list
      child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
            child: Text("Select a Team to Hire In:", style: GoogleFonts.lato(fontSize: 16.5, fontWeight: FontWeight.bold, color: _fabColor)),
          ),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _companyTeams.length,
              itemBuilder: (context, index) {
                final team = _companyTeams[index];
                final bool isTeamSelectedForHiring = _selectedTeamIdForHiring == team['id'];
                return Card(
                  elevation: isTeamSelectedForHiring ? 4 : 2,
                  margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                  color: isTeamSelectedForHiring ? _selectedTeamCardColor : _cardColor.withOpacity(0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: isTeamSelectedForHiring ? BorderSide(color: _fabColor, width: 1.8) : BorderSide(color: Colors.grey.shade300, width: 0.7)
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    title: Text(team['name'] ?? 'Unnamed Team', style: GoogleFonts.lato(fontWeight: FontWeight.w500, color: _cardTextColor)),
                    subtitle: Text(team['description'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(color: _cardSecondaryTextColor, fontSize: 12.5)),
                    leading: Icon(Icons.groups_3_outlined, color: _fabColor.withOpacity(0.7)), // Consistent icon
                    trailing: ElevatedButton(
                      onPressed: _isProcessingAction ? null : () {
                        setState(() => _selectedTeamIdForHiring = team['id']); // Select the team
                        _hireSelectedApplicantsToTeam(team['id'] as int); // Then attempt to hire
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _fabColor.withOpacity(isTeamSelectedForHiring ? 1 : 0.85),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: GoogleFonts.lato(fontSize: 12.5, fontWeight: FontWeight.bold)
                      ),
                      child: Text(_isProcessingAction && isTeamSelectedForHiring ? "Hiring..." : "Hire Here"),
                    ),
                    selected: isTeamSelectedForHiring,
                    onTap: () { setState(() => _selectedTeamIdForHiring = team['id']); }, // Allow selecting by tapping list tile
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(child: Padding(padding: const EdgeInsets.all(30.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.cloud_off_rounded, color: _fabColor.withOpacity(0.7), size: 70), const SizedBox(height: 20),
      Text(_errorMessage ?? "An error occurred.", style: GoogleFonts.lato(color: _fabColor, fontSize: 18, fontWeight: FontWeight.w500), textAlign: TextAlign.center), const SizedBox(height: 25),
      ElevatedButton.icon(icon: Icon(Icons.refresh_rounded, color: Colors.white), label: Text("Try Again", style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold)), onPressed: () => _fetchApplicants(showLoading: true), style: ElevatedButton.styleFrom(backgroundColor: _fabColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))
    ])));
  }

  Widget _buildEmptyStateWidget() {
    return Center(child: Padding(padding: const EdgeInsets.all(30.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.people_outline_rounded, color: _fabColor.withOpacity(0.6), size: 70), const SizedBox(height: 20),
      Text("No applicants have applied for this job yet.", style: GoogleFonts.lato(color: _fabColor.withOpacity(0.8), fontSize: 17, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      TextButton.icon(
        icon: Icon(Icons.refresh_rounded, color: _fabColor.withOpacity(0.7)),
        label: Text("Tap to refresh", style: GoogleFonts.lato(color: _fabColor.withOpacity(0.7))),
        onPressed: () => _fetchApplicants(showLoading: true),
      )
    ])));
  }
}