import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../controllers/auth_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/selected_project_controller.dart';
import '../services/api_service.dart';
import '../theme.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthController>(context, listen: false);
      final dash = Provider.of<DashboardController>(context, listen: false);
      final user = auth.user;
      if (user != null) {
        final role = user.role?.toLowerCase();
        if (role == 'estudiante') {
          await dash.loadForStudent(user.id);
        } else if (role == 'profesor') {
          await dash.loadForProfessor(user.id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dash = Provider.of<DashboardController>(context);
    final auth = Provider.of<AuthController>(context);

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 800;

      if (dash.loading) {
        return const Center(child: CircularProgressIndicator());
      }

      Widget header = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Bienvenido, ${auth.user?.role ?? ''}',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          Row(
            children: const [
              Text('Hoy • 12 Nov', style: TextStyle(color: AppColors.muted)),
              SizedBox(width: 12),
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                    'https://api.dicebear.com/6.x/bottts/svg?seed=cristian'),
              )
            ],
          )
        ],
      );

      Widget topCards = isMobile
          ? Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Progreso general',
                            style: TextStyle(color: AppColors.muted)),
                        Text(
                            '${dash.desempeno?['promedio_calificaciones'] ?? 'N/A'}%',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w700))
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Próximas entregas',
                            style: TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 8),
                        if (dash.proyectos.isEmpty)
                          const Text('Sin próximas entregas'),
                        for (var p in dash.proyectos.take(3))
                          Text(
                              '- ${p.titulo} • ${p.fechaEntrega ?? 'Sin fecha'}')
                      ],
                    ),
                  ),
                )
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Progreso general',
                              style: TextStyle(color: AppColors.muted)),
                          const SizedBox(height: 8),
                          Text(
                              '${dash.desempeno?['promedio_calificaciones'] ?? 'N/A'}%',
                              style: const TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.w700))
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Próximas entregas',
                              style: TextStyle(color: AppColors.muted)),
                          const SizedBox(height: 8),
                          if (dash.proyectos.isEmpty)
                            const Text('Sin próximas entregas'),
                          for (var p in dash.proyectos.take(3))
                            Text(
                                '- ${p.titulo} • ${p.fechaEntrega ?? 'Sin fecha'}')
                        ],
                      ),
                    ),
                  ),
                )
              ],
            );

      Widget proyectosList = Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Proyectos activos',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('+ Nuevo proyecto',
                            style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                          onPressed: () {}, child: const Text('Exportar'))
                    ],
                  )
                ],
              ),
              const SizedBox(height: 12),

              // Mobile list
              if (isMobile)
                dash.proyectos.isEmpty
                    ? const Center(child: Text('No hay proyectos activos'))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: dash.proyectos.length,
                        itemBuilder: (ctx, i) {
                          final p = dash.proyectos[i];
                          final materia = dash.cursoNames[p.cursoId] ??
                              (p.descripcion ?? '-');
                          final vinfo = dash.ultimaVersion[p.id];
                          final ultima = vinfo != null
                              ? 'v${vinfo['numero_version'] ?? ''}'
                              : (p.fechaEntrega ?? '-');
                          final estado = 'Pendiente';

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              title: Text(p.titulo,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Text(materia),
                                  const SizedBox(height: 4),
                                  Text('Última: $ultima',
                                      style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 12)),
                                  const SizedBox(height: 6),
                                  Text('Estado: $estado',
                                      style: const TextStyle(
                                          fontSize: 12, color: AppColors.muted))
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      Provider.of<SelectedProjectController>(
                                              context,
                                              listen: false)
                                          .select(p.id);
                                    },
                                    icon: const Icon(Icons.visibility),
                                  ),
                                  IconButton(
                                    onPressed: () async {
                                      if (vinfo != null &&
                                          vinfo['id'] != null) {
                                        final url =
                                            '${ApiService.baseUrl}/proyectos/${p.id}/versiones/${vinfo['id']}/archivo';
                                        await launchUrlString(url);
                                      } else {
                                        final url =
                                            '${ApiService.baseUrl}/proyectos/${p.id}/archivo';
                                        await launchUrlString(url);
                                      }
                                    },
                                    icon: const Icon(Icons.download),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      )

              // Desktop table-like list
              else
                dash.proyectos.isEmpty
                    ? const Center(child: Text('No hay proyectos activos'))
                    : Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                                color: AppColors.bg,
                                borderRadius: BorderRadius.circular(6)),
                            child: Row(
                              children: const [
                                Expanded(
                                    flex: 3,
                                    child: Text('Proyecto',
                                        style:
                                            TextStyle(color: AppColors.muted))),
                                Expanded(
                                    flex: 2,
                                    child: Text('Materia',
                                        style:
                                            TextStyle(color: AppColors.muted))),
                                Expanded(
                                    flex: 2,
                                    child: Text('Última entrega',
                                        style:
                                            TextStyle(color: AppColors.muted))),
                                Expanded(
                                    flex: 1,
                                    child: Text('Estado',
                                        style:
                                            TextStyle(color: AppColors.muted))),
                                SizedBox(
                                    width: 80,
                                    child: Text('Acciones',
                                        style:
                                            TextStyle(color: AppColors.muted)))
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: dash.proyectos.length,
                            itemBuilder: (ctx, i) {
                              final p = dash.proyectos[i];
                              final materia = dash.cursoNames[p.cursoId] ??
                                  (p.descripcion ?? '-');
                              final vinfo = dash.ultimaVersion[p.id];
                              final ultima = vinfo != null
                                  ? 'v${vinfo['numero_version'] ?? ''}'
                                  : (p.fechaEntrega ?? '-');
                              final estado = 'Pendiente';

                              return InkWell(
                                onTap: () {
                                  Provider.of<SelectedProjectController>(
                                          context,
                                          listen: false)
                                      .select(p.id);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 8),
                                  decoration: const BoxDecoration(
                                      border: Border(
                                          bottom: BorderSide(
                                              color: Colors.grey,
                                              width: 0.12))),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(p.titulo,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            const SizedBox(height: 6),
                                            Text('v${p.versionActual}',
                                                style: const TextStyle(
                                                    color: AppColors.muted,
                                                    fontSize: 12))
                                          ],
                                        ),
                                      ),
                                      Expanded(flex: 2, child: Text(materia)),
                                      Expanded(flex: 2, child: Text(ultima)),
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 6, horizontal: 8),
                                          decoration: BoxDecoration(
                                              color: Colors.orangeAccent,
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          child: Center(
                                            child: Text(estado,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12)),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 80,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            IconButton(
                                              onPressed: () {
                                                Provider.of<SelectedProjectController>(
                                                        context,
                                                        listen: false)
                                                    .select(p.id);
                                              },
                                              icon:
                                                  const Icon(Icons.visibility),
                                            ),
                                            IconButton(
                                              onPressed: () async {
                                                if (vinfo != null &&
                                                    vinfo['id'] != null) {
                                                  final url =
                                                      '${ApiService.baseUrl}/proyectos/${p.id}/versiones/${vinfo['id']}/archivo';
                                                  await launchUrlString(url);
                                                } else {
                                                  final url =
                                                      '${ApiService.baseUrl}/proyectos/${p.id}/archivo';
                                                  await launchUrlString(url);
                                                }
                                              },
                                              icon: const Icon(Icons.download),
                                            )
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        ],
                      )
            ],
          ),
        ),
      );

      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 12),
              topCards,
              const SizedBox(height: 12),
              proyectosList
            ],
          ),
        ),
      );
    });
  }
}
