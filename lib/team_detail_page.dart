// team_detail_page.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart'; // For entry animations
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

// --- Make sure this import path is correct for your project ---
import 'team_projects_page.dart'; // Placeholder for Team Projects Page
// import 'login_screen.dart'; // Import if needed for _handleAuthError redirection

class TeamDetailPage extends StatefulWidget {
  final String teamId;
  final String? initialTeamName;
  final String companyId;      // Required: ID of the parent company
  final String companyName;    // Required: Name of the parent company

  const TeamDetailPage({
    super.key,
    required this.teamId,
    this.initialTeamName,
    required this.companyId,
    required this.companyName,
  });

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage> with TickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  final String _baseDomain = Platform.isAndroid ? "http://10.0.2.2:3000" : "http://localhost:3000";
  late final String _teamDetailApiUrl; // API to get team details (and members)
  late final String _addMemberApiUrl;    // API to add a member to this team

  Map<String, dynamic>? _teamData; // Holds all data for the current team
  List<dynamic> _members = [];     // Holds the list of members for the current team
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessingAction = false; // For the "Add Provider" dialog button

  // Form key and controller for "Add Provider to Team" dialog
  final _addMemberFormKey = GlobalKey<FormState>();
  final TextEditingController _providerIdController = TextEditingController();

  // UI Colors (consistent with other pages for a cohesive look)
  final Color _appBarBackgroundColor1 = const Color(0xFFa3b29f).withOpacity(0.9);
  final Color _appBarBackgroundColor2 = const Color(0xFF697C6B).withOpacity(0.98);
  final Color _pageBackgroundColor1 = const Color(0xFFF2DEC5); // Beige
  final Color _pageBackgroundColor2 = const Color(0xFF697C6B); // Olive/Dark Green
  final Color _appBarTextColor = Colors.white;
  final Color _fabColor = const Color(0xFF4A5D52); // Dark olive for FAB
  final Color _cardColor = Colors.white.withOpacity(0.97); // For team info card
  final Color _cardTextColor = const Color(0xFF33475B); // Dark slate blue for main text in cards
  final Color _cardSecondaryTextColor = Colors.grey.shade700; // For secondary text in cards
  final Color _memberCardColor = Colors.white.withOpacity(0.94); // For member cards
  final Color _headerTextColorOnGradient = const Color(0xFF4A5D52); // Dark olive for headers on page background

  @override
  void initState() {
    super.initState();
    _teamDetailApiUrl = "$_baseDomain/api/owner/teams/${widget.teamId}";
    _addMemberApiUrl = "$_baseDomain/api/owner/teams/${widget.teamId}/members";
    _loadTeamDetails();
  }

