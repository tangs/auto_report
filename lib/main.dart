import 'package:auto_report/pages/auth_page.dart';
import 'package:auto_report/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return OKToast(
      // 2-A: wrap your app with OKToast
      child: MaterialApp(
        title: 'Flutter Demo',
        routes: {
          '/auth': (context) => const AuthPage(),
        },
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const HomePage(title: 'auto reporter'),
      ),
    );
  }
}
