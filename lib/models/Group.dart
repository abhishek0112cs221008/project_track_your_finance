import 'dart:convert';
import 'package:flutter/material.dart';


// You would typically have this in a separate file, e.g., 'group.dart'
@immutable
class Group {
  final int? id;
  final String name;
  final List<String> members;
  final String paidBy;
  final DateTime createdAt;

  const Group({
    this.id,
    required this.name,
    required this.members,
    required this.paidBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'members': jsonEncode(members), // Store as JSON string
      'paidBy': paidBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'],
      name: map['name'],
      members: List<String>.from(jsonDecode(map['members'])), // Decode from JSON string
      paidBy: map['paidBy'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
