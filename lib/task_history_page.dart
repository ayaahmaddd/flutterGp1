import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'login.dart';
import 'taskdetiels.dart'; // لاستخدام TaskDetailsPage عند الضغط على عنصر

class TaskHistoryPage extends StatefulWidget {
  const TaskHistoryPage({super.key});

  @override
  State<TaskHistoryPage> createState() => _TaskHistoryPageState();
}

class _TaskHistoryPageState extends State<TaskHistoryPage> with SingleTickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  final String _baseDomain = "http://localhost:3000"; // أو "http://10.0.2.2:3000"
  late final String _tasksApiBaseUrl = "$_baseDomain/api";

  List<dynamic> _historyTasks = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  final int _limit = 10;
  bool _isLastPage = false;
  String _selectedStatusValue = 'all';

  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _tabs = [
    {'label': 'All History', 'statusValue': 'all'},
    {'label': 'Completed', 'statusValue': 'completed'},
    {'label': 'Rejected', 'statusValue': 'rejected'},
    {'label': 'Approved', 'statusValue': 'approved'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _selectedStatusValue = _tabs.first['statusValue']!;
    _tabController.addListener(_handleTabSelection);
    WidgetsBinding.instance.addPostFrameCallback((_) {
        if(mounted){
            _fetchHistoryTasks(page: 1, status: _selectedStatusValue, initialLoad: true);
        }
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          !_isLastPage) {
        print("--- Scroll Listener: Reached bottom, fetching more data for status: $_selectedStatusValue ---");
        _fetchHistoryTasks(page: _currentPage + 1, status: _selectedStatusValue);
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging || (_tabController.animation != null && _tabController.animation!.value == _tabController.index.toDouble())) {
      final currentTabIndex = _tabController.index;
      final Map<String, String> selectedTabConfig = _tabs[currentTabIndex];
      final String newStatus = selectedTabConfig['statusValue']!;

      if (newStatus != _selectedStatusValue || _historyTasks.isEmpty) {
        print("--- Tab Changed to: ${selectedTabConfig['label']}, Status Value: $newStatus ---");
        setState(() {
          _selectedStatusValue = newStatus;
          _isLoading = true;
          _historyTasks = [];
          _currentPage = 1;
          _isLastPage = false;
          _errorMessage = null;
        });
        _fetchHistoryTasks(page: 1, status: _selectedStatusValue, initialLoad: true);
      }
    }
  }

  Future<void> _fetchHistoryTasks({required int page, required String status, bool initialLoad = false}) async {
    if (!mounted) return;
    if (page > 1 && _isLoading && !initialLoad) return;

    print("--- TaskHistory: Fetching - Page: $page, Status: $status, Initial: $initialLoad ---");
    if (initialLoad || page == 1) {
        setState(() {
            _isLoading = true;
            _errorMessage = null;
            if (initialLoad) {
                _historyTasks = [];
                _currentPage = 1;
                _isLastPage = false;
            }
        });
    } else {
        setState(() => _isLoading = true);
    }

    String? token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      if (mounted) await _handleAuthError();
      return;
    }

    try {
      Map<String, String> queryParams = {'limit': _limit.toString(), 'page': page.toString()};
      if (status != 'all') queryParams['status'] = status;

      final url = Uri.parse("$_tasksApiBaseUrl/tasks/history/all").replace(queryParameters: queryParams);
      print("--- Requesting History URL: $url");

      final response = await http.get(url, headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 25));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> fetchedTasks = data['tasks'] as List<dynamic>? ?? [];
        setState(() {
          if (initialLoad || page == 1) _historyTasks = fetchedTasks;
          else _historyTasks.addAll(fetchedTasks);
          _currentPage = data['currentPage'] as int? ?? page;
          int totalPagesFromApi = data['totalPages'] as int? ?? 0;
          _isLastPage = fetchedTasks.isEmpty || fetchedTasks.length < _limit || (totalPagesFromApi > 0 && _currentPage >= totalPagesFromApi) ;
          if (fetchedTasks.isEmpty && page > 1 && !_isLastPage) _isLastPage = true;
          _isLoading = false;
          if (_historyTasks.isEmpty && (initialLoad || page == 1) ) _errorMessage = "No tasks found for ${status == 'all' ? 'any status' : status}.";
          else _errorMessage = null;
        });
      } else if (response.statusCode == 401) { await _handleAuthError();
      } else { print("!!! FetchHistoryTasks Error: ${response.statusCode}, Body: ${response.body}"); setState(() { _errorMessage = "Error: ${response.statusCode}"; _isLoading = false; }); }
    } on SocketException { if (!mounted) return; setState(() { _errorMessage = "Network error."; _isLoading = false; });
    } on TimeoutException { if (!mounted) return; setState(() { _errorMessage = "Connection timed out."; _isLoading = false; });
    } catch (e, s) { print("!!! FetchHistoryTasks Exc: $e\n$s"); if (!mounted) return; setState(() { _errorMessage = "Unexpected error."; _isLoading = false; }); }
  }

  Future<void> _handleAuthError() async {
      if (!mounted) return;
      _showMessage('Session expired. Please log in.', isError: true);
      await _storage.delete(key: 'auth_token');
      await _storage.delete(key: 'user_id');
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false);
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

  Widget _buildHistoryTaskItem(Map<String, dynamic> task) {
    final String? creationDateString = task['created_at']?.toString() ?? task['created']?.toString();
    String formattedTime = "Date N/A";
    if (creationDateString != null) {
        try {
            DateTime? creationDate = DateTime.tryParse(creationDateString)?.toLocal();
            if (creationDate != null) {
                 final String locale = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
                 formattedTime = timeago.format(creationDate, locale: locale == 'ar' ? 'ar' : 'en_short');
            }
        } catch(e) { print("Error parsing date for history item: $e");}
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(task['status']?.toString() ?? '').withOpacity(0.15),
          child: Icon(_getStatusIcon(task['status']?.toString() ?? ''), color: _getStatusColor(task['status']?.toString() ?? ''), size: 22),
        ),
        title: Text(task['description']?.toString() ?? 'No Description', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task['client_name'] != null) Text("Client: ${task['client_name']?.toString()}", style: const TextStyle(fontSize: 13)),
            Text("Status: ${task['status']?.toString() ?? 'N/A'}", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _getStatusColor(task['status']?.toString() ?? ''))),
            if (task['status']?.toString() == 'completed') ...[
              if (task['actual_price'] != null) Text("Actual Price: ${task['actual_price']?.toString()}", style: const TextStyle(fontSize: 13)),
              if (task['actual_time'] != null) Text("Actual Time: ${task['actual_time']?.toString()}", style: const TextStyle(fontSize: 13)),
            ],
             if (task['status']?.toString() == 'rejected' && task['rejection_reason'] != null && task['rejection_reason'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top:2.0),
                  child: Text("Reason: ${task['rejection_reason']}", style: TextStyle(fontSize: 13, color: Colors.red.shade700, fontStyle: FontStyle.italic)),
                ),
            Text("Created: $formattedTime", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        onTap: () {
          final dynamic taskIdRaw = task['id'];
          int? taskIdInt;
          if (taskIdRaw is int) taskIdInt = taskIdRaw;
          else if (taskIdRaw is String) taskIdInt = int.tryParse(taskIdRaw);

          if (taskIdInt != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailsPage(taskId: taskIdInt!)))
            .then((valueFromDetailsPage) {
                print("Returned from TaskDetailsPage, refreshing current history tab: $_selectedStatusValue");
                _fetchHistoryTasks(page: 1, status: _selectedStatusValue, initialLoad: true);
            });
          }
        },
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return Icons.check_circle_outline_rounded;
      case 'rejected': return Icons.cancel_outlined;
      case 'pending': return Icons.pending_actions_rounded;
      case 'active': return Icons.local_activity_outlined;
      case 'approved': return Icons.thumb_up_alt_outlined;
      default: return Icons.history_toggle_off_rounded;
    }
  }
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return Colors.green.shade700;
      case 'rejected': return Colors.red.shade700;
      case 'pending': return Colors.blue.shade700;
      case 'active': return Colors.teal.shade700;
      case 'approved': return Colors.lightGreen.shade800;
      default: 
        // تأكد من أن context متاح هنا إذا كنت ستستخدمه
        // إذا تم استدعاء هذه الدالة من مكان لا يوجد فيه context، ستحتاج لتمريره أو استخدام لون ثابت
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    // الألوان التي ستُستخدم في TabBar
    // نفترض أن لون خلفية AppBar هو primaryColor من الثيم
    // وأننا نريد لون نص التبويب المختار أن يكون واضحًا على هذه الخلفية (عادة أبيض أو لون فاتح)
    // ولون نص التبويبات غير المختارة أن يكون أفتح قليلاً أو رماديًا.
    final Color selectedTabLabelColor = Theme.of(context).appBarTheme.foregroundColor ?? Colors.white;
    final Color unselectedTabLabelColor = selectedTabLabelColor.withOpacity(0.7);
    final Color indicatorColor = Theme.of(context).colorScheme.secondary; // لون المؤشر

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task History'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: indicatorColor,
          indicatorWeight: 3.0,
          labelColor: selectedTabLabelColor,
          unselectedLabelColor: unselectedTabLabelColor,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5), // زيادة طفيفة في حجم الخط للتبويب المختار
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          tabs: _tabs.map((tab) => Tab(text: tab['label'])).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tabConfig) {
          // نفس المنطق السابق لعرض المحتوى بناءً على الحالة المختارة
          if (_selectedStatusValue != tabConfig['statusValue']!) {
             return const Center(child: CircularProgressIndicator());
          }

          if (_isLoading && _historyTasks.isEmpty) {
            return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
          }
          if (_errorMessage != null && _historyTasks.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade300, size: 50),
                    const SizedBox(height: 10),
                    Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700, fontSize: 16), textAlign: TextAlign.center),
                     const SizedBox(height: 20),
                    ElevatedButton.icon(
                        onPressed: () => _fetchHistoryTasks(page: 1, status: _selectedStatusValue, initialLoad: true),
                        icon: const Icon(Icons.refresh),
                        label: const Text("Try Again")
                    )
                  ],
                ),
              )
            );
          }
          if (_historyTasks.isEmpty && !_isLoading) {
             return Center(
                child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Icon(Icons.inbox_outlined, size: 60, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text('No tasks found for "${tabConfig['label']}".', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                    ),
                )
             );
          }

          return RefreshIndicator(
            onRefresh: () => _fetchHistoryTasks(page: 1, status: _selectedStatusValue, initialLoad: true),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: _historyTasks.length + (_isLoading && !_isLastPage && _historyTasks.isNotEmpty ? 1 : 0),
              itemBuilder: (context, i) {
                if (i < _historyTasks.length) {
                  return _buildHistoryTaskItem(_historyTasks[i]);
                } else if (_isLoading && !_isLastPage) {
                  return const Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: Center(child: CircularProgressIndicator()));
                }
                return const SizedBox.shrink();
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}