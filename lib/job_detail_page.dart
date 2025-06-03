import 'dart:convert'; // For json.decode and utf8.decode
import 'dart:io';     // For Platform.isAndroid
import 'dart:async';    // For Future, Stream, TimeoutException

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // For custom fonts
import 'package:animate_do/animate_do.dart';     // For animations
import 'package:http/http.dart' as http;        // For HTTP requests
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // For secure token storage
import 'package:intl/intl.dart'; // For date formatting

// --- قم بإنشاء هذا الملف لاحقًا ---
// تأكد من تعديل المسار إذا كان الملف في مكان مختلف
import 'ApplicantsPage.dart'; 

class JobDetailPage extends StatefulWidget {
  final String jobId;               // ID of the job to fetch details for
  final String? initialJobName;      // Optional: To display while loading
  final String? initialCompanyName;  // Optional: To display while loading
 final String companyId;
  const JobDetailPage({
    super.key,
    required this.jobId,
    
    this.initialJobName,
    this.initialCompanyName,
     required this.companyId,
  });

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> with TickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  final String _baseDomain = Platform.isAndroid ? "http://10.0.2.2:3000" : "http://localhost:3000";
  late final String _jobDetailApiUrl; // For fetching this specific job's details
  late final String _deleteJobApiUrl; // For deleting this job
  // URLs for add/update job modals - they might be different
  // For now, Add Job will use a general endpoint, Update Job will use specific job ID
  final String _addJobGeneralApiUrl = "/api/owner/jobs"; 
  late final String _updateJobSpecificApiUrl;


  Map<String, dynamic>? _jobData;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessingAction = false; // For Add, Update, Delete buttons

  // Form keys and controllers for Add/Update Job Modals
  final _jobFormKey = GlobalKey<FormState>();
  final TextEditingController _jobNameController = TextEditingController();
  final TextEditingController _jobDescriptionController = TextEditingController();


  @override
  void initState() {
    super.initState();
    _jobDetailApiUrl = "$_baseDomain/api/owner/jobs/${widget.jobId}";
    _deleteJobApiUrl = "$_baseDomain/api/owner/jobs/${widget.jobId}";
    _updateJobSpecificApiUrl = "$_baseDomain/api/owner/jobs/${widget.jobId}";
    _loadJobDetails();
  }

