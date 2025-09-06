import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:synchronized/synchronized.dart';
import '../models/transaction_group.dart' as my_transaction;
import '../models/group.dart';

class DBHelper {
  static const String dbName = "finance.db";
  static const String tableTransactions = "transactions";
  static const String tableGroups = "groups";

  static final _lock = Lock();
  static Database? _database;

  DBHelper._internal();

  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;

  static Future<Database> getDatabase() async {
    if (_database != null) {
      return _database!;
    }
    return await _lock.synchronized(() async {
      if (_database != null) {
        return _database!;
      }
      final path = join(await getDatabasesPath(), dbName);
      _database = await openDatabase(
        path,
        version: 3,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE $tableTransactions(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              amount REAL NOT NULL,
              isIncome INTEGER NOT NULL,
              category TEXT NOT NULL,
              date TEXT NOT NULL,
              groupId INTEGER,
              paidBy TEXT,
              split TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE $tableGroups(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              members TEXT NOT NULL,
              paidBy TEXT NOT NULL,
              createdAt TEXT NOT NULL
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 3) {
            // Add new columns to the transactions table.
            await db.execute('ALTER TABLE $tableTransactions ADD COLUMN groupId INTEGER');
            await db.execute('ALTER TABLE $tableTransactions ADD COLUMN paidBy TEXT');
            await db.execute('ALTER TABLE $tableTransactions ADD COLUMN split TEXT');
            
            // This is the crucial fix: explicitly add the paidBy column to the groups table.
            await db.execute('ALTER TABLE $tableGroups ADD COLUMN paidBy TEXT');
          }
        },
      );
      return _database!;
    });
  }

  static Future<int> insertTransaction(my_transaction.Transaction transaction) async {
    final db = await getDatabase();
    try {
      final map = transaction.toMap();
      if (transaction.split != null) {
        map['split'] = jsonEncode(transaction.split);
      }
      return await db.insert(
        tableTransactions,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error inserting transaction: $e');
      rethrow;
    }
  }

  static Future<List<my_transaction.Transaction>> getTransactions() async {
    final db = await getDatabase();
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        tableTransactions,
        orderBy: 'date DESC',
      );
      return List.generate(maps.length, (i) => my_transaction.Transaction.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
      return [];
    }
  }

  static Future<List<my_transaction.Transaction>> getGroupTransactions(int groupId) async {
    final db = await getDatabase();
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        tableTransactions,
        where: 'groupId = ?',
        whereArgs: [groupId],
        orderBy: 'date DESC',
      );
      return List.generate(maps.length, (i) => my_transaction.Transaction.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Error fetching group transactions: $e');
      return [];
    }
  }
  
  static Future<void> deleteTransaction(int id) async {
    final db = await getDatabase();
    try {
      await db.delete(
        tableTransactions,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
    }
  }

  static Future<int> updateTransaction(my_transaction.Transaction transaction) async {
    final db = await getDatabase();
    try {
      final map = transaction.toMap();
      if (transaction.split != null) {
        map['split'] = jsonEncode(transaction.split);
      }
      return await db.update(
        tableTransactions,
        map,
        where: 'id = ?',
        whereArgs: [transaction.id],
      );
    } catch (e) {
      debugPrint('Error updating transaction: $e');
      rethrow;
    }
  }

  static Future<int> insertGroup(Group group) async {
    final db = await getDatabase();
    try {
      return await db.insert(
        tableGroups,
        group.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error inserting group: $e');
      rethrow;
    }
  }

  static Future<List<Group>> getGroups() async {
    final db = await getDatabase();
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        tableGroups,
        orderBy: 'createdAt DESC',
      );
      return List.generate(maps.length, (i) => Group.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Error fetching groups: $e');
      return [];
    }
  }

  static Future<void> deleteGroup(int id) async {
    final db = await getDatabase();
    try {
      await db.delete(
        tableGroups,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('Error deleting group: $e');
    }
  }

  static Future<int> updateGroup(Group group) async {
    final db = await getDatabase();
    try {
      return await db.update(
        tableGroups,
        group.toMap(),
        where: 'id = ?',
        whereArgs: [group.id],
      );
    } catch (e) {
      debugPrint('Error updating group: $e');
      rethrow;
    }
  }

  static Future<void> closeDatabase() async {
    final db = await getDatabase();
    if (db.isOpen) {
      await db.close();
      _database = null;
    }
  }
}
