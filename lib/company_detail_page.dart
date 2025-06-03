// company_detail_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:animate_do/animate_do.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart'; 
// import 'package:url_launcher/url_launcher.dart'; // إذا كنت ستستخدمه

import 'login.dart'; 
import 'create_project_page.dart'; 

class CompanyDetailPage extends StatefulWidget {
  final int companyId;
  final String baseUrl;
  final FlutterSecureStorage storage;

  const CompanyDetailPage({
    super.key,
    required this.companyId,
    required this.baseUrl,
    required this.storage,
  });

  @override
  State<CompanyDetailPage> createState() => _CompanyDetailPageState();
}

class _CompanyDetailPageState extends State<CompanyDetailPage> {
  Map<String, dynamic>? _companyData;
  List<dynamic> _teams = [];
  List<dynamic> _companyPositions = []; // لتخزين المناصب الخاصة بالشركة
  List<dynamic> _companyReviews = [];   // لتخزين مراجعات الشركة

  bool _isLoading = true;
  String? _errorMessage;

  final Color _pageBackgroundColorTop = const Color(0xFFFAF3E0);
  final Color _pageBackgroundColorBottom = const Color(0xFFA3B29F);
  final Color _appBarColor = Colors.white;
  final Color _appBarItemColor = const Color(0xFF4A5D52);
  final Color _iconColor = const Color(0xFF4A5D52);
  final Color _primaryTextColor = const Color(0xFF3A3A3A);
  final Color _secondaryTextColor = Colors.grey.shade700;
  final Color _cardBackgroundColor = Colors.white.withOpacity(0.97);
  final Color _buttonColor = const Color(0xFF4A5D52);
  final Color _starColor = Colors.amber;


  @override
  void initState() {
    super.initState();
    _fetchCompanyDetailsAndTeams();
  }

