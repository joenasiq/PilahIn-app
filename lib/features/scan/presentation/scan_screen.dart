import 'package:flutter/material.dart';

class ScanScreen extends StatelessWidget {
  
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ScanScreen')),
      body: Center(child: Text('ScanScreen', style: Theme.of(context).textTheme.headlineMedium)),
    );
  }
}
