import 'dart:convert';



class Transaction {

  final int? id;

  final String name;

  final double amount;

  final bool isIncome;

  final String category;

  final DateTime date;

  final int? groupId;

  final String? paidBy;

  final Map<String, double>? split;



  Transaction({

    this.id,

    required this.name,

    required this.amount,

    required this.isIncome,

    required this.category,

    required this.date,

    this.groupId,

    this.paidBy,

    this.split,

  });



  // Convert Transaction to Map for database operations

  Map<String, dynamic> toMap() {

    return {

      'id': id,

      'name': name,

      'amount': amount,

      'isIncome': isIncome ? 1 : 0,

      'category': category,

      'date': date.toIso8601String(),

      'groupId': groupId,

      'paidBy': paidBy,

      'split': split != null ? jsonEncode(split) : null,

    };

  }



  // Create Transaction from Map (database)

  factory Transaction.fromMap(Map<String, dynamic> map) {

    Map<String, double>? splitMap;

    

    if (map['split'] != null && map['split'].toString().isNotEmpty) {

      try {

        final splitJson = jsonDecode(map['split']);

        splitMap = Map<String, double>.from(splitJson);

      } catch (e) {

        print('Error parsing split data: $e');

        splitMap = null;

      }

    }



    return Transaction(

      id: map['id'],

      name: map['name'] ?? '',

      amount: (map['amount'] ?? 0.0).toDouble(),

      isIncome: (map['isIncome'] ?? 0) == 1,

      category: map['category'] ?? 'Others',

      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),

      groupId: map['groupId'],

      paidBy: map['paidBy'],

      split: splitMap,

    );

  }



  // Create a copy with updated fields

  Transaction copyWith({

    int? id,

    String? name,

    double? amount,

    bool? isIncome,

    String? category,

    DateTime? date,

    int? groupId,

    String? paidBy,

    Map<String, double>? split,

  }) {

    return Transaction(

      id: id ?? this.id,

      name: name ?? this.name,

      amount: amount ?? this.amount,

      isIncome: isIncome ?? this.isIncome,

      category: category ?? this.category,

      date: date ?? this.date,

      groupId: groupId ?? this.groupId,

      paidBy: paidBy ?? this.paidBy,

      split: split ?? this.split,

    );

  }



  // Check if this is a group transaction

  bool get isGroupTransaction => groupId != null;



  // Get formatted amount string

  String get formattedAmount => '₹${amount.toStringAsFixed(2)}';



  // Get formatted date string

  String get formattedDate {

    final now = DateTime.now();

    final difference = now.difference(date);

    

    if (difference.inDays == 0) {

      return 'Today';

    } else if (difference.inDays == 1) {

      return 'Yesterday';

    } else if (difference.inDays < 7) {

      return '${difference.inDays} days ago';

    } else {

      return '${date.day}/${date.month}/${date.year}';

    }

  }



  // Get split amount for a specific member

  double getSplitAmount(String member) {

    return split?[member] ?? 0.0;

  }



  // Get all members involved in the split

  List<String> get splitMembers {

    return split?.keys.toList() ?? [];

  }



  // Get total split amount (should equal the transaction amount)

  double get totalSplitAmount {

    if (split == null) return amount;

    return split!.values.fold(0.0, (sum, amount) => sum + amount);

  }



  // Validate the transaction

  bool get isValid {

    if (name.trim().isEmpty) return false;

    if (amount <= 0) return false;

    

    // For group transactions, validate split data

    if (isGroupTransaction) {

      if (paidBy == null || paidBy!.trim().isEmpty) return false;

      if (split == null || split!.isEmpty) return false;

      

      // Check if split amounts roughly equal the total amount

      final totalSplit = totalSplitAmount;

      final difference = (totalSplit - amount).abs();

      if (difference > 0.01) return false; // Allow small floating point differences

    }

    

    return true;

  }



  @override

  String toString() {

    return 'Transaction{id: $id, name: $name, amount: $amount, isIncome: $isIncome, '

           'category: $category, date: $date, groupId: $groupId, paidBy: $paidBy, '

           'split: $split}';

  }



  @override

  bool operator ==(Object other) {

    if (identical(this, other)) return true;

    

    return other is Transaction &&

        other.id == id &&

        other.name == name &&

        other.amount == amount &&

        other.isIncome == isIncome &&

        other.category == category &&

        other.date == date &&

        other.groupId == groupId &&

        other.paidBy == paidBy;

  }



  @override

  int get hashCode {

    return id.hashCode ^

        name.hashCode ^

        amount.hashCode ^

        isIncome.hashCode ^

        category.hashCode ^

        date.hashCode ^

        groupId.hashCode ^

        paidBy.hashCode;

  }

}

