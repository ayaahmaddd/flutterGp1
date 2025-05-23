// company_teams_page.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

// --- تأكد من أن هذا المسار صحيح لمشروعك ---
import 'team_detail_page.dart'; 
// import 'login_screen.dart'; // إذا احتجت لإعادة التوجيه عند خطأ المصادقة

class CompanyTeamsPage extends StatefulWidget {
  final String companyId;
  final String companyName;

  const CompanyTeamsPage({
    super.key,
    required this.companyId,
    required this.companyName,
  });

  @override
  State<CompanyTeamsPage> createState() => _CompanyTeamsPageState();
}

class _CompanyTeamsPageState extends State<CompanyTeamsPage> {
  final _storage = const FlutterSecureStorage();
  final String _baseDomain = Platform.isAndroid ? "http://10.0.2.2:3000" : "http://localhost:3000";
  late final String _teamsApiUrl; // لجلب فرق الشركة
  late final String _addTeamApiUrl;  // لإضافة فريق جديد للشركة

  List<dynamic> _teams = [];
  bool _isLoading = true;
  String? _errorMessage;

  // مفتاح النموذج ووحدات التحكم لنافذة إضافة فريق جديد
  final _addTeamFormKey = GlobalKey<FormState>();
  final TextEditingController _newTeamNameController = TextEditingController();
  final TextEditingController _newTeamDescriptionController = TextEditingController();
  bool _isAddingTeam = false; // لإدارة حالة زر الإضافة في الـ Dialog

  // تعريفات الألوان والأيقونات للواجهة
  final IconData _defaultTeamIcon = Icons.groups_2_outlined; 
  final Color _cardBackgroundColor = Colors.white.withOpacity(0.96);
  final Color _cardTitleColor = const Color(0xFF2E3D4E);
  final Color _cardSubtitleColor = Colors.black54;
  final Color _cardIconColor = Colors.blueGrey.shade700; 
  final Color _cardDateColor = Colors.grey.shade600; // لم نعد نستخدمه في بطاقة الفريق
  final Color _cardArrowColor = Colors.grey.shade400;
  final Color _fabColor = const Color(0xFF4A5D52); 
  final Color _appBarTextColor = Colors.white; // لون نصوص وأيقونات AppBar

  @override
  void initState() {
    super.initState();
    // تحديد نقاط نهاية الـ API
    _teamsApiUrl = "$_baseDomain/api/owner/companies/${widget.companyId}/teams";
    _addTeamApiUrl = "$_baseDomain/api/owner/companies/${widget.companyId}/teams"; // POST request to the same URL
    _loadTeams();
  }

