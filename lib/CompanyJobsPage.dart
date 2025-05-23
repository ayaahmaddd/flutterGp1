import 'dart:convert'; // For json.decode and utf8.decode
import 'dart:io';     // For Platform.isAndroid
import 'dart:async';    // For Future, Stream, TimeoutException

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // For custom fonts
import 'package:animate_do/animate_do.dart';     // For animations
import 'package:http/http.dart' as http;        // For HTTP requests
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // For secure token storage
import 'package:intl/intl.dart'; // For date formatting

// Ensure this import path is correct for your project structure
import 'job_detail_page.dart'; // Page to navigate to for job details
// import 'login_screen.dart'; // Import if needed for _handleAuthError redirection

class CompanyJobsPage extends StatefulWidget {
  final String companyId;
  final String companyName;

  const CompanyJobsPage({
    super.key,
    required this.companyId,
    required this.companyName,
  });

  @override
  State<CompanyJobsPage> createState() => _CompanyJobsPageState();
}

class _CompanyJobsPageState extends State<CompanyJobsPage> {
  final _storage = const FlutterSecureStorage();
  // Adjust base domain for your development/production environment
  final String _baseDomain = Platform.isAndroid ? "http://10.0.2.2:3000" : "http://localhost:3000";
  late final String _jobsApiUrl; // For GETTING jobs for a company
  late final String _addJobApiUrl;  // For POSTING a new job

  List<dynamic> _jobs = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Form key and controllers for the "Add New Job" dialog
  final _addJobFormKey = GlobalKey<FormState>();
  final TextEditingController _newJobNameController = TextEditingController();
  final TextEditingController _newJobDescriptionController = TextEditingController();
  bool _isAddingJob = false;


  // --- Card and Content Colors ---
  // Icon for job cards
  final IconData _defaultJobIcon = Icons.work_outline_rounded;
  // Colors for content inside the light/white job cards
  final Color _cardBackgroundColor = Colors.white.withOpacity(0.96); // Light card color
  final Color _cardTitleColor = const Color(0xFF2E3D4E);         // Dark blue-grey for titles
  final Color _cardSubtitleColor = Colors.black54;               // Standard grey for subtitles
  final Color _cardIconColor = Colors.teal.shade700;           // A distinct teal/green for icons
  final Color _cardDateColor = Colors.grey.shade600;             // Slightly darker grey for dates
  final Color _cardArrowColor = Colors.grey.shade400;            // Lighter arrow for subtle look
  final Color _fabColor = const Color(0xFF4A5D52); // Color for FAB and AppBar items

  @override
  void initState() {
    super.initState();
    _jobsApiUrl = "$_baseDomain/api/owner/companies/${widget.companyId}/jobs";
    _addJobApiUrl = "$_baseDomain/api/owner/jobs"; // Endpoint for adding a new job
    _loadJobs();
  }

  @override
  void dispose() {
    _newJobNameController.dispose();
    _newJobDescriptionController.dispose();
    super.dispose();
  }


