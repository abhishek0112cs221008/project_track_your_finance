import 'package:flutter/cupertino.dart';
import '../database/db_helper_group.dart'; 
import '../models/group.dart'; 
import 'add_group_screen.dart';
import 'group_details_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<Group> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    final groups = await DBHelper.getGroups();
    setState(() {
      _groups = groups;
      _isLoading = false;
    });
  }

  void _navigateToAddGroup() async {
    final result = await Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => const AddGroupScreen()),
    );
    if (result == true) {
      _loadGroups(); // Refresh the list if a new group was added
    }
  }
  
  // New method for navigating to group details
  void _navigateToGroupDetails(Group group) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => GroupDetailsScreen(group: group),
      ),
    ).then((_) => _loadGroups()); // Refresh when returning
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text("Groups"),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _navigateToAddGroup,
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : _groups.isEmpty
                ? const Center(
                    child: Text(
                      "No groups created yet.\nTap '+' to add a new group.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: CupertinoColors.systemGrey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _groups.length,
                    itemBuilder: (context, index) {
                      final group = _groups[index];
                      return CupertinoListTile(
                        title: Text(group.name),
                        subtitle: Text("${group.members.length} members"),
                        onTap: () => _navigateToGroupDetails(group), // Correct navigation
                      );
                    },
                  ),
      ),
    );
  }
}

// A simple CupertinoListTile for demonstration. You can use your own.
class CupertinoListTile extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final VoidCallback? onTap;

  const CupertinoListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: CupertinoColors.systemGrey5,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    DefaultTextStyle(
                      style: const TextStyle(
                        color: CupertinoColors.systemGrey,
                        fontSize: 12,
                      ),
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_forward, color: CupertinoColors.systemGrey),
          ],
        ),
      ),
    );
  }
}
