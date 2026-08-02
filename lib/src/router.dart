import 'package:common_app_kit/common_app_kit.dart';
import 'package:go_router/go_router.dart';

import 'pages/analysis_page.dart';
import 'pages/decision_form_page.dart';
import 'pages/decision_routing_page.dart';
import 'pages/shop_page.dart';
import 'services/analytics.dart';
import 'state/app_settings_controller.dart';
import 'state/session_controller.dart';

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
          return DecisionRoutingPage(settings: settings);
        },
      ),
      GoRoute(
        path: '/decision/do-or-buy',
        name: 'decision-do-or-buy',
        builder: (context, state) {
          return DecisionFormPage(
            path: DecisionPath.doOrBuy,
            session: session,
          );
        },
      ),
      GoRoute(
        path: '/decision/this-or-that',
        name: 'decision-this-or-that',
        builder: (context, state) {
          return DecisionFormPage(
            path: DecisionPath.thisOrThat,
            session: session,
          );
        },
      ),
      GoRoute(
        path: '/analysis',
        name: 'analysis',
        builder: (context, state) {
          return AnalysisPage(session: session);
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
