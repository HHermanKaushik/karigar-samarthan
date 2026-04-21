import 'package:go_router/go_router.dart';
import 'pages/final_listing_screen.dart';
import 'pages/home_page.dart';
import 'pages/language_selection_page.dart';
import 'pages/add_product_wizard_page.dart';
import 'pages/edit_products_page.dart';
import 'pages/my_orders_page.dart';
import 'pages/onboarding_volume_page.dart';
import 'pages/language_confirm_page.dart';
import 'pages/add_product_intro_page.dart';
import 'pages/product_review_page.dart';
import 'pages/product_published_page.dart';
import 'pages/delete_product_confirm_page.dart';
import 'pages/order_details_page.dart';
import 'pages/account_overview_page.dart';
import 'pages/network_error_page.dart';
import '../models/product.dart';

/// GoRouter configuration for app navigation
///
/// This uses go_router for declarative routing, which provides:
/// - Type-safe navigation
/// - Deep linking support (web URLs, app links)
/// - Easy route parameters
/// - Navigation guards and redirects
///
/// To add a new route:
/// 1. Add a route constant to AppRoutes below
/// 2. Add a GoRoute to the routes list
/// 3. Navigate using context.go() or context.push()
/// 4. Use context.pop() to go back.
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.languageSelection,
    routes: [
      GoRoute(
        path: AppRoutes.languageSelection,
        name: 'languageSelection',
        pageBuilder: (context, state) =>
            NoTransitionPage(child: const LanguageSelectionPage()),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) =>
            NoTransitionPage(child: const HomePage()),
      ),
      GoRoute(
        path: AppRoutes.addProduct,
        name: 'addProduct',
        pageBuilder: (context, state) =>
            NoTransitionPage(child: const AddProductWizardPage()),
      ),
      GoRoute(
        path: AppRoutes.editProducts,
        name: 'editProducts',
        pageBuilder: (context, state) =>
            NoTransitionPage(child: const EditProductsPage()),
      ),
      GoRoute(
        path: AppRoutes.productReview,
        name: 'productReview',
        pageBuilder: (context, state) {
          // Extract the product from the 'extra' parameter
          final product = state.extra as Product;
          return NoTransitionPage(
            child: FinalReviewPage(draftProduct: product),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.myOrders,
        name: 'myOrders',
        pageBuilder: (context, state) =>
            NoTransitionPage(child: const MyOrdersPage()),
      ),
      GoRoute(
        path: '/volume-check',
        pageBuilder: (_, __) =>
            NoTransitionPage(child: const OnboardingVolumePage()),
      ),
      GoRoute(
        path: '/language-confirm',
        pageBuilder: (_, __) =>
            NoTransitionPage(child: const LanguageConfirmPage()),
      ),
      GoRoute(
        path: '/add-product-intro',
        pageBuilder: (_, __) =>
            NoTransitionPage(child: const AddProductIntroPage()),
      ),
      GoRoute(
        path: '/product-review',
        pageBuilder: (_, __) =>
            NoTransitionPage(child: const ProductReviewPage()),
      ),
      GoRoute(
        path: '/product-published',
        pageBuilder: (_, __) =>
            NoTransitionPage(child: const ProductPublishedPage()),
      ),
      GoRoute(
        path: '/delete-confirm',
        pageBuilder: (_, __) =>
            NoTransitionPage(child: const DeleteProductConfirmPage()),
      ),
      GoRoute(
        path: '/order-details',
        pageBuilder: (_, __) =>
            NoTransitionPage(child: const OrderDetailsPage()),
      ),
      GoRoute(
        path: '/account',
        pageBuilder: (_, __) =>
            NoTransitionPage(child: const AccountOverviewPage()),
      ),
      GoRoute(
        path: '/network-error',
        pageBuilder: (_, __) =>
            NoTransitionPage(child: const NetworkErrorPage()),
      ),
    ],
  );
}

/// Route path constants
/// Use these instead of hard-coding route strings
class AppRoutes {
  static const String languageSelection = '/language-selection';
  static const String home = '/';
  static const String account = '/account';
  static const String addProduct = '/add-product';
  static const String editProducts = '/edit-products';
  static const String productReview = '/product-review';
  static const String myOrders = '/my-orders';
}
