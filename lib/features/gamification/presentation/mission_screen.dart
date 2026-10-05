import 'package:flutter/material.dart';

class MissionScreen extends StatelessWidget {
  
  const MissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('MissionScreen')),
      body: Center(child: Text('MissionScreen', style: Theme.of(context).textTheme.headlineMedium)),
    );
  }
}