  @override
  void dispose() {
    _providerIdController.dispose();
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

  Future<void> _loadTeamDetails({bool showLoadingIndicator = true}) async {
    if (showLoadingIndicator && mounted) setState(() { _isLoading = true; _errorMessage = null; });
    
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = "Authentication token missing."; });
      return;
    }
    print("--- TeamDetailPage: Fetching team details from $_teamDetailApiUrl ---");
    try {
      final response = await http.get(Uri.parse(_teamDetailApiUrl), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 20));
      if (!mounted) return;

      final responseBodyString = utf8.decode(response.bodyBytes);
      debugPrint("Fetch Team Details Response Status: ${response.statusCode}");
      // debugPrint("Fetch Team Details Response Body (Raw): $responseBodyString"); // Uncomment for debugging

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBodyString);
        if (data['success'] == true && data['team'] != null) {
          if (mounted) setState(() {
            _teamData = data['team'] as Map<String, dynamic>;
            // API for "Get one team info" includes members array directly
            _members = _teamData?['members'] as List<dynamic>? ?? []; 
            _isLoading = false;
            if(_members.isEmpty && _teamData != null) { // If team data loaded but no members
                _errorMessage = "No members in this team yet.";
            } else if (_teamData == null) { // Should not happen if success is true and team is not null
                _errorMessage = "Team data is unexpectedly null.";
            }
             else {
                _errorMessage = null;
            }
          });
        } else { throw Exception(data['message']?.toString() ?? 'Failed to parse team data from API'); }
      } else if (response.statusCode == 401) { await _handleAuthError(); if(mounted) setState(() {_isLoading = false; _errorMessage = "Unauthorized.";});
      } else if (response.statusCode == 404) { if(mounted) setState(() { _isLoading = false; _errorMessage = "Team not found."; });
      } else { 
        String errorMsg = 'Failed to load team details. Status: ${response.statusCode}';
        try{ final errorData = jsonDecode(responseBodyString); if(errorData is Map && errorData['message'] != null) errorMsg = errorData['message']; } catch(_){}
        throw Exception(errorMsg); 
      }
    } catch (e) {
      print("!!! TeamDetailPage: LoadTeamDetails Exception: $e");
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString().replaceFirst("Exception: ", ""); });
    }
  }

  Future<void> _addProviderToTeam(StateSetter setDialogState) async {
    if (!_addMemberFormKey.currentState!.validate()) {
      setDialogState(() => _isProcessingAction = false);
      return;
    }
    if (!mounted) return;

    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      _showMessage("Authentication error.", isError: true);
      setDialogState(() => _isProcessingAction = false);
      return;
    }
    final Map<String, dynamic> payload = {
      "providerId": int.tryParse(_providerIdController.text.trim()),
    };
    print("--- TeamDetailPage: Adding provider to team. URL: $_addMemberApiUrl, Payload: $payload ---");
    try {
      final response = await http.post( Uri.parse(_addMemberApiUrl),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;
      final responseBodyString = utf8.decode(response.bodyBytes);
      print("Add Provider Response Status: ${response.statusCode}");
      print("Add Provider Response Body (Raw): $responseBodyString");
      final responseBody = jsonDecode(responseBodyString);

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showMessage(responseBody['message'] ?? "Provider added to team successfully!", isSuccess: true);
        _providerIdController.clear();
        if (Navigator.canPop(context)) Navigator.of(context).pop();
        await _loadTeamDetails(showLoadingIndicator: false);
      } else {
        _showMessage(responseBody['message'] ?? "Failed to add provider (${response.statusCode})", isError: true);
      }
    } catch (e) {
      print("!!! TeamDetailPage: AddProviderToTeam Exception: $e");
      _showMessage("An error occurred: $e", isError: true);
    } finally {
      if (mounted) {
         setDialogState(() => _isProcessingAction = false);
      }
    }
  }

  void _showAddProviderDialog() {
    _providerIdController.clear();
    bool isDialogButtonLoading = false;

    showDialog(
      context: context, barrierDismissible: !isDialogButtonLoading,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text("Add Provider to Team", style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: _fabColor)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            backgroundColor: Colors.white.withOpacity(0.98),
            contentPadding: const EdgeInsets.all(20),
            content: SingleChildScrollView(
              child: Form(
                key: _addMemberFormKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  TextFormField(
                    controller: _providerIdController,
                    decoration: InputDecoration(labelText: "Provider User ID *", prefixIcon: Icon(Icons.person_add_alt_1_rounded, color: _fabColor.withOpacity(0.7)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _fabColor, width: 1.5))),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter Provider ID';
                      if (int.tryParse(value) == null) return 'Provider ID must be a number';
                      return null;
                    },
                  ),
                ]),
              ),
            ),
            actionsAlignment: MainAxisAlignment.end,
            actionsPadding: const EdgeInsets.fromLTRB(10,0,10,10),
            actions: <Widget>[
              TextButton(child: Text("Cancel", style: GoogleFonts.lato(color: Colors.grey.shade700)), onPressed: isDialogButtonLoading ? null : () => Navigator.of(dialogContext).pop()),
              ElevatedButton.icon(
                icon: isDialogButtonLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.group_add_rounded, size: 20),
                label: Text(isDialogButtonLoading ? "Adding..." : "Add to Team", style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
                onPressed: isDialogButtonLoading ? null : () async { 
                    if (_addMemberFormKey.currentState!.validate()) { 
                        setDialogState(() => isDialogButtonLoading = true); 
                        await _addProviderToTeam(setDialogState);
                        if (mounted && isDialogButtonLoading) { 
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
    ).then((_){ if(mounted && _isProcessingAction) setState(()=> _isProcessingAction = false); });
  }

  String _formatTeamDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "N/A";
    try { return DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(dateStr).toLocal()); }
    catch (_) { return dateStr; }
  }

  Widget _buildInfoRow(IconData icon, String label, String? value, {Color? iconColor, Color? labelColor, Color? valueColor}) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: iconColor ?? _fabColor.withOpacity(0.8)), const SizedBox(width: 12),
          Text("$label: ", style: GoogleFonts.lato(fontSize: 15.5, fontWeight: FontWeight.w600, color: labelColor ?? _cardTextColor.withOpacity(0.9))),
          Expanded(child: Text(value, style: GoogleFonts.lato(fontSize: 15.5, color: valueColor ?? _cardTextColor.withOpacity(0.8)))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    String displayTeamName = _isLoading ? (widget.initialTeamName ?? "Loading Team...") : (_teamData?['name']?.toString() ?? "Team Details");
    // Company name for display will come from the widget parameter, as API for team details might not always include it.
    String displayCompanyNameForInfoCard = widget.companyName; 

    return Scaffold(
      appBar: AppBar(
        title: Text(displayTeamName, style: GoogleFonts.lato(color: _appBarTextColor, fontWeight: FontWeight.bold, fontSize: 20), overflow: TextOverflow.ellipsis),
        flexibleSpace: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [_appBarBackgroundColor1, _appBarBackgroundColor2], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        elevation: 2, iconTheme: IconThemeData(color: _appBarTextColor),
        actions: [ if (!_isLoading && _teamData != null) IconButton(icon: Icon(Icons.refresh_rounded, color: _appBarTextColor), onPressed: _loadTeamDetails, tooltip: "Refresh Team Details")],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [_pageBackgroundColor1, _pageBackgroundColor2.withOpacity(0.85), _pageBackgroundColor2], begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.0, 0.35, 1.0])),
        child: SafeArea(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: _appBarTextColor.withOpacity(0.8)))
              : _errorMessage != null && _teamData == null
                  ? _buildErrorWidget(_headerTextColorOnGradient)
                  : _teamData == null
                      ? Center(child: Text("No team data available.", style: GoogleFonts.lato(fontSize: 18, color: _headerTextColorOnGradient.withOpacity(0.7))))
                      : Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80), // Padding for FAB
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildTeamInfoCard(displayCompanyNameForInfoCard),
                                    const SizedBox(height: 28),
                                    _buildTeamMembersSection(_members, _headerTextColorOnGradient),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
        ),
      ),
   
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildTeamInfoCard(String companyNameForDisplay) {
    return FadeInDown(
      duration: const Duration(milliseconds: 450),
      child: Stack(
        children: [
          Card(
            elevation: 5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            color: _cardColor,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _teamData!['name']?.toString() ?? 'Team Name',
                          style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: _cardTextColor),
                        ),
                      ),
                      const SizedBox(width: 40), // Space for the icon button
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: Colors.grey.shade200, thickness: 0.8),
                  const SizedBox(height: 12),
                  Text(
                    _teamData!['description']?.toString() ?? 'No description.',
                    style: GoogleFonts.lato(fontSize: 16, color: _cardTextColor.withOpacity(0.85), height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow(Icons.business_rounded, "Company", companyNameForDisplay, iconColor: Colors.indigo.shade400, labelColor: _cardTextColor, valueColor: _cardSecondaryTextColor),
                  _buildInfoRow(Icons.group_work_rounded, "Members", (_teamData!['member_count'] ?? _members.length).toString(), iconColor: Colors.purple.shade400, labelColor: _cardTextColor, valueColor: _cardSecondaryTextColor),
                  _buildInfoRow(Icons.calendar_month_rounded, "Created", _formatTeamDate(_teamData!['created']?.toString()), iconColor: Colors.green.shade500, labelColor: _cardTextColor, valueColor: _cardSecondaryTextColor),
                  _buildInfoRow(Icons.edit_calendar_rounded, "Last Updated", _formatTeamDate(_teamData!['updated']?.toString()), iconColor: Colors.orange.shade600, labelColor: _cardTextColor, valueColor: _cardSecondaryTextColor),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Bounce(
              delay: const Duration(milliseconds: 600),
              child: Material(
                color: Colors.transparent, shape: const CircleBorder(), clipBehavior: Clip.antiAlias,
                child: IconButton(
                  icon: Icon(Icons.folder_shared_outlined, color: Colors.blueGrey.shade600, size: 28),
                  tooltip: "Team Projects", padding: const EdgeInsets.all(8), constraints: const BoxConstraints(),
                  onPressed: () {
                    if (_teamData == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TeamProjectsPage(
                          teamId: widget.teamId,
                          teamName: _teamData!['name']?.toString() ?? widget.initialTeamName ?? 'Team',
                          companyId: widget.companyId, // Passed from CompanyTeamsPage
                          companyName: widget.companyName, // Passed from CompanyTeamsPage
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMembersSection(List members, Color headerTextColor) {
    if (members.isEmpty && _errorMessage != null && !_isLoading) {
       return FadeInUp(delay: const Duration(milliseconds: 300), child: Center(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0),
            child: Text(_errorMessage!, style: GoogleFonts.lato(fontSize: 16, color: headerTextColor.withOpacity(0.8)), textAlign: TextAlign.center))));
    }
    if (members.isEmpty) {
      return FadeInUp(delay: const Duration(milliseconds: 300), child: Center(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0),
            child: Column(children: [
                Icon(Icons.no_accounts_rounded, size: 50, color: headerTextColor.withOpacity(0.6)), const SizedBox(height: 12),
                Text("No members in this team yet.", style: GoogleFonts.lato(fontSize: 16, color: headerTextColor.withOpacity(0.8))),
            ]))));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeInUp(delay: const Duration(milliseconds: 250), child: Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 18.0),
            child: Text("Team Members (${members.length})", style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.w700, color: headerTextColor)))),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : (MediaQuery.of(context).size.width > 500 ? 3 : 2),
            crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.9,
          ),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index] as Map<String, dynamic>;
            final String memberName = "${member['first_name'] ?? ''} ${member['last_name'] ?? ''}".trim();
            final String memberEmail = member['email']?.toString() ?? 'N/A';
            final String memberPosition = member['position']?.toString() ?? 'N/A'; // From API
            final String imageUrl = member['image_url']?.toString() ?? 'https://via.placeholder.com/100/B0BEC5/FFFFFF?Text=...';

            return BounceInUp( // Entry animation for the card
                delay: Duration(milliseconds: 150 * (index + 1)), 
                duration: const Duration(milliseconds: 400), 
                child: Card(
                    elevation: 3.5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), 
                    color: _memberCardColor, // Light color for member card
                    child: InkWell(
                      onTap: (){ _showMessage("Viewing details for $memberName (TODO)"); },
                      borderRadius: BorderRadius.circular(13),
                      child: Padding(padding: const EdgeInsets.all(10.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            CircleAvatar(radius: 30, backgroundColor: Colors.grey.shade200, backgroundImage: NetworkImage(imageUrl), onBackgroundImageError: (e,s){}, child: imageUrl.contains('placeholder.com') ? const Icon(Icons.person_outline_rounded, size: 30, color: Colors.grey) : null),
                            const SizedBox(height: 8),
                            Text(memberName.isEmpty ? "Unnamed Member" : memberName, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(fontSize: 13.5, fontWeight: FontWeight.w600, color: _cardTextColor)),
                            if (memberPosition != 'N/A' && memberPosition.isNotEmpty) ...[const SizedBox(height: 3), Text(memberPosition, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(fontSize: 11.5, color: _fabColor.withOpacity(0.8), fontWeight: FontWeight.w500))], // Using _fabColor for position
                            const SizedBox(height: 3),
                            Text(memberEmail, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(fontSize: 10.5, color: _cardSecondaryTextColor)),
                      ])),
                    ),
            ));
          },
        ),
      ],
    );
  }

  Widget _buildErrorWidget(Color textColor) {
    return Center(child: Padding(padding: const EdgeInsets.all(30.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline_rounded, color: Colors.red.shade200, size: 70), const SizedBox(height: 20),
      Text("Error Loading Team Details", style: GoogleFonts.lato(color: textColor, fontSize: 19, fontWeight: FontWeight.bold), textAlign: TextAlign.center), const SizedBox(height: 10),
      Text(_errorMessage ?? "An unknown error occurred.", style: GoogleFonts.lato(color: textColor.withOpacity(0.8), fontSize: 16), textAlign: TextAlign.center), const SizedBox(height: 25),
      ElevatedButton.icon(icon: Icon(Icons.refresh_rounded, color: Colors.teal.shade800), label: Text("Try Again", style: GoogleFonts.lato(color: Colors.teal.shade800, fontWeight: FontWeight.bold, fontSize: 15)), onPressed: _loadTeamDetails, style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.85), padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))
    ])));
  }
}