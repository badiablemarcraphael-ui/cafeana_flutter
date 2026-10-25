import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(
    home: Scaffold(
      bottomNavigationBar: NavigationBar(
        destinations: List.generate(6, (i) => NavigationDestination(icon: Icon(Icons.home), label: 'Tab $i')),
      ),
    ),
  ));
}
