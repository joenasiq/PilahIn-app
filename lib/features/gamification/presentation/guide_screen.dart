import 'package:flutter/material.dart';

class GuideScreen extends StatelessWidget {
  
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('GuideScreen')),
      body: Center(child: Text('GuideScreen', style: Theme.of(context).textTheme.headlineMedium)),
    );
  }
}