  @override
  void dispose() {
    _newTeamNameController.dispose();
    _newTeamDescriptionController.dispose();
    super.dispose();
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

  Future<void> _loadTeams({bool showLoadingIndicator = true}) async {
    if (!mounted) return;
    if (showLoadingIndicator) {
      setState(() { _isLoading = true; _errorMessage = null; });
    }
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = "Authentication token missing."; });
      return;
    }
    print("--- CompanyTeamsPage: Fetching teams from $_teamsApiUrl ---");
    try {
      final response = await http.get(Uri.parse(_teamsApiUrl), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() { 
          _teams = data['teams'] as List<dynamic>? ?? []; 
          _isLoading = false; 
          _errorMessage = _teams.isEmpty ? "No teams created for this company yet." : null; 
        });
        }
      } else if (response.statusCode == 401) { await _handleAuthError();
      } else {
        String errorMsg = "Failed to load teams (${response.statusCode})";
        try { final errorData = jsonDecode(utf8.decode(response.bodyBytes)); if (errorData is Map && errorData['message'] != null) errorMsg = errorData['message'] as String; } catch(_){}
        if(mounted) setState(() { _errorMessage = errorMsg; _isLoading = false; _teams = []; });
      }
    } catch (e) {
      print("!!! CompanyTeamsPage: LoadTeams Exception: $e");
      if (mounted) setState(() { _errorMessage = "Error loading teams: ${e.toString().replaceFirst("Exception: ", "")}"; _isLoading = false; _teams = []; });
    }
  }

  Future<void> _addNewTeam() async {
    if (!_addTeamFormKey.currentState!.validate()) return;
    if (!mounted) return;
    
    // هذا الـ setState يؤثر على حالة الصفحة الرئيسية (مثلاً، إذا أردت إظهار مؤشر عام)
    // الـ Dialog له StatefulBuilder لإدارة حالة زر الإضافة داخله.
    setState(() => _isAddingTeam = true); // هذا يمكن أن يكون مفيدًا لتعطيل زر FAB الرئيسي مثلاً

    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      _showMessage("Authentication error.", isError: true);
      if (mounted) setState(() => _isAddingTeam = false);
      return;
    }
    final Map<String, dynamic> newTeamData = {
      "name": _newTeamNameController.text.trim(),
      "description": _newTeamDescriptionController.text.trim(),
    };
    print("--- CompanyTeamsPage: Adding new team: $newTeamData to $_addTeamApiUrl ---");
    try {
      final response = await http.post(
        Uri.parse(_addTeamApiUrl),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode(newTeamData),
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;
      final responseBodyString = utf8.decode(response.bodyBytes);
      print("Add Team Response Status: ${response.statusCode}");
      print("Add Team Response Body (Raw): $responseBodyString");

      if (response.statusCode == 201 || response.statusCode == 200) { // 201 Created
        _showMessage("New team added successfully!", isSuccess: true);
        _newTeamNameController.clear(); 
        _newTeamDescriptionController.clear();
        if (Navigator.canPop(context)) Navigator.of(context).pop(); // أغلق الـ Dialog
        await _loadTeams(showLoadingIndicator: false); // تحديث القائمة
      } else {
        String errorMsg = "Failed to add team";
        try { final errorData = jsonDecode(responseBodyString); if (errorData is Map && errorData['message'] != null) errorMsg = errorData['message'] as String; } catch(_){}
        _showMessage("$errorMsg (${response.statusCode})", isError: true);
      }
    } catch (e) {
      print("!!! CompanyTeamsPage: AddNewTeam Exception: $e");
      _showMessage("An error occurred: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isAddingTeam = false);
    }
  }

  void _showAddTeamDialog() {
    _newTeamNameController.clear(); 
    _newTeamDescriptionController.clear();
    // لا نحتاج لمسح _errorMessage الخاص بالصفحة هنا

    showDialog(
      context: context, 
      barrierDismissible: _isAddingTeam, // استخدم _isAddingTeam الخاص بالصفحة هنا إذا أردت تعطيل الإغلاق العام
      builder: (BuildContext dialogContext) { // استخدام dialogContext
        // متغير حالة محلي للـ Dialog لإدارة زر الإرسال الخاص به
        bool isDialogButtonLoading = false; 
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Add New Team", style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: _cardTitleColor)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              backgroundColor: Colors.white.withOpacity(0.98),
              contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 10), // تقليل الحشو السفلي قليلاً
              content: SingleChildScrollView(
                child: Form(
                  key: _addTeamFormKey,
                  child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    TextFormField(
                      controller: _newTeamNameController,
                      decoration: InputDecoration(labelText: "Team Name *", prefixIcon: Icon(Icons.groups_rounded, color: _fabColor.withOpacity(0.7)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _fabColor, width: 1.5))),
                      validator: (value) => (value == null || value.isEmpty) ? 'Please enter a team name' : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _newTeamDescriptionController,
                      decoration: InputDecoration(labelText: "Team Description (Optional)", prefixIcon: Icon(Icons.description_outlined, color: _fabColor.withOpacity(0.7)), alignLabelWithHint: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _fabColor, width: 1.5))),
                      maxLines: 3,
                    ),
                  ]),
                ),
              ),
              actionsAlignment: MainAxisAlignment.end,
              actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              actions: <Widget>[
                TextButton(child: Text("Cancel", style: GoogleFonts.lato(color: Colors.grey.shade700)), onPressed: isDialogButtonLoading ? null : () => Navigator.of(dialogContext).pop()),
                ElevatedButton.icon(
                  icon: isDialogButtonLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add_circle_outline_rounded, size: 20),
                  label: Text(isDialogButtonLoading ? "Adding..." : "Add Team", style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
                  onPressed: isDialogButtonLoading ? null : () async { 
                    if (_addTeamFormKey.currentState!.validate()) { 
                      setDialogState(() => isDialogButtonLoading = true); 
                      await _addNewTeam(); 
                      if (mounted && isDialogButtonLoading) { // إذا لم يتم إغلاق الـ Dialog بواسطة _addNewTeam (بسبب خطأ مثلاً)
                        setDialogState(() => isDialogButtonLoading = false); 
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _fabColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ],
            );
          });
      },
    ).then((valueFromDialog){ // هذا الـ .then يتم استدعاؤه بعد إغلاق الـ Dialog
      // التأكد من أن _isAddingTeam (الخاص بالصفحة) يعود إلى false إذا كان الـ Dialog قد أُغلق
      // ولم يقم _addNewTeam بإعادة تعيينه (مثلاً، إذا أغلق المستخدم الـ Dialog يدويًا)
      if (mounted && _isAddingTeam) {
        setState(() => _isAddingTeam = false);
      }
    });
  }

  String _formatTeamDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try { return DateFormat('dd MMM yyyy').format(DateTime.parse(dateString).toLocal()); }
    catch (_) { return dateString.length > 10 ? dateString.substring(0, 10) : dateString; }
  }

  Widget _buildTeamCard(Map<String, dynamic> team, int index) {
    IconData teamIcon = _defaultTeamIcon;
    final String currentTeamId = team['id']?.toString() ?? '';
    final String currentTeamName = team['name']?.toString() ?? 'Untitled Team';
    final int memberCount = team['member_count'] ?? 0; // من استجابة API للفرق

    return FadeInUp(
      delay: Duration(milliseconds: 120 * (index + 1)), duration: const Duration(milliseconds: 450),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 4,
        margin: const EdgeInsets.symmetric(vertical: 9, horizontal: 8), color: _cardBackgroundColor,
        child: InkWell(
          onTap: () async { // جعل الدالة async لاستقبال القيمة من .then
            if (currentTeamId.isNotEmpty) {
              // الانتقال إلى صفحة تفاصيل الفريق وتوقع قيمة عند العودة
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TeamDetailPage(
                    teamId: currentTeamId,
                    initialTeamName: currentTeamName,
                    companyId: widget.companyId,
                    companyName: widget.companyName,

                    // companyId: widget.companyId, // تمرير هذا إذا كانت TeamDetailPage تحتاجه مباشرة
                  )
                ),
              );
              // إذا عادت TeamDetailPage بقيمة true (يعني تم تغيير، مثل إضافة عضو)
              if (result == true && mounted) { 
                _loadTeams(showLoadingIndicator: false); // تحديث قائمة الفرق بسلاسة
              }
            } else { _showMessage("Error: Team ID is missing.", isError: true); }
          },
          borderRadius: BorderRadius.circular(15), splashColor: _cardIconColor.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 18.0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _cardIconColor.withOpacity(0.12), shape: BoxShape.circle), child: Icon(teamIcon, size: 28, color: _cardIconColor)),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(currentTeamName, style: GoogleFonts.lato(fontSize: 17.5, fontWeight: FontWeight.w600, color: _cardTitleColor)),
                      const SizedBox(height: 5),
                      if (team['description'] != null && team['description'].toString().isNotEmpty) ...[
                        Text(team['description'].toString(), style: GoogleFonts.lato(fontSize: 14.2, color: _cardSubtitleColor, height: 1.35), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                      ],
                      Text("Members: $memberCount", style: GoogleFonts.lato(fontSize: 12, color: _cardDateColor, fontWeight: FontWeight.w500)),
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
      title: Text(
  "${widget.companyName}  Teams", // <-- التصحيح هنا
  style: GoogleFonts.lato(
      color: _appBarTextColor, // استخدام اللون المعرف _appBarTextColor
      fontWeight: FontWeight.w700,
      fontSize: 22),
  overflow: TextOverflow.ellipsis,
),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFa3b29f), Color(0xFF697C6B)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        elevation: 2, iconTheme: IconThemeData(color: appBarItemColor),
        actions: [IconButton(icon: Icon(Icons.refresh_rounded, color: appBarItemColor), onPressed: _isLoading ? null : _loadTeams, tooltip: "Refresh Teams")],
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
                    : _errorMessage != null && _teams.isEmpty // عرض الخطأ فقط إذا لم تكن هناك فرق لعرضها
                        ? _buildErrorWidget(appBarItemColor)
                        : RefreshIndicator(
                            onRefresh: () => _loadTeams(showLoadingIndicator: true),
                            color: Colors.white, backgroundColor: const Color(0xFF556B2F).withOpacity(0.9),
                            child: _teams.isEmpty && _errorMessage == null // الحالة التي لا يوجد فيها فرق ولا يوجد خطأ
                                ? _buildEmptyStateWidget(appBarItemColor)
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(10, 15, 10, 80),
                                    itemCount: _teams.length,
                                    itemBuilder: (context, index) => _buildTeamCard(_teams[index], index),
                                  ),
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _showAddTeamDialog, // تعطيل الزر أثناء التحميل العام للصفحة
        label: Text("Add Team", style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: Colors.white)),
        icon: const Icon(Icons.group_add_rounded, color: Colors.white),
        backgroundColor: _fabColor,
        elevation: 8,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildErrorWidget(Color textColor) {
    return Center(child: Padding(padding: const EdgeInsets.all(30.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline_rounded, color: Colors.orange.shade300, size: 75), const SizedBox(height: 22),
          Text(_errorMessage ?? "An error occurred.", style: GoogleFonts.lato(color: textColor, fontSize: 18.5, fontWeight: FontWeight.w500), textAlign: TextAlign.center), const SizedBox(height: 28),
          ElevatedButton.icon(
            icon: const Icon(Icons.replay_circle_filled_rounded, color: Color(0xFF3A4D39)), label: Text("Try Again", style: GoogleFonts.lato(color: Color(0xFF3A4D39), fontWeight: FontWeight.bold, fontSize: 15)),
            onPressed: () => _loadTeams(showLoadingIndicator: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.92), padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          )
    ])));
  }

  Widget _buildEmptyStateWidget(Color textColor) {
    return Center(child: Padding(padding: const EdgeInsets.all(30.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.group_outlined, color: textColor.withOpacity(0.7), size: 75), const SizedBox(height: 22),
          Text("No teams created for this company yet.", style: GoogleFonts.lato(color: textColor.withOpacity(0.9), fontSize: 18.5, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TextButton.icon(
            icon: Icon(Icons.refresh_rounded, color: textColor.withOpacity(0.8)),
            label: Text("Tap to refresh", style: GoogleFonts.lato(color: textColor.withOpacity(0.8))),
            onPressed: () => _loadTeams(showLoadingIndicator: true),
          )
    ])));
   }
}