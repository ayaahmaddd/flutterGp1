import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui; // For TextDirection

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

// Adjust paths as necessary for your project structure
import 'login.dart';
import 'create_company_page.dart';
import 'company_dashboard_page.dart';

class MyCompaniesPage extends StatefulWidget {
  const MyCompaniesPage({super.key});

  @override
  State<MyCompaniesPage> createState() => _MyCompaniesPageState();
}

class _MyCompaniesPageState extends State<MyCompaniesPage> {
  final _storage = const FlutterSecureStorage();
  final String _baseDomain = Platform.isAndroid ? "http://10.0.2.2:3000" : "http://localhost:3000";
  late final String _apiUrl = "$_baseDomain/api/owner/my-companies";

  List<dynamic> _companies = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _expandedCardIndex;

  final double _bottomAnimationBarHeight = 70.0;
  final double _fabBottomMargin = 16.0;
  final double _fabHeight = 56.0;

  // Colors for light cards and their content, to contrast with the new background
  final Color _companyCardColor = Colors.white.withOpacity(0.94); 
  final Color _cardTitleColor = const Color(0xFF3A4D39); // Darker olive for titles on light cards
  final Color _cardTextColor = const Color(0xFF4F4F4F); // Dark grey for text
  final Color _cardSecondaryTextColor = Colors.grey.shade600; 
  final Color _cardIconColor = const Color(0xFF556B2F); // Olive green for icons
  final Color _cardPrimaryIconColor = const Color(0xFF4A5D52); // Dark olive for main company icon

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _handleAuthError({String message = 'Session expired. Please log in again.'}) async {
    if (!mounted) return;
    _showMessage(message, isError: true);
    await _storage.deleteAll();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()), 
          (Route<dynamic> route) => false);
    }
  }

  Future<void> _logout() async {
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Logout', style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: _cardTitleColor)),
          content: Text('Are you sure you want to log out?', style: GoogleFonts.lato(color: _cardTextColor)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          backgroundColor: Colors.white.withOpacity(0.95),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: GoogleFonts.lato(color: Colors.grey.shade700)),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: Text('Logout', style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmLogout == true && mounted) {
      await _handleAuthError(message: 'You have been logged out successfully.');
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.lato(color: Colors.white)),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.teal.shade700,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating, elevation: 6.0, margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _loadCompanies() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; _companies = []; });
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) { if (mounted) await _handleAuthError(); return; }
    try {
      final response = await http.get(Uri.parse(_apiUrl), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) setState(() { _companies = data['companies'] as List<dynamic>? ?? []; _isLoading = false; _expandedCardIndex = null; _errorMessage = _companies.isEmpty ? "You haven't created or joined any companies yet." : null; });
      } else if (response.statusCode == 401) { await _handleAuthError();
      } else {
        String errorMsg = "Failed to load companies (${response.statusCode})";
        try { final errorData = jsonDecode(utf8.decode(response.bodyBytes)); if (errorData is Map && errorData['message'] != null) errorMsg = errorData['message'] as String; } catch(_){}
        if(mounted) setState(() { _errorMessage = errorMsg; _isLoading = false; });
      }
    } on SocketException { if(mounted) setState(() { _errorMessage = "Network error. Please check connection."; _isLoading = false; });
    } on TimeoutException { if(mounted) setState(() { _errorMessage = "Connection timed out. Please try again."; _isLoading = false; });
    } catch (e) { if(mounted) setState(() { _errorMessage = "An unexpected error: $e"; _isLoading = false; });}
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return "N/A";
    try { return DateFormat('dd MMM yyyy, hh:mm a', 'en_US').format(DateTime.parse(dateString).toLocal()); }
    catch (_) { return dateString; }
  }

  Widget _buildCompanyCard(Map<String, dynamic> company, int index) {
    final bool isExpanded = _expandedCardIndex == index;
    String? logoUrl = company['image_url'] as String?;
    final String? companyId = company['id']?.toString();
    final String? companyName = company['name']?.toString();

    return FadeInUp(
      delay: Duration(milliseconds: 150 * (index + 1)), duration: const Duration(milliseconds: 500),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        elevation: isExpanded ? 8 : 5, // Adjusted shadow
        clipBehavior: Clip.antiAlias,
        color: _companyCardColor.withOpacity(isExpanded ? 0.97 : 0.94), // Light card color
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () {
            if (companyId != null && companyName != null && companyName.isNotEmpty) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyDashboardPage(companyId: companyId, companyName: companyName)));
            } else { _showMessage('Error: Company details missing.', isError: true); }
          },
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 28, 
                      backgroundColor: _cardPrimaryIconColor.withOpacity(0.1),
                      backgroundImage: logoUrl != null && logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
                      child: logoUrl == null || logoUrl.isEmpty ? Icon(Icons.business_rounded, size: 28, color: _cardPrimaryIconColor) : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text(companyName ?? 'Unnamed Company', style: GoogleFonts.lato(fontSize: 19, fontWeight: FontWeight.w600, color: _cardTitleColor))),
                    Material(color: Colors.transparent,
                      child: IconButton(
                        icon: AnimatedRotation(turns: isExpanded ? 0.5 : 0, duration: const Duration(milliseconds: 300), child: Icon(Icons.expand_more_rounded, color: Colors.grey.shade600, size: 30)),
                        onPressed: () => setState(() => _expandedCardIndex = isExpanded ? null : index),
                        splashRadius: 24, padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox(height: 3),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(color: Colors.grey.shade300, thickness: 0.8), const SizedBox(height: 12),
                        if (company['description'] != null && company['description'].toString().isNotEmpty) ...[
                          Text("About:", style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: _cardTitleColor.withOpacity(0.85), fontSize: 15)), const SizedBox(height: 6),
                          Text(company['description'].toString(), style: GoogleFonts.lato(fontSize: 14.5, color: _cardTextColor, height: 1.45)), const SizedBox(height: 18),
                        ],
                        _buildInfoRow(Icons.person_outline_rounded, "Owner User ID", company['user_id']?.toString()),
                        _buildInfoRow(Icons.vpn_key_outlined, "Company ID", companyId),
                        _buildInfoRow(Icons.location_on_outlined, "Location ID", company['location_id']?.toString()),
                        _buildInfoRow(Icons.location_city_outlined, "City", company['city_name']?.toString()),
                        _buildInfoRow(Icons.map_outlined, "Zip Code", company['zip_code']?.toString()),
                        _buildInfoRow(Icons.groups_outlined, "Teams", company['team_count']?.toString() ?? '0'),
                        _buildInfoRow(Icons.people_outline_rounded, "Employees", company['employee_count']?.toString() ?? '0'),
                        const SizedBox(height: 14),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Flexible(child: Text("Created: ${_formatDate(company['created']?.toString())}", style: TextStyle(fontFamily: GoogleFonts.lato().fontFamily, fontSize: 11.5, color: _cardSecondaryTextColor))),
                            Flexible(child: Text("Updated: ${_formatDate(company['updated']?.toString())}", style: TextStyle(fontFamily: GoogleFonts.lato().fontFamily, fontSize: 11.5, color: _cardSecondaryTextColor))),
                        ]),
                      ],
                    ),
                  ),
                  crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 320), sizeCurve: Curves.easeOutCubic,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty || value.toLowerCase() == "null") return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _cardIconColor),
          const SizedBox(width: 10),
          Text("$label: ", style: GoogleFonts.lato(fontWeight: FontWeight.w500, fontSize: 14.2, color: _cardTextColor.withOpacity(0.9))),
          Expanded(child: Text(value, style: GoogleFonts.lato(fontSize: 14.2, color: _cardTextColor))),
        ],
      ),
    );
  }

  Widget _buildErrorStateWidget() { 
    Color errorColor = Theme.of(context).colorScheme.error;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.cloud_off_rounded, color: errorColor.withOpacity(0.7), size: 70), const SizedBox(height: 20),
            Text(_errorMessage ?? "An error occurred.", style: GoogleFonts.lato(color: errorColor, fontSize: 18, fontWeight: FontWeight.w500), textAlign: TextAlign.center), const SizedBox(height: 25),
            ElevatedButton.icon(icon: const Icon(Icons.refresh_rounded, color: Colors.white), label: Text("Try Again", style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold)), onPressed: _loadCompanies, style: ElevatedButton.styleFrom(backgroundColor: errorColor.withOpacity(0.8), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarItemColor = const Color(0xFF4A5D52); // Dark olive for AppBar items

    return Scaffold(
      body: Container(
        // --- تطبيق التدرج اللوني البيج/الأخضر المطلوب للخلفية ---
        decoration: const BoxDecoration(
          gradient: LinearGradient( 
            colors: [
              Color(0xFFE1CDB5), // بيج دافئ / بني فاتح في الأعلى (أغمق من السابق)
              Color(0xFFD8C7A8), // درجة أغمق قليلاً من البيج المائل للبني
              Color(0xFFC6B89A), // بيج مائل للزيتي الخفيف (أغمق)
              Color(0xFFAFB898), // أخضر زيتوني باهت (أغمق وأكثر دفئًا)
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.25, 0.5, 0.75], 
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  AppBar(
                    title: Text("My Companies", style: GoogleFonts.lora(fontWeight: FontWeight.bold, color: appBarItemColor, fontSize: 23)),
                    backgroundColor: const ui.Color.fromARGB(0, 18, 9, 9), elevation: 0, centerTitle: true,
                    iconTheme: IconThemeData(color: appBarItemColor),
                    actions: [
                      IconButton(icon: Icon(Icons.refresh_rounded, color: appBarItemColor), onPressed: _isLoading ? null : _loadCompanies, tooltip: "Refresh Companies"),
                      IconButton(icon: Icon(Icons.logout_rounded, color: appBarItemColor), onPressed: _logout, tooltip: "Logout"),
                    ],
                  ),
                  Expanded(
                    child: _isLoading && _companies.isEmpty
                        ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(appBarItemColor.withOpacity(0.8))))
                        : _errorMessage != null && _companies.isEmpty
                            ? _buildErrorStateWidget()
                            : _companies.isEmpty
                                ? Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Icon(Icons.business_center_outlined, size: 70, color: appBarItemColor.withOpacity(0.6)), const SizedBox(height: 20),
                                      Text("You haven't created or joined any companies yet.", style: GoogleFonts.lato(fontSize: 17, color: appBarItemColor.withOpacity(0.8), fontWeight: FontWeight.w500), textAlign: TextAlign.center), const SizedBox(height: 25),
                                      ElevatedButton.icon(
                                        icon: Icon(Icons.add_business_outlined, color: appBarItemColor), label: Text("Create Company", style: GoogleFonts.lato(color: appBarItemColor, fontWeight: FontWeight.bold)),
                                        onPressed: () async { final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateCompanyPage())); if (result == true && mounted) _loadCompanies(); },
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.85), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                      )])))
                                : RefreshIndicator(
                                    onRefresh: _loadCompanies, color: appBarItemColor, backgroundColor: const Color(0xFFAFB898).withOpacity(0.9), // لون متناسق مع الخلفية الجديدة
                                    child: ListView.builder(
                                      itemCount: _companies.length,
                                      padding: EdgeInsets.fromLTRB(8, 5, 8, _bottomAnimationBarHeight + _fabHeight + (_fabBottomMargin * 2) + 30),
                                      itemBuilder: (context, index) => _buildCompanyCard(_companies[index], index),
                                    ),
                                  ),
                  ),
                ],
              ),
              Positioned(bottom: 0, left: 0, right: 0, height: _bottomAnimationBarHeight, child: const AnimatedPeopleRow()),
              if (!_isLoading && _errorMessage == null)
                Positioned(
                  bottom: _bottomAnimationBarHeight + _fabBottomMargin, right: 20,
                  child: FadeInUp(
                    delay: const Duration(milliseconds: 600),
                    child: FloatingActionButton.extended(
                      onPressed: () async { final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateCompanyPage())); if (result == true && mounted) _loadCompanies(); },
                      label: Text("New Company", style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: Colors.white)),
                      icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                      backgroundColor: appBarItemColor, elevation: 8,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- ودجات الأنيميشن (AnimatedPeopleRow & _EmojiPainter) ---
