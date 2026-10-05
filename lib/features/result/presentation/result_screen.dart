import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ResultScreen')),
      body: Center(child: Text('ResultScreen', style: Theme.of(context).textTheme.headlineMedium)),
    );
  }
}
