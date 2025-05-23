import 'dart:convert';
import 'dart:io'; // لاستخدام SocketException
import 'dart:async'; // لاستخدام TimeoutException

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart'; // لاستيراد DateFormat لتنسيق الوقت

import 'login.dart'; // تأكد من وجود هذا الملف

class TaskDetailsPage extends StatefulWidget {
  final int taskId;
  const TaskDetailsPage({super.key, required this.taskId});

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  final _storage = const FlutterSecureStorage();
  final String _baseDomain = "http://localhost:3000"; // أو "http://10.0.2.2:3000"
  late final String _tasksApiBaseUrl = "$_baseDomain/api";

  bool _isLoadingDetails = true;
  bool _isUpdating = false;
  bool _isApproving = false;
  bool _isRejecting = false;

  Map<String, dynamic>? _task;
  String? _errorMessage;

  TimeOfDay? _selectedEstimatedTime;

  final TextEditingController _initialPriceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _rejectionReasonController = TextEditingController();
  final TextEditingController _actualTimeController = TextEditingController();
  final TextEditingController _actualPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print("--- TaskDetailsPage initState: Fetching details for task ${widget.taskId} ---");
    _fetchTaskDetails();
  }

  @override
  void dispose() {
    _initialPriceController.dispose();
    _notesController.dispose();
    _rejectionReasonController.dispose();
    _actualTimeController.dispose();
    _actualPriceController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleAuthenticationError({String message = 'Session expired. Please log in.'}) async {
    if (!mounted) return;
    _showMessage(message, isError: true);
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_id');
    print("--- TaskDetailsPage AuthError: Cleared credentials ---");
    if (mounted) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
        if(mounted) {
            Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
            );
        }
       });
    }
  }

  Future<void> _fetchTaskDetails() async {
    if (!mounted) return;
    setState(() { _isLoadingDetails = true; _errorMessage = null; });
    String? token;
    try {
      token = await _storage.read(key: 'auth_token');
      if (token == null || token.isEmpty) {
        await _handleAuthenticationError(message: 'Authentication required.');
        return;
      }
      final url = Uri.parse("$_tasksApiBaseUrl/tasks/${widget.taskId}");
      final response = await http.get(url, headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final taskData = data['task'] ?? data;
        if (taskData is Map<String, dynamic>) {
          setState(() {
            _task = taskData;
            String? estimatedTimeString = _task?['estimated_time']?.toString();
            if (estimatedTimeString != null && estimatedTimeString.isNotEmpty) {
              try {
                List<String> parts = estimatedTimeString.split(':');
                if (parts.length >= 2) {
                  _selectedEstimatedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
                }
              } catch (e) { print("Error parsing estimated_time from API: $e"); _selectedEstimatedTime = null; }
            } else { _selectedEstimatedTime = null; }
            _initialPriceController.text = _task?['initial_price']?.toString() ?? '';
            _notesController.text = _task?['notes']?.toString() ?? '';
            // نفترض أن الـ API يرجع سبب الرفض في حقل اسمه "rejection_reason"
            if (_task?['status']?.toString().toLowerCase() == 'rejected') {
                _rejectionReasonController.text = _task?['rejection_reason']?.toString() ?? '';
            } else {
                 _rejectionReasonController.clear();
            }
            _isLoadingDetails = false;
          });
          print("--- TaskDetailsPage: Fetched. Rejection reason from backend: ${_task?['rejection_reason']} ---");
        } else { throw FormatException("Invalid task data format."); }
      } else if (response.statusCode == 401) { await _handleAuthenticationError();
      } else { setState(() { _errorMessage = 'Error fetching details: ${response.statusCode}'; _isLoadingDetails = false; }); }
    } on SocketException { if (!mounted) return; setState(() { _errorMessage = 'Network error.'; _isLoadingDetails = false; });
    } on TimeoutException { if (!mounted) return; setState(() { _errorMessage = 'Connection timed out.'; _isLoadingDetails = false; });
    } catch (e,s) { print("FetchTaskDetails Exc: $e\n$s"); if (!mounted) return; setState(() { _errorMessage = 'Unexpected error fetching details.'; _isLoadingDetails = false; });
    } finally { if (mounted && _isLoadingDetails) { setState(() => _isLoadingDetails = false); } }
  }

  Future<void> _submitUpdate() async {
    if (_isUpdating || _isApproving || _isRejecting || !mounted ) return;
    setState(() => _isUpdating = true);
    String? token;
    try {
      token = await _storage.read(key: 'auth_token');
      if (token == null || token.isEmpty) {
        await _handleAuthenticationError(message: 'Auth required to update.');
        if (mounted) setState(() => _isUpdating = false); return;
      }
      final url = Uri.parse("$_tasksApiBaseUrl/tasks/${widget.taskId}");
      Map<String, dynamic> bodyToUpdate = {};
      String? formattedEstimatedTime;
      if (_selectedEstimatedTime != null) {
        final now = DateTime.now();
        final dt = DateTime(now.year, now.month, now.day, _selectedEstimatedTime!.hour, _selectedEstimatedTime!.minute);
        formattedEstimatedTime = DateFormat('HH:mm:ss').format(dt);
        bodyToUpdate['estimated_time'] = formattedEstimatedTime;
      } else { bodyToUpdate['estimated_time'] = null; }
      String initialPriceText = _initialPriceController.text.trim();
      if (initialPriceText.isNotEmpty) {
        final double? price = double.tryParse(initialPriceText);
        if (price != null) bodyToUpdate['initial_price'] = price;
        else { _showMessage("Invalid Initial Price.", isError: true); if (mounted) setState(() => _isUpdating = false); return; }
      } else { bodyToUpdate['initial_price'] = null; }
      String notesText = _notesController.text.trim();
      bodyToUpdate['notes'] = notesText.isEmpty ? null : notesText;
      bool hasMeaningfulChange = (formattedEstimatedTime != (_task?['estimated_time']?.toString())) ||
                        (initialPriceText != (_task?['initial_price']?.toString() ?? '')) || (initialPriceText.isEmpty && (_task?['initial_price'] != null)) ||
                        (notesText != (_task?['notes']?.toString() ?? '')) || (notesText.isEmpty && (_task?['notes'] != null));
      if (!hasMeaningfulChange) {
          _showMessage("No changes detected to submit.", isError: false);
          if (mounted) setState(() => _isUpdating = false); return;
      }
      final String requestBodyJson = jsonEncode(bodyToUpdate);
      print("--- TaskDetailsPage: Submitting update. Body: $requestBodyJson ---");
      final response = await http.put(url, headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': 'Bearer $token'}, body: requestBodyJson).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      print("--- Update Response Status: ${response.statusCode}, Body: ${response.body} ---");
      if (response.statusCode == 200 || response.statusCode == 204) {
        _showMessage("Task updated!"); await _fetchTaskDetails();
      } else if (response.statusCode == 401) { await _handleAuthenticationError();
      } else { _showMessage('Update failed: ${response.statusCode}. Details: ${response.body}', isError: true); }
    } catch (e,s) { print("Update Exc: $e\n$s"); _showMessage('Update error.', isError: true);
    } finally { if (mounted) setState(() => _isUpdating = false); }
  }

  Future<void> _approveTask() async {
    if (_isApproving || _isUpdating || _isRejecting || !mounted) return;
    setState(() => _isApproving = true);
    String? token;
    try {
      token = await _storage.read(key: 'auth_token');
      if (token == null || token.isEmpty) {
        await _handleAuthenticationError(message: 'Auth required for approval.');
        if (mounted) setState(() => _isApproving = false); return;
      }
      final url = Uri.parse("$_tasksApiBaseUrl/tasks/${widget.taskId}/approve");
      final response = await http.put(url, headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        _showMessage("Task approved!"); await _fetchTaskDetails();
      } else if (response.statusCode == 401) { await _handleAuthenticationError();
      } else { _showMessage('Approval failed: ${response.statusCode}.', isError: true); }
    } catch (e) { _showMessage('Approval error: $e', isError: true);
    } finally { if (mounted) setState(() => _isApproving = false); }
  }

  Future<void> _rejectTask() async {
    if (_isRejecting || _isUpdating || _isApproving || !mounted) return;
    final String reasonText = _rejectionReasonController.text.trim(); // استخدام متغير جديد ليكون أوضح
    if (reasonText.isEmpty) {
      _showMessage("Rejection reason is required.", isError: true);
      return;
    }
    setState(() => _isRejecting = true);
    String? token;
    try {
      token = await _storage.read(key: 'auth_token');
      if (token == null || token.isEmpty) {
        await _handleAuthenticationError(message: 'Authentication required to reject task.');
        if (mounted) setState(() => _isRejecting = false);
        return;
      }

      final url = Uri.parse("$_tasksApiBaseUrl/tasks/${widget.taskId}/reject");
      // ***** تعديل هنا: استخدام "reason" كمفتاح في الـ body *****
      final body = jsonEncode({"reason": reasonText});
      // ***** نهاية التعديل *****
      print("--- TaskDetailsPage: Rejecting task. Task ID: ${widget.taskId} ---");
      print("--- Sending Rejection Body: $body ---");

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: body,
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      print("--- Reject Task Response Status: ${response.statusCode} ---");
      print("--- Reject Task Response Body: ${response.body} ---");


      if (response.statusCode == 200 || response.statusCode == 204) {
        _showMessage("Task rejected successfully.");
        // الـ API يجب أن يكون قد قام بتحديث `cancelled` إلى 1 و `status` إلى 'rejected'
        // و `rejection_reason` (أو `reason` حسب ما يخزنه الـ API) بالسبب المرسل.
        await _fetchTaskDetails(); // أعد تحميل البيانات لإظهار التغييرات
      } else if (response.statusCode == 401) {
        await _handleAuthenticationError();
      } else {
        String serverMessage = "Failed to reject task: ${response.statusCode}.";
        try {
          final errorData = jsonDecode(response.body);
          if(errorData['message'] != null) serverMessage += " ${errorData['message']}";
        } catch (_) {}
        _showMessage(serverMessage, isError: true);
      }
    } on SocketException {
      if (!mounted) return; _showMessage('Network error.', isError: true);
    } on TimeoutException {
      if (!mounted) return; _showMessage('Connection timed out.', isError: true);
    } catch (e, s) {
      print("!!! TaskDetailsPage: Reject Task Exception: $e !!!");
      print(s);
      if (!mounted) return;
      _showMessage('An unexpected error occurred during rejection.', isError: true);
    } finally {
      if (mounted) setState(() => _isRejecting = false);
    }
  }

  Future<void> _completeTaskApiCall(String actualTime, String actualPrice, Function(bool) setLoadingInDialog, BuildContext dialogContext) async {
    if (actualTime.trim().isEmpty || actualPrice.trim().isEmpty) {
      _showMessage("Actual time and price are required.", isError: true);
      setLoadingInDialog(false); return;
    }
    final double? price = double.tryParse(actualPrice.trim());
    if (price == null) {
      _showMessage("Invalid format for actual price.", isError: true);
      setLoadingInDialog(false); return;
    }
    String? token;
    try {
      token = await _storage.read(key: 'auth_token');
      if (token == null || token.isEmpty) {
        await _handleAuthenticationError(message: 'Auth required to complete task.');
        if (mounted) setLoadingInDialog(false); return;
      }
      final url = Uri.parse("$_tasksApiBaseUrl/tasks/${widget.taskId}/complete");
      final body = jsonEncode({ "actual_time": actualTime.trim(), "actual_price": price });
      final response = await http.put(url, headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': 'Bearer $token'}, body: body).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200 || response.statusCode == 204) {
        _showMessage("Task completed successfully!");
        await _fetchTaskDetails();
        if (mounted && Navigator.canPop(dialogContext)) Navigator.of(dialogContext).pop();
      } else if (response.statusCode == 401) {
        await _handleAuthenticationError(); if (mounted) setLoadingInDialog(false);
      } else { _showMessage('Failed to complete: ${response.statusCode}.', isError: true); if (mounted) setLoadingInDialog(false); }
    } catch (e,s) { print("CompleteTask Exc: $e\n$s"); _showMessage('Completion error.', isError: true); if (mounted) setLoadingInDialog(false); }
  }

  Future<void> _showCompleteTaskDialog() async {
    _actualTimeController.text = _task?['actual_time']?.toString() ?? '';
    _actualPriceController.text = _task?['actual_price']?.toString() ?? '';
    bool isLoadingInDialog = false;
    return showDialog<void>(
      context: context, barrierDismissible: !isLoadingInDialog,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
            void setLoading(bool loading) { if (mounted) setDialogState(() => isLoadingInDialog = loading); }
            return WillPopScope(
              onWillPop: () async => !isLoadingInDialog,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
                titlePadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 10.0),
                contentPadding: const EdgeInsets.fromLTRB(24.0, 10.0, 24.0, 0.0),
                actionsPadding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                title: const Text('Complete Task', style: TextStyle(fontWeight: FontWeight.bold)),
                content: SingleChildScrollView(child: ListBody(children: <Widget>[
                      Text('Please enter the actual time and price for completing this task.', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                      const SizedBox(height: 20),
                      _buildTextField("Actual Time (e.g., 90 min, 2 hours)", _actualTimeController, enabled: !isLoadingInDialog),
                      const SizedBox(height: 12),
                      _buildTextField("Actual Price", _actualPriceController, enabled: !isLoadingInDialog, keyboardType: TextInputType.numberWithOptions(decimal: true)),
                    ],)),
                actions: <Widget>[
                  TextButton(child: Text('Cancel', style: TextStyle(color: Theme.of(context).primaryColor)), onPressed: isLoadingInDialog ? null : () => Navigator.of(dialogContext).pop()),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: isLoadingInDialog ? Container(width: 20, height: 20, padding: const EdgeInsets.all(2.0), child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Icon(Icons.check_circle_outline_rounded, size: 20),
                    label: const Text('Submit Completion'),
                    onPressed: isLoadingInDialog ? null : () async { setLoading(true); await _completeTaskApiCall(_actualTimeController.text, _actualPriceController.text, setLoading, dialogContext); },
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)), textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          });
      },
    );
  }
  
  Future<void> _selectEstimatedTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedEstimatedTime ?? TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedEstimatedTime) {
      setState(() => _selectedEstimatedTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_task != null ? "Task #${_task!['id']}" : "Task Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: (_isLoadingDetails || _isUpdating || _isApproving || _isRejecting) ? null : _fetchTaskDetails,
            tooltip: "Refresh Details",
          )
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingDetails) return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
    if (_errorMessage != null) return _buildErrorWidget();
    if (_task == null) return const Center(child: Text("No task data. Try refreshing."));

    final String currentStatus = _task!['status']?.toString().toLowerCase() ?? "";
    bool canEditEstimates = currentStatus == 'pending' || currentStatus == 'active' || currentStatus == 'approved';
    bool canApprove = currentStatus == 'pending';
    bool canReject = currentStatus == 'pending' || currentStatus == 'active';
    bool canComplete = currentStatus == 'active' || currentStatus == 'approved';
    bool isCompletedOrRejected = currentStatus == 'completed' || currentStatus == 'rejected';
    bool anyPageOperationInProgress = _isUpdating || _isApproving || _isRejecting;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("Task Information"),
          _infoCard(children: [
            _infoRow("ID", _task!["id"]?.toString() ?? "N/A"),
            _infoRow("Description", _task!["description"]?.toString() ?? "N/A"),
            _infoRow("Status", _task!["status"]?.toString() ?? "N/A", highlight: true),
            _infoRow("Created At", _formatDate(_task!["created_at"]?.toString() ?? _task!["created"]?.toString())),
            if (isCompletedOrRejected) ...[
              const SizedBox(height: 5),
              _infoRow("Actual Time", _task!["actual_time"]?.toString()),
              _infoRow("Actual Price", _task!["actual_price"]?.toString()),
              // عرض سبب الرفض هنا إذا كانت المهمة مرفوضة وكان هناك سبب
              if (currentStatus == 'rejected' && _task!["rejection_reason"] != null && _task!["rejection_reason"].toString().isNotEmpty)
                _infoRow("Rejection Reason", _task!["rejection_reason"]?.toString(), highlight: true),
            ]
          ]),
          const SizedBox(height: 20),
          _buildSectionTitle("Client Details"),
          _infoCard(children: [
            _infoRow("Client Name", _task!["client_name"]?.toString() ?? "N/A"),
            _infoRow("Client Email", _task!["client_email"]?.toString() ?? "N/A"),
            _infoRow("Client Phone", _task!["client_phone"]?.toString() ?? "N/A"),
          ]),

          if (canEditEstimates && !isCompletedOrRejected) ...[
            const SizedBox(height: 24), const Divider(thickness: 1), const SizedBox(height: 12),
            _buildSectionTitle("Update Estimates / Notes"),
            _buildTimePickerField(label: "Estimated Time", selectedTime: _selectedEstimatedTime, onTap: () => _selectEstimatedTime(context), enabled: !anyPageOperationInProgress),
            _buildTextField("Initial Estimated Price", _initialPriceController, keyboardType: TextInputType.numberWithOptions(decimal: true), enabled: !anyPageOperationInProgress),
            _buildTextField("Notes", _notesController, maxLines: 3, enabled: !anyPageOperationInProgress),
            const SizedBox(height: 16),
            Center(child: ElevatedButton.icon(onPressed: anyPageOperationInProgress ? null : _submitUpdate, icon: _isUpdating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Icon(Icons.save_alt_outlined), label: const Text("Save Estimates/Notes"))),
          ],

          if (!isCompletedOrRejected) ...[
            const SizedBox(height: 24), const Divider(thickness: 1), const SizedBox(height: 12),
             _buildSectionTitle("Task Actions"),
            if (canApprove) ...[
              Center(child: ElevatedButton.icon(onPressed: anyPageOperationInProgress ? null : _approveTask, icon: _isApproving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Icon(Icons.check_circle_outline), label: const Text("Approve Task"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)))),
              const SizedBox(height: 10),
            ],
            if (canReject) ...[
              _buildTextField("Reason for Rejection", _rejectionReasonController, maxLines: 2, enabled: !anyPageOperationInProgress),
              const SizedBox(height: 8),
              Center(child: ElevatedButton.icon(onPressed: anyPageOperationInProgress ? null : _rejectTask, icon: _isRejecting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Icon(Icons.cancel_outlined), label: const Text("Reject Task"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)))),
              const SizedBox(height: 10),
            ],
            if (canComplete) ...[
              Center(child: ElevatedButton.icon(onPressed: anyPageOperationInProgress ? null : _showCompleteTaskDialog, icon: const Icon(Icons.task_alt_outlined), label: const Text("Mark as Completed"), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)))),
            ],
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildTimePickerField({ required String label, required TimeOfDay? selectedTime, required VoidCallback onTap, bool enabled = true, }) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: InkWell(onTap: enabled ? onTap : null, child: InputDecorator(decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade400)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.8)), disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)), filled: true, fillColor: enabled ? Colors.white.withOpacity(0.95) : Colors.grey.shade200, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[Text(selectedTime != null ? selectedTime.format(context) : 'Choose Time', style: TextStyle(fontSize: 16, color: enabled ? (selectedTime != null ? Colors.black87 : Colors.grey.shade700) : Colors.grey.shade500)), Icon(Icons.arrow_drop_down, color: enabled ? Colors.grey.shade700 : Colors.grey.shade500)],),),),);
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
            const SizedBox(height: 16),
            Text(_errorMessage ?? "An unexpected error occurred.", style: const TextStyle(color: Colors.redAccent, fontSize: 17, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("Try Again"),
              onPressed: _fetchTaskDetails,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0, top: 16.0),
      child: Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
    );
  }

  Widget _infoCard({required List<Widget> children}) {
    return Card(
      elevation: 2.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }

  Widget _infoRow(String label, String? value, {bool highlight = false}) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label: ", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800, fontSize: 15.5)),
          Expanded(
            child: Text(value, style: TextStyle(
                fontSize: 15.5,
                color: highlight ? Theme.of(context).primaryColor : Colors.black87,
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1, TextInputType keyboardType = TextInputType.text, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        enabled: enabled,
        style: TextStyle(color: enabled ? Colors.black87 : Colors.grey.shade700, fontSize: 16),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return "N/A";
    try {
      final dateTime = DateTime.parse(dateString).toLocal();
      return "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
    } catch (e) { return dateString; }
  }
}