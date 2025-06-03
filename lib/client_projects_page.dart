// client_projects_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'client_project_detail_page.dart';
import 'login.dart';
import 'provider_profile_page.dart';
import 'company_detail_page.dart'; 

import 'edit_client_profile_page.dart';

class ClientProjectsPage extends StatefulWidget {
  const ClientProjectsPage({super.key});

  @override
  State<ClientProjectsPage> createState() => _ClientProjectsPageState();
}

class _ClientProjectsPageState extends State<ClientProjectsPage> {
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = Platform.isAndroid ? "http://10.0.2.2:3000" : "http://localhost:3000";
  
  List<dynamic> _projectsOriginal = [];
  List<dynamic> _results = [];
  bool _isLoadingProjects = true;
  bool _isProcessingSearchOrFilter = false;
  String? _dataErrorMessage;

  final TextEditingController _searchQueryController = TextEditingController();
  String _currentSearchQueryText = "";
  String _searchTypeForAPIAppBar = 'companies'; 

  String? _selectedFilterTypeDialog = 'companies';
  final TextEditingController _filterCityController = TextEditingController();
  final TextEditingController _filterCategoryController = TextEditingController();
  String? _selectedMinRatingDialog;

  final List<String> _filterTypeOptions = ['companies', 'providers'];
  final List<String> _ratingOptionsForFilter = ['Any Rating', '1', '2', '3', '4', '5'];

  Map<String, dynamic>? _clientDataForAvatar;
  bool _isLoadingAvatar = true;            

  String _lastOperationResultType = 'companies'; // لتحديد نوع النتائج المعروضة

  final Color _pageBackgroundColorTop = const Color(0xFFFAF3E0);
  final Color _pageBackgroundColorBottom = const Color(0xFFA3B29F);
  final Color _appBarColor = Colors.white;
  final Color _appBarItemColor = const Color(0xFF4A5D52);
  final Color _iconColor = const Color(0xFF4A5D52);
  final Color _primaryTextColor = const Color(0xFF3A3A3A);
  final Color _secondaryTextColor = Colors.grey.shade700;
  final Color _cardBackgroundColor = Colors.white.withOpacity(0.97);
  final Color _filterButtonColor = const Color(0xFF4A5D52);

  @override
  void initState() {
    super.initState();
    _selectedMinRatingDialog = _ratingOptionsForFilter.first;
    _selectedFilterTypeDialog = 'companies'; 
    _searchTypeForAPIAppBar = 'companies';   
    _lastOperationResultType = 'companies';  
    _loadClientProfileForAvatar(); 
    _fetchClientProjects();
  }

  @override
  void dispose(){
    _searchQueryController.dispose();
    _filterCityController.dispose();
    _filterCategoryController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.lato(color: Colors.white)),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : (isSuccess ? Colors.green.shade600 : _iconColor),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating, elevation: 6.0, margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
  
