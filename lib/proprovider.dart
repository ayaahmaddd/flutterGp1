import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'login.dart'; // إذا احتجت لإعادة التوجيه
// إذا كان لديك صفحة تفاصيل مشروع منفصلة، قم باستيرادها
// import 'project_details_page.dart';


// --- تعريف ItemType ---
enum ItemType { task, project }
// --- نهاية تعريف ItemType ---


class ProviderProjectsPage extends StatefulWidget {
  const ProviderProjectsPage({super.key});

  @override
  State<ProviderProjectsPage> createState() => _ProviderProjectsPageState();
}

class _ProviderProjectsPageState extends State<ProviderProjectsPage> {
  final _storage = const FlutterSecureStorage();
  final String _baseDomain = "http://localhost:3000"; // أو "http://10.0.2.2:3000"
  late final String _apiBaseUrl = "$_baseDomain/api";

  List<dynamic> _projects = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMyProjects();
  }

  Future<void> _fetchMyProjects() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _projects = [];
    });

    String? token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      if (mounted) await _handleAuthError();
      return;
    }

    final url = Uri.parse("$_apiBaseUrl/provider/work/projects");
    print("--- ProviderProjectsPage: Fetching projects from $url ---");

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic>? fetchedProjects = data['projects'] as List<dynamic>?;

        if (fetchedProjects != null) {
          setState(() {
            _projects = fetchedProjects;
            _isLoading = false;
            if (_projects.isEmpty) {
              _errorMessage = "You don't have any projects assigned yet.";
            } else {
              _errorMessage = null;
            }
          });
        } else {
          if (mounted) setState(() { _errorMessage = "Invalid response: 'projects' key not found."; _isLoading = false; });
        }
      } else if (response.statusCode == 401) {
        await _handleAuthError();
      } else {
        if (mounted) setState(() { _errorMessage = "Error fetching projects: ${response.statusCode}"; _isLoading = false; });
      }
    } on SocketException {
      if (mounted) setState(() { _errorMessage = "Network error. Please check connection."; _isLoading = false; });
    } on TimeoutException {
      if (mounted) setState(() { _errorMessage = "Connection timed out."; _isLoading = false; });
    } catch (e, s) {
      print("!!! ProviderProjectsPage: FetchProjects Exception: $e\n$s !!!");
      if (mounted) setState(() { _errorMessage = "An unexpected error occurred."; _isLoading = false; });
    }
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

  Widget _buildProjectList() {
    if (_projects.isEmpty && _errorMessage != null && !_isLoading) {
         return _buildErrorState();
    }
    if (_projects.isEmpty && !_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_off_outlined, size: 70, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? "No projects assigned yet.",
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
               ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text("Refresh"),
                  onPressed: _fetchMyProjects,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMyProjects,
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _projects.length,
        itemBuilder: (context, index) {
          final project = _projects[index];
          final int? projectIdInt = int.tryParse(project['id']?.toString() ?? '');
          if (projectIdInt == null) return const SizedBox.shrink();

          return TaskListItem(
            itemData: project,
            itemId: projectIdInt,
            primaryColor: Theme.of(context).colorScheme.secondary,
            itemType: ItemType.project,
            onTap: () {
              print("Tapped on project ID: $projectIdInt.");
              // Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailsPage(projectId: projectIdInt)));
            },
          );
        },
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
              onPressed: _fetchMyProjects,
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
        title: const Text("My Projects"),
        actions: [
            IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _isLoading ? null : _fetchMyProjects,
                tooltip: "Refresh Projects",
            )
        ],
      ),
      body: _isLoading && _projects.isEmpty
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
          : _buildProjectList(),
    );
  }
}


// --- ودجة عنصر القائمة (TaskListItem) ---
class TaskListItem extends StatelessWidget {
  final Map<String, dynamic> itemData;
  final int itemId;
  final ItemType itemType;
  final VoidCallback? onTap;
  final Color? primaryColor;

  const TaskListItem({
    super.key,
    required this.itemData,
    required this.itemId,
    required this.itemType,
    this.onTap,
    this.primaryColor,
  });

