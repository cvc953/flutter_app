import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/auth_controller.dart';
import 'controllers/project_controller.dart';
import 'controllers/dashboard_controller.dart';
import 'controllers/selected_project_controller.dart';
import 'views/login_view.dart';
import 'widgets/app_shell.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authController = AuthController();
  // restore session if available before building the app
  await authController.restoreSession();
  runApp(MyApp(authController: authController));
}

class MyApp extends StatelessWidget {
  final AuthController authController;
  const MyApp({super.key, required this.authController});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authController),
        ChangeNotifierProvider(create: (_) => ProjectController()),
        ChangeNotifierProvider(create: (_) => DashboardController()),
        ChangeNotifierProvider(create: (_) => SelectedProjectController()),
      ],
      child: MaterialApp(
        title: 'EduProjects',
        theme: buildAppTheme(),
        initialRoute: '/',
        routes: {
          '/': (context) => const LoginView(),
          '/dashboard': (context) => const AppShell(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
