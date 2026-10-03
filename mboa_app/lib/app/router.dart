import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/tokens.dart';
import '../design/widgets/mboa_logo.dart';
import '../design/widgets/mboa_nav_bar.dart';
import '../features/admin/presentation/admin_console_screen.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/auth_screens.dart';
import '../features/certificates/presentation/certificates_screen.dart';
import '../features/contribution/domain/models.dart';
import '../features/contribution/presentation/contribution_entry_screen.dart';
import '../features/contribution/presentation/contribution_queue_screen.dart';
import '../features/culture/presentation/culture_detail_screen.dart';
import '../features/culture/presentation/culture_hub_screen.dart';
import '../features/culture/presentation/culture_quiz_screen.dart';
import '../features/culture/presentation/feed_screen.dart';
import '../features/culture/presentation/gallery_screen.dart';
import '../features/culture/presentation/media_screens.dart';
import '../features/culture/presentation/region_screens.dart';
import '../features/habilitation/specialist_application_screen.dart';
import '../features/home/home_screen.dart';
import '../features/learning/presentation/path_screen.dart';
import '../features/market/presentation/artisan_screen.dart';
import '../features/market/presentation/courier_screen.dart';
import '../features/market/presentation/market_application_screen.dart';
import '../features/market/presentation/market_screen.dart';
import '../features/market/presentation/my_orders_screen.dart';
import '../features/market/presentation/product_detail_screen.dart';
import '../features/lesson/lesson_player_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/setup_screen.dart';
import '../features/profile/profile_edit_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/translation/presentation/translation_screen.dart';

/// Rafraîchit le routeur quand l'état de session change.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen(sessionProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionListenable(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;
      const publicRoutes = {'/onboarding', '/register', '/login'};

      if (session.status == AuthStatus.unknown) {
        return location == '/splash' ? null : '/splash';
      }
      if (session.status == AuthStatus.signedOut) {
        return publicRoutes.contains(location) ? null : '/onboarding';
      }
      // Connecté.
      if (publicRoutes.contains(location) || location == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _Splash()),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      // Configuration initiale : elle suit l'inscription, car ses reponses
      // s'enregistrent sur le compte.
      GoRoute(path: '/setup', builder: (_, __) => const SetupScreen()),
      GoRoute(
        path: '/lesson/:id',
        builder: (_, state) =>
            LessonPlayerScreen(lessonId: state.pathParameters['id']),
      ),
      GoRoute(path: '/review', builder: (_, __) => const LessonPlayerScreen()),
      GoRoute(
        path: '/translate',
        builder: (_, __) => const TranslationScreen(),
      ),
      GoRoute(path: '/admin', builder: (_, __) => const AdminConsoleScreen()),
      GoRoute(
        path: '/certificates',
        builder: (_, __) => const CertificatesScreen(),
      ),
      GoRoute(path: '/orders', builder: (_, __) => const MyOrdersScreen()),
      GoRoute(path: '/artisan', builder: (_, __) => const ArtisanScreen()),
      GoRoute(path: '/courier', builder: (_, __) => const CourierScreen()),
      GoRoute(
        path: '/become/:role',
        builder: (_, state) => MarketApplicationScreen(
          role: state.pathParameters['role']!.toUpperCase(),
        ),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, __) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/become-specialist',
        builder: (_, __) => const SpecialistApplicationScreen(),
      ),
      GoRoute(
        path: '/contribute',
        builder: (_, __) => const ContributionQueueScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                ContributionEntryScreen(entry: state.extra! as CorpusEntry),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Shell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/learn', builder: (_, __) => const PathScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/culture',
                builder: (_, __) => const CultureHubScreen(),
                routes: [
                  // Les chemins nommes passent avant `:id`, qui les capturerait.
                  GoRoute(
                    path: 'fil',
                    builder: (_, __) => const CultureFeedScreen(),
                  ),
                  GoRoute(
                    path: 'mediatheque',
                    builder: (_, __) => const GalleryScreen(),
                  ),
                  GoRoute(
                    path: 'regions',
                    builder: (_, __) => const RegionsScreen(),
                  ),
                  GoRoute(
                    path: 'region/:id',
                    builder: (_, state) => RegionDetailScreen(
                      regionId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: 'quiz',
                    builder: (_, __) => const CultureQuizScreen(),
                  ),
                  GoRoute(
                    path: 'favoris',
                    builder: (_, __) => const FavoritesScreen(),
                  ),
                  GoRoute(
                    path: 'region/:id/media',
                    builder: (_, state) => RegionMediaScreen(
                      regionId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: 'region/:id/fil',
                    builder: (_, state) =>
                        CultureFeedScreen(regionId: state.pathParameters['id']),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => CultureDetailScreen(
                      contentId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/shop',
                builder: (_, __) => const MarketScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => ProductDetailScreen(
                      productId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Cinq destinations au maximum (SS24).
///
/// Chaque onglet emmène vers une section qui a sa couleur : la pastille active
/// de la barre reprend le dégradé de l'en-tête de la page. On sait où l'on est
/// sans lire.
class _Shell extends StatelessWidget {
  const _Shell({required this.shell});
  final StatefulNavigationShell shell;

  static const _destinations = [
    MboaNavDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Accueil',
      section: MboaSection.accueil,
    ),
    MboaNavDestination(
      icon: Icons.route_outlined,
      selectedIcon: Icons.route_rounded,
      label: 'Apprendre',
      section: MboaSection.apprendre,
    ),
    MboaNavDestination(
      icon: Icons.museum_outlined,
      selectedIcon: Icons.museum_rounded,
      label: 'Culture',
      section: MboaSection.culture,
    ),
    MboaNavDestination(
      icon: Icons.storefront_outlined,
      selectedIcon: Icons.storefront_rounded,
      label: 'Boutique',
      section: MboaSection.boutique,
    ),
    MboaNavDestination(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Profil',
      section: MboaSection.profil,
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    // Le fond suit la section affichée : l'application n'est plus uniformément
    // blanche, et le changement d'onglet se voit.
    backgroundColor: _destinations[shell.currentIndex].section.fond,
    // Pas d'`extendBody` : la barre est opaque, donc le contenu qui passerait
    // dessous serait simplement caché — et les derniers éléments d'une page
    // deviendraient inatteignables, quel que soit le défilement.
    body: shell,
    bottomNavigationBar: MboaNavBar(
      currentIndex: shell.currentIndex,
      destinations: _destinations,
      onSelected: (i) =>
          shell.goBranch(i, initialLocation: i == shell.currentIndex),
    ),
  );
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MboaLogo(variant: MboaLogoVariant.embleme, height: 120),
          SizedBox(height: MboaSpace.xl),
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ],
      ),
    ),
  );
}