  String _formatDisplayDate(String? dateString) {
    if (dateString == null) return "N/A";
    try {
      final dateTime = DateTime.parse(dateString).toLocal();
      return DateFormat('dd MMM yyyy').format(dateTime);
    } catch (e) { return dateString; }
  }

  String _formatSecondsToReadableTime(dynamic secondsRaw) {
    if (secondsRaw == null) return "N/A";
    int totalSeconds;
    if (secondsRaw is int) { totalSeconds = secondsRaw; }
    else if (secondsRaw is String) { totalSeconds = int.tryParse(secondsRaw) ?? 0; }
    else if (secondsRaw is double) { totalSeconds = secondsRaw.toInt(); }
    else { return "N/A"; }

    if (totalSeconds <= 0) return "N/A";
    int days = totalSeconds ~/ (24 * 3600);
    totalSeconds %= (24 * 3600);
    int hours = totalSeconds ~/ 3600;
    totalSeconds %= 3600;
    int minutes = totalSeconds ~/ 60;

    String result = "";
    if (days > 0) result += "${days}d ";
    if (hours > 0) result += "${hours}h ";
    if (minutes > 0) result += "${minutes}m";
    return result.trim().isEmpty ? (totalSeconds > 0 && days == 0 && hours == 0 && minutes == 0 ? "$totalSeconds s" : "N/A") : result.trim();
  }

