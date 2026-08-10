import 'package:common_app_kit/common_app_kit.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pages/analysis_page.dart';
import 'pages/decision_form_page.dart';
import 'pages/shop_page.dart';
import 'services/analytics.dart';
import 'state/app_settings_controller.dart';
import 'state/session_controller.dart';

CustomTransitionPage<void> _fadePage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: child,
      );
    },
  );
}

GoRouter buildRouter({
  required SessionController session,
  required LicenseController license,
  required Analytics analytics,
  required AppSettingsController settings,
}) {
  return GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) {
          analytics.track('route_view');
          return DecisionFormPage(
            session: session,
            settings: settings,
          );
        },
      ),
      GoRoute(
        path: '/analysis',
        name: 'analysis',
        pageBuilder: (context, state) {
          return _fadePage(
            key: state.pageKey,
            child: AnalysisPage(session: session),
          );
        },
      ),
      GoRoute(
        path: '/shop',
        name: 'shop',
        builder: (context, state) {
          analytics.track('buy_intent');
          return ShopPage(controller: license);
        },
      ),
    ],
  );
}
