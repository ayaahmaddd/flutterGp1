// provider_profile_page.dart
import 'dart:convert';
import 'dart:io'; // لـ Platform.isAndroid
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:animate_do/animate_do.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'create_task_page.dart'; // تأكد من أن هذا المسار صحيح

class ProviderProfilePage extends StatefulWidget {
  final int providerId;
  final String baseUrl;
  final FlutterSecureStorage storage;

  const ProviderProfilePage({
    super.key,
    required this.providerId,
    required this.baseUrl,
    required this.storage,
  });

  @override
  State<ProviderProfilePage> createState() => _ProviderProfilePageState();
}

class _ProviderProfilePageState extends State<ProviderProfilePage> {
  Map<String, dynamic>? _providerData;
  List<dynamic> _reviews = []; // لتخزين المراجعات منفصلة
  List<dynamic> _positions = []; // لتخزين المناصب منفصلة

  bool _isLoading = true;
  String? _errorMessage;

  // --- UI Colors ---
  final Color _pageBackgroundColorTop = const Color(0xFFFAF3E0);
  final Color _pageBackgroundColorBottom = const Color(0xFFA3B29F);
  final Color _appBarColor = Colors.white;
  final Color _appBarItemColor = const Color(0xFF4A5D52);
  final Color _iconColor = const Color(0xFF4A5D52);
  final Color _primaryTextColor = const Color(0xFF3A3A3A);
  final Color _secondaryTextColor = Colors.grey.shade700;
  final Color _cardBackgroundColor = Colors.white.withOpacity(0.97);
  final Color _starColor = Colors.amber;


  @override
  void initState() {
    super.initState();
    _fetchProviderProfile();
  }

