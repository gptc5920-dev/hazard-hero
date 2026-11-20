import 'package:flutter/material.dart';
import '../presentation/view_models/auth_view_model.dart';
import '../presentation/views/auth_view.dart';
import '../presentation/views/workspace_view.dart';
import 'app_dependencies.dart';

class HazardHeroApp extends StatefulWidget {
  const HazardHeroApp({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<HazardHeroApp> createState() => _HazardHeroAppState();
}

class _HazardHeroAppState extends State<HazardHeroApp> {
  late final AuthViewModel authViewModel;
  @override
  void initState() {
    super.initState();
    authViewModel = AuthViewModel(widget.dependencies.auth);
    authViewModel.initialize();
  }

  @override
  void dispose() {
    authViewModel.dispose();
    widget.dependencies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Hazard Hero',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xfff97316)),
      scaffoldBackgroundColor: const Color(0xfff8fafc),
      inputDecorationTheme: const InputDecorationTheme(filled: true),
      cardTheme: const CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
      ),
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xfff97316),
        brightness: Brightness.dark,
      ),
    ),
    home: StreamBuilder<AuthState>(
      stream: authViewModel.states,
      initialData: authViewModel.state,
      builder: (context, snapshot) {
        final state = snapshot.data!;
        if (state.phase == AuthPhase.initializing) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.phase == AuthPhase.authenticated) {
          return WorkspaceView(
            key: ValueKey(state.session!.id),
            session: state.session!,
            dependencies: widget.dependencies,
            authViewModel: authViewModel,
          );
        }
        return AuthView(state: state, viewModel: authViewModel);
      },
    ),
  );
}