  Future<void> _handleAuthError({String message = 'Session expired. Please log in again.'}) async {
    if (!mounted) return;
    _showMessage(message, isError: true);
    await _storage.deleteAll();
    if (mounted) { 
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r)=> false);
    }
  }

  Future<void> _loadClientProfileForAvatar() async {
    if (!mounted) return;
    setState(() => _isLoadingAvatar = true);
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _isLoadingAvatar = false);
      return;
    }
    final url = Uri.parse("$_baseUrl/api/client/profile");
    try {
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['client'] != null) {
          setState(() { _clientDataForAvatar = data['client']; _isLoadingAvatar = false; });
        } else { if (mounted) setState(() => _isLoadingAvatar = false); }
      } else { 
          if (mounted) setState(() => _isLoadingAvatar = false); 
          if (response.statusCode == 401) _handleAuthError();
      }
    } catch (_) { if (mounted) setState(() => _isLoadingAvatar = false); }
  }

  void _navigateToEditProfile() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditClientProfilePage()));
    if (result == true && mounted) {
      _loadClientProfileForAvatar(); 
    }
  }

  Future<void> _logout() async {
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Confirm Logout', style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to log out?', style: GoogleFonts.lato()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(child: Text('Cancel', style: GoogleFonts.lato(color: Colors.grey.shade700)), onPressed: () => Navigator.of(dialogContext).pop(false)),
          TextButton(child: Text('Logout', style: GoogleFonts.lato(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)), onPressed: () => Navigator.of(dialogContext).pop(true)),
        ],
      )
    );
    if (confirmLogout == true && mounted) {
      await _handleAuthError(message: "Logged out successfully.");
    }
  }
  
  Widget _buildProfileInfoRowInDialog(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty || (value == '0' && label != "Zip Code") || value.toLowerCase() == "n/a" || value.toLowerCase() == "not specified") {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(children: [
          FaIcon(icon, size: 17, color: _iconColor.withOpacity(0.85)), const SizedBox(width: 12),
          Text("$label:", style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: _primaryTextColor.withOpacity(0.9), fontSize: 15)), const SizedBox(width: 8),
          Expanded(child: Text(value, style: GoogleFonts.lato(fontSize: 15, color: _secondaryTextColor), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  void _showProfileDialog() {
    if (_clientDataForAvatar == null && !_isLoadingAvatar) _loadClientProfileForAvatar(); 
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      backgroundColor: _pageBackgroundColorTop.withOpacity(0.98),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (_clientDataForAvatar == null && !_isLoadingAvatar) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
                _loadClientProfileForAvatar().then((_) {
                  if (mounted) setDialogState(() {});
                });
             });
          }

          if (_isLoadingAvatar || _clientDataForAvatar == null) {
            return Container(
              height: 200, 
              padding: const EdgeInsets.all(32), 
              child: Center(
                child: _isLoadingAvatar 
                       ? CircularProgressIndicator(color: _iconColor) 
                       : Text("Could not load profile. Please try again.", style: GoogleFonts.lato(color: _primaryTextColor))
              )
            );
          }
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 25),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
                Text("My Profile", style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: _iconColor)), const SizedBox(height: 20),
                CircleAvatar(
                  radius: 45, backgroundColor: Colors.grey.shade300,
                  backgroundImage: (_clientDataForAvatar?["image_url"]?.toString() != null && (_clientDataForAvatar!["image_url"].toString()).isNotEmpty && Uri.tryParse(_clientDataForAvatar!["image_url"].toString())?.hasAbsolutePath == true) ? NetworkImage(_clientDataForAvatar!["image_url"].toString()) : null,
                  child: (_clientDataForAvatar?["image_url"] == null || (_clientDataForAvatar!["image_url"].toString()).isEmpty || Uri.tryParse(_clientDataForAvatar!["image_url"].toString())?.hasAbsolutePath != true) ? Icon(Icons.person, size: 45, color: Colors.grey.shade500) : null,
                ),
                const SizedBox(height: 15),
                Text("${_clientDataForAvatar?["first_name"] ?? ''} ${_clientDataForAvatar?["last_name"] ?? ''}".trim(), style: GoogleFonts.lato(fontSize: 19, fontWeight: FontWeight.bold, color: _primaryTextColor)),
                const SizedBox(height: 5),
                Text(_clientDataForAvatar?["email"]?.toString() ?? '-', style: GoogleFonts.lato(fontSize: 14.5, color: _secondaryTextColor)),
                const SizedBox(height: 18), Divider(color: Colors.grey.shade300), const SizedBox(height: 12),
                _buildProfileInfoRowInDialog(FontAwesomeIcons.phone, "Phone", _clientDataForAvatar?["phone"]?.toString()),
                _buildProfileInfoRowInDialog(FontAwesomeIcons.city, "City", _clientDataForAvatar?["city_name"]?.toString() ?? _clientDataForAvatar?["city"]?.toString()),
                _buildProfileInfoRowInDialog(FontAwesomeIcons.mapPin, "Zip Code", _clientDataForAvatar?["zip_code"]?.toString()),
                if (_clientDataForAvatar?["facebook_url"] != null && (_clientDataForAvatar!["facebook_url"].toString()).isNotEmpty && _clientDataForAvatar!["facebook_url"].toString().toLowerCase() != 'test')
                    _buildProfileInfoRowInDialog(FontAwesomeIcons.facebookF, "Facebook", _clientDataForAvatar?["facebook_url"].toString()),
                const SizedBox(height: 25),
                 Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () { Navigator.pop(context); _navigateToEditProfile(); },
                      icon: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 18), 
                      label: Text("Edit Profile", style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      style: ElevatedButton.styleFrom(backgroundColor: _iconColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 3),
                    ),
                     TextButton.icon(
                      icon: Icon(Icons.logout_rounded, color: Theme.of(context).colorScheme.error, size: 18),
                      label: Text("Logout", style: GoogleFonts.lato(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold, fontSize: 15)),
                      onPressed: () {
                        Navigator.pop(context);
                        _logout();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
            ]),
          );
        },
      ),
    );
  }
  
  InputDecoration _customInputDecorationForFilter(String? hint, IconData? icon) {
    return InputDecoration(
      hintText: hint ?? "Select an option",
      hintStyle: GoogleFonts.lato(color: _secondaryTextColor.withOpacity(0.7), fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, color: _iconColor.withOpacity(0.6), size: 20) : null,
      filled: true, fillColor: Colors.grey.shade100.withOpacity(0.7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300, width: 0.8)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300, width: 0.8)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _iconColor, width: 1.5)),
    );
  }

  void _navigateToProviderProfile(int providerId) {
    Navigator.push(context,MaterialPageRoute(builder: (_) => ProviderProfilePage(providerId: providerId,baseUrl: _baseUrl,storage: _storage)));
  }

  void _navigateToCompanyProfile(int companyId) {
    Navigator.push(context,MaterialPageRoute(builder: (_) => CompanyDetailPage(companyId: companyId,baseUrl: _baseUrl,storage: _storage)));
  }

  Widget _buildProviderSearchCard(Map<String, dynamic> provider) {
    String? imageUrl = provider['image_url']?.toString();
    int? providerId = int.tryParse(provider['id']?.toString() ?? provider['user_id']?.toString() ?? provider['provider_id']?.toString() ?? '');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8), color: _cardBackgroundColor, elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(radius: 28, backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null, child: (imageUrl == null || imageUrl.isEmpty) ? Icon(Icons.person_rounded, size: 28, color: _iconColor.withOpacity(0.6)) : null),
        title: Text("${provider['first_name']?.toString() ?? ''} ${provider['last_name']?.toString() ?? ''}".trim(), style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryTextColor)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(provider['category_name']?.toString() ?? (provider['position']?.toString() ?? 'No category/position'), style: GoogleFonts.lato(color: _iconColor, fontSize: 13.5, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(provider['city_name']?.toString() ?? 'No city', style: GoogleFonts.lato(color: _secondaryTextColor, fontSize: 12.5)),
            if (provider['avg_rating'] != null && double.tryParse(provider['avg_rating'].toString()) != null)
              Row(children: [Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 16), const SizedBox(width:3), Text(double.parse(provider['avg_rating'].toString()).toStringAsFixed(1), style: GoogleFonts.lato(fontSize: 12.5, fontWeight: FontWeight.w500))]),
        ]),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: _iconColor.withOpacity(0.7)),
        onTap: () { 
          if (providerId != null) {
            _navigateToProviderProfile(providerId);
          } else {
            _showMessage("Provider ID not found, cannot view profile.", isError: true);
          }
        },
      ),
    );
  }

  Widget _buildCompanySearchCard(Map<String, dynamic> company) {
    String? imageUrl = company['image_url']?.toString();
    int? companyId = int.tryParse(company['id']?.toString() ?? '');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8), color: _cardBackgroundColor, elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(radius: 28, backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null, child: (imageUrl == null || imageUrl.isEmpty) ? Icon(Icons.business_center_rounded, size: 28, color: _iconColor.withOpacity(0.6)) : null),
        title: Text(company['name']?.toString() ?? 'Unknown Company', style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryTextColor)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(company['description']?.toString() ?? 'No description', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(color: _secondaryTextColor, fontSize: 12.5)),
            if (company['avg_rating'] != null && double.tryParse(company['avg_rating'].toString()) != null)
              Row(children: [Icon(Icons.star_rate_rounded, color: Colors.amber.shade700, size: 16), const SizedBox(width:3), Text(double.parse(company['avg_rating'].toString()).toStringAsFixed(1), style: GoogleFonts.lato(fontSize: 12.5, fontWeight: FontWeight.w500))]),
        ]),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: _iconColor.withOpacity(0.7)),
        onTap: () { 
          if(companyId != null){
             _navigateToCompanyProfile(companyId);
          } else {
             _showMessage("Company ID not found.", isError: true);
          }
        },
      ),
    );
  }

  Widget _buildResultsErrorWidget() {
    return Center(child: Padding(padding: const EdgeInsets.all(30.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline_rounded, color: _iconColor.withOpacity(0.6), size: 60), const SizedBox(height: 15),
          Text(_dataErrorMessage?? _dataErrorMessage ?? "An error occurred.", style: GoogleFonts.lato(color: _iconColor, fontSize: 17, fontWeight: FontWeight.w500), textAlign: TextAlign.center), const SizedBox(height: 20),
          ElevatedButton.icon(icon: Icon(Icons.refresh_rounded, color: Colors.white), label: Text("Try Again", style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold)), onPressed: () {
            bool wereFiltersApplied = (
                                      _selectedFilterTypeDialog != (_filterTypeOptions.isNotEmpty ? _filterTypeOptions.first : 'companies') || 
                                      _filterCityController.text.isNotEmpty || 
                                      _filterCategoryController.text.isNotEmpty || 
                                      _selectedMinRatingDialog != (_ratingOptionsForFilter.isNotEmpty ? _ratingOptionsForFilter.first : null)
                                    );
            if (_searchQueryController.text.isNotEmpty && !wereFiltersApplied ) {
                 _performSearchOrFilter(queryFromSearchField: _currentSearchQueryText);
            } else if (wereFiltersApplied) { 
                _performSearchOrFilter(isFilterSearch: true); 
            } else { 
                _fetchClientProjects(); // أو _loadInitialDashboardContent إذا كانت هي الصفحة الرئيسية
            }
          } , style: ElevatedButton.styleFrom(backgroundColor: _iconColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))
    ])));
  }
  
  Widget _buildEmptyResultsWidget() {
    return Center(child: Padding(padding: const EdgeInsets.all(30.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.search_off_rounded, color: _iconColor.withOpacity(0.5), size: 60), const SizedBox(height: 15),
          Text(_dataErrorMessage?? _dataErrorMessage ?? "No results found for your criteria.", style: GoogleFonts.lato(color: _iconColor.withOpacity(0.7), fontSize: 17, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          const SizedBox(height: 15),
          Text("Try adjusting your search or filter criteria.", style: GoogleFonts.lato(color: _iconColor.withOpacity(0.6), fontSize: 14), textAlign: TextAlign.center),
    ])));
  }
  
  void _loadInitialPageContent(){ // دالة جديدة لمسح نتائج البحث وعرض قائمة المشاريع الأصلية
    if (mounted) {
      setState(() {
        _isProcessingSearchOrFilter = false; 
        _results = [];
        _dataErrorMessage = null; // استخدام _dataErrorMessage هنا
        _searchQueryController.clear();
        _currentSearchQueryText = "";
        _filterCityController.clear();
        _filterCategoryController.clear();
        _selectedFilterTypeDialog = _filterTypeOptions.isNotEmpty ? _filterTypeOptions.first : 'companies';
        _searchTypeForAPIAppBar = _filterTypeOptions.isNotEmpty ? _filterTypeOptions.first : 'companies';
        _lastOperationResultType = _filterTypeOptions.isNotEmpty ? _filterTypeOptions.first : 'companies';
        _selectedMinRatingDialog = _ratingOptionsForFilter.isNotEmpty ? _ratingOptionsForFilter.first : null;
        _fetchClientProjects(); // جلب قائمة المشاريع الأصلية
        print("Resetting search/filter states for ClientProjectsPage and fetching projects.");
      });
    }
  }


  Future<void> _fetchClientProjects() async {
    if (!mounted) return;
    setState(() { _isLoadingProjects = true; _dataErrorMessage = null; _results = []; });

    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      if(mounted) setState(() { _isLoadingProjects = false; _dataErrorMessage = "Authentication required.";});
      _handleAuthError();
      return;
    }

    final url = Uri.parse("$_baseUrl/api/client/projects");
    print("--- Fetching Client Projects: $url ---");

    try {
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
      if (!mounted) return;
      final data = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() { _projectsOriginal = data['projects'] as List<dynamic>? ?? []; _isLoadingProjects = false; });
      } else {
        if(response.statusCode == 401) _handleAuthError();
        throw Exception(data['message'] ?? "Failed to load projects (${response.statusCode})");
      }
    } catch (e) {
      if (mounted) setState(() { _isLoadingProjects = false; _dataErrorMessage = e.toString(); });
    }
  }
  
  String _formatDisplayDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try { return DateFormat('dd MMM yyyy').format(DateTime.parse(dateString).toLocal()); } 
    catch (_) { return dateString.split('T')[0]; }
  }

  Future<void> _performSearchOrFilter({String? queryFromSearchField, bool isFilterSearch = false}) async {
    if (!mounted) return;
    setState(() { _isProcessingSearchOrFilter = true; _dataErrorMessage = null; _results = []; 
      if (queryFromSearchField != null) _currentSearchQueryText = queryFromSearchField;
    });

    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) { 
      if (mounted) setState(() { _isProcessingSearchOrFilter = false; _dataErrorMessage = "Authentication token missing."; });
      _handleAuthError();
      return; 
    }

    Uri apiUri;
    String operationType = "";
    Map<String, String> queryParams = {};
    String currentResultType = _filterTypeOptions.isNotEmpty ? _filterTypeOptions.first : 'companies';

    if (isFilterSearch) {
      operationType = "Filtering";
      currentResultType = _selectedFilterTypeDialog ?? (_filterTypeOptions.isNotEmpty ? _filterTypeOptions.first : 'companies');
      queryParams['type'] = currentResultType;
      
      final cityToFilter = _filterCityController.text.trim();
      if (cityToFilter.isNotEmpty) queryParams['city'] = cityToFilter;
      
      final categoryToFilter = _filterCategoryController.text.trim();
      if (currentResultType == 'providers' && categoryToFilter.isNotEmpty) {
        queryParams['category'] = categoryToFilter;
      } else if (currentResultType == 'companies' && categoryToFilter.isNotEmpty) {
         print("Note: Category filter for 'companies' on ClientProjectsPage is currently not sent unless API supports a specific key like 'industry'.");
      }

      if (_selectedMinRatingDialog != null && _selectedMinRatingDialog!.toLowerCase() != 'any rating') {
        queryParams['minRating'] = _selectedMinRatingDialog!;
      }
      
      bool noSpecificFilters = cityToFilter.isEmpty &&
                              !(currentResultType == 'providers' && categoryToFilter.isNotEmpty) &&
                              (_selectedMinRatingDialog == null || _selectedMinRatingDialog!.toLowerCase() == 'any rating');

      if (queryParams.length <= 1 && noSpecificFilters) {
         if (mounted) setState(() { _isProcessingSearchOrFilter = false; _results = []; _dataErrorMessage = "Please select more specific filters."; });
         return;
      }
      apiUri = Uri.parse("$_baseUrl/api/client/filter").replace(queryParameters: queryParams);
      setState(() { _searchTypeForAPIAppBar = currentResultType; });
    } else { 
      operationType = "Searching";
      currentResultType = _searchTypeForAPIAppBar;
      queryParams['type'] = currentResultType;

      if (_currentSearchQueryText.isEmpty) {
         if (mounted) setState(() { _isProcessingSearchOrFilter = false; _results = []; });
         _loadInitialPageContent();
         return;
      }
      queryParams['query'] = _currentSearchQueryText;
      apiUri = Uri.parse("$_baseUrl/api/client/search").replace(queryParameters: queryParams);
       setState(() { _selectedFilterTypeDialog = currentResultType; });
    }
    
    print("--- ClientProjectsPage: $operationType from $apiUri --- Query Params: $queryParams");
    try {
      final response = await http.get(apiUri, headers: {'Authorization': 'Bearer $token'});
      if (!mounted) return;
      final data = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _results = data['results'] as List<dynamic>? ?? [];
          _isProcessingSearchOrFilter = false;
          _lastOperationResultType = currentResultType;
          if (_results.isEmpty) {
            _dataErrorMessage = isFilterSearch ? "No results match your filters." : "No results found for '$_currentSearchQueryText' in ${currentResultType.myCapitalizeFirst()}.";
          }
        });
      } else {
        if (response.statusCode == 401) _handleAuthError();
        throw Exception(data['message'] ?? "$operationType failed (${response.statusCode})");
      }
    } catch (e) {
      if (mounted) setState(() { _isProcessingSearchOrFilter = false; _dataErrorMessage = e.toString(); });
    }
  }
  
  void _showFilterDialog() {
    String? tempDialogFilterType = _selectedFilterTypeDialog;
    TextEditingController tempCityController = TextEditingController(text: _filterCityController.text);
    TextEditingController tempCategoryController = TextEditingController(text: _filterCategoryController.text);
    String? tempDialogMinRating = _selectedMinRatingDialog;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            bool isCategoryEnabledForFilter = tempDialogFilterType == 'providers';

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20, left: 20, right: 20, top: 25),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Text("Set Filters", style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: _iconColor))),
                    const SizedBox(height: 25),

                    Text("Filter For:", style: GoogleFonts.lato(fontWeight: FontWeight.w600, fontSize: 16, color: _primaryTextColor)),
                    DropdownButtonFormField<String>(
                      value: tempDialogFilterType,
                      items: _filterTypeOptions.map((type) => DropdownMenuItem(value: type, child: Text(type.myCapitalizeFirst(), style: GoogleFonts.lato()))).toList(),
                      onChanged: (value) {
                        setModalState(() {
                          tempDialogFilterType = value;
                          isCategoryEnabledForFilter = tempDialogFilterType == 'providers';
                          if (!isCategoryEnabledForFilter) {
                            tempCategoryController.clear(); 
                          }
                        });
                      },
                      decoration: _customInputDecorationForFilter(null, Icons.business_center_rounded),
                      validator: (v) => v == null ? 'Type is required' : null,
                    ),
                    const SizedBox(height: 18),

                    Text("Category:", style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: _primaryTextColor, fontSize: 16)),
                    TextFormField(
                       controller: tempCategoryController,
                       decoration: _customInputDecorationForFilter(
                          isCategoryEnabledForFilter ? "Enter Category (e.g., Plumber)" : "Category (for Providers only)", 
                          Icons.category_outlined
                        ),
                       enabled: isCategoryEnabledForFilter,
                       style: TextStyle(color: isCategoryEnabledForFilter ? _primaryTextColor : Colors.grey.shade500),
                    ),
                    const SizedBox(height: 18),

                    Text("City:", style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: _primaryTextColor, fontSize: 16)),
                    TextFormField(
                       controller: tempCityController,
                       decoration: _customInputDecorationForFilter("Enter City Name", Icons.location_city_rounded),
                    ),
                    const SizedBox(height: 18),

                    Text("Minimum Rating:", style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: _primaryTextColor, fontSize: 16)),
                    DropdownButtonFormField<String>(
                      value: tempDialogMinRating,
                      items: _ratingOptionsForFilter.map((rating) => DropdownMenuItem(
                        value: rating,
                        child: rating == "Any Rating" 
                               ? Text(rating, style: GoogleFonts.lato()) 
                               : Row(children: [Text("$rating ", style: GoogleFonts.lato()), ...List.generate(int.tryParse(rating) ?? 0, (i) => Icon(Icons.star_rounded, color: Colors.amber, size: 20))])
                      )).toList(),
                      onChanged: (value) => setModalState(() => tempDialogMinRating = value),
                      decoration: _customInputDecorationForFilter(null, Icons.star_border_rounded),
                    ),
                    const SizedBox(height: 30),

                    SizedBox(width: double.infinity, child: ElevatedButton.icon(
                        icon: const Icon(Icons.filter_alt_rounded, color: Colors.white),
                        label: Text("Apply Filters", style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        onPressed: () {
                          if (tempDialogFilterType == null) { _showMessage("Please select a filter type.", isError: true); return; }
                          setState(() {
                            _selectedFilterTypeDialog = tempDialogFilterType;
                            _filterCityController.text = tempCityController.text.trim();
                            _filterCategoryController.text = (tempDialogFilterType == 'providers') ? tempCategoryController.text.trim() : '';
                            _selectedMinRatingDialog = tempDialogMinRating;
                          });
                          Navigator.pop(modalContext);
                          _performSearchOrFilter(isFilterSearch: true);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: _filterButtonColor, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    )),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: TextButton(
                        onPressed: (){
                           setModalState(() { 
                             tempDialogFilterType = _filterTypeOptions.first; 
                             tempCityController.clear(); 
                             tempCategoryController.clear();
                             tempDialogMinRating = _ratingOptionsForFilter.first; 
                            });
                           _loadInitialPageContent();
                           Navigator.pop(modalContext);
                        },
                        child: Text("Clear Filters & Show Projects", style: GoogleFonts.lato(color: _iconColor, fontWeight: FontWeight.w500))
                    )),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_){
      if(_results.isEmpty && _searchQueryController.text.isEmpty) {
        setState(() {
          _selectedFilterTypeDialog = _searchTypeForAPIAppBar;
        });
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    String? avatarUrl = _clientDataForAvatar?["image_url"]?.toString();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(
                color: _pageBackgroundColorTop.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20)
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _searchTypeForAPIAppBar,
                  icon: Icon(Icons.arrow_drop_down_rounded, color: _iconColor, size: 24),
                  style: GoogleFonts.lato(color: _appBarItemColor, fontSize: 14, fontWeight: FontWeight.w500),
                  items: _filterTypeOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value.myCapitalizeFirst()),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _searchTypeForAPIAppBar = newValue;
                        if (_searchQueryController.text.isNotEmpty) {
                          _performSearchOrFilter(queryFromSearchField: _searchQueryController.text);
                        }
                      });
                    }
                  },
                  dropdownColor: _pageBackgroundColorTop,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(height: 42, child: TextField(
                  controller: _searchQueryController,
                  decoration: InputDecoration(
                    hintText: "Search by category/name...",
                    hintStyle: GoogleFonts.lato(fontSize: 14.5, color: Colors.grey.shade500),
                    filled: true, fillColor: _pageBackgroundColorTop.withOpacity(0.8),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide(color: _iconColor, width: 1.5)),
                  ),
                  onChanged: (query){ 
                     _currentSearchQueryText = query;
                  },
                  onSubmitted: (query) {
                    if (query.isNotEmpty) _performSearchOrFilter(queryFromSearchField: query);
                    else setState(() { _results = []; _dataErrorMessage = null; _currentSearchQueryText = ""; _fetchClientProjects();}); 
                  },
                  textInputAction: TextInputAction.search,
              )),
            ),
          ],
        ),
        actions: [
          IconButton(icon: Icon(Icons.filter_alt_rounded, color: _appBarItemColor), onPressed: _showFilterDialog, tooltip: "Filters"),
          Padding(
            padding: const EdgeInsets.only(right: 10.0, left: 5.0),
            child: GestureDetector(
              onTap: _showProfileDialog,
              child: Hero(
                tag: 'client-projects-avatar-appbar', 
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: _iconColor.withOpacity(0.1),
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty && Uri.tryParse(avatarUrl)?.hasAbsolutePath == true)
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: (_isLoadingAvatar)
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey))
                      : ((avatarUrl == null || avatarUrl.isEmpty || Uri.tryParse(avatarUrl)?.hasAbsolutePath != true)
                          ? Icon(Icons.person, color: _iconColor.withOpacity(0.7), size: 20)
                          : null),
                ),
              ),
            ),
          ),
        ],
        backgroundColor: _appBarColor,
        iconTheme: IconThemeData(color: _appBarItemColor),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_pageBackgroundColorTop, _pageBackgroundColorBottom],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: _buildContentBody(),
      ),
    );
  }

  Widget _buildContentBody() {
    if (_isProcessingSearchOrFilter) {
      return Center(child: CircularProgressIndicator(color: _iconColor));
    }
    if (_dataErrorMessage != null && _results.isEmpty && (_currentSearchQueryText.isNotEmpty || _filterCategoryController.text.isNotEmpty || _filterCityController.text.isNotEmpty || _selectedMinRatingDialog != _ratingOptionsForFilter.first) ) {
      return _buildResultsErrorWidget();
    }
    if (_results.isNotEmpty || (_currentSearchQueryText.isNotEmpty && !_isProcessingSearchOrFilter) ) { 
      if (_results.isEmpty && _currentSearchQueryText.isNotEmpty && _dataErrorMessage != null) {
          return _buildEmptyResultsWidget(); 
      }
      if (_results.isEmpty && _currentSearchQueryText.isNotEmpty && _dataErrorMessage == null && !_isProcessingSearchOrFilter) {
          return _buildEmptyResultsWidget();
      }
       if (_results.isEmpty && !_isProcessingSearchOrFilter && _dataErrorMessage == null && (_filterCategoryController.text.isNotEmpty || _filterCityController.text.isNotEmpty || _selectedMinRatingDialog != _ratingOptionsForFilter.first )) {
         return _buildEmptyResultsWidget();
      }

      String resultDisplayType = _lastOperationResultType;
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final item = _results[index];
          if (resultDisplayType == 'providers') {
            return FadeInUp(delay: Duration(milliseconds: 80 * index), child: _buildProviderSearchCard(item));
          } else if (resultDisplayType == 'companies') {
            return FadeInUp(delay: Duration(milliseconds: 80 * index), child: _buildCompanySearchCard(item));
          }
          return const SizedBox.shrink();
        },
      );
    }
    
    if (_isLoadingProjects) {
      return Center(child: CircularProgressIndicator(color: _iconColor));
    }
    if (_dataErrorMessage != null && _projectsOriginal.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_dataErrorMessage!, textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 16, color: Colors.red.shade700)), SizedBox(height:10), ElevatedButton(onPressed: _fetchClientProjects, child: Text("Retry"))])));
    }
    if (_projectsOriginal.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FontAwesomeIcons.folderMinus, size: 60, color: _iconColor.withOpacity(0.5)),
            const SizedBox(height: 20),
            Text(
              "You don't have any projects yet.",
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(fontSize: 18, color: _secondaryTextColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: _projectsOriginal.length,
      itemBuilder: (context, index) {
        final project = _projectsOriginal[index];
        return _buildProjectCard(project);
      },
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final projectId = project['id']?.toString();
    if (projectId == null) return const SizedBox.shrink();

    return FadeInUp(
      delay: Duration(milliseconds: 100 * (int.tryParse(project['id'].toString()) ?? 0) % 5),

      child: Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: _cardBackgroundColor,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          leading: CircleAvatar(
            backgroundColor: _iconColor.withOpacity(0.1),
            backgroundImage: project['company_logo'] != null && project['company_logo'].toString().isNotEmpty && Uri.tryParse(project['company_logo'].toString())?.hasAbsolutePath == true
                           ? NetworkImage(project['company_logo'].toString())
                           : null,
            child: project['company_logo'] == null || project['company_logo'].toString().isEmpty || Uri.tryParse(project['company_logo'].toString())?.hasAbsolutePath != true
                   ? FaIcon(FontAwesomeIcons.solidFolderOpen, color: _iconColor, size: 22)
                   : null,
          ),
          title: Text(
            project['name']?.toString() ?? 'Unnamed Project',
            style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16.5, color: _primaryTextColor),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4),
              if(project['company_name'] != null)
                Text("Company: ${project['company_name']}", style: GoogleFonts.lato(fontSize: 13, color: _secondaryTextColor)),
              if(project['team_name'] != null)
                 Text("Team: ${project['team_name']}", style: GoogleFonts.lato(fontSize: 13, color: _secondaryTextColor)),
              SizedBox(height: 6),
               Row(
                 children: [
                   Icon(Icons.play_arrow_rounded, size: 16, color: Colors.green.shade600),
                   SizedBox(width: 4),
                   Text("Start: ${_formatDisplayDate(project['start_date']?.toString())}", style: GoogleFonts.lato(fontSize: 12.5, color: _secondaryTextColor)),
                 ],
               ),
               Row(
                 children: [
                   Icon(Icons.flag_rounded, size: 16, color: Colors.red.shade600),
                   SizedBox(width: 4),
                   Text("End: ${_formatDisplayDate(project['end_date']?.toString())}", style: GoogleFonts.lato(fontSize: 12.5, color: _secondaryTextColor)),
                 ],
               ),
            ],
          ),
          trailing: Icon(Icons.arrow_forward_ios_rounded, color: _iconColor.withOpacity(0.7), size: 18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClientProjectDetailPage(
                  projectId: projectId,
                  initialProjectName: project['name']?.toString(),
                  teamId: project['team_id']?.toString() ?? '',
                  companyId: project['company_id']?.toString() ?? '', 
                  companyName: project['company_name']?.toString() ?? '',
                ),
              ),
            ).then((value){
              if (value == true) { 
                _fetchClientProjects();
              }
            });
          },
        ),
      ),
    );
  }
}
