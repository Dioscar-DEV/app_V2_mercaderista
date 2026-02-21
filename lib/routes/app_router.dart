import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/auth/login_screen_new.dart';
import '../presentation/screens/auth/register_screen.dart';
import '../presentation/screens/mercaderista/home_screen.dart';
import '../presentation/screens/admin/admin_home_screen.dart';
import '../presentation/screens/admin/users_list_screen.dart';
import '../presentation/screens/admin/user_detail_screen.dart';
import '../presentation/screens/admin/create_user_screen.dart';
import '../presentation/screens/clients/clients_list_screen.dart';
import '../presentation/screens/clients/client_detail_screen.dart';
import '../presentation/screens/clients/clients_map_screen.dart';
import '../presentation/screens/routes/route_calendar_screen.dart';
import '../presentation/screens/routes/create_edit_route_screen.dart';
import '../presentation/screens/routes/route_execution_screen.dart';
import '../presentation/screens/admin/events/event_list_screen.dart';
import '../presentation/screens/admin/events/create_edit_event_screen.dart';
import '../presentation/screens/admin/events/event_detail_screen.dart';
import '../presentation/screens/events/event_check_in_screen.dart';
import '../presentation/screens/prospects/prospect_form_screen.dart';
import '../presentation/screens/admin/reports/reports_dashboard_screen.dart';
import '../presentation/screens/admin/reports/mercaderistas_report_screen.dart';
import '../presentation/screens/admin/reports/client_coverage_report_screen.dart';
import '../presentation/screens/admin/reports/routes_report_screen.dart';
import '../presentation/screens/admin/reports/events_report_screen.dart';
import '../presentation/screens/admin/reports/form_answers_screen.dart';

/// Configuración de rutas de la aplicación
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
      // Splash Screen
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Rutas de autenticación
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreenNew(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // Rutas del mercaderista
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const MercaderistaHomeScreen(),
      ),

      // Rutas del administrador
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminHomeScreen(),
        routes: [
          // Gestión de usuarios
          GoRoute(
            path: 'users',
            name: 'users_list',
            builder: (context, state) => const UsersListScreen(),
          ),
          GoRoute(
            path: 'users/create',
            name: 'create_user',
            builder: (context, state) => const CreateUserScreen(),
          ),
          GoRoute(
            path: 'users/:id',
            name: 'user_detail',
            builder: (context, state) {
              final userId = state.pathParameters['id']!;
              return UserDetailScreen(userId: userId);
            },
          ),
          // Gestión de clientes
          GoRoute(
            path: 'clients',
            name: 'clients_list',
            builder: (context, state) => const ClientsListScreen(),
          ),
          GoRoute(
            path: 'clients/map',
            name: 'clients_map',
            builder: (context, state) => const ClientsMapScreen(),
          ),
          GoRoute(
            path: 'clients/:coCli',
            name: 'client_detail',
            builder: (context, state) {
              final clientId = state.pathParameters['coCli']!;
              return ClientDetailScreen(clientId: clientId);
            },
          ),
          // Gestión de rutas
          GoRoute(
            path: 'routes',
            name: 'routes_calendar',
            builder: (context, state) => const RouteCalendarScreen(),
          ),
          GoRoute(
            path: 'routes/create',
            name: 'create_route',
            builder: (context, state) => const CreateEditRouteScreen(),
          ),
          GoRoute(
            path: 'routes/:id',
            name: 'route_detail',
            builder: (context, state) {
              final routeId = state.pathParameters['id']!;
              return RouteExecutionScreen(routeId: routeId);
            },
          ),
          GoRoute(
            path: 'routes/:id/edit',
            name: 'edit_route',
            builder: (context, state) {
              final routeId = state.pathParameters['id']!;
              return CreateEditRouteScreen(routeId: routeId);
            },
          ),
          // Reportes
          GoRoute(
            path: 'reports',
            name: 'reports_dashboard',
            builder: (context, state) => const ReportsDashboardScreen(),
            routes: [
              GoRoute(
                path: 'mercaderistas',
                name: 'reports_mercaderistas',
                builder: (context, state) => const MercaderistasReportScreen(),
              ),
              GoRoute(
                path: 'clients',
                name: 'reports_clients',
                builder: (context, state) => const ClientCoverageReportScreen(),
              ),
              GoRoute(
                path: 'routes',
                name: 'reports_routes',
                builder: (context, state) => const RoutesReportScreen(),
              ),
              GoRoute(
                path: 'events',
                name: 'reports_events',
                builder: (context, state) => const EventsReportScreen(),
              ),
              GoRoute(
                path: 'answers',
                name: 'reports_answers',
                builder: (context, state) => const FormAnswersScreen(),
              ),
            ],
          ),
          // Gestión de eventos
          GoRoute(
            path: 'events',
            name: 'events_list',
            builder: (context, state) => const EventListScreen(),
          ),
          GoRoute(
            path: 'events/create',
            name: 'create_event',
            builder: (context, state) => const CreateEditEventScreen(),
          ),
          GoRoute(
            path: 'events/:id',
            name: 'event_detail',
            builder: (context, state) {
              final eventId = state.pathParameters['id']!;
              return EventDetailScreen(eventId: eventId);
            },
          ),
          GoRoute(
            path: 'events/:id/edit',
            name: 'edit_event',
            builder: (context, state) {
              final eventId = state.pathParameters['id']!;
              return CreateEditEventScreen(eventId: eventId);
            },
          ),
        ],
      ),

      // Rutas del mercaderista
      GoRoute(
        path: '/mercaderista/route/:id',
        name: 'mercaderista_route',
        builder: (context, state) {
          final routeId = state.pathParameters['id']!;
          return RouteExecutionScreen(routeId: routeId);
        },
      ),
      GoRoute(
        path: '/mercaderista/prospect/new',
        name: 'mercaderista_prospect',
        builder: (context, state) => const ProspectFormScreen(),
      ),
      GoRoute(
        path: '/mercaderista/event/:id',
        name: 'mercaderista_event',
        builder: (context, state) {
          final eventId = state.pathParameters['id']!;
          return EventCheckInScreen(eventId: eventId);
        },
      ),

      // TODO: Agregar más rutas según se implementen las pantallas
      // GoRoute(
      //   path: '/routes',
      //   name: 'routes',
      //   builder: (context, state) => const RoutesManagementScreen(),
      // ),
      // GoRoute(
      //   path: '/clients',
      //   name: 'clients',
      //   builder: (context, state) => const ClientsManagementScreen(),
      // ),
      // GoRoute(
      //   path: '/events',
      //   name: 'events',
      //   builder: (context, state) => const EventsManagementScreen(),
      // ),
      // GoRoute(
      //   path: '/reports',
      //   name: 'reports',
      //   builder: (context, state) => const ReportsScreen(),
      // ),
      // GoRoute(
      //   path: '/route/:id',
      //   name: 'route_detail',
      //   builder: (context, state) {
      //     final id = state.pathParameters['id']!;
      //     return RouteDetailScreen(routeId: id);
      //   },
      // ),
      // GoRoute(
      //   path: '/visit/:routeId/:clientId',
      //   name: 'visit_form',
      //   builder: (context, state) {
      //     final routeId = state.pathParameters['routeId']!;
      //     final clientId = state.pathParameters['clientId']!;
      //     return VisitFormScreen(routeId: routeId, clientId: clientId);
      //   },
      // ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Página no encontrada',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'La ruta "${state.uri}" no existe',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    ),
  );
}
