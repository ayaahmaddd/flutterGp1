import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart'; // تأكد من وجود هذا الاستيراد

import 'edit_profile_page.dart';
import 'login.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  final _storage = const FlutterSecureStorage();
  final String _baseDomain = "http://localhost:3000";
  late final String _profileApiUrl = "$_baseDomain/api/provider";
  late final String _availabilityApiUrl = "$_baseDomain/api/provider/availability";

  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _statsData;
  List<dynamic> _positionsList = [];
  bool _isAvailable = true;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isUpdatingAvailability = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchProfileData({bool showLoadingIndicator = true}) async {
    if (!mounted) return;
    if (showLoadingIndicator) {
      setState(() { _isLoading = true; _errorMessage = null; });
    }
    String? token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      await _handleAuthError();
      return;
    }
    try {
      final response = await http.get(
        Uri.parse(_profileApiUrl),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _profileData = data['profile'] as Map<String, dynamic>?;
          _statsData = data['stats'] as Map<String, dynamic>?;
          _positionsList = data['positions'] as List<dynamic>? ?? [];
          var availabilityFromApi = _profileData?['is_available'];
          if (availabilityFromApi is int) _isAvailable = availabilityFromApi == 1;
          else if (availabilityFromApi is bool) _isAvailable = availabilityFromApi;
          else if (availabilityFromApi is String) _isAvailable = availabilityFromApi == "1";
          _isLoading = false; _errorMessage = null;
        });
      } else if (response.statusCode == 401) { await _handleAuthError();
      } else { setState(() { _errorMessage = "Failed to load profile (${response.statusCode})"; _isLoading = false; });}
    } on SocketException { setState(() { _errorMessage = "Network error."; _isLoading = false; });
    } on TimeoutException { setState(() { _errorMessage = "Connection timed out."; _isLoading = false; });
    } catch (e, s) { print("FetchProfile Exc: $e\n$s"); setState(() { _errorMessage = "Unexpected error."; _isLoading = false; }); }
  }

  Future<void> _updateAvailability(bool newValue) async {
    if (!mounted || _isUpdatingAvailability) return;
    setState(() => _isUpdatingAvailability = true);
    String? token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) { await _handleAuthError(); if (mounted) setState(() => _isUpdatingAvailability = false); return; }
    try {
      final response = await http.put( Uri.parse(_availabilityApiUrl),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({'is_available': newValue}),
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() => _isAvailable = newValue);
        _showMessage("Availability updated.", isError: false);
      } else if (response.statusCode == 401) { await _handleAuthError();
      } else { _showMessage("Failed to update availability (${response.statusCode})", isError: true); if(mounted) setState(() => _isAvailable = !newValue); }
    } catch (e) { _showMessage("Error updating availability.", isError: true); if (mounted) setState(() => _isAvailable = !newValue); }
    finally { if (mounted) setState(() => _isUpdatingAvailability = false); }
  }

  Future<void> _handleAuthError() async {
    if (!mounted) return;
    _showMessage('Session expired. Please log in again.', isError: true);
    await _storage.delete(key: 'auth_token'); await _storage.delete(key: 'user_id');
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green.shade600,
      duration: const Duration(seconds: 3), behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _launchUrl(String? urlString) async {
    if (urlString == null || urlString.isEmpty) {
      _showMessage('URL is not available or invalid.', isError: true);
      return;
    }
    if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
      urlString = 'https://$urlString';
    }
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        _showMessage('Could not launch $urlString', isError: true);
      }
    } else {
       _showMessage('Cannot launch URL: $urlString. Invalid URL or no app can handle it.', isError: true);
    }
  }

  Widget _buildProfileHeader() {
    if (_profileData == null) return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
    String imageUrl = _profileData!['image_url']?.toString() ?? '';
    String name = "${_profileData!['first_name'] ?? 'Provider'} ${_profileData!['last_name'] ?? 'User'}".trim();
    String email = _profileData!['email']?.toString() ?? 'No email provided';

    return Column(children: [
        CircleAvatar(
          radius: 55, backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          backgroundImage: imageUrl.isNotEmpty && Uri.tryParse(imageUrl)?.hasAbsolutePath == true ? NetworkImage(imageUrl) : null,
          child: imageUrl.isEmpty || Uri.tryParse(imageUrl)?.hasAbsolutePath != true ? Icon(Icons.person_rounded, size: 60, color: Theme.of(context).colorScheme.primary) : null,
        ),
        const SizedBox(height: 12),
        Text(name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        Text(email, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
        const SizedBox(height: 20),
      ],);
  }

  Widget _buildInfoTile(IconData icon, String title, String? subtitle, {VoidCallback? onTap, bool isLink = false}) {
    if (subtitle == null || subtitle.isEmpty || subtitle.toLowerCase() == "not specified" || subtitle.toLowerCase() == "null") {
      return const SizedBox.shrink();
    }
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor.withOpacity(0.9), size: 22),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 14.5, color: isLink ? Colors.blue.shade700 : Colors.grey.shade800, decoration: isLink ? TextDecoration.underline : TextDecoration.none)),
      onTap: onTap,
      trailing: onTap != null && !isLink ? Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade500) : (isLink ? Icon(Icons.open_in_new_rounded, size: 20, color: Colors.blue.shade700) : null),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Card(
        elevation: 0.5,
        color: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_outlined, size: 28),
            tooltip: "Edit Profile",
            onPressed: _profileData == null || _isLoading ? null : () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfilePage(
                    initialProfileData: Map<String, dynamic>.from(_profileData!),
                    currentPositions: _positionsList.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
                  ),
                ),
              );
              if (result == true && mounted) {
                _fetchProfileData(showLoadingIndicator: false);
              }
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 60), SizedBox(height:16), Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.redAccent, fontSize: 17, fontWeight: FontWeight.w500)), SizedBox(height:24), ElevatedButton.icon(icon: Icon(Icons.refresh), label: Text("Try Again"), onPressed: _fetchProfileData)])))
              : _profileData == null
                  ? const Center(child: Text("Could not load profile data. Pull to refresh.", style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _fetchProfileData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildProfileHeader(),
                            Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 12.0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Column(
                                  children: [
                                    _buildInfoTile(Icons.info_outline_rounded, "Bio", _profileData!['bio']?.toString()),
                                    _buildInfoTile(Icons.attach_money_rounded, "Hourly Rate", _profileData!['hourly_rate'] != null ? "\$${_profileData!['hourly_rate']}/hr" : null),
                                    _buildInfoTile(Icons.build_circle_outlined, "Skills", _profileData!['skills']?.toString()),
                                    _buildInfoTile(Icons.work_history_outlined, "Positions",
                                      _positionsList.isNotEmpty
                                          ? _positionsList.map((p) => p['name']?.toString() ?? 'N/A').where((n) => n != 'N/A').join(', ')
                                          : "Not specified",
                                    ),
                                    _buildInfoTile(Icons.location_city_rounded, "City", "${_profileData!['city_name'] ?? ''} - ${_profileData!['zip_code'] ?? ''}".trim() == "-" ? null : "${_profileData!['city_name'] ?? ''} - ${_profileData!['zip_code'] ?? ''}"),
                                    _buildInfoTile(
                                      Icons.facebook_rounded, // يمكنك استخدام أيقونة فيسبوك إذا أضفت font_awesome_flutter
                                      "Facebook",
                                      _profileData!['facebook_url']?.toString(),
                                      onTap: () => _launchUrl(_profileData!['facebook_url']?.toString()),
                                      isLink: true,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: SwitchListTile(
                                title: const Text("Availability", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15.5)),
                                subtitle: Text(_isAvailable ? "Online - Ready for tasks" : "Offline - Not available", style: TextStyle(fontSize: 13, color: _isAvailable ? Colors.green.shade700 : Colors.grey.shade700)),
                                secondary: Icon(_isAvailable ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded, color: _isAvailable ? Colors.green.shade700 : Colors.grey.shade700, size: 30),
                                value: _isAvailable,
                                onChanged: _isUpdatingAvailability ? null : (val) => _updateAvailability(val),
                                activeColor: Colors.green.shade600,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                              ),
                            ),
                            if (_isUpdatingAvailability) const Padding(padding: EdgeInsets.symmetric(vertical:8.0), child: LinearProgressIndicator()),
                            const SizedBox(height: 24),
                            Text("Your Statistics", textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                            const SizedBox(height: 12),
                            if (_statsData != null)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatCard("Total Tasks", _statsData!['total_tasks']?.toString() ?? '0'),
                                  const SizedBox(width: 10),
                                  _buildStatCard("Completed", _statsData!['completed_tasks']?.toString() ?? '0'),
                                  const SizedBox(width: 10),
                                  _buildStatCard("Avg. Rating", _statsData!['avg_rating']?.toString() ?? 'N/A'),
                                ],
                              )
                            else
                              const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Center(child: Text("No statistics available yet.", style: TextStyle(color: Colors.grey)))),
                          ],
                        ),
                      ),
                    ),
    );
  }
}