  Future<void> _fetchProviderProfile() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final token = await widget.storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Authentication token missing. Please log in again.";
        });
      }
      return;
    }

    final url = Uri.parse("${widget.baseUrl}/api/client/providers/${widget.providerId}");
    print("--- Fetching Provider Profile: $url ---");

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;
      final data = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && data['success'] == true && data['provider'] != null) {
        setState(() {
          _providerData = data['provider'] as Map<String, dynamic>;
          _reviews = _providerData?['reviews'] as List<dynamic>? ?? [];
          _positions = _providerData?['positions'] as List<dynamic>? ?? [];
          _isLoading = false;
        });
      } else {
         if (response.statusCode == 401 && mounted) {
           _showMessage('Session expired. Please log in again.', isError: true);
           // يمكنك إضافة Navigator.of(context).pushAndRemoveUntil(...) هنا
         }
        throw Exception(data['message'] ?? "Failed to load provider profile (${response.statusCode})");
      }
    } catch (e) {
      if (mounted) {
        print("Error fetching provider profile: $e");
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
        });
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
     if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.lato(color: Colors.white)),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : _iconColor,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }


  Future<void> _launchURL(String urlString) async {
    if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
      urlString = 'https://$urlString';
    }
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showMessage('Could not launch $urlString', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          _isLoading || _providerData == null
              ? 'Loading Profile...'
              : "${_providerData!['first_name'] ?? ''} ${_providerData!['last_name'] ?? ''}".trim(),
          style: GoogleFonts.lato(color: _appBarItemColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _appBarColor,
        elevation: 1,
        iconTheme: IconThemeData(color: _appBarItemColor),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _appBarItemColor),
            onPressed: _isLoading ? null : _fetchProviderProfile,
            tooltip: "Refresh Profile",
          )
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_pageBackgroundColorTop, _pageBackgroundColorBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.1, 0.9],
          ),
        ),
        child: _buildBodyContent(),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _iconColor));
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, color: _iconColor.withOpacity(0.7), size: 50),
              const SizedBox(height: 15),
              Text(_errorMessage!, style: GoogleFonts.lato(fontSize: 16, color: _primaryTextColor), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(Icons.refresh_rounded, color: Colors.white),
                label: Text("Retry", style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: _fetchProviderProfile,
                style: ElevatedButton.styleFrom(backgroundColor: _iconColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              )
            ],
          ),
        ),
      );
    }
    if (_providerData == null) {
      return Center(child: Text("Provider data not found.", style: GoogleFonts.lato(fontSize: 16, color: _primaryTextColor)));
    }

    final provider = _providerData!;
    String? imageUrl = provider['image_url']?.toString();
    String fullName = "${provider['first_name'] ?? ''} ${provider['last_name'] ?? ''}".trim();
    // عرض أول منصب كفئة رئيسية، والباقي في قسم المناصب
    String mainCategory = _positions.isNotEmpty ? _positions.first['name']?.toString() ?? 'Service Provider' : 'Service Provider';
    String city = provider['city_name']?.toString() ?? provider['city']?.toString() ?? 'N/A';
    double? avgRating = double.tryParse(provider['avg_rating']?.toString() ?? '');
    int ratingCount = int.tryParse(provider['review_count']?.toString() ?? '0') ?? 0; // استخدام review_count
    
    bool? isAvailable = provider['is_available'] == 1 || provider['is_available'] == true;
    String? facebookUrl = provider['facebook_url']?.toString();
    dynamic skillsData = provider['skills']; 
    String skillsText = "Not specified";

    if (skillsData is String && skillsData.isNotEmpty) {
        skillsText = skillsData.split(RegExp(r'[,;]')).map((s) => s.trim()).where((s) => s.isNotEmpty).join(' • ');
        if (skillsText.isEmpty) skillsText = "Not specified";
    } else if (skillsData is List && skillsData.isNotEmpty) {
        skillsText = skillsData.map((s) => s.toString().trim()).where((s) => s.isNotEmpty).join(' • ');
         if (skillsText.isEmpty) skillsText = "Not specified";
    }
    bool shouldShowFacebook = facebookUrl != null && facebookUrl.isNotEmpty && facebookUrl.trim().toLowerCase() != "test";


    return SlideInUp(
      duration: const Duration(milliseconds: 500),
      child: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          Center(
            child: Hero(
              tag: 'provider-avatar-${widget.providerId}',
              child: CircleAvatar(
                radius: 60,
                backgroundColor: _iconColor.withOpacity(0.1),
                backgroundImage: (imageUrl != null && imageUrl.isNotEmpty && Uri.tryParse(imageUrl)?.hasAbsolutePath == true)
                    ? NetworkImage(imageUrl)
                    : null,
                child: (imageUrl == null || imageUrl.isEmpty || Uri.tryParse(imageUrl)?.hasAbsolutePath != true)
                    ? Icon(Icons.person_rounded, size: 60, color: _iconColor.withOpacity(0.7))
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(child: Text(fullName, style: GoogleFonts.lato(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryTextColor))),
          Center(child: Text(mainCategory, style: GoogleFonts.lato(fontSize: 18, color: _iconColor, fontWeight: FontWeight.w500))),
          const SizedBox(height: 8),
           if (avgRating != null)
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, color: _starColor, size: 22),
                  const SizedBox(width: 5),
                  Text(avgRating.toStringAsFixed(1), style: GoogleFonts.lato(fontSize: 17, fontWeight: FontWeight.bold, color: _secondaryTextColor)),
                  if (ratingCount > 0)
                    Text(" ($ratingCount reviews)", style: GoogleFonts.lato(fontSize: 14, color: _secondaryTextColor.withOpacity(0.8))),
                ],
              ),
            ),
          if (isAvailable != null)
            Padding(
              padding: const EdgeInsets.only(top: 12.0, bottom: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAvailable ? Icons.event_available_rounded : Icons.event_busy_rounded,
                    color: isAvailable ? Colors.green.shade600 : Colors.red.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isAvailable ? "Available for new tasks" : "Currently unavailable",
                    style: GoogleFonts.lato(
                      fontSize: 15,
                      color: isAvailable ? Colors.green.shade700 : Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 15),
          Card(
            elevation: 3,
            color: _cardBackgroundColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(FontAwesomeIcons.idBadge, "Provider ID", provider['id']?.toString()),
                  _buildInfoRow(FontAwesomeIcons.solidUser, "User ID", provider['user_id']?.toString()),
                  _buildInfoRow(FontAwesomeIcons.envelope, "Email", provider['email']?.toString()),
                  _buildInfoRow(FontAwesomeIcons.phoneAlt, "Phone", provider['phone']?.toString() == "0" ? "Not Provided" : provider['phone']?.toString()),
                  _buildInfoRow(FontAwesomeIcons.mapMarkedAlt, "City", city),
                  _buildInfoRow(FontAwesomeIcons.mapPin, "Zip Code", provider['zip_code']?.toString()),
                  _buildInfoRow(FontAwesomeIcons.dollarSign, "Hourly Rate", provider['hourly_rate']?.toString()),
                  _buildInfoRow(FontAwesomeIcons.briefcase, "Experience", provider['years_of_experience'] != null ? "${provider['years_of_experience']} years" : null),
                  _buildInfoRow(FontAwesomeIcons.tools, "Skills", skillsText, isMultiLine: true),

                  if (_positions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text("Positions:", style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryTextColor)),
                    const SizedBox(height: 5),
                    ..._positions.map((pos) => Padding(
                          padding: const EdgeInsets.only(left: 10.0, top: 2.0, bottom: 2.0),
                          child: Text("• ${pos['name'] ?? ''} (Code: ${pos['code'] ?? 'N/A'})", style: GoogleFonts.lato(fontSize: 15, color: _secondaryTextColor)),
                        )).toList(),
                  ],


                  if (shouldShowFacebook)
                    Padding(
                      padding: const EdgeInsets.only(top:15.0, bottom: 5.0), // تعديل المسافة
                      child: InkWell(
                        onTap: () => _launchURL(facebookUrl!),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            FaIcon(FontAwesomeIcons.facebookF, size: 19, color: Colors.blue.shade800),
                            const SizedBox(width: 15),
                            Text("Facebook:", style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: _primaryTextColor.withOpacity(0.9), fontSize: 15.5)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "View Profile", 
                                style: GoogleFonts.lato(fontSize: 15.5, color: Colors.blue.shade700, decoration: TextDecoration.underline),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (provider['bio'] != null && (provider['bio'].toString()).isNotEmpty)
                     _buildInfoRow(FontAwesomeIcons.solidCommentDots, "Bio", provider['bio'].toString(), isMultiLine: true),
                  
                  _buildInfoRow(FontAwesomeIcons.solidCalendarPlus, "Joined", provider['created'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(provider['created'])) : null),
                  _buildInfoRow(FontAwesomeIcons.solidCalendarCheck, "Last Update", provider['updated'] != null ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(provider['updated']).toLocal()) : null),
                ],
              ),
            ),
          ),

          // --- قسم المراجعات ---
          if (_reviews.isNotEmpty) ...[
            const SizedBox(height: 25),
            Text("Client Reviews (${_reviews.length})", style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryTextColor)),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reviews.length,
              itemBuilder: (context, index) {
                final review = _reviews[index];
                String? clientImageUrl = review['client_image']?.toString();
                return Card(
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
                              backgroundImage: (clientImageUrl != null && clientImageUrl.isNotEmpty) ? NetworkImage(clientImageUrl) : null,
                              child: (clientImageUrl == null || clientImageUrl.isEmpty) ? Icon(Icons.person_outline_rounded, size: 20, color: _secondaryTextColor) : null,
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
                                i < (review['rate'] ?? 0) ? Icons.star_rounded : Icons.star_border_rounded,
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
                );
              },
            )
          ],


          const SizedBox(height: 25),
          ElevatedButton.icon(
            icon: Icon(FontAwesomeIcons.paperPlane, color: Colors.white, size: 18),
            label: Text("Request Service from $fullName", style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            onPressed: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskPage(baseUrl: widget.baseUrl, storage: widget.storage, prefilledProviderId: widget.providerId,)));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _iconColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 3,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value, {bool isMultiLine = false}) {
    if (value == null || value.isEmpty || value.trim().toLowerCase() == 'n/a' || value.trim().toLowerCase() == 'not specified') {
      // استثناء خاص لعرض "0" إذا كان هو القيمة الفعلية وليس "Not specified" أو "N/A"
      if ((label == "Phone" || label == "Zip Code" || label == "Experience") && value == "0") {
         // استمر لعرض الصفر لهذه الحقول
      } else {
        return const SizedBox.shrink();
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          FaIcon(icon, size: 18, color: _iconColor.withOpacity(0.85)),
          const SizedBox(width: 15),
          Text("$label: ", style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: _primaryTextColor.withOpacity(0.9), fontSize: 15.5)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value!,
              style: GoogleFonts.lato(fontSize: 15.5, color: _secondaryTextColor),
              softWrap: isMultiLine,
            ),
          ),
        ],
      ),
    );
  }
}