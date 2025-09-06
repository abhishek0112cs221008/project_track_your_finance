import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../database/db_helper_group.dart';
import '../models/group.dart';

class AddGroupScreen extends StatefulWidget {
  const AddGroupScreen({super.key});

  @override
  State<AddGroupScreen> createState() => _AddGroupScreenState();
}

class _AddGroupScreenState extends State<AddGroupScreen> {
  final _groupNameController = TextEditingController();
  final _memberNameController = TextEditingController();
  final List<String> _members = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    _memberNameController.dispose();
    super.dispose();
  }

  void _addMember() {
    final memberName = _memberNameController.text.trim();
    if (memberName.isNotEmpty && !_members.contains(memberName)) {
      setState(() {
        _members.add(memberName);
        _memberNameController.clear();
      });
    } else if (memberName.isNotEmpty && _members.contains(memberName)) {
      _showAlertDialog('Duplicate Member', 'This member has already been added.');
    }
  }

  void _removeMember(String member) {
    setState(() {
      _members.remove(member);
    });
  }

  Future<void> _saveGroup() async {
    final groupName = _groupNameController.text.trim();

    if (groupName.isEmpty || _members.isEmpty) {
      _showAlertDialog(
        'Missing Information',
        'Please enter a group name and at least one member.',
      );
      return;
    }

    setState(() => _isSaving = true);

    final newGroup = Group(
      name: groupName,
      members: _members,
      paidBy: "You", // Assuming the current user is 'You'
      createdAt: DateTime.now(),
    );

    try {
      await DBHelper.insertGroup(newGroup);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _showAlertDialog('Error', 'Failed to save group. Please try again.');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showAlertDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text("New Group"),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isSaving ? null : _saveGroup,
          child: _isSaving
              ? const CupertinoActivityIndicator()
              : const Text("Save"),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CupertinoFormSection.insetGrouped(
                header: const Text('GROUP DETAILS'),
                children: [
                  CupertinoTextFormFieldRow(
                    controller: _groupNameController,
                    placeholder: 'Group Name (e.g., Paris Trip)',
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CupertinoFormSection.insetGrouped(
                header: const Text('MEMBERS'),
                children: [
                  CupertinoTextFormFieldRow(
                    controller: _memberNameController,
                    placeholder: 'Enter member name',
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    style: const TextStyle(fontSize: 16),
                    onFieldSubmitted: (_) => _addMember(),
                    prefix: CupertinoButton(
                      padding: const EdgeInsets.all(0),
                      child: const Icon(
                        CupertinoIcons.add_circled_solid,
                        color: CupertinoColors.activeBlue,
                      ),
                      onPressed: _addMember,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_members.isNotEmpty)
                CupertinoListSection.insetGrouped(
                  header: const Text('GROUP MEMBERS'),
                  children: _members.map((member) {
                    return CupertinoListTile(
                      title: Text(member),
                      trailing: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _removeMember(member),
                        child: const Icon(CupertinoIcons.minus_circle, color: CupertinoColors.systemRed),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// A simple CupertinoListTile for demonstration
class CupertinoListTile extends StatelessWidget {
  final Widget title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const CupertinoListTile({
    super.key,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: title),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