// (الكود الخاص بها يبقى كما هو ولم يتغير)
class AnimatedPeopleRow extends StatefulWidget { const AnimatedPeopleRow({super.key}); @override State<AnimatedPeopleRow> createState() => _AnimatedPeopleRowState(); }
class _AnimatedPeopleRowState extends State<AnimatedPeopleRow> with SingleTickerProviderStateMixin { late AnimationController _controller; final List<String> emojis = ["🏢", "📈", "💼", "📊", "🧑‍💼", "👩‍💼","👷‍♂️", "👩‍🔧"]; @override void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat(); } @override void dispose() { _controller.dispose(); super.dispose(); } @override Widget build(BuildContext context) { return IgnorePointer(child: AnimatedBuilder(animation: _controller, builder: (context, child) => CustomPaint(painter: _EmojiPainter(_controller.value, emojis), child: Container()))); } }
class _EmojiPainter extends CustomPainter { final double animationValue; final List<String> emojis; _EmojiPainter(this.animationValue, this.emojis); @override void paint(Canvas canvas, Size size) { final textPainter = TextPainter(textDirection: ui.TextDirection.ltr); final double spacing = emojis.isNotEmpty ? size.width / (emojis.length + 1) : size.width; if (emojis.isEmpty) return; for (int i = 0; i < emojis.length; i++) { final double uniqueOffset = i * (pi / emojis.length); final double dx = (spacing * (i + 1)) - 20 + sin(animationValue * 2 * pi + uniqueOffset) * (10 + (i % 3 * 5)); final double dy = size.height * 0.35 + cos(animationValue * 2 * pi * 1.5 + uniqueOffset * 2) * (8 + (i % 2 * 4)); textPainter.text = TextSpan(text: emojis[i], style: TextStyle(fontSize: 24 + (i % 3 * 2.0) )); textPainter.layout(); textPainter.paint(canvas, Offset(dx, dy)); } } @override bool shouldRepaint(covariant _EmojiPainter oldDelegate) => true; }