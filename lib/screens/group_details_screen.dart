import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../database/db_helper_group.dart';
import '../models/group.dart';
import '../models/transaction_group.dart' as my_transaction;
import 'add_group_transaction_screen.dart';

class GroupDetailsScreen extends StatefulWidget {
  final Group group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> 
    with TickerProviderStateMixin {
  List<my_transaction.Transaction> _groupTransactions = [];
  Map<String, double> _balances = {};
  bool _isLoading = true;
  String? _error;
  late AnimationController _animationController;
  late AnimationController _fabController;
  late AnimationController _refreshController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  bool _showFAB = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadGroupData();
    _fabController.forward();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController, 
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController, 
        curve: const Interval(0.2, 1.0, curve: Curves.elasticOut),
      ),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController, 
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fabController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupData() async {
    if (!_isLoading) {
      setState(() => _isRefreshing = true);
      _refreshController.forward();
    } else {
      setState(() => _isLoading = true);
    }
    
    setState(() => _error = null);
    
    try {
      // Add slight delay for better UX
      await Future.delayed(const Duration(milliseconds: 300));
      
      final transactions = await DBHelper.getGroupTransactions(widget.group.id!);
      
      if (mounted) {
        setState(() {
          _groupTransactions = transactions.cast<my_transaction.Transaction>();
          _calculateBalances();
          _isLoading = false;
          _isRefreshing = false;
          _error = null;
        });
        
        _animationController.forward();
        if (_isRefreshing) {
          _refreshController.reverse();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          _error = 'Failed to load group data. Please try again.';
        });
        _showErrorSnackbar('Failed to load group data');
      }
    }
  }

  void _calculateBalances() {
    final Map<String, double> balances = {};
    
    // Initialize all members with 0 balance
    for (var member in widget.group.members) {
      if (member.trim().isNotEmpty) {
        balances[member.trim()] = 0.0;
      }
    }

    for (var transaction in _groupTransactions) {
      try {
        if (transaction.split != null && 
            transaction.paidBy != null && 
            transaction.paidBy!.trim().isNotEmpty) {
          
          final paidBy = transaction.paidBy!.trim();
          
          // Add amount paid by the member
          balances[paidBy] = (balances[paidBy] ?? 0) + transaction.amount;
          
          // Subtract what each member owes
          transaction.split!.forEach((member, owedAmount) {
            final memberKey = member.trim();
            if (memberKey.isNotEmpty && owedAmount > 0) {
              balances[memberKey] = (balances[memberKey] ?? 0) - owedAmount;
            }
          });
        }
      } catch (e) {
        // Handle individual transaction calculation errors gracefully
        print('Error calculating balance for transaction ${transaction.id}: $e');
      }
    }
    
    _balances = balances;
  }

  Future<void> _navigateToAddGroupTransaction() async {
    // Haptic feedback for better UX
    HapticFeedback.lightImpact();
    
    setState(() => _showFAB = false);
    _fabController.reverse();
    
    try {
      final result = await Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => AddGroupTransactionScreen(group: widget.group),
          fullscreenDialog: true,
        ),
      );
      
      if (mounted) {
        setState(() => _showFAB = true);
        _fabController.forward();
        
        if (result == true) {
          _animationController.reset();
          await _loadGroupData();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _showFAB = true);
        _fabController.forward();
        _showErrorSnackbar('Failed to open add transaction screen');
      }
    }
  }
  
  void _confirmDeleteTransaction(my_transaction.Transaction transaction) {
    HapticFeedback.mediumImpact();
    
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: const Text(
          "Delete Transaction?",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            "Are you sure you want to delete '${transaction.name}'? This action cannot be undone.",
            style: const TextStyle(
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "Cancel",
              style: TextStyle(
                fontWeight: FontWeight.w400,
                color: CupertinoColors.activeBlue,
              ),
            ),
          ),
          CupertinoDialogAction(
            onPressed: () => _deleteTransaction(transaction),
            isDestructiveAction: true,
            child: const Text(
              "Delete",
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction(my_transaction.Transaction transaction) async {
    Navigator.of(context).pop();
    
    try {
      await DBHelper.deleteTransaction(transaction.id!);
      
      if (mounted) {
        _animationController.reset();
        await _loadGroupData();
        _showSuccessSnackbar('Transaction deleted successfully');
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to delete transaction. Please try again.');
      }
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_circle_fill,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: CupertinoColors.systemRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              CupertinoIcons.checkmark_circle_fill,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: CupertinoColors.activeGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pullToRefresh() async {
    HapticFeedback.lightImpact();
    await _loadGroupData();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CupertinoPageScaffold(
          backgroundColor: CupertinoColors.systemGroupedBackground,
          child: RefreshIndicator.adaptive(
            onRefresh: _pullToRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                CupertinoSliverNavigationBar(
                  backgroundColor: CupertinoColors.systemBackground.withOpacity(0.95),
                  largeTitle: Text(
                    widget.group.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  trailing: _buildAddButton(),
                  leading: _isRefreshing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CupertinoActivityIndicator(radius: 10),
                        )
                      : null,
                ),
                SliverToBoxAdapter(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ),
        if (_showFAB) _buildFloatingActionButton(),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: const Center(
          child: CupertinoActivityIndicator(radius: 20),
        ),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildBalanceSummary(),
                  const SizedBox(height: 24),
                  _groupTransactions.isEmpty
                      ? _buildEmptyState()
                      : _buildTransactionList(),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: CupertinoColors.systemRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              CupertinoIcons.exclamationmark_circle,
              size: 40,
              color: CupertinoColors.systemRed,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Something went wrong",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? "Unknown error occurred",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          CupertinoButton.filled(
            onPressed: () {
              _animationController.reset();
              _loadGroupData();
            },
            child: const Text("Try Again"),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _navigateToAddGroupTransaction,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: CupertinoColors.activeBlue,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.activeBlue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          CupertinoIcons.add,
          color: CupertinoColors.white,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Positioned(
      right: 20,
      bottom: 40,
      child: AnimatedBuilder(
        animation: _fabController,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabController.value,
            child: GestureDetector(
              onTap: _navigateToAddGroupTransaction,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF007AFF),
                      Color(0xFF5856D6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF007AFF).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.add,
                  color: CupertinoColors.white,
                  size: 22,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceSummary() {
    final balancesToDisplay = _balances.entries
        .where((e) => e.value.abs() > 0.01)
        .toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: balancesToDisplay.isEmpty 
                          ? CupertinoColors.activeGreen.withOpacity(0.15)
                          : CupertinoColors.activeBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      balancesToDisplay.isEmpty 
                          ? CupertinoIcons.checkmark_circle_fill
                          : CupertinoIcons.money_dollar_circle_fill,
                      color: balancesToDisplay.isEmpty 
                          ? CupertinoColors.activeGreen
                          : CupertinoColors.activeBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    "Group Balance",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: CupertinoColors.label,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            if (balancesToDisplay.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: CupertinoColors.activeGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: CupertinoColors.activeGreen.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        CupertinoIcons.checkmark_alt_circle_fill,
                        color: CupertinoColors.activeGreen,
                        size: 24,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          "All settled up! No pending balances.",
                          style: TextStyle(
                            color: CupertinoColors.activeGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...balancesToDisplay.asMap().entries.map((entry) {
                final index = entry.key;
                final mapEntry = entry.value;
                final member = mapEntry.key;
                final balance = mapEntry.value;
                final isOwed = balance > 0;
                final formattedAmount = "₹${balance.abs().toStringAsFixed(2)}";
                final isLast = index == balancesToDisplay.length - 1;
                
                return Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  decoration: BoxDecoration(
                    border: isLast 
                        ? null 
                        : const Border(
                            bottom: BorderSide(
                              color: CupertinoColors.separator,
                              width: 0.3,
                            ),
                          ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isOwed 
                              ? CupertinoColors.activeGreen.withOpacity(0.1)
                              : CupertinoColors.systemRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isOwed 
                                ? CupertinoColors.activeGreen.withOpacity(0.3)
                                : CupertinoColors.systemRed.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            member.isNotEmpty ? member[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: isOwed 
                                  ? CupertinoColors.activeGreen
                                  : CupertinoColors.systemRed,
                              fontWeight: FontWeight.w700,
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
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.label,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isOwed ? "is owed $formattedAmount" : "owes $formattedAmount",
                              style: TextStyle(
                                fontSize: 14,
                                color: isOwed 
                                    ? CupertinoColors.activeGreen
                                    : CupertinoColors.systemRed,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isOwed 
                              ? CupertinoColors.activeGreen.withOpacity(0.1)
                              : CupertinoColors.systemRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isOwed 
                                ? CupertinoColors.activeGreen.withOpacity(0.3)
                                : CupertinoColors.systemRed.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          formattedAmount,
                          style: TextStyle(
                            color: isOwed 
                                ? CupertinoColors.activeGreen
                                : CupertinoColors.systemRed,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            if (balancesToDisplay.isNotEmpty) const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList() {
    // Sort transactions by date (most recent first)
    final sortedTransactions = List<my_transaction.Transaction>.from(_groupTransactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemOrange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      CupertinoIcons.creditcard_fill,
                      color: CupertinoColors.systemOrange,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    "Recent Expenses (${sortedTransactions.length})",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: CupertinoColors.label,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            ...List.generate(sortedTransactions.length, (index) {
              final transaction = sortedTransactions[index];
              final isLast = index == sortedTransactions.length - 1;
              
              return Dismissible(
                key: Key('transaction_${transaction.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF3B30),
                        Color(0xFFFF6B60),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.delete_solid,
                        color: CupertinoColors.white,
                        size: 26,
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Delete",
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.endToStart) {
                    _confirmDeleteTransaction(transaction);
                  }
                  return false;
                },
                child: Container(
                  margin: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    border: isLast 
                        ? null 
                        : const Border(
                            bottom: BorderSide(
                              color: CupertinoColors.separator,
                              width: 0.3,
                            ),
                          ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: CupertinoColors.systemBlue.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.money_dollar,
                          color: CupertinoColors.systemBlue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transaction.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.label,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Paid by ${transaction.paidBy ?? 'Unknown'}",
                              style: const TextStyle(
                                fontSize: 14,
                                color: CupertinoColors.secondaryLabel,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM dd, yyyy • h:mm a').format(transaction.date),
                              style: const TextStyle(
                                fontSize: 12,
                                color: CupertinoColors.tertiaryLabel,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "₹${transaction.amount.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: CupertinoColors.label,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGrey6,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "Split ${transaction.split?.length ?? 0}",
                              style: const TextStyle(
                                fontSize: 11,
                                color: CupertinoColors.secondaryLabel,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (sortedTransactions.isNotEmpty) const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  CupertinoColors.systemGrey5,
                  CupertinoColors.systemGrey6,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              CupertinoIcons.money_dollar_circle,
              size: 60,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            "No expenses yet",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.label,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Start splitting expenses with your group by adding your first transaction. Track who pays what and settle up easily.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.secondaryLabel,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 40),
          CupertinoButton.filled(
            onPressed: _navigateToAddGroupTransaction,
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.add, size: 20),
                SizedBox(width: 8),
                Text(
                  "Add First Expense",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
