import 'dart:convert';
import 'dart:io'; // لاستخدام SocketException
import 'dart:async'; // لاستخدام TimeoutException

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'login.dart'; // إذا احتجت لإعادة التوجيه عند خطأ المصادقة

class ProviderTeamsPage extends StatefulWidget {
  const ProviderTeamsPage({super.key});

  @override
  State<ProviderTeamsPage> createState() => _ProviderTeamsPageState();
}

class _ProviderTeamsPageState extends State<ProviderTeamsPage> {
  final _storage = const FlutterSecureStorage();
  final String _baseDomain = "http://localhost:3000"; // أو "http://10.0.2.2:3000"
  late final String _apiUrl = "$_baseDomain/api/provider/work/teams";

  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _teams = [];

  @override
  void initState() {
    super.initState();
    _fetchTeams();
  }

  Future<void> _handleAuthError() async {
    if (!mounted) return;
    _showMessage('Session expired. Please log in.', isError: true);
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_id');
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green,
      duration: const Duration(seconds: 3),
    ));
  }


  Future<void> _fetchTeams() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      // يمكنك مسح _teams هنا إذا أردت إظهار تحميل كامل عند كل تحديث
      // _teams = [];
    });

    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      if(mounted) await _handleAuthError();
      return;
    }

    print("--- ProviderTeamsPage: Fetching teams from $_apiUrl ---");

    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // تأكد أن الـ API يرجع قائمة الفرق داخل مفتاح "teams"
        final List<dynamic>? fetchedTeams = data['teams'] as List<dynamic>?;
        if (fetchedTeams != null) {
            setState(() {
            _teams = fetchedTeams;
            _isLoading = false;
            if (_teams.isEmpty) {
                _errorMessage = "You are not part of any teams yet.";
            }
            });
        } else {
            print("!!! ProviderTeamsPage: 'teams' key not found or not a list in API response. Body: ${response.body}");
            if (mounted) setState(() { _errorMessage = 'Invalid data format from server.'; _isLoading = false; _teams = []; });
        }
      } else if (response.statusCode == 401) {
        await _handleAuthError();
      }
      else {
        print("!!! ProviderTeamsPage: Failed to fetch teams. Status: ${response.statusCode}, Body: ${response.body}");
        if (mounted) setState(() {
          _errorMessage = 'Failed to fetch teams (${response.statusCode})';
          _isLoading = false;
          _teams = [];
        });
      }
    } on SocketException {
      if (mounted) setState(() { _errorMessage = 'Network error. Please check connection.'; _isLoading = false; _teams = []; });
    } on TimeoutException {
      if (mounted) setState(() { _errorMessage = 'Connection timed out.'; _isLoading = false; _teams = []; });
    }
    catch (e,s) {
      print("!!! ProviderTeamsPage: FetchTeams Exception: $e\n$s");
      if (mounted) setState(() {
        _errorMessage = 'Something went wrong while fetching teams.';
        _isLoading = false;
        _teams = [];
      });
    }
  }

  Widget _buildTeamCard(Map<String, dynamic> team) {
    String? companyLogoUrl = team['company_logo'] as String?;
    List<dynamic> members = team['members'] as List<dynamic>? ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey.shade200, // لون احتياطي
                  backgroundImage: companyLogoUrl != null && companyLogoUrl.isNotEmpty
                      ? NetworkImage(companyLogoUrl)
                      : null,
                  child: companyLogoUrl == null || companyLogoUrl.isEmpty
                      ? Icon(Icons.group_work_outlined, size: 30, color: Theme.of(context).primaryColor)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(team['name']?.toString() ?? 'Unnamed Team', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (team['company_name'] != null) ...[
                        const SizedBox(height: 2),
                        Text(team['company_name']?.toString() ?? '', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                      ]
                    ],
                  ),
                ),
              ],
            ),
            if (team['description'] != null && team['description'].toString().isNotEmpty) ...[
              const Divider(height: 20, thickness: 0.5),
              Text(team['description']?.toString() ?? '', style: TextStyle(fontSize: 14.5, color: Colors.grey.shade800)),
            ],
            const Divider(height: 24, thickness: 0.5),
            Text("Members (${team['member_count']?.toString() ?? members.length}):", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            if (members.isNotEmpty)
              ListView.builder(
                shrinkWrap: true, // مهم داخل Column
                physics: const NeverScrollableScrollPhysics(), // لمنع التمرير المتداخل
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index] as Map<String, dynamic>;
                  String? memberImageUrl = member['image_url'] as String?;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: memberImageUrl != null && memberImageUrl.isNotEmpty
                          ? NetworkImage(memberImageUrl)
                          : null,
                      child: memberImageUrl == null || memberImageUrl.isEmpty
                          ? Icon(Icons.person_outline, color: Theme.of(context).primaryColor.withOpacity(0.7))
                          : null,
                    ),
                    title: Text(member['name']?.toString() ?? 'Unknown Member', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
                    subtitle: Text(member['position']?.toString() ?? 'No position', style: const TextStyle(fontSize: 13)),
                  );
                },
              )
            else
              const Text("No members listed for this team.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(){
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? "An error occurred.",
              style: const TextStyle(color: Colors.redAccent, fontSize: 17),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("Try Again"),
              onPressed: _fetchTeams,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Teams"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchTeams,
            tooltip: "Refresh Teams",
          )
        ],
      ),
      body: _isLoading && _teams.isEmpty // إظهار التحميل فقط إذا كانت القائمة فارغة تمامًا
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
          : _errorMessage != null && _teams.isEmpty // عرض الخطأ فقط إذا لم تكن هناك فرق لعرضها
              ? _buildErrorState()
              : _teams.isEmpty // لا يوجد خطأ، ولكن لا توجد فرق
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline_rounded, size: 70, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            const Text(
                              "You are not part of any teams yet.",
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                             const SizedBox(height: 20),
                             ElevatedButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text("Refresh"),
                                onPressed: _fetchTeams,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator( // لإضافة السحب للتحديث
                      onRefresh: _fetchTeams,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top:8, bottom: 8),
                        itemCount: _teams.length,
                        itemBuilder: (context, index) {
                          return _buildTeamCard(_teams[index]);
                        },
                      ),
                    ),
    );
  }
}