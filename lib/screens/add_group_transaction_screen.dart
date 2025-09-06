import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_track_your_finance/models/transaction.dart';
import '../database/db_helper_group.dart';
import '../models/group.dart';
import '../models/transaction_group.dart' as my_transaction;

class AddGroupTransactionScreen extends StatefulWidget {
  final Group group;

  const AddGroupTransactionScreen({super.key, required this.group});

  @override
  State<AddGroupTransactionScreen> createState() =>
      _AddGroupTransactionScreenState();
}

class _AddGroupTransactionScreenState extends State<AddGroupTransactionScreen> 
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _amountFocusNode = FocusNode();
  
  String _paidBy = '';
  String _selectedCategory = 'Food';
  final Map<String, bool> _splitMembers = {};
  bool _isSaving = false;
  
  late AnimationController _animationController;
  late AnimationController _saveButtonController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Food', 'icon': CupertinoIcons.shopping_cart, 'color': CupertinoColors.systemOrange},
    {'name': 'Transport', 'icon': CupertinoIcons.car, 'color': CupertinoColors.systemBlue},
    {'name': 'Shopping', 'icon': CupertinoIcons.bag, 'color': CupertinoColors.systemPink},
    {'name': 'Entertainment', 'icon': CupertinoIcons.tv, 'color': CupertinoColors.systemPurple},
    {'name': 'Utilities', 'icon': CupertinoIcons.lightbulb, 'color': CupertinoColors.systemYellow},
    {'name': 'Rent', 'icon': CupertinoIcons.house, 'color': CupertinoColors.systemGreen},
    {'name': 'Travel', 'icon': CupertinoIcons.airplane, 'color': CupertinoColors.systemTeal},
    {'name': 'Others', 'icon': CupertinoIcons.ellipsis_circle, 'color': CupertinoColors.systemGrey},
  ];

  @override
  void initState() {
    super.initState();
    _paidBy = widget.group.members.first;
    for (var member in widget.group.members) {
      _splitMembers[member] = true;
    }
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _saveButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _saveButtonController, curve: Curves.elasticOut),
    );
    
    _animationController.forward();
    _saveButtonController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _nameFocusNode.dispose();
    _amountFocusNode.dispose();
    _animationController.dispose();
    _saveButtonController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _getCategoryData(String categoryName) {
    return _categories.firstWhere(
      (cat) => cat['name'] == categoryName,
      orElse: () => _categories.last,
    );
  }

  void _showAlertDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            message,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTransaction() async {
    final name = _nameController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    // Validation
    if (name.isEmpty) {
      _showAlertDialog('Missing Information', 'Please enter an expense name.');
      _nameFocusNode.requestFocus();
      return;
    }

    if (amountText.isEmpty || amount == null || amount <= 0) {
      _showAlertDialog('Invalid Amount', 'Please enter a valid amount greater than zero.');
      _amountFocusNode.requestFocus();
      return;
    }

    final membersToSplit = _splitMembers.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
        
    if (membersToSplit.isEmpty) {
      _showAlertDialog('Invalid Split',
          'Please select at least one person to split the expense with.');
      return;
    }

    // Show saving state
    setState(() => _isSaving = true);
    _saveButtonController.reverse();

    try {
      final perPersonAmount = amount / membersToSplit.length;
      final splitMap = {
        for (var member in membersToSplit) member: perPersonAmount
      };

      final newTransaction = my_transaction.Transaction(
        name: name,
        amount: amount,
        isIncome: false,
        category: _selectedCategory,
        date: DateTime.now(),
        groupId: widget.group.id,
        paidBy: _paidBy,
        split: splitMap,
      );

      await DBHelper.insertTransaction(newTransaction);
      
      if (mounted) {
        // Show success feedback
        _showSuccessSnackbar('Expense added successfully!');
        await Future.delayed(const Duration(milliseconds: 300));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _saveButtonController.forward();
      _showAlertDialog('Error', 'Failed to save expense. Please try again.');
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              CupertinoIcons.checkmark_circle_fill,
              color: CupertinoColors.white,
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: CupertinoColors.activeGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            backgroundColor: CupertinoColors.systemBackground.withOpacity(0.9),
            largeTitle: const Text(
              'Add Expense',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _isSaving ? null : _saveTransaction,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: _isSaving
                            ? null
                            : const LinearGradient(
                                colors: [
                                  Color(0xFF007AFF),
                                  Color(0xFF5856D6),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        color: _isSaving ? CupertinoColors.systemGrey4 : null,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CupertinoActivityIndicator(
                                radius: 8,
                                color: CupertinoColors.white,
                              ),
                            )
                          : const Text(
                              'Save',
                              style: TextStyle(
                                color: CupertinoColors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildExpenseDetailsCard(),
                          const SizedBox(height: 20),
                          _buildPaidByCard(),
                          const SizedBox(height: 20),
                          _buildSplitCard(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseDetailsCard() {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    CupertinoIcons.doc_text,
                    color: CupertinoColors.systemBlue,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Expense Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: CupertinoTextField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              placeholder: 'What did you spend on?',
              style: const TextStyle(fontSize: 16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              textCapitalization: TextCapitalization.words,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: CupertinoTextField(
              controller: _amountController,
              focusNode: _amountFocusNode,
              placeholder: '0.00',
              style: const TextStyle(fontSize: 16),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
              ],
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              prefix: Container(
                padding: const EdgeInsets.only(left: 16),
                child: const Text(
                  '₹',
                  style: TextStyle(
                    fontSize: 16,
                    color: CupertinoColors.systemGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          _buildCategorySelector(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    final categoryData = _getCategoryData(_selectedCategory);
    
    return GestureDetector(
      onTap: _showCategoryPicker,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: categoryData['color'].withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                categoryData['icon'],
                color: categoryData['color'],
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  Text(
                    _selectedCategory,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: CupertinoColors.systemGrey3,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaidByCard() {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    CupertinoIcons.person_crop_circle,
                    color: CupertinoColors.systemGreen,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Paid By',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _showPaidByPicker,
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: CupertinoColors.activeBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        _paidBy.isNotEmpty ? _paidBy[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: CupertinoColors.activeBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _paidBy,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.chevron_right,
                    color: CupertinoColors.systemGrey3,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitCard() {
    final splitCount = _splitMembers.values.where((selected) => selected).length;
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final perPersonAmount = splitCount > 0 ? amount / splitCount : 0.0;
    
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    CupertinoIcons.group,
                    color: CupertinoColors.systemOrange,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Split Equally',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (amount > 0 && splitCount > 0)
                        Text(
                          '₹${perPersonAmount.toStringAsFixed(2)} per person',
                          style: const TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...widget.group.members.asMap().entries.map((entry) {
            final index = entry.key;
            final member = entry.value;
            final isSelected = _splitMembers[member] ?? true;
            final isLast = index == widget.group.members.length - 1;
            
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: BoxDecoration(
                border: isLast 
                    ? null 
                    : const Border(
                        bottom: BorderSide(
                          color: CupertinoColors.separator,
                          width: 0.5,
                        ),
                      ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? CupertinoColors.activeBlue.withOpacity(0.1)
                          : CupertinoColors.systemGrey5,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        member.isNotEmpty ? member[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: isSelected 
                              ? CupertinoColors.activeBlue
                              : CupertinoColors.systemGrey,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isSelected 
                                ? CupertinoColors.label
                                : CupertinoColors.systemGrey,
                          ),
                        ),
                        if (isSelected && amount > 0 && splitCount > 0)
                          Text(
                            '₹${perPersonAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Transform.scale(
                    scale: 0.9,
                    child: CupertinoSwitch(
                      value: isSelected,
                      activeColor: CupertinoColors.activeBlue,
                      onChanged: (value) {
                        setState(() {
                          _splitMembers[member] = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showCategoryPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 400,
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const Text(
                    'Select Category',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category['name'];
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category['name'];
                      });
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? category['color'].withOpacity(0.1)
                            : CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected
                            ? Border.all(color: category['color'], width: 2)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: category['color'].withOpacity(0.2),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Icon(
                              category['icon'],
                              color: category['color'],
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            category['name'],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected 
                                  ? FontWeight.w600 
                                  : FontWeight.w500,
                              color: isSelected 
                                  ? category['color']
                                  : CupertinoColors.label,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaidByPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const Text(
                    'Who Paid?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: widget.group.members.length,
                itemBuilder: (context, index) {
                  final member = widget.group.members[index];
                  final isSelected = _paidBy == member;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _paidBy = member;
                      });
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? CupertinoColors.activeBlue.withOpacity(0.1)
                            : CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: CupertinoColors.activeBlue, width: 2)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? CupertinoColors.activeBlue.withOpacity(0.2)
                                  : CupertinoColors.systemGrey4,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                member.isNotEmpty ? member[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: isSelected 
                                      ? CupertinoColors.activeBlue
                                      : CupertinoColors.systemGrey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              member,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected 
                                    ? FontWeight.w600 
                                    : FontWeight.w500,
                                color: isSelected 
                                    ? CupertinoColors.activeBlue
                                    : CupertinoColors.label,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              CupertinoIcons.checkmark_circle_fill,
                              color: CupertinoColors.activeBlue,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
