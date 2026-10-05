import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../scan/domain/classification_result.dart';
import '../../scan/domain/waste_category.dart';
import '../../../core/constants/ml_config.dart';
import '../data/guidance_content.dart';

class GuidanceScreen extends StatelessWidget {
  final ClassificationResult? result;

  const GuidanceScreen({super.key, this.result});

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Panduan Pengelolaan')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Data hasil tidak ditemukan'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/scan'),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      );
    }

    final guidance = GuidanceContent.getGuidance(result!.category);
    final isOrganic = result!.category == WasteCategory.organik;
    final color = isOrganic ? Colors.green : Colors.blue;
    final iconData = isOrganic ? Icons.eco : Icons.recycling;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panduan Pengelolaan', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.blue),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gambar di atas
            Image.file(
              File(result!.imagePath),
              height: 250,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 250,
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, size: 64, color: Colors.grey),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: Icon(iconData, color: color, size: 18),
                        label: Text(
                          isOrganic ? 'Organik' : 'Anorganik',
                          style: TextStyle(color: color, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: color.withAlpha(25),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                      if (MlConfig.showScanPoints)
                        Chip(
                          avatar: const Icon(Icons.auto_awesome, color: Colors.blue, size: 18),
                          label: Text(
                            '+${MlConfig.scanPointsReward} Poin Pemindaian',
                            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: Colors.blue.withAlpha(25),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Judul dan Deskripsi
                  Text(
                    guidance.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    guidance.description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Langkah Pengelolaan
                  Text(
                    'Langkah Pengelolaan',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(guidance.steps.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.blue.withAlpha(25),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(guidance.steps[index], style: const TextStyle(fontSize: 15)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  
                  const SizedBox(height: 8),
                  
                  // Kartu Do and Dont
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Do
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Boleh dilakukan',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...guidance.doList.map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6, right: 8),
                                      child: CircleAvatar(radius: 3, backgroundColor: Colors.green.shade400),
                                    ),
                                    Expanded(
                                      child: Text(
                                        item,
                                        style: TextStyle(fontSize: 13, color: Colors.green.shade900),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Dont
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.cancel, color: Colors.red.shade600, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Hindari',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...guidance.dontList.map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6, right: 8),
                                      child: CircleAvatar(radius: 3, backgroundColor: Colors.red.shade400),
                                    ),
                                    Expanded(
                                      child: Text(
                                        item,
                                        style: TextStyle(fontSize: 13, color: Colors.red.shade900),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
