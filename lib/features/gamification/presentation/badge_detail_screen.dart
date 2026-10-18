import 'package:flutter/material.dart';

class BadgeDetailScreen extends StatelessWidget {
  
  const BadgeDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('BadgeDetailScreen')),
      body: Center(child: Text('BadgeDetailScreen', style: Theme.of(context).textTheme.headlineMedium)),
    );
  }
}
