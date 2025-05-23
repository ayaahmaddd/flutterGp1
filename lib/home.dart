import 'dart:convert';
import 'dart:io'; // لاستخدام SocketException
import 'dart:async'; // لاستخدام TimeoutException

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart'; // لاستيراد DateFormat

// استيراد الصفحات الأخرى
import 'login.dart';
import 'taskdetiels.dart';
import 'task_history_page.dart';
import 'proprovider.dart';
import 'teampro.dart';
import 'my_companies_page.dart';
import 'my_profile_page.dart';
import 'CompanyJobsPage.dart';


// --- الصفحة الرئيسية ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _storage = const FlutterSecureStorage();
  final String _baseDomain = "http://localhost:3000"; // أو "http://10.0.2.2:3000"
  late final String _authBaseUrl = "$_baseDomain/api/auth";
  late final String _tasksApiBaseUrl = "$_baseDomain/api";

  bool _isLoadingTasks = true;
  bool _isLogoutLoading = false;
  String? _tasksErrorMessage;
  List<dynamic> _tasks = []; // قائمة المهام النشطة فقط
  final String _currentViewTitle = "Available Tasks"; // الصفحة الرئيسية تعرض دائمًا المهام النشطة

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    print("--- HomePage initState: Calling _fetchAvailableTasks ---");
    _fetchAvailableTasks();
  }

  Future<void> _fetchAvailableTasks() async {
    print("--- HomePage _fetchAvailableTasks: Started ---");
    if (!mounted) return;
    setState(() {
      _isLoadingTasks = true;
      _tasksErrorMessage = null;
      _tasks = [];
    });

    String? token;
    try {
      token = await _storage.read(key: 'auth_token');
      if (token == null || token.isEmpty) {
        if (mounted) { setState(() { _tasksErrorMessage = 'Authentication required. Please log in.'; _isLoadingTasks = false; }); WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false); });}
        return;
      }
      final url = Uri.parse("$_tasksApiBaseUrl/tasks/active");
      print("--- HomePage _fetchAvailableTasks: Requesting $url ---");

      final response = await http.get(url, headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 20));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic>? taskList = data['tasks'] as List<dynamic>?;
        if (taskList != null) {
          setState(() { _tasks = taskList; _isLoadingTasks = false; });
          print("--- HomePage _fetchAvailableTasks: Loaded ${_tasks.length} tasks ---");
        } else { throw FormatException("Expected 'tasks' list in response."); }
      } else if (response.statusCode == 401) { await _handleAuthenticationError();
      } else if (response.statusCode == 403) { setState(() { _tasksErrorMessage = 'Access Denied (403).'; _isLoadingTasks = false; });
      } else { print("Fetch Error ${response.statusCode}: ${response.body}"); setState(() { _tasksErrorMessage = 'Server Error: ${response.statusCode}.'; _isLoadingTasks = false; }); }
    } on SocketException { if (!mounted) return; setState(() { _tasksErrorMessage = 'Network error.'; _isLoadingTasks = false; });
    } on TimeoutException { if (!mounted) return; setState(() { _tasksErrorMessage = 'Connection timed out.'; _isLoadingTasks = false; });
    } catch (e, s) { print("FetchAvailableTasks Exc: $e\n$s"); if (!mounted) return; setState(() { _tasksErrorMessage = 'Unexpected error.'; _isLoadingTasks = false; });
    } finally { if (mounted && _isLoadingTasks) { setState(() => _isLoadingTasks = false); } }
  }

  Future<void> _handleAuthenticationError() async {
    if (!mounted) return;
    _showMessage('Session expired. Please log in again.', isError: true);
    await _storage.delete(key: 'auth_token'); await _storage.delete(key: 'user_id');
    setState(() { _tasksErrorMessage = 'Session expired.'; _isLoadingTasks = false; _tasks = []; });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false);
    });
  }

  Future<void> _handleLogout() async {
    if (!mounted || _isLogoutLoading) return;
    setState(() => _isLogoutLoading = true);
    final String? token = await _storage.read(key: 'auth_token');
    final String? userId = await _storage.read(key: 'user_id');
    Future<void> performLocalLogout() async {
      await _storage.delete(key: 'auth_token'); await _storage.delete(key: 'user_id');
      if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false);
    }
    if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
      _showMessage("Auth missing. Logging out.", isError: true); await performLocalLogout();
      if (mounted) setState(() => _isLogoutLoading = false); return;
    }
    final url = Uri.parse('$_authBaseUrl/logout');
    try {
      await http.post(url, headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': 'Bearer $token'}, body: jsonEncode({'user_id': userId})).timeout(const Duration(seconds: 10));
      _showMessage("Logged out.");
    } catch (error) { _showMessage('Logout error. Logged out locally.', isError: true);
    } finally { await performLocalLogout(); if (mounted) setState(() => _isLogoutLoading = false); }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message), backgroundColor: isError ? Colors.redAccent : Colors.green, duration: const Duration(seconds: 3), behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final Color currentPrimaryColor = Theme.of(context).primaryColor;
    final Color currentScaffoldBackgroundColor = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: currentScaffoldBackgroundColor,
      appBar: AppBar(title: Text(_currentViewTitle), actions: [
          if (_isLogoutLoading) const Padding(padding: EdgeInsets.only(right: 20.0), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)))
          else IconButton(icon: const Icon(Icons.logout), onPressed: _handleLogout, tooltip: "Logout"),
        ],
      ),
      drawer: _buildDrawer(currentPrimaryColor),
      body: _buildTaskItemBody(currentPrimaryColor),
    );
  }

  Widget _buildDrawer(Color currentPrimaryColor) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(decoration: BoxDecoration(color: currentPrimaryColor), child: const Center(child: Text("Menu", style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)))),
          ListTile(leading: Icon(Icons.person_outline_rounded, color: currentPrimaryColor), title: const Text("My Profile", style: TextStyle(fontSize: 18)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const MyProfilePage())); }),
          // لا يوجد Divider هنا إذا أردت "My Jobs" مباشرة تحت "My Profile"
          // إذا أردت فاصلًا، أضف: const Divider(),

          ListTile(leading: Icon(Icons.list_alt_rounded, color: currentPrimaryColor), title: const Text("Available Tasks", style: TextStyle(fontSize: 18)), onTap: () { Navigator.pop(context); if (!_isLoadingTasks) _fetchAvailableTasks(); }, enabled: !(_isLoadingTasks || _isLogoutLoading)),
          // ***** "My Jobs" الآن تحت "Available Tasks" *****
          ListTile(
            leading: Icon(Icons.work_history_outlined, color: currentPrimaryColor),
            title: const Text("My Jobs", style: TextStyle(fontSize: 18)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) =>  CompanyJobsPage(companyId: '', companyName: '',)));
            },
             enabled: !(_isLoadingTasks || _isLogoutLoading),
          ),
          // ***** نهاية "My Jobs" *****
          ListTile(leading: Icon(Icons.folder_special_outlined, color: currentPrimaryColor), title: const Text("My Projects", style: TextStyle(fontSize: 18)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const ProviderProjectsPage())); }, enabled: !(_isLoadingTasks || _isLogoutLoading)),
          ListTile(leading: Icon(Icons.group_work_outlined, color: currentPrimaryColor), title: const Text("My Team", style: TextStyle(fontSize: 18)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const ProviderTeamsPage())); }),
          ListTile(leading: Icon(Icons.business_center_outlined, color: currentPrimaryColor), title: const Text("The Company I Work For", style: TextStyle(fontSize: 18)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const MyCompaniesPage())); }),
          const Divider(),
          ListTile(leading: Icon(Icons.history_rounded, color: currentPrimaryColor), title: const Text("Task History", style: TextStyle(fontSize: 18)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const TaskHistoryPage())); }),
          const Divider(),
          ListTile(leading: Icon(Icons.logout_rounded, color: Colors.red.shade700), title: const Text("Logout", style: TextStyle(fontSize: 18)), onTap: (_isLoadingTasks || _isLogoutLoading) ? null : _handleLogout, enabled: !(_isLoadingTasks || _isLogoutLoading)),
        ],
      ),
    );
  }

  Widget _buildTaskItemBody(Color currentPrimaryColor) {
    if (_isLoadingTasks) return Center(child: CircularProgressIndicator(color: currentPrimaryColor));
    if (_tasksErrorMessage != null) return _buildErrorWidget(_tasksErrorMessage!, currentPrimaryColor);
    if (_tasks.isEmpty) return _buildNoItemsWidget("Available Tasks", currentPrimaryColor);
    return _buildTaskListWidget(currentPrimaryColor);
  }

  Widget _buildErrorWidget(String errorMessage, Color currentPrimaryColor) {
    bool isAuthError = errorMessage.contains('Auth') || errorMessage.contains('Session');
    bool isForbiddenError = errorMessage.contains('Access Denied') || errorMessage.contains('403');
    String buttonText = "Try Again";
    VoidCallback? onPressedAction = _fetchAvailableTasks;
    IconData buttonIcon = Icons.refresh; Color buttonColor = currentPrimaryColor;
    if(isAuthError) { buttonText = "Go to Login"; onPressedAction = () { if(mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false); }; buttonIcon = Icons.login; }
    else if (isForbiddenError) { buttonText = "Logout"; onPressedAction = _handleLogout; buttonIcon = Icons.logout; buttonColor = Colors.orange.shade800; }
    return Center( child: Padding( padding: const EdgeInsets.all(20.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(isForbiddenError ? Icons.lock_outline : Icons.error_outline, color: Colors.redAccent, size: 60), const SizedBox(height: 16), Text(errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 17, fontWeight: FontWeight.w500), textAlign: TextAlign.center), const SizedBox(height: 24), ElevatedButton.icon( icon: Icon(buttonIcon), label: Text(buttonText), onPressed: onPressedAction, style: ElevatedButton.styleFrom(backgroundColor: buttonColor)), ], ), ) );
  }

  Widget _buildNoItemsWidget(String itemTypeTitle, Color currentPrimaryColor) {
     return Center( child: Padding( padding: const EdgeInsets.all(20.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.inbox_outlined, size: 70, color: Colors.grey[500]), const SizedBox(height: 20), Text( "No items found for \"$itemTypeTitle\".", style: TextStyle(fontSize: 18, color: Colors.grey[700]), textAlign: TextAlign.center), const SizedBox(height: 24), ElevatedButton.icon( icon: const Icon(Icons.refresh), label: const Text("Check Again"), onPressed: _isLoadingTasks ? null : _fetchAvailableTasks, style: ElevatedButton.styleFrom(backgroundColor: currentPrimaryColor)), ], ), ) );
  }

  Widget _buildTaskListWidget(Color currentPrimaryColor) {
    return RefreshIndicator(
      onRefresh: _fetchAvailableTasks,
      color: currentPrimaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          final dynamic taskIdRaw = task['id'];
          int? taskIdInt;
          if (taskIdRaw is int) { taskIdInt = taskIdRaw; }
          else if (taskIdRaw is String) { taskIdInt = int.tryParse(taskIdRaw); }
          if (taskIdInt == null) return const SizedBox.shrink();

          return TaskListItem(
            itemData: task,
            itemId: taskIdInt,
            primaryColor: currentPrimaryColor,
            itemType: ItemType.task, // HomePage تعرض مهام فقط
            onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailsPage(taskId: taskIdInt!)))
                    .then((value) => _fetchAvailableTasks());
            },
          );
        },
      ),
    );
  }
}

