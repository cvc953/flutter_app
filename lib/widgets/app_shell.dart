import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../views/dashboard_view.dart';
import '../views/projects_view.dart';
import '../views/reports_view.dart';
import '../views/courses_view.dart';
import '../views/profile_view.dart';
import '../views/review_submissions_view.dart';
import '../controllers/auth_controller.dart';
import '../controllers/selected_project_controller.dart';
import '../controllers/project_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../views/project_right_panel.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selected = 0;

  List<Widget> _buildPages(String? role) {
    // Build pages dynamically so they can react to role changes
    final isProfesor = role?.toLowerCase() == 'profesor';
    return [
      DashboardView(),
      ProjectsView(),
      if (isProfesor) CoursesView(),
      if (isProfesor) ReviewSubmissionsView(), // Solo para profesores
      ReportsView(),
      ProfileView()
    ];
  }

  List<String> _buildLabels(String? role) {
    // Customize labels per role
    final isProfesor = role?.toLowerCase() == 'profesor';
    return [
      'Dashboard',
      'Proyectos',
      if (isProfesor) 'Cursos',
      if (isProfesor) 'Revisar Entregas', // Solo para profesores
      'Reportes',
      'Perfil'
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    final role = auth.user?.role;
    final _pages = _buildPages(role);
    final _labels = _buildLabels(role);

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 800;

      if (isMobile) {
        // Mobile layout: top app bar + pages + bottom navigation
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.accent,
            title: const Text('EduProjects'),
            actions: [
              IconButton(
                  onPressed: () {
                    // open profile or settings
                    setState(() => _selected = _selected);
                  },
                  icon: const Icon(Icons.person))
            ],
          ),
          body: SafeArea(child: _pages[_selected]),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selected,
            onTap: (i) => setState(() => _selected = i),
            items: _labels
                .map((l) => BottomNavigationBarItem(
                    icon: const Icon(Icons.circle), label: l))
                .toList(),
            type: BottomNavigationBarType.fixed,
          ),
          // Floating action to show selected project's detail if exists
          floatingActionButton:
              Consumer<SelectedProjectController>(builder: (ctx, sel, _) {
            final id = sel.selectedId;
            if (id == null) return const SizedBox.shrink();
            return FloatingActionButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Detalle')),
                          body: ProjectRightPanel(proyectoId: id))));
                },
                child: const Icon(Icons.open_in_new));
          }),
        );
      }

      // Desktop / large layout: sidebar / main / right panel
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Row(
          children: [
            // Sidebar
            Container(
              width: 260,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: const LinearGradient(colors: [
                              AppColors.accent,
                              AppColors.accent600
                            ])),
                        child: const Center(
                            child: Text('ES',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)))),
                    const SizedBox(width: 12),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Colegio Digital',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          Text('EduProjects',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 12))
                        ])
                  ]),
                  const SizedBox(height: 18),
                  ...List.generate(_labels.length, (i) {
                    final active = i == _selected;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () => setState(() => _selected = i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                              color: active ? AppColors.accent : Colors.white,
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(children: [
                            Text(_labels[i],
                                style: TextStyle(
                                    color:
                                        active ? Colors.white : AppColors.muted,
                                    fontWeight: FontWeight.w600))
                          ]),
                        ),
                      ),
                    );
                  }),
                  const Spacer(),
                  // Logout button at bottom of sidebar
                  Row(children: [
                    Expanded(
                        child: OutlinedButton.icon(
                      onPressed: () async {
                        // confirm then clear selection and logout and reset controllers
                        final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) {
                              return AlertDialog(
                                title: const Text('Cerrar sesión'),
                                content: const Text(
                                    '¿Estás seguro que deseas cerrar sesión?'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancelar')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Sí, cerrar')),
                                ],
                              );
                            });
                        if (confirm != true) return;
                        // clear selection
                        Provider.of<SelectedProjectController>(context,
                                listen: false)
                            .clear();
                        // clear controllers
                        try {
                          Provider.of<ProjectController>(context, listen: false)
                              .clear();
                        } catch (_) {}
                        try {
                          Provider.of<DashboardController>(context,
                                  listen: false)
                              .clear();
                        } catch (_) {}
                        auth.logout();
                        Navigator.of(context).pushReplacementNamed('/');
                      },
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Cerrar sesión'),
                    ))
                  ])
                ],
              ),
            ),
            // Main
            Expanded(child: _pages[_selected]),
            // Right panel: show selected project details or placeholder
            Container(
                width: 420,
                padding: const EdgeInsets.all(18),
                child:
                    Consumer<SelectedProjectController>(builder: (ctx, sel, _) {
                  final id = sel.selectedId;
                  if (id == null) {
                    return Column(children: const [
                      Text('Detalle',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 12),
                      Expanded(
                          child: Center(child: Text('Seleccione un proyecto')))
                    ]);
                  }
                  // Ensure the right panel gets a bounded height by using Expanded
                  return Column(
                    children: [
                      const Text('Detalle',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Expanded(child: ProjectRightPanel(proyectoId: id))
                    ],
                  );
                })),
          ],
        ),
      );
    });
  }
}
