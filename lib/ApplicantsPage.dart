import 'dart:convert'; // For json.decode and utf8.decode
import 'dart:io';     // For Platform.isAndroid
import 'dart:async';    // For Future, Stream, TimeoutException

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // For custom fonts
import 'package:animate_do/animate_do.dart';     // For animations
import 'package:http/http.dart' as http;        // For HTTP requests
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // For secure token storage
// import 'login_screen.dart'; // Import if needed for _handleAuthError redirection

class ApplicantsPage extends StatefulWidget {
  final String jobId; 
  final String jobName;

  const ApplicantsPage({
    super.key,
    required this.jobId,
    required this.jobName,
  });

  @override
  State<ApplicantsPage> createState() => _ApplicantsPageState();
}

class _ApplicantsPageState extends State<ApplicantsPage> {
  final _storage = const FlutterSecureStorage();
  final List<Map<String, dynamic>> _applicants = [];
  bool _isDeleteMode = false;
  final Set<int> _selectedApplicantIndices = {};
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessingAction = false; // For add button in dialog and delete button in AppBar

  String get _baseUrl => Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000';
  late String _fetchApplicantsUrl;
  late String _addApplicantUrl;

  // UI Colors (consistent with other pages)
  final Color _appBarBackgroundColor1 = const Color(0xFFa3b29f).withOpacity(0.9);
  final Color _appBarBackgroundColor2 = const Color(0xFF697C6B).withOpacity(0.98);
  final Color _pageBackgroundColor1 = const Color(0xFFF2DEC5); // Beige
  final Color _pageBackgroundColor2 = const Color(0xFF697C6B); // Olive/Dark Green
  final Color _appBarTextColor = Colors.white;
  final Color _fabColor = const Color(0xFF4A5D52); // Dark olive for FAB
  final Color _cardColor = Colors.white.withOpacity(0.95);
  final Color _cardTextColor = const Color(0xFF33475B); // Dark slate blue
  final Color _cardSecondaryTextColor = Colors.grey.shade700;

