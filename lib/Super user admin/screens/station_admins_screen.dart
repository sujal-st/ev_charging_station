import 'package:flutter/material.dart';
import '../services/super_admin_service.dart';
import '../../models/user_model.dart';
import '../../models/roles.dart';
import '../widgets/user_card.dart';
import 'view_user_details_screen.dart';

class StationAdminsScreen extends StatefulWidget {
  const StationAdminsScreen({super.key});

  @override
  State<StationAdminsScreen> createState() => _StationAdminsScreenState();
}

class _StationAdminsScreenState extends State<StationAdminsScreen> {
  final SuperAdminService _superAdminService = SuperAdminService();
  Map<String, int> _stationsCount = {};
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<String> _previousAdminIds = [];
  bool _isLoadingStationsCount = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  Future<void> _refreshAdmins() async {
    // This will trigger a rebuild of the StreamBuilder
    setState(() {});
  }

  Future<void> _loadStationsCount(List<UserModel> admins) async {
    if (_isLoadingStationsCount) {
      return; // Already loading
    }

    _isLoadingStationsCount = true;

    final stationsCountMap = <String, int>{};
    for (var admin in admins) {
      try {
        final count = await _superAdminService.getStationsCountByUser(admin.uid);
        stationsCountMap[admin.uid] = count;
      } catch (e) {
        stationsCountMap[admin.uid] = 0;
      }
    }
    if (mounted) {
      setState(() {
        _stationsCount = stationsCountMap;
        _isLoadingStationsCount = false;
      });
    }
  }

  List<UserModel> _filterAdmins(List<UserModel> admins) {
    if (_searchQuery.isEmpty) return admins;
    
    return admins.where((admin) {
      final name = admin.name.toLowerCase();
      final email = admin.email.toLowerCase();
      return name.contains(_searchQuery) || email.contains(_searchQuery);
    }).toList();
  }


  Future<void> _deleteUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Station Admin'),
        content: Text(
          'Are you sure you want to delete ${user.name}? '
          'This will also affect all stations owned by this admin. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _superAdminService.deleteUser(user.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Station admin deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshAdmins();
      }
    } catch (e) {
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete user: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleUserStatus(UserModel user) async {
    final isActive = (user.toFirestore()['isActive'] ?? true) as bool;
    try {
      await _superAdminService.toggleUserStatus(user.uid, !isActive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${!isActive ? 'activated' : 'deactivated'} successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshAdmins();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update user status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search station admins by name or email...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        // Station Admins List - Using StreamBuilder for real-time updates
        Expanded(
          child: StreamBuilder<List<UserModel>>(
            stream: _superAdminService.getAllStationAdminsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading station admins: ${snapshot.error}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshAdmins,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isNotEmpty
                            ? Icons.search_off
                            : Icons.business_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No station admins found matching "$_searchQuery"'
                            : 'No station admins found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }

              final admins = snapshot.data!;
              
              // Load stations count when admins list changes (only if list actually changed)
              final currentAdminIds = admins.map((a) => a.uid).toList()..sort();
              final hasChanged = currentAdminIds.length != _previousAdminIds.length ||
                  !currentAdminIds.every((id) => _previousAdminIds.contains(id));
              
              if (hasChanged && !_isLoadingStationsCount) {
                // List has changed, load stations count asynchronously
                _previousAdminIds = List.from(currentAdminIds);
                Future.microtask(() {
                  if (mounted) {
                    _loadStationsCount(admins);
                  }
                });
              }

              final filteredAdmins = _filterAdmins(admins);

              if (filteredAdmins.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No station admins found matching "$_searchQuery"',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _refreshAdmins,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredAdmins.length,
                  itemBuilder: (context, index) {
                    final admin = filteredAdmins[index];
                    final stationsCount = _stationsCount[admin.uid] ?? 0;
                    return UserCard(
                      user: admin,
                      stationsCount: stationsCount,
                      onViewDetails: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ViewUserDetailsScreen(user: admin),
                          ),
                        );
                      },
                      onToggleStatus: () => _toggleUserStatus(admin),
                      onDelete: () => _deleteUser(admin),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

}