  Future<void> _handleAuthError() async {
    if (!mounted) return;
    _showMessage('Session expired. Please log in again.', isError: true);
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_id');
    await _storage.delete(key: 'user_type');
    // Assuming LoginScreen page exists for redirection on auth error
    // if (mounted) {
    //   Navigator.of(context).pushAndRemoveUntil(
    //       MaterialPageRoute(builder: (context) => const LoginScreen()), // Replace with your LoginScreen
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

  Future<void> _loadJobs({bool showLoadingIndicator = true}) async {
    if (!mounted) return;
    if (showLoadingIndicator) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        // _jobs = []; // Keep existing jobs for smoother refresh if not initial load
      });
    }

    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = "Authentication token missing."; });
      return;
    }

    print("--- CompanyJobsPage: Fetching jobs from $_jobsApiUrl for company ${widget.companyId} ---");

    try {
      final response = await http.get(Uri.parse(_jobsApiUrl), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) setState(() { _jobs = data['jobs'] as List<dynamic>? ?? []; _isLoading = false; _errorMessage = _jobs.isEmpty ? "No jobs posted by this company yet." : null; });
      } else if (response.statusCode == 401) { await _handleAuthError();
      } else {
        String errorMsg = "Failed to load jobs (${response.statusCode})";
        try { final errorData = jsonDecode(utf8.decode(response.bodyBytes)); if (errorData is Map && errorData['message'] != null) errorMsg = errorData['message'] as String; } catch(_){}
        if(mounted) setState(() { _errorMessage = errorMsg; _isLoading = false; _jobs = []; });
      }
    } on SocketException {
      if (mounted) setState(() { _errorMessage = "Network error. Please check your connection."; _isLoading = false; _jobs = []; });
    } on TimeoutException {
      if (mounted) setState(() { _errorMessage = "Connection timed out. Please try again."; _isLoading = false; _jobs = []; });
    } catch (e) {
      print("!!! CompanyJobsPage: LoadJobs Exception: $e");
      if (mounted) setState(() { _errorMessage = "Error loading jobs: ${e.toString()}"; _isLoading = false; _jobs = []; });
    }
  }

  Future<void> _addNewJob() async {
    if (!_addJobFormKey.currentState!.validate()) {
      return;
    }
    if (!mounted) return;
    
    // Use setDialogState if called from within StatefulBuilder, otherwise use setState
    // For simplicity, we'll assume _isAddingJob is managed by the main page's setState for this version
    // If _showAddJobDialog's StatefulBuilder's setDialogState is used, this setState here for _isAddingJob is redundant for the dialog button.
    setState(() => _isAddingJob = true);


    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      _showMessage("Authentication error. Cannot add job.", isError: true);
      if (mounted) setState(() => _isAddingJob = false);
      return;
    }

    final Map<String, dynamic> newJobData = {
      "name": _newJobNameController.text.trim(),
      "description": _newJobDescriptionController.text.trim(),
      "company_id": int.tryParse(widget.companyId),
    };

    print("--- CompanyJobsPage: Adding new job: $newJobData to $_addJobApiUrl ---");

    try {
      final response = await http.post(
        Uri.parse(_addJobApiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode(newJobData),
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showMessage("New job added successfully!", isSuccess: true);
        _newJobNameController.clear();
        _newJobDescriptionController.clear();
        if (Navigator.canPop(context)) { // Close the dialog if it's open
           Navigator.of(context).pop();
        }
        await _loadJobs(showLoadingIndicator: false); 
      } else {
        String errorMsg = "Failed to add job";
        try { final errorData = jsonDecode(utf8.decode(response.bodyBytes)); if (errorData is Map && errorData['message'] != null) errorMsg = errorData['message'] as String; } catch(_){}
        _showMessage("$errorMsg (${response.statusCode})", isError: true);
      }
    } catch (e) {
      print("!!! CompanyJobsPage: AddNewJob Exception: $e");
      _showMessage("An error occurred while adding job: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() => _isAddingJob = false);
      }
    }
  }

  void _showAddJobDialog() {
    _newJobNameController.clear();
    _newJobDescriptionController.clear();
    // _errorMessage = null; // This _errorMessage is for the page, not the dialog specifically

    showDialog(
      context: context,
      barrierDismissible: !_isAddingJob,
      builder: (BuildContext context) {
        return StatefulBuilder( // Use StatefulBuilder to manage _isAddingJob for the dialog's button state
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Add New Job", style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: _cardTitleColor)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              backgroundColor: Colors.white.withOpacity(0.98),
              contentPadding: const EdgeInsets.all(20),
              content: SingleChildScrollView(
                child: Form(
                  key: _addJobFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextFormField(
                        controller: _newJobNameController,
                        decoration: InputDecoration(
                          labelText: "Job Title *", 
                          prefixIcon: Icon(Icons.title_rounded, color: _fabColor.withOpacity(0.7)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _fabColor, width: 1.5)),
                        ),
                        validator: (value) => (value == null || value.isEmpty) ? 'Please enter a job title' : null,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _newJobDescriptionController,
                        decoration: InputDecoration(
                          labelText: "Job Description *", 
                          prefixIcon: Icon(Icons.description_outlined, color: _fabColor.withOpacity(0.7)),
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _fabColor, width: 1.5)),
                        ),
                        maxLines: 3,
                        validator: (value) => (value == null || value.isEmpty) ? 'Please enter a job description' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text("Cancel", style: GoogleFonts.lato(color: Colors.grey.shade700)),
                  onPressed: _isAddingJob ? null : () => Navigator.of(context).pop(),
                ),
                ElevatedButton.icon(
                  icon: _isAddingJob
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_circle_outline_rounded, size: 20),
                  label: Text(_isAddingJob ? "Adding..." : "Add Job", style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
                  onPressed: _isAddingJob ? null : () async {
                      if (_addJobFormKey.currentState!.validate()) {
                        setDialogState(() => _isAddingJob = true); 
                        await _addNewJob();
                        // If _addNewJob did not pop the dialog on success (e.g. due to error), 
                        // or if it's still mounted and _isAddingJob is true (error case), reset dialog state.
                        if (mounted && _isAddingJob) { 
                           setDialogState(() => _isAddingJob = false);
                        }
                      }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _fabColor, 
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                  ),
                ),
              ],
            );
          }
        );
      },
    ).then((_) {
      if (mounted && _isAddingJob) { // Ensure _isAddingJob is reset if dialog is dismissed externally
        setState(() => _isAddingJob = false);
      }
    });
  }

  String _formatJobDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try { return DateFormat('dd MMM yyyy').format(DateTime.parse(dateString).toLocal()); }
    catch (_) { return dateString.length > 10 ? dateString.substring(0, 10) : dateString; }
  }

  Widget _buildJobCard(Map<String, dynamic> job, int index) {
    IconData jobIcon = _defaultJobIcon;
    final String currentJobId = job['id']?.toString() ?? '';
    final String currentJobName = job['name']?.toString() ?? 'Untitled Job';

    return FadeInUp(
      delay: Duration(milliseconds: 120 * (index + 1)), duration: const Duration(milliseconds: 450),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 4,
        margin: const EdgeInsets.symmetric(vertical: 9, horizontal: 8), color: _cardBackgroundColor,
        child: InkWell(
          onTap: () {
            if (currentJobId.isNotEmpty) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => JobDetailPage(jobId: currentJobId, initialJobName: currentJobName, initialCompanyName: widget.companyName,companyId: widget.companyId,)));
            } else { _showMessage("Error: Job ID is missing.", isError: true); }
          },
          borderRadius: BorderRadius.circular(15), splashColor: _cardIconColor.withOpacity(0.1), highlightColor: _cardIconColor.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 18.0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _cardIconColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(jobIcon, size: 28, color: _cardIconColor)),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(currentJobName, style: GoogleFonts.lato(fontSize: 17.5, fontWeight: FontWeight.w600, color: _cardTitleColor)),
                      const SizedBox(height: 5),
                      if (job['description'] != null && job['description'].toString().isNotEmpty) ...[
                        Text(job['description'].toString(), style: GoogleFonts.lato(fontSize: 14.2, color: _cardSubtitleColor, height: 1.35), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 10),
                      ],
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text("Created: ${_formatJobDate(job['created']?.toString())}", style: GoogleFonts.lato(fontSize: 11.8, color: _cardDateColor)),
                          Text("Updated: ${_formatJobDate(job['updated']?.toString())}", style: GoogleFonts.lato(fontSize: 11.8, color: _cardDateColor)),
                      ]),
                  ]),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios_rounded, size: 18, color: _cardArrowColor),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarItemColor = Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.companyName} - Jobs", style: GoogleFonts.lato(color: appBarItemColor, fontWeight: FontWeight.w700, fontSize: 22), overflow: TextOverflow.ellipsis),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFa3b29f), Color(0xFF697C6B)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        elevation: 2, iconTheme: IconThemeData(color: appBarItemColor),
        actions: [IconButton(icon: Icon(Icons.refresh_rounded, color: appBarItemColor), onPressed: _isLoading ? null : _loadJobs, tooltip: "Refresh Jobs")],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFFF2DEC5), Color(0xFFd3c8aa), Color(0xFFa3b29f), Color(0xFF697C6B)], begin: Alignment.topLeft, end: Alignment.bottomRight, stops: [0.0, 0.3, 0.6, 1.0]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.85))))
                    : _errorMessage != null
                        ? _buildErrorWidget(appBarItemColor)
                        : RefreshIndicator(
                            onRefresh: () => _loadJobs(showLoadingIndicator: true), // Ensure full loading indicator on manual refresh
                            color: Colors.white, backgroundColor: const Color(0xFF556B2F).withOpacity(0.9),
                            child: _jobs.isEmpty
                                ? _buildEmptyJobsWidget(appBarItemColor)
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(10, 15, 10, 80),
                                    itemCount: _jobs.length,
                                    itemBuilder: (context, index) => _buildJobCard(_jobs[index], index),
                                  ),
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddJobDialog,
        label: Text("Add Job", style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: Colors.white)),
        icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
        backgroundColor: _fabColor,
        elevation: 8,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildErrorWidget(Color textColor) {
    return Center(child: Padding(padding: const EdgeInsets.all(30.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline_rounded, color: Colors.orange.shade300, size: 75), const SizedBox(height: 22),
          Text(_errorMessage!, style: GoogleFonts.lato(color: textColor, fontSize: 18.5, fontWeight: FontWeight.w500), textAlign: TextAlign.center), const SizedBox(height: 28),
          ElevatedButton.icon(
            icon: const Icon(Icons.replay_circle_filled_rounded, color: Color(0xFF3A4D39)), label: Text("Try Again", style: GoogleFonts.lato(color: Color(0xFF3A4D39), fontWeight: FontWeight.bold, fontSize: 15)),
            onPressed: () => _loadJobs(showLoadingIndicator: true), // Ensure full loading on try again
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.92), padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          )
    ])));
  }

  Widget _buildEmptyJobsWidget(Color textColor) {
    return Center(child: Padding(padding: const EdgeInsets.all(30.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.search_off_rounded, color: textColor.withOpacity(0.7), size: 75), const SizedBox(height: 22),
          Text("No jobs posted by this company yet.", style: GoogleFonts.lato(color: textColor.withOpacity(0.9), fontSize: 18.5, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TextButton.icon( // Added a refresh button here as well for convenience
            icon: Icon(Icons.refresh_rounded, color: textColor.withOpacity(0.8)),
            label: Text("Tap to refresh", style: GoogleFonts.lato(color: textColor.withOpacity(0.8))),
            onPressed: () => _loadJobs(showLoadingIndicator: true),
          )
    ])));
  }
}