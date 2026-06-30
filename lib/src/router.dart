import 'package:common_app_kit/common_app_kit.dart';
import 'package:go_router/go_router.dart';

import 'pages/home_page.dart';
import 'pages/shop_page.dart';
import 'services/analytics.dart';
import 'state/session_controller.dart';

GoRouter buildRouter({
  required SessionController session,
  required LicenseController license,
  required Analytics analytics,
}) {
  return GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) {
          analytics.track('route_view');
          return HomePage(session: session, license: license);
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
