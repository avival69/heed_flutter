import 'package:flutter/material.dart';
import 'router.dart'; 
class HeedApp extends StatelessWidget {
  const HeedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
