import 'package:flutter/material.dart';

class Agent {
  final String slug;
  final String name;
  final String domain;
  final String description;
  final String icon;
  final String colorHex;

  const Agent({
    required this.slug,
    required this.name,
    required this.domain,
    required this.description,
    required this.icon,
    required this.colorHex,
  });

  factory Agent.fromJson(Map<String, dynamic> json) => Agent(
        slug: json['slug'] as String,
        name: json['name'] as String,
        domain: json['domain'] as String,
        description: json['description'] as String,
        icon: json['icon'] as String,
        colorHex: json['color'] as String,
      );

  Color get color {
    final hex = colorHex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
