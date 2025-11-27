import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/project_controller.dart';
import '../controllers/auth_controller.dart';
import 'upload_view.dart';
import '../controllers/selected_project_controller.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pc = Provider.of<ProjectController>(context, listen: false);
      final auth = Provider.of<AuthController>(context, listen: false);
      final user = auth.user;
      if (user != null) {
        final role = user.role?.toLowerCase();
        if (role == 'estudiante') {
          pc.loadProjectsForStudent(user.id);
        } else if (role == 'profesor') {
          pc.loadProjectsForProfessor(user.id);
        }
        // if padre: leave empty — parent must input student id to view
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pc = Provider.of<ProjectController>(context);
    final auth = Provider.of<AuthController>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Proyectos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              auth.logout();
              Navigator.of(context).pushReplacementNamed('/');
            },
          )
        ],
      ),
      floatingActionButton: auth.user?.role?.toLowerCase() == 'estudiante'
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const UploadView())),
              child: const Icon(Icons.upload_file),
            )
          : null,
      body: pc.loading
          ? const Center(child: CircularProgressIndicator())
          : pc.projects.isEmpty && auth.user?.role?.toLowerCase() == 'padre'
              ? Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      final idTxt = await showDialog<String?>(
                          context: context,
                          builder: (_) {
                            final ctl = TextEditingController();
                            return AlertDialog(
                              title: const Text('Ingrese ID del estudiante'),
                              content: TextField(
                                  controller: ctl,
                                  keyboardType: TextInputType.number),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, null),
                                    child: const Text('Cancelar')),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, ctl.text.trim()),
                                    child: const Text('OK'))
                              ],
                            );
                          });
                      if (idTxt != null && idTxt.isNotEmpty) {
                        final sid = int.tryParse(idTxt);
                        if (sid != null) {
                          final pc = Provider.of<ProjectController>(context,
                              listen: false);
                          try {
                            await pc.loadProjectsForStudent(sid);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')));
                          }
                        }
                      }
                    },
                    child: const Text('Ver proyectos de un estudiante'),
                  ),
                )
              : ListView.builder(
                  itemCount: pc.projects.length,
                  itemBuilder: (context, idx) {
                    final p = pc.projects[idx];
                    return ListTile(
                      title: Text(p.titulo),
                      subtitle: Text('Versión actual: ${p.versionActual}'),
                      onTap: () {
                        Provider.of<SelectedProjectController>(context,
                                listen: false)
                            .select(p.id);
                      },
                    );
                  },
                ),
    );
  }
}