  void _showMessage(String message, {bool isError = false, bool isSuccess = false}) {
     if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.lato(color: Colors.white)),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : (isSuccess ? Colors.green.shade600 : _iconColor),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      elevation: 6.0,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _handleAuthError({String message = 'Session expired. Please log in again.'}) async {
    if (!mounted) return;
    _showMessage(message, isError: true);
    await widget.storage.deleteAll();
    if (mounted) { 
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r)=> false);
    }
  }
  
  Future<void> _fetchCompanyDetailsAndTeams() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    final token = await widget.storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) { 
      if(mounted) setState(() { _isLoading = false; _errorMessage = "Authentication required.";});
      _handleAuthError();
      return; 
    }

    try {
      final companyUrl = Uri.parse("${widget.baseUrl}/api/client/companies/${widget.companyId}");
      print("--- Fetching Company Details: $companyUrl ---");
      final companyResponse = await http.get(companyUrl, headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 15));
      
      if (!mounted) return;
      if (companyResponse.statusCode == 200) {
        final companyJson = json.decode(utf8.decode(companyResponse.bodyBytes));
        if (companyJson['success'] == true && companyJson['company'] != null) {
          _companyData = companyJson['company'];
          _companyPositions = _companyData?['positions'] as List<dynamic>? ?? []; // جلب المناصب
          _companyReviews = _companyData?['reviews'] as List<dynamic>? ?? [];     // جلب المراجعات
        } else {
          throw Exception(companyJson['message'] ?? 'Failed to load company details');
        }
      } else {
        if (companyResponse.statusCode == 401) { _handleAuthError(); return; }
        throw Exception('Failed to load company details (${companyResponse.statusCode})');
      }

      final teamsUrl = Uri.parse("${widget.baseUrl}/api/client/companies/${widget.companyId}/teams");
      print("--- Fetching Company Teams: $teamsUrl ---");
      final teamsResponse = await http.get(teamsUrl, headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      if (teamsResponse.statusCode == 200) {
        final teamsJson = json.decode(utf8.decode(teamsResponse.bodyBytes));
        if (teamsJson['success'] == true && teamsJson['teams'] != null) {
          _teams = teamsJson['teams'] as List<dynamic>;
        } else {
          _teams = [];
          print(teamsJson['message'] ?? 'No teams found or failed to load teams');
        }
      } else {
         if (teamsResponse.statusCode == 401) { _handleAuthError(); return; }
        print('Failed to load teams (${teamsResponse.statusCode})');
        _teams = []; 
      }

      if(mounted) setState(() { _isLoading = false; });

    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString().replaceFirst("Exception: ", ""); });
      print("Error in _fetchCompanyDetailsAndTeams: $e");
    }
  }
  
  Widget _buildInfoRow(IconData icon, String label, String? value, {bool isLink = false, VoidCallback? onLinkTap}) {
    if (value == null || value.isEmpty || value.trim().toLowerCase() == 'n/a' || value.trim().toLowerCase() == 'null' || (value == '0' && label != "Phone" && label != "Zip Code" && label != "Review Count" && label != "User ID" && label != "Location ID")) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(icon, color: _iconColor.withOpacity(0.8), size: 18),
          const SizedBox(width: 12),
          Text("$label: ", style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: _primaryTextColor, fontSize: 15)),
          Expanded(
            child: isLink && onLinkTap != null
              ? InkWell(
                  onTap: onLinkTap,
                  child: Text(
                    value, 
                    style: GoogleFonts.lato(color: Colors.blue.shade700, fontSize: 15, decoration: TextDecoration.underline),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : Text(value, style: GoogleFonts.lato(color: _secondaryTextColor, fontSize: 15)),
          ),
        ],
      ),
    );
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          _isLoading || _companyData == null ? 'Loading Company...' : (_companyData!['name']?.toString() ?? 'Company Details'),
          style: GoogleFonts.lato(color: _appBarItemColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _appBarColor,
        elevation: 1,
        iconTheme: IconThemeData(color: _appBarItemColor),
         actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _appBarItemColor),
            onPressed: _isLoading ? null : _fetchCompanyDetailsAndTeams,
            tooltip: "Refresh Data",
          )
        ],
      ),
      body: Container(
         width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_pageBackgroundColorTop, _pageBackgroundColorBottom],
            begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.1, 0.9],
          ),
        ),
        child: _buildBodyContent(),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: _iconColor));
    if (_errorMessage != null && _companyData == null) {
        return Center(
            child: Padding(
            padding: const EdgeInsets.all(20), 
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 50),
                const SizedBox(height: 10),
                Text(_errorMessage!, textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 16, color: _primaryTextColor)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                    icon: Icon(Icons.refresh_rounded, color: Colors.white),
                    label: Text("Retry", style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: _fetchCompanyDetailsAndTeams,
                    style: ElevatedButton.styleFrom(backgroundColor: _iconColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                )
                ]
            )
            )
        );
    }
    if (_companyData == null) return Center(child: Text('Company data not found.', style: GoogleFonts.lato()));

    final company = _companyData!;
    String? imageUrl = company['image_url']?.toString();

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        FadeInDown(
          duration: const Duration(milliseconds: 300),
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: _iconColor.withOpacity(0.1),
                backgroundImage: (imageUrl != null && imageUrl.isNotEmpty && Uri.tryParse(imageUrl)?.hasAbsolutePath == true) 
                                 ? NetworkImage(imageUrl) 
                                 : null,
                child: (imageUrl == null || imageUrl.isEmpty || Uri.tryParse(imageUrl)?.hasAbsolutePath != true) 
                       ? Icon(Icons.business_rounded, size: 50, color: _iconColor.withOpacity(0.7)) 
                       : null,
              ),
              const SizedBox(height: 16),
              Text(company['name']?.toString() ?? 'N/A', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryTextColor)),
              if (company['description'] != null && company['description'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 0.0),
                  child: Text(company['description'].toString(), textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 15, color: _secondaryTextColor)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FadeInUp(
          delay: const Duration(milliseconds: 100),
          child: Card(
            elevation: 3,
            color: _cardBackgroundColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Company Information", style: GoogleFonts.lato(fontSize: 17, fontWeight: FontWeight.bold, color: _iconColor)),
                  Divider(height: 20, thickness: 0.8, color: _iconColor.withOpacity(0.3)),
                  _buildInfoRow(FontAwesomeIcons.idBadge, "Company ID", company['id']?.toString()),
                  _buildInfoRow(FontAwesomeIcons.userTie, "Owner User ID", company['user_id']?.toString()),
                  _buildInfoRow(FontAwesomeIcons.mapMarkerAlt, "Location ID", company['location_id']?.toString()),
                  _buildInfoRow(Icons.location_city_rounded, "City", company['city_name'] ?? company['city']?.toString()),
                  _buildInfoRow(FontAwesomeIcons.mapPin, "Zip Code", company['zip_code']?.toString()),
                  _buildInfoRow(FontAwesomeIcons.solidUserCircle, "Owner", "${company['owner_first_name'] ?? ''} ${company['owner_last_name'] ?? ''}".trim()),
                  if (company['avg_rating'] != null && double.tryParse(company['avg_rating'].toString()) != null)
                    _buildInfoRow(Icons.star_half_rounded, "Rating", "${double.parse(company['avg_rating'].toString()).toStringAsFixed(1)} (${company['review_count'] ?? 0} reviews)"),
                  _buildInfoRow(FontAwesomeIcons.solidCalendarPlus, "Created", _formatDisplayDate(company['created']?.toString())),
                  _buildInfoRow(FontAwesomeIcons.solidCalendarCheck, "Last Updated", _formatDisplayDate(company['updated']?.toString(), format: 'dd MMM yyyy, hh:mm a')),
                ],
              )
            ),
          ),
        ),

    
        
        if (_teams.isNotEmpty) ...[
          const SizedBox(height: 24),
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: Text("Teams (${_teams.length})", style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryTextColor))),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _teams.length,
            itemBuilder: (context, index) {
              final team = _teams[index];
              return FadeInUp(
                delay: Duration(milliseconds: 300 + (index * 100)),
                child: Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  color: _cardBackgroundColor.withOpacity(0.95),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    leading: CircleAvatar(
                        backgroundColor: _iconColor.withOpacity(0.1),
                        child: FaIcon(FontAwesomeIcons.users, color: _iconColor, size: 20),
                    ),
                    title: Text(team['name']?.toString() ?? 'Unnamed Team', style: GoogleFonts.lato(fontWeight: FontWeight.w600, fontSize: 15.5, color: _primaryTextColor)),
                    subtitle: Text(team['description']?.toString() ?? 'No description', maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(fontSize: 13, color: _secondaryTextColor)),
                    trailing: ElevatedButton.icon(
                      icon: Icon(Icons.add_circle_outline_rounded, size: 18, color: Colors.white),
                      label: Text("New Project", style: GoogleFonts.lato(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CreateProjectPage(
                            teamId: team['id'].toString(),
                            companyId: widget.companyId.toString(),
                            baseUrl: widget.baseUrl,
                            storage: widget.storage,
                          )),
                        ).then((projectCreated) {
                           if (projectCreated == true) {
                             // لا يوجد ما يتم تحديثه هنا بشكل مباشر، ولكن يمكنك عرض رسالة نجاح
                             _showMessage("New project creation initiated for team: ${team['name']}.", isSuccess: true);
                           }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _buttonColor,
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      ),
                    ),
                  ),
                ),
              );
            },
          )
        ] else if (!_isLoading && _teams.isEmpty)
           Padding(
             padding: const EdgeInsets.only(top: 20.0),
             child: Text("No teams found for this company.", style: GoogleFonts.lato(color: _secondaryTextColor, fontStyle: FontStyle.italic, fontSize: 14), textAlign: TextAlign.center),
           ),

        // --- قسم المراجعات ---
        if (_companyReviews.isNotEmpty) ...[
            const SizedBox(height: 24),
            FadeInUp(
            delay: const Duration(milliseconds: 250),
            child: Text("Client Reviews (${_companyReviews.length})", style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryTextColor))),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _companyReviews.length,
              itemBuilder: (context, index) {
                final review = _companyReviews[index];
                String? clientImageUrl = review['client_image']?.toString();
                return FadeInUp(
                  delay: Duration(milliseconds: 350 + (index * 100)),
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: _cardBackgroundColor.withOpacity(0.9),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: (clientImageUrl != null && clientImageUrl.isNotEmpty && Uri.tryParse(clientImageUrl)?.hasAbsolutePath == true) ? NetworkImage(clientImageUrl) : null,
                                child: (clientImageUrl == null || clientImageUrl.isEmpty || Uri.tryParse(clientImageUrl)?.hasAbsolutePath != true) ? Icon(Icons.person_outline_rounded, size: 20, color: _secondaryTextColor) : null,
                                backgroundColor: Colors.grey.shade200,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  review['client_name']?.toString() ?? 'Anonymous',
                                  style: GoogleFonts.lato(fontWeight: FontWeight.w600, fontSize: 15, color: _primaryTextColor),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(5, (i) => Icon(
                                  i < (int.tryParse(review['rate']?.toString() ?? '0') ?? 0) ? Icons.star_rounded : Icons.star_border_rounded,
                                  color: _starColor,
                                  size: 18,
                                )),
                              )
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            review['feedback']?.toString() ?? 'No feedback provided.',
                            style: GoogleFonts.lato(fontSize: 14, color: _secondaryTextColor, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            )
        ] else if (!_isLoading && _companyReviews.isEmpty)
           Padding(
             padding: const EdgeInsets.only(top: 20.0),
             child: Text("No reviews yet for this company.", style: GoogleFonts.lato(color: _secondaryTextColor, fontStyle: FontStyle.italic, fontSize: 14), textAlign: TextAlign.center),
           ),
        const SizedBox(height: 20),
      ],
    );
  }
}

extension StringExtension on String {
  String myCapitalizeFirst() { 
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}