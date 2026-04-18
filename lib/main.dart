import 'package:flutter/material.dart';
import 'services/data_service.dart';
import 'utils/router.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DataService.init();
  runApp(const PetSyndromeApp());
}

class PetSyndromeApp extends StatelessWidget {
  const PetSyndromeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '펫신드룸 단가 계산기',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
