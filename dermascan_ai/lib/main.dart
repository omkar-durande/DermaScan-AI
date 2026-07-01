import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'constants/colors.dart';
import 'providers/auth_provider.dart';
import 'providers/scan_provider.dart';
import 'providers/history_provider.dart';
import 'services/connectivity_service.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/home_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/results_screen.dart';
import 'screens/history_screen.dart';
import 'screens/treatment_progress_screen.dart';
import 'screens/nearby_hospitals_screen.dart';
import 'screens/uv_exposure_screen.dart';
import 'screens/home_remedies_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/ai_chat_screen.dart';
import 'widgets/bottom_nav_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with generated config
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init failed: $e');
    debugPrint('Running without Firebase — auth features will not work.');
  }

  // Start connectivity monitoring
  ConnectivityService().startMonitoring();

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const DermaScanApp());
}

class DermaScanApp extends StatelessWidget {
  const DermaScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => ScanProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider.value(value: ConnectivityService()),
      ],
      child: MaterialApp(
        title: 'DermaScan AI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: AppColors.background,
          useMaterial3: true,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/onboarding': (context) => const OnboardingScreen(),
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/verify-email': (context) {
            final email = ModalRoute.of(context)!.settings.arguments as String? ?? '';
            return EmailVerificationScreen(email: email);
          },
          '/home': (context) => const MainNavigationShell(),
          '/scan': (context) => const ScanScreen(),
          '/results': (context) => const ResultsScreen(),
          '/history': (context) => const HistoryScreen(),
          '/treatment': (context) => const TreatmentProgressScreen(),
          '/hospitals': (context) => const NearbyHospitalsScreen(),
          '/uv': (context) => const UvExposureScreen(),
          '/remedies': (context) => const HomeRemediesScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/chat': (context) => const AiChatScreen(),
        },
      ),
    );
  }
}

/// Main navigation shell with bottom navigation bar
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Load initial data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistoryData());
  }

  void _loadHistoryData() {
    final uid = context.read<AuthProvider>().uid;
    if (uid != null) {
      context.read<HistoryProvider>().loadScans(uid);
    }
  }

  // Only keep screens that should persist in the navigation stack
  // ScanScreen is excluded because it uses live camera and should only be
  // active when explicitly opened
  final List<Widget> _screens = const [
    HomeScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  // Map bottom nav indices to screen indices
  // 0 = Home, 1 = Scan (navigates away — always show Home underneath), 2 = History, 3 = Profile
  int _screenIndex(int navIndex) {
    if (navIndex == 2) return 1; // History
    if (navIndex == 3) return 2; // Profile
    return 0;                    // Home (covers 0 and 1)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _screenIndex(_currentIndex),
        children: _screens,
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1) {
            // Scan tab: navigate to scan screen as a separate route
            // Keep _currentIndex = 0 (Home) so IndexedStack shows Home underneath
            Navigator.pushNamed(context, '/scan').then((_) {
              // Ensure we're back on Home tab when returning from scan
              setState(() => _currentIndex = 0);
              // Reload history after a short delay so Firestore write completes
              Future.delayed(const Duration(milliseconds: 1500), () {
                if (mounted) _loadHistoryData();
              });
            });
          } else {
            // Reload history data when switching to History tab
            if (index == 2) _loadHistoryData();
            setState(() => _currentIndex = index);
          }
        },
      ),
    );
  }
}