// --- نوع العنصر للتمييز بين مهمة ومشروع ---
enum ItemType { task, project }

// --- ودجة عنصر القائمة (TaskListItem) ---
class TaskListItem extends StatelessWidget {
  final Map<String, dynamic> itemData;
  final int itemId;
  final Color primaryColor;
  final ItemType itemType;
  final VoidCallback? onTap;

  const TaskListItem({
    super.key,
    required this.itemData,
    required this.itemId,
    required this.primaryColor,
    required this.itemType,
    this.onTap,
  });

  String _formatDisplayDate(String? dateString) {
    if (dateString == null) return "N/A";
    try { final dateTime = DateTime.parse(dateString).toLocal(); return DateFormat('dd MMM yyyy').format(dateTime); }
    catch (e) { return dateString; }
  }

  String _formatSecondsToReadableTime(dynamic secondsRaw) {
    if (secondsRaw == null) return "N/A";
    int totalSeconds;
    if (secondsRaw is int) { totalSeconds = secondsRaw; }
    else if (secondsRaw is String) { totalSeconds = int.tryParse(secondsRaw) ?? 0; }
    else if (secondsRaw is double) { totalSeconds = secondsRaw.toInt(); }
    else { return "N/A"; }
    if (totalSeconds <= 0) return "N/A";
    int days = totalSeconds ~/ (24 * 3600); totalSeconds %= (24 * 3600);
    int hours = totalSeconds ~/ 3600; totalSeconds %= 3600;
    int minutes = totalSeconds ~/ 60;
    String result = "";
    if (days > 0) result += "${days}d ";
    if (hours > 0) result += "${hours}h ";
    if (minutes > 0) result += "${minutes}m";
    return result.trim().isEmpty ? (totalSeconds > 0 && days == 0 && hours == 0 && minutes == 0 ? "$totalSeconds s" : "N/A") : result.trim();
  }