  @override
  Widget build(BuildContext context) {
    final themePrimaryColor = primaryColor ?? Theme.of(context).primaryColor;

    String title = itemData['name']?.toString() ?? itemData['description']?.toString() ?? 'N/A';
    String status = itemData['status']?.toString() ?? (itemType == ItemType.project ? 'In Progress' : 'Unknown');
    String? creationDateString = itemData['created_at']?.toString() ?? itemData['created']?.toString();
    IconData leadingIconData = itemType == ItemType.task ? Icons.construction_outlined : Icons.folder_open_outlined;

    String? companyName = itemData['company_name']?.toString();
    String? clientNameForProject = itemData['client_name']?.toString();
    String? teamName = itemData['team_name']?.toString();
    String? projectDescription = (itemType == ItemType.project && itemData['description'] != title) ? itemData['description']?.toString() : null;
    String? startDate = itemData['start_date']?.toString();
    String? endDate = itemData['end_date']?.toString();
    String? initialProjectPrice = itemData['Initial_price']?.toString();
    String? maxProjectPrice = itemData['max_price']?.toString();
    String? actualProjectPrice = itemData['actual_price']?.toString();
    String? initialTimeS = itemData['Initial_time_s']?.toString();
    final finalTimeSeconds = itemData['final_time_s'];
    dynamic actualTimeRaw = itemData['actual_time'];
    String displayActualTime;
    if (actualTimeRaw is int || (actualTimeRaw is String && int.tryParse(actualTimeRaw.toString()) != null)) {
      displayActualTime = _formatSecondsToReadableTime(actualTimeRaw);
    } else if (actualTimeRaw is String) {
      displayActualTime = actualTimeRaw;
    } else {
      displayActualTime = "N/A";
    }

    String displaySubtitle = itemType == ItemType.task ? (itemData['client_name']?.toString() ?? 'N/A Client') : (companyName ?? clientNameForProject ?? 'N/A Company/Client');
    String? companyLogoUrl = itemData['company_logo']?.toString();

    return Card(
      elevation: 2.5, color: Colors.white, margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10), onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: themePrimaryColor.withOpacity(0.1),
                    child: companyLogoUrl != null && companyLogoUrl.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              companyLogoUrl, width: 52, height: 52, fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(leadingIconData, size: 28, color: themePrimaryColor),
                              loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(child: CircularProgressIndicator(value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null, strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(themePrimaryColor)));
                              },
                            ),
                          )
                        : Icon(leadingIconData, size: 28, color: themePrimaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(displaySubtitle, style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  // السهم تمت إزالته من هنا
                ],
              ),
              if (projectDescription != null && projectDescription.isNotEmpty) ...[
                const Divider(height: 20, thickness: 0.5),
                Text("Description:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: themePrimaryColor.withOpacity(0.8))),
                const SizedBox(height: 4),
                Text(projectDescription, style: TextStyle(fontSize: 13.5, color: Colors.grey.shade800), maxLines: 4, overflow: TextOverflow.ellipsis),
              ],
              const Divider(height: 22, thickness: 0.5),
              if (itemType == ItemType.project) ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    if (startDate != null) _infoColumn(context, "Start Date", _formatDisplayDate(startDate)),
                    if (endDate != null) _infoColumn(context, "End Date", _formatDisplayDate(endDate)),
                  ],),
                const SizedBox(height: 8),
                if (initialProjectPrice != null || maxProjectPrice != null)
                  _buildInfoRow(context, Icons.monetization_on_outlined, "Est. Price: ${initialProjectPrice ?? '?'} ${maxProjectPrice != null && maxProjectPrice != initialProjectPrice ? '- $maxProjectPrice' : ''}", iconColor: Colors.orange.shade800),
                if (actualProjectPrice != null && actualProjectPrice != "null")
                   _buildInfoRow(context, Icons.price_check_rounded, "Actual Price: $actualProjectPrice", iconColor: Colors.green.shade700),
                if (initialTimeS != null)
                  _buildInfoRow(context, Icons.timer_outlined, "Est. Initial Time: ${_formatSecondsToReadableTime(initialTimeS)}", iconColor: Colors.blueGrey.shade600),
                if (finalTimeSeconds != null)
                  _buildInfoRow(context, Icons.hourglass_full, "Est. Final Time: ${_formatSecondsToReadableTime(finalTimeSeconds)}", iconColor: Colors.blueGrey.shade600),
                if (actualTimeRaw != null && actualTimeRaw.toString() != "null" && displayActualTime != "N/A")
                  _buildInfoRow(context, Icons.timelapse_rounded, "Actual Time Spent: $displayActualTime", iconColor: Colors.indigo.shade700),
                if (teamName != null) _buildInfoRow(context, Icons.group_work_outlined, "Team: $teamName"),
                if (clientNameForProject != null && clientNameForProject != companyName) _buildInfoRow(context, Icons.person_pin_circle_outlined, "Client Contact: $clientNameForProject"),
              ],
              if (itemType == ItemType.task) ...[
                if (itemData['estimated_time'] != null && itemData['estimated_time'].toString().isNotEmpty)
                  _buildInfoRow(context, Icons.access_time_outlined, "Est. Time: ${itemData['estimated_time']?.toString()}"),
              ],
              const SizedBox(height: 8),
              _buildInfoRow(context, Icons.history_toggle_off_outlined, "Created: ${_buildCreationTime(creationDateString)}", iconColor: Colors.grey.shade600),
              const SizedBox(height: 10),
              if (itemData['status'] != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Chip(
                    avatar: Icon(Icons.flag_outlined, color: _getStatusColor(status, context), size: 16),
                    label: Text(status, style: TextStyle(color: _getStatusColor(status, context), fontWeight: FontWeight.w500, fontSize: 12)),
                    backgroundColor: _getStatusColor(status, context).withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoColumn(BuildContext context, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text, {Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor ?? Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14.0))),
        ],
      ),
    );
  }

  String _buildCreationTime(String? dateString) {
    if (dateString == null) return "N/A";
    DateTime? creationDate;
    try { creationDate = DateTime.parse(dateString).toLocal(); }
    catch (e) { return "N/A"; }
    return timeago.format(creationDate, locale: WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'ar' ? 'ar' : null);
  }

   Color _getStatusColor(String status, BuildContext context) {
    switch (status.toLowerCase()) {
      case 'completed': return Colors.green.shade700;
      case 'rejected': return Colors.red.shade700;
      case 'pending': return Colors.orange.shade700;
      case 'active': return Colors.blue.shade700;
      case 'approved': return Colors.teal.shade600;
      case 'in progress': return Colors.purple.shade600;
      default: return Theme.of(context).colorScheme.primary;
    }
  }
}