  @override
  void dispose() {
    _jobNameController.dispose();
    _jobDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleAuthError({String message = 'Session expired. Please log in again.'}) async {
    if (!mounted) return;
    _showMessage(message, isError: true);
    await _storage.deleteAll();
    // if (mounted) { // Assuming LoginScreen exists and is imported
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
      backgroundColor: isError ? Theme.of(context).colorScheme.error : (isSuccess ? Colors.green.shade700 : Colors.teal.shade700),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating, elevation: 6.0, margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _loadJobDetails() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = "Authentication token is missing."; });
      return;
    }
    try {
      final response = await http.get(Uri.parse(_jobDetailApiUrl), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['job'] != null) {
          if (mounted) setState(() { _jobData = data['job'] as Map<String, dynamic>; _isLoading = false; });
        } else { throw Exception(data['message']?.toString() ?? 'Failed to parse job data'); }
      } else if (response.statusCode == 401) { await _handleAuthError(); if (mounted) setState(() { _isLoading = false; _errorMessage = "Unauthorized."; });
      } else if (response.statusCode == 404) { if (mounted) setState(() { _isLoading = false; _errorMessage = "Job not found. It might have been deleted."; });
      } else { throw Exception('Failed to load job details. Status: ${response.statusCode}'); }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString().replaceFirst("Exception: ", ""); });
    }
  }
  
  Future<void> _deleteJob() async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Confirm Delete', style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this job: "${_jobData?['name'] ?? widget.initialJobName ?? 'This Job'}"?\nThis action cannot be undone.', style: GoogleFonts.lato()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        actions: [
          TextButton(child: Text('Cancel', style: GoogleFonts.lato(color: Colors.grey.shade700)), onPressed: () => Navigator.of(context).pop(false)),
          TextButton(style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error), child: Text('Delete Job', style: GoogleFonts.lato(fontWeight: FontWeight.bold)), onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );

    if (confirmDelete != true || !mounted) return;
    setState(() => _isProcessingAction = true);
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      _showMessage("Authentication error.", isError: true);
      if (mounted) setState(() => _isProcessingAction = false);
      return;
    }
    try {
      final response = await http.delete(Uri.parse(_deleteJobApiUrl), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        _showMessage("Job deleted successfully.", isSuccess: true);
        if(mounted) Navigator.of(context).pop(true); // Pop and indicate success
      } else {
        String errorMsg = "Failed to delete job";
        try{ final errorData = jsonDecode(response.body); if(errorData is Map && errorData['message'] != null) errorMsg = errorData['message']; } catch(_){}
        _showMessage("$errorMsg (${response.statusCode})", isError: true);
      }
    } catch (e) { _showMessage("An error occurred: $e", isError: true);
    } finally { if (mounted) setState(() => _isProcessingAction = false); }
  }

  Future<void> _submitJobForm({required bool isUpdate}) async {
    if (!_jobFormKey.currentState!.validate()) return;
    if (!mounted) return;
    setState(() => _isProcessingAction = true);

    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      _showMessage("Authentication error.", isError: true);
      if (mounted) setState(() => _isProcessingAction = false);
      return;
    }

    final Map<String, dynamic> jobPayload = {
      "name": _jobNameController.text.trim(),
      "description": _jobDescriptionController.text.trim(),
      // إذا كنا نضيف وظيفة جديدة، قم بتضمين company_id
      // company_id هنا هو معرف الشركة التي يتم عرض وظائفها حاليًا
      // أو التي يتم إضافة وظيفة جديدة إليها من خلال هذه الصفحة.
      // نفترض أن widget.companyId (المُمرر إلى JobDetailPage) هو معرف الشركة الصحيح.
      if (!isUpdate) "company_id": int.tryParse(widget.companyId),
    };


    final Uri apiUri = isUpdate ? Uri.parse(_updateJobSpecificApiUrl) : Uri.parse("$_baseDomain$_addJobGeneralApiUrl");
    final Future<http.Response> request;

    if (isUpdate) {
      request = http.put(apiUri, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json; charset=UTF-8'}, body: json.encode(jobPayload));
    } else {
      request = http.post(apiUri, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json; charset=UTF-8'}, body: json.encode(jobPayload));
    }
    
    try {
      final response = await request.timeout(const Duration(seconds: 20));
      if (!mounted) return;

      final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
      final String action = isUpdate ? "updated" : "added";

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage("Job $action successfully!", isSuccess: true);
         if (Navigator.canPop(context)) Navigator.of(context).pop(); // Close dialog
        _loadJobDetails(); // Refresh job details (and indirectly, the list on previous page if it re-fetches on pop)
      } else {
        _showMessage(responseBody['message'] ?? "Failed to ${isUpdate ? 'update' : 'add'} job (${response.statusCode})", isError: true);
      }
    } catch (e) {
      _showMessage("An error occurred: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  void _showJobFormModal({bool isUpdate = false}) {
    if (isUpdate && _jobData == null) {
      _showMessage("Job data not available for update.", isError: true);
      return;
    }
    _jobNameController.text = isUpdate ? (_jobData?['name'] ?? '') : '';
    _jobDescriptionController.text = isUpdate ? (_jobData?['description'] ?? '') : '';

    showDialog(
      context: context,
      barrierDismissible: !_isProcessingAction,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setDialogState) { // To update button state
          return AlertDialog(
            title: Text(isUpdate ? "Update Job" : "Add New Job", style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            contentPadding: const EdgeInsets.all(20),
            content: SingleChildScrollView(
              child: Form(
                key: _jobFormKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  TextFormField(
                    controller: _jobNameController,
                    decoration: const InputDecoration(labelText: "Job Title *", prefixIcon: Icon(Icons.title_rounded)),
                    validator: (value) => (value == null || value.isEmpty) ? 'Please enter job title' : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _jobDescriptionController,
                    decoration: const InputDecoration(labelText: "Job Description *", prefixIcon: Icon(Icons.description_outlined), alignLabelWithHint: true),
                    maxLines: 4, minLines: 2,
                    validator: (value) => (value == null || value.isEmpty) ? 'Please enter job description' : null,
                  ),
                ]),
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text("Cancel", style: GoogleFonts.lato(color: Colors.grey.shade700)),
                onPressed: _isProcessingAction ? null : () => Navigator.of(context).pop(),
              ),
              ElevatedButton.icon(
                icon: _isProcessingAction
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(isUpdate ? Icons.save_as_rounded : Icons.add_circle_outline_rounded, size: 20),
                label: Text(_isProcessingAction ? (isUpdate ? "Updating..." : "Adding...") : (isUpdate ? "Save Changes" : "Add Job"), style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
                onPressed: _isProcessingAction ? null : () async {
                  setDialogState(() => _isProcessingAction = true); // Update dialog state for loading
                  await _submitJobForm(isUpdate: isUpdate);
                  if(mounted && _isProcessingAction) { // If an error occurred and didn't pop
                     setDialogState(() => _isProcessingAction = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A5D52), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ],
          );
        });
      },
    ).then((_){
      if(mounted && _isProcessingAction) setState(()=> _isProcessingAction = false); // Reset page state if dialog dismissed
    });
  }


  String _formatDate(String? dateStr) { /* ... */ 
    if (dateStr == null || dateStr.isEmpty) return "N/A";
    try { return DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(dateStr).toLocal()); }
    catch (_) { return dateStr; }
  }
  Widget _buildInfoRow(IconData icon, String label, String? value, {Color? iconColor, Color? labelColor, Color? valueColor}) { /* ... */ 
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: iconColor ?? Colors.teal.shade700), const SizedBox(width: 12),
          Text("$label: ", style: GoogleFonts.lato(fontSize: 15.5, fontWeight: FontWeight.w600, color: labelColor ?? Colors.black.withOpacity(0.8))),
          Expanded(child: Text(value, style: GoogleFonts.lato(fontSize: 15.5, color: valueColor ?? Colors.black.withOpacity(0.7)))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarItemColor = Colors.white;
    String displayJobName = _isLoading ? (widget.initialJobName ?? "Loading Job...") : (_jobData?['name']?.toString() ?? "Job Details");
    String displayCompanyName = _isLoading ? (widget.initialCompanyName ?? "Company") : (_jobData?['company_name']?.toString() ?? "Company");
    String? companyLogoUrl = _jobData?['company_logo']?.toString();
    final List applicantsList = _jobData?['applications'] as List? ?? [];

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFFF2DEC5), Color(0xFFd3c8aa), Color(0xFFa3b29f), Color(0xFF697C6B)], begin: Alignment.topLeft, end: Alignment.bottomRight, stops: [0.0, 0.3, 0.6, 1.0]),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                AppBar(
                  flexibleSpace: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFFa3b29f).withOpacity(0.9), const Color(0xFF697C6B).withOpacity(0.98)], begin: Alignment.centerLeft, end: Alignment.centerRight))),
                  elevation: 2, title: Text(displayJobName, style: GoogleFonts.lato(color: appBarItemColor, fontWeight: FontWeight.bold, fontSize: 20), overflow: TextOverflow.ellipsis),
                  centerTitle: true, iconTheme: IconThemeData(color: appBarItemColor),
                  actions: [ if (!_isLoading && _jobData != null) IconButton(icon: Icon(Icons.refresh_rounded, color: appBarItemColor), onPressed: _loadJobDetails, tooltip: "Refresh Job Details")],
                ),
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: appBarItemColor.withOpacity(0.8)))
                      : _errorMessage != null
                          ? _buildErrorWidget(appBarItemColor)
                          : _jobData == null
                              ? Center(child: Text("No job data available.", style: GoogleFonts.lato(fontSize: 18, color: appBarItemColor.withOpacity(0.7))))
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildJobInfoCard(displayCompanyName, companyLogoUrl),
                                      const SizedBox(height: 28),
                                      _buildApplicantsSection(applicantsList, appBarItemColor),
                                      const SizedBox(height: 30),
                                      _buildActionButtons(), // الأزرار مدمجة هنا
                                    ],
                                  ),
                                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobInfoCard(String companyName, String? companyLogoUrl) { /* ... نفس كود _buildJobInfoCard ... */ 
    return FadeInDown(duration: const Duration(milliseconds: 450), child: Card(
        elevation: 5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), color: Colors.white.withOpacity(0.97),
        child: Padding(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  if (companyLogoUrl != null && companyLogoUrl.isNotEmpty) FadeIn(duration: const Duration(milliseconds: 600), child: CircleAvatar(radius: 26, backgroundColor: Colors.grey.shade100, backgroundImage: NetworkImage(companyLogoUrl), onBackgroundImageError: (e,s){})),
                  if (companyLogoUrl != null && companyLogoUrl.isNotEmpty) const SizedBox(width: 12),
                  Expanded(child: Text(_jobData!['name']?.toString() ?? 'Job Title', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1A2E35)))),
              ]),
              const SizedBox(height: 14), Divider(color: Colors.grey.shade200, thickness: 0.8), const SizedBox(height: 14),
              Text(_jobData!['description']?.toString() ?? 'N/A', style: GoogleFonts.lato(fontSize: 16, color: Colors.black.withOpacity(0.75), height: 1.5)),
              const SizedBox(height: 20),
              _buildInfoRow(Icons.business_rounded, "Company", companyName, iconColor: Colors.indigo.shade300),
              _buildInfoRow(Icons.calendar_month_rounded, "Created", _formatDate(_jobData!['created']?.toString()), iconColor: Colors.green.shade500),
              _buildInfoRow(Icons.edit_calendar_rounded, "Last Updated", _formatDate(_jobData!['updated']?.toString()), iconColor: Colors.orange.shade600),
        ]))));
  }

  Widget _buildApplicantsSection(List applicantsData, Color headerTextColor) {
    return FadeInUp(
      delay: const Duration(milliseconds: 250),
      child: Material(
        color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12), elevation: 0.5,
        child: InkWell(
          onTap: () {
            if (_jobData == null) { _showMessage("Job data loading, please wait.", isError: true); return; }
            if (!mounted) return;
            Navigator.push(context, MaterialPageRoute(builder: (context) => ApplicantsPage(
                  jobId: widget.jobId, jobName: _jobData!['name']?.toString() ?? "Applicants", companyId: widget.companyId,

                  // applicants: applicantsData, // Pass if ApplicantsPage expects it directly
            )));
          },
          borderRadius: BorderRadius.circular(12), splashColor: headerTextColor.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                    Icon(Icons.people_alt_rounded, color: headerTextColor, size: 24), const SizedBox(width: 10),
                    Text("Applicants (${applicantsData.length})", style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: headerTextColor)),
                ]),
                Icon(Icons.arrow_forward_ios_rounded, color: headerTextColor.withOpacity(0.8), size: 18),
            ]),
          ),
        ),
      ),
    );
  }
  
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15.0),
      child: Column(
        children: [
         
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _isProcessingAction || _jobData == null ? null : () => _showJobFormModal(isUpdate: true), // Update Job
            icon: const Icon(Icons.edit_note_rounded, color: Colors.white), label: Text("Update This Job", style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA3B29F), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _isProcessingAction || _jobData == null ? null : _deleteJob, // Delete Job
            icon: _isProcessingAction && ModalRoute.of(context)?.isCurrent == true // Check if current route is this one to show loader for delete
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                : const Icon(Icons.delete_forever_rounded, color: Colors.white),
            label: Text(_isProcessingAction ? "Processing..." : "Delete This Job", style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.shade400, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(Color textColor) { /* ... نفس كود _buildErrorWidget ... */ 
    return Center(child: Padding(padding: const EdgeInsets.all(30.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline_rounded, color: Colors.red.shade200, size: 70), const SizedBox(height: 20),
      Text("Error Loading Job Details", style: GoogleFonts.lato(color: textColor, fontSize: 19, fontWeight: FontWeight.bold), textAlign: TextAlign.center), const SizedBox(height: 10),
      Text(_errorMessage ?? "An unknown error occurred.", style: GoogleFonts.lato(color: textColor.withOpacity(0.8), fontSize: 16), textAlign: TextAlign.center), const SizedBox(height: 25),
      ElevatedButton.icon(icon: Icon(Icons.refresh_rounded, color: Colors.teal.shade800), label: Text("Try Again", style: GoogleFonts.lato(color: Colors.teal.shade800, fontWeight: FontWeight.bold, fontSize: 15)), onPressed: _loadJobDetails, style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.85), padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))
    ])));
  }
}

// --- ApplicantsPage (Placeholder - Create this in a new file: applicants_page.dart) ---
// class ApplicantsPage extends StatelessWidget {
//   final String jobId;
//   final String jobName;
//   // final List applicants; // Optional: if you pass the list directly

//   const ApplicantsPage({
//     super.key,
//     required this.jobId,
//     required this.jobName,
//     // this.applicants = const [],
//   });

//   @override
//   Widget build(BuildContext context) {
//     // TODO: Fetch applicants for this.jobId or display passed applicants
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Applicants for $jobName"),
//         backgroundColor: const Color(0xFF697C6B), // Consistent AppBar color
//       ),
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Color(0xFFF2DEC5), Color(0xFFd3c8aa), Color(0xFFa3b29f), Color(0xFF697C6B)],
//             begin: Alignment.topLeft, end: Alignment.bottomRight, stops: [0.0, 0.3, 0.6, 1.0],
//           ),
//         ),
//         child: Center(
//           child: Text(
//             "Applicants list for Job ID: $jobId will be shown here.\nImplement API call to fetch applicants.",
//             textAlign: TextAlign.center,
//             style: GoogleFonts.lato(fontSize: 18, color: Colors.white70),
//           ),
//         ),
//       ),
//     );
//   }
// }