  @override
  void initState() {
    super.initState();
    _fetchApplicantsUrl = "$_baseUrl/api/owner/jobs/${widget.jobId}/applicants";
    _addApplicantUrl = "$_baseUrl/api/owner/jobs/${widget.jobId}/applicants";
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

  Future<void> _handleAuthError() async {
    if (!mounted) return;
    _showMessage('Session expired. Please log in again.', isError: true);
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
      debugPrint("Fetch Applicants Response Body (Raw): $responseBodyString");

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
          if (_applicants.isEmpty) _errorMessage = "No applicants found for this job yet.";
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

      if (response.statusCode == 201) { // 201 Created is the typical success for POST
        try {
          final responseBody = jsonDecode(responseBodyString);
          _showMessage(responseBody['message'] ?? "Applicant added successfully", isSuccess: true);
        } catch (e) { // If response is not JSON but status is 201
           _showMessage("Applicant added (unexpected server response format).", isSuccess: true);
           debugPrint("⚠️ Add applicant: Status 201 but non-JSON response: $responseBodyString");
        }
        if (Navigator.canPop(context)) Navigator.pop(context); // Close dialog
        await _fetchApplicants(showLoading: false); // Refresh list
      } else {
        // --- This is the updated error handling section ---
        try {
          final responseBody = jsonDecode(responseBodyString);
          debugPrint("❌ Add applicant error from server: ${responseBody.toString()}");
          _showMessage(responseBody['message']?.toString() ?? "Failed to add applicant (${response.statusCode})", isError: true);
        } catch (e) {
          debugPrint("❌ Error parsing server error message: $e. Raw response: $responseBodyString");
          _showMessage("Failed to add applicant (${response.statusCode}). Server sent an unexpected response format.", isError: true);
        }
        // --- End of updated error handling section ---
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
    if (_selectedApplicantIndices.isEmpty) {
      _showMessage("No applicants selected for deletion.", isError: true);
      return;
    }
    
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Confirm Deletion', style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete ${_selectedApplicantIndices.length} selected applicant(s)? This action cannot be undone.', style: GoogleFonts.lato()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(child: Text('Cancel', style: GoogleFonts.lato(color: Colors.grey.shade700)), onPressed: () => Navigator.of(context).pop(false)),
          TextButton(child: Text('Delete', style: GoogleFonts.lato(color: Colors.red, fontWeight: FontWeight.bold)), onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );

    if (confirmDelete != true || !mounted) return;

    setState(() => _isProcessingAction = true); // Global indicator for AppBar delete button

    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      _showMessage("Authentication error.", isError: true);
      if(mounted) setState(() => _isProcessingAction = false);
      return;
    }

    List<int> applicantsToDeleteIds = _selectedApplicantIndices.map((index) => _applicants[index]['id'] as int).toList();
    
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
      _selectedApplicantIndices.clear();
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
                           // Pass the dialog's own StateSetter to _addApplicant
                           await _addApplicant(providerIdInput, setDialogState); 
                           // If _addApplicant encounters an error and doesn't pop, reset here
                           if(mounted && isDialogButtonLoading && Navigator.canPop(context)) {
                              // This case should ideally be handled by _addApplicant's finally block
                              // or if addApplicant decides not to pop due to an error it shows
                           }
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
      if (!_isDeleteMode) {
        _selectedApplicantIndices.clear();
      }
    });
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
          if (_applicants.isNotEmpty && !_isLoading)
            IconButton(
              icon: Icon(_isDeleteMode ? Icons.close_rounded : Icons.delete_outline_rounded, color: _appBarTextColor),
              tooltip: _isDeleteMode ? "Cancel Delete Mode" : "Enable Delete Mode",
              onPressed: _toggleDeleteMode,
            ),
          if (_isDeleteMode && _selectedApplicantIndices.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              tooltip: "Delete Selected",
              onPressed: _isProcessingAction ? null : _deleteSelectedApplicants,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddApplicantCard,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: Text("Add Applicant", style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: _fabColor,
        elevation: 8,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_pageBackgroundColor1, _pageBackgroundColor2.withOpacity(0.8), _pageBackgroundColor2], begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.0, 0.4, 1.0]),
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: _fabColor.withOpacity(0.8)))
            : _errorMessage != null && _applicants.isEmpty
                ? _buildErrorWidget()
                : _applicants.isEmpty
                    ? _buildEmptyStateWidget()
                    : _buildApplicantsGrid(),
      ),
    );
  }

  Widget _buildApplicantsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.82,
      ),
      itemCount: _applicants.length,
      itemBuilder: (context, index) {
        final applicant = _applicants[index];
        final isSelected = _selectedApplicantIndices.contains(index);
        final String imageUrl = applicant['image']?.toString() ?? 'https://via.placeholder.com/120/E0E0E0/B0B0B0?Text=No+Img';

        return BounceInUp(
          delay: Duration(milliseconds: 100 * (index % (MediaQuery.of(context).size.width > 600 ? 9 : 6))),
          duration: const Duration(milliseconds: 400),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Card(
                elevation: _isDeleteMode && isSelected ? 7 : 3.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: _isDeleteMode && isSelected
                      ? const BorderSide(color: Colors.redAccent, width: 2.5)
                      : BorderSide(color: Colors.grey.shade300, width: 0.5),
                ),
                color: _cardColor,
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () {
                    if (_isDeleteMode) {
                      setState(() { isSelected ? _selectedApplicantIndices.remove(index) : _selectedApplicantIndices.add(index); });
                    } else {
                      _showMessage("Viewing details for ${applicant['name']}");
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundImage: NetworkImage(imageUrl),
                          radius: 36, backgroundColor: Colors.grey.shade200,
                          onBackgroundImageError: (e,s) { print("Error loading image $imageUrl: $e");},
                          child: imageUrl.contains("placeholder.com") ? Icon(Icons.person_outline_rounded, size: 30, color: Colors.grey.shade500) : null,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          applicant['name']?.toString() ?? 'N/A',
                          style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 15.5, color: _cardTextColor),
                          textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                         if (applicant['position'] != null && applicant['position'].toString().isNotEmpty) ...[
                          Text(
                            applicant['position'].toString(),
                            style: GoogleFonts.lato(fontSize: 13, color: Colors.teal.shade700, fontWeight: FontWeight.w500), // Using _cardIconColor for position
                            textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          applicant['email']?.toString() ?? 'N/A',
                          style: GoogleFonts.lato(fontSize: 12, color: _cardSecondaryTextColor),
                          textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_isDeleteMode)
                Positioned(
                  top: 5, right: 5,
                  child: GestureDetector(
                    onTap: () { setState(() { isSelected ? _selectedApplicantIndices.remove(index) : _selectedApplicantIndices.add(index); }); },
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: isSelected ? Colors.redAccent : Colors.black.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon( isSelected ? Icons.check_circle_rounded : Icons.circle_outlined, color: Colors.white, size: 22),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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
      Icon(Icons.people_outline, color: _fabColor.withOpacity(0.6), size: 70), const SizedBox(height: 20),
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