import 'package:flutter/material.dart';
import '../services/super_admin_service.dart';
import '../../models/user_model.dart';
import '../../models/roles.dart';
import '../widgets/user_card.dart';
import '../widgets/edit_user_dialog.dart';
import 'view_user_details_screen.dart';

class AllUsersScreen extends StatefulWidget {
  const AllUsersScreen({super.key});

  @override
  State<AllUsersScreen> createState() => _AllUsersScreenState();
}

class _AllUsersScreenState extends State<AllUsersScreen> {
  final SuperAdminService _superAdminService = SuperAdminService();
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Map<String, int> _bookingsCount = {};
  Map<String, int> _stationsCount = {};

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

  Future<void> _refreshUsers() async {
    // This will trigger a rebuild of the StreamBuilder
    setState(() {});
  }

  Future<void> _loadBookingsCount(List<UserModel> users) async {
    final bookingsCountMap = <String, int>{};
    final stationsCountMap = <String, int>{};
    
    for (var user in users) {
      try {
        final bookingsCount = await _superAdminService.getBookingsCountByUser(user.uid);
        bookingsCountMap[user.uid] = bookingsCount;
      } catch (e) {
        bookingsCountMap[user.uid] = 0;
      }
      
      // Load stations count for station admins
      if (user.role == Roles.chargingStationUser) {
        try {
          final stationsCount = await _superAdminService.getStationsCountByUser(user.uid);
          stationsCountMap[user.uid] = stationsCount;
        } catch (e) {
          stationsCountMap[user.uid] = 0;
        }
      }
    }
    if (mounted) {
      setState(() {
        _bookingsCount = bookingsCountMap;
        _stationsCount = stationsCountMap;
      });
    }
  }

  List<UserModel> _filterUsers(List<UserModel> users) {
    if (_searchQuery.isEmpty) return users;
    
    return users.where((user) {
      final name = user.name.toLowerCase();
      final email = user.email.toLowerCase();
      return name.contains(_searchQuery) || email.contains(_searchQuery);
    }).toList();
  }


  Future<void> _deleteUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.name}? This action cannot be undone.'),
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
              content: Text('User deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _refreshUsers();
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
        _refreshUsers();
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
              hintText: 'Search all users by name or email...',
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
        // Users List - Using StreamBuilder for real-time updates
        Expanded(
          child: StreamBuilder<List<UserModel>>(
            stream: _superAdminService.getAllUsersStream(),
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
                        'Error loading users: ${snapshot.error}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshUsers,
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
                            : Icons.people_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No users found matching "$_searchQuery"'
                            : 'No users found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }

              final users = snapshot.data!;
              
              // Load bookings count when users list changes
              final currentUserIds = users.map((u) => u.uid).toList()..sort();
              final previousUserIds = _bookingsCount.keys.toList()..sort();
              final hasChanged = currentUserIds.length != previousUserIds.length ||
                  !currentUserIds.every((id) => previousUserIds.contains(id));
              
              if (hasChanged) {
                Future.microtask(() {
                  if (mounted) {
                    _loadBookingsCount(users);
                  }
                });
              }

              final filteredUsers = _filterUsers(users);

              if (filteredUsers.isEmpty) {
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
                        'No users found matching "$_searchQuery"',
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
                onRefresh: _refreshUsers,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final bookingsCount = _bookingsCount[user.uid] ?? 0;
                    final isStationAdmin = user.role == Roles.chargingStationUser;
                    
                    return UserCard(
                      user: user,
                      stationsCount: isStationAdmin ? _stationsCount[user.uid] : null,
                      bookingsCount: bookingsCount > 0 ? bookingsCount : null,
                      onViewDetails: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ViewUserDetailsScreen(user: user),
                          ),
                        );
                      },
                      onToggleStatus: () => _toggleUserStatus(user),
                      onDelete: () => _deleteUser(user),
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