  @override
  Widget build(BuildContext context) {
    String title = itemType == ItemType.task
        ? (itemData['description']?.toString() ?? 'N/A Task Description')
        : (itemData['name']?.toString() ?? 'N/A Project Name');
    String subtitle = itemType == ItemType.task
        ? (itemData['client_name']?.toString() ?? 'N/A Client')
        : (itemData['company_name']?.toString() ?? 'N/A Company');

    String? estimatedTiming = itemData['estimated_time']?.toString() ?? itemData['Initial_time_s']?.toString();
    String? projectEndDate = itemData['end_date']?.toString();
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
    String? teamName = itemData['team_name']?.toString();
    String? clientNameForProject = itemData['client_name']?.toString();
    String? projectDescription = (itemType == ItemType.project && itemData['description'] != title) ? itemData['description']?.toString() : null;


    String status = itemData['status']?.toString() ?? 'Unknown';
    String? creationDateString = itemData['created_at']?.toString() ?? itemData['created']?.toString();

    IconData leadingIconData = itemType == ItemType.task ? Icons.construction_outlined : Icons.folder_open_outlined;

    return Card(
      elevation: 3.0, color: Colors.white, margin: const EdgeInsets.only(bottom: 12.0, left: 8, right: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10), onTap: onTap,
        splashColor: primaryColor.withOpacity(0.1), highlightColor: primaryColor.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 26, backgroundColor: primaryColor.withOpacity(0.1),
                    backgroundImage: itemType == ItemType.project && itemData['company_logo'] != null ? NetworkImage(itemData['company_logo'].toString()) : null,
                    child: (itemType == ItemType.project && itemData['company_logo'] == null) || itemType == ItemType.task ? Icon(leadingIconData, size: 28, color: primaryColor) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(subtitle, style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  if (onTap != null) Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 26),
                ],
              ),
              if (projectDescription != null && projectDescription.isNotEmpty) ...[
                const Divider(height: 20, thickness: 0.5),
                Text("Description:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryColor)),
                const SizedBox(height: 4),
                Text(projectDescription, style: TextStyle(fontSize: 13.5, color: Colors.grey.shade800), maxLines: 4, overflow: TextOverflow.ellipsis),
              ],

              const Divider(height: 22, thickness: 0.5),

              if (itemType == ItemType.project) ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    if (itemData['start_date'] != null) _infoColumn(context, "Start Date", _formatDisplayDate(itemData['start_date']?.toString())),
                    if (itemData['end_date'] != null) _infoColumn(context, "End Date", _formatDisplayDate(itemData['end_date']?.toString())),
                  ],),
                const SizedBox(height: 6),
                if (initialProjectPrice != null || maxProjectPrice != null)
                  _buildInfoRow(context, Icons.monetization_on_outlined, "Est. Price: ${initialProjectPrice ?? '?'} ${maxProjectPrice != null && maxProjectPrice != initialProjectPrice ? '- $maxProjectPrice' : ''}", iconColor: Colors.orange.shade700),
                if (actualProjectPrice != null && actualProjectPrice != "null")
                   _buildInfoRow(context, Icons.price_check_rounded, "Actual Price: $actualProjectPrice", iconColor: Colors.green.shade800),
                if (initialTimeS != null)
                  _buildInfoRow(context, Icons.timer_outlined, "Est. Initial Time: ${_formatSecondsToReadableTime(initialTimeS)}", iconColor: Colors.blueGrey.shade700),
                if (finalTimeSeconds != null)
                  _buildInfoRow(context, Icons.hourglass_full, "Est. Final Time: ${_formatSecondsToReadableTime(finalTimeSeconds)}", iconColor: Colors.blueGrey.shade600),
                if (actualTimeRaw != null && actualTimeRaw.toString() != "null" && displayActualTime != "N/A")
                  _buildInfoRow(context, Icons.timelapse_rounded, "Actual Time Spent: $displayActualTime", iconColor: Colors.indigo.shade700),
                if (teamName != null)
                  _buildInfoRow(context, Icons.group_work_outlined, "Team: $teamName"),
                if (clientNameForProject != null && clientNameForProject != subtitle)
                   _buildInfoRow(context, Icons.person_pin_circle_outlined, "Client Contact: $clientNameForProject"),
              ],

              if (itemType == ItemType.task) ...[ // هذا الجزء خاص بالمهام فقط
                if (estimatedTiming != null && estimatedTiming.isNotEmpty)
                  _buildInfoRow(context, Icons.access_time_outlined, "Est. Time: $estimatedTiming"),
              ],

              if ((itemType == ItemType.project && (initialProjectPrice != null || teamName != null || itemData['start_date'] != null)) || (itemType == ItemType.task && estimatedTiming != null && estimatedTiming.isNotEmpty))
                const SizedBox(height: 6),

              _buildInfoRow(context, Icons.history_toggle_off_outlined, "Created: ${_buildCreationTime(creationDateString)}", iconColor: Colors.grey.shade600),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Chip(
                  avatar: Icon(Icons.flag_outlined, color: _getStatusColor(status, context), size: 16),
                  label: Text(status, style: TextStyle(color: _getStatusColor(status, context), fontWeight: FontWeight.w500, fontSize: 12)),
                  backgroundColor: _getStatusColor(status, context).withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
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

  Widget _buildInfoRow(BuildContext context, IconData icon, String? text, {Color? iconColor}) {
    if (text == null || text.isEmpty || text.toLowerCase() == 'n/a') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0, top: 3.0),
      child: Row(
        children: [
          Icon(icon, size: 15, color: iconColor ?? Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: Colors.grey[800], fontSize: 13.5), maxLines: 2, overflow: TextOverflow.ellipsis)),
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
//Icons.hourglass_full