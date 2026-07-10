import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/auth_gate.dart';

final appRouter = GoRouter(
  routes: [GoRoute(path: '/', builder: (context, state) => const AuthGate())],
  errorBuilder:
      (context, state) =>
          Scaffold(body: Center(child: Text('页面暂时走丢了：${state.error}'))),
);
