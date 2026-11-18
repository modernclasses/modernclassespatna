import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:modern_classes_patna/core/constants/app_constants.dart';
import 'package:modern_classes_patna/core/theme/app_theme.dart';
import 'package:modern_classes_patna/features/auth/data/models/user_model.dart';
import 'package:modern_classes_patna/features/auth/logic/auth_provider.dart';
import 'package:modern_classes_patna/providers/course_provider.dart';
import 'package:modern_classes_patna/providers/theme_provider.dart';
import 'package:modern_classes_patna/screens/admin/app_settings_screen.dart';
import 'package:modern_classes_patna/screens/student/student_profile_screen.dart';
import 'fake_course_repository.dart';

class FakeProfileAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  UserModel get currentUser => const UserModel(
    id: 'test-student-1',
    name: 'Anjali Kumari',
    email: 'anjali@example.com',
    phone: '+919876543210',
    role: UserRole.student,
  );

  @override
  bool get isAuthenticated => true;

  @override
  bool get isStudent => true;

  @override
  bool get isTeacher => false;

  @override
  bool get isAdmin => false;

  @override
  UserRole get currentRole => UserRole.student;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  bool get hasSessionWithoutProfile => false;

  @override
  bool get requiresEmailConfirmation => false;

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('ThemeProvider Unit Tests & Local Persistence', () {
    test(
      'Default mode is light mode and autoLoad loads without error',
      () async {
        SharedPreferences.setMockInitialValues({});
        final provider = ThemeProvider(autoLoad: false);

        expect(provider.themeMode, ThemeMode.light);
        expect(provider.isDarkMode, false);
        expect(provider.isInitialized, false);

        await provider.loadThemePreference();
        expect(provider.isInitialized, true);
        expect(provider.themeMode, ThemeMode.light);
        expect(provider.isDarkMode, false);
      },
    );

    test('Loads dark theme from SharedPreferences correctly', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.keyAppTheme: 'dark',
      });

      final provider = ThemeProvider(autoLoad: false);
      await provider.loadThemePreference();

      expect(provider.themeMode, ThemeMode.dark);
      expect(provider.isDarkMode, true);
      expect(provider.isInitialized, true);
    });

    test('Loads light theme from SharedPreferences correctly', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.keyAppTheme: 'light',
      });

      final provider = ThemeProvider(autoLoad: false);
      await provider.loadThemePreference();

      expect(provider.themeMode, ThemeMode.light);
      expect(provider.isDarkMode, false);
    });

    test(
      'setThemeMode updates state and persists to SharedPreferences',
      () async {
        SharedPreferences.setMockInitialValues({});
        final provider = ThemeProvider(autoLoad: false);

        await provider.setThemeMode(ThemeMode.dark);
        expect(provider.themeMode, ThemeMode.dark);
        expect(provider.isDarkMode, true);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(AppConstants.keyAppTheme), 'dark');

        await provider.setThemeMode(ThemeMode.light);
        expect(provider.themeMode, ThemeMode.light);
        expect(provider.isDarkMode, false);
        expect(prefs.getString(AppConstants.keyAppTheme), 'light');
      },
    );

    test('toggleTheme alternates between light and dark modes', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider(autoLoad: false);

      expect(provider.isDarkMode, false);

      await provider.toggleTheme();
      expect(provider.themeMode, ThemeMode.dark);
      expect(provider.isDarkMode, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.keyAppTheme), 'dark');

      await provider.toggleTheme();
      expect(provider.themeMode, ThemeMode.light);
      expect(provider.isDarkMode, false);
      expect(prefs.getString(AppConstants.keyAppTheme), 'light');
    });
  });

  group('AppTheme & Color Palette Coordinated Themes', () {
    test('academicTheme is Material 3 light theme with warm ivory canvas', () {
      final lightTheme = AppTheme.academicTheme;

      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.useMaterial3, true);
      expect(lightTheme.scaffoldBackgroundColor, AppColors.warmIvory);
      expect(lightTheme.colorScheme.brightness, Brightness.light);
      expect(lightTheme.colorScheme.surface, AppColors.surface);
    });

    test('darkTheme is Material 3 dark theme with deep night canvas', () {
      final darkTheme = AppTheme.darkTheme;

      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.useMaterial3, true);
      expect(darkTheme.scaffoldBackgroundColor, AppColors.darkBackground);
      expect(darkTheme.colorScheme.brightness, Brightness.dark);
      expect(darkTheme.colorScheme.surface, AppColors.darkSurface);
    });

    testWidgets('AppColors contextual helpers adapt to light and dark themes', (
      tester,
    ) async {
      late BuildContext lightContext;
      late BuildContext darkContext;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.academicTheme,
          home: Builder(
            builder: (ctx) {
              lightContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(AppColors.surfaceFor(lightContext), AppColors.surface);
      expect(AppColors.cardSurfaceFor(lightContext), AppColors.surfaceCard);
      expect(AppColors.borderFor(lightContext), AppColors.border);
      expect(AppColors.textPrimaryFor(lightContext), AppColors.textPrimary);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (ctx) {
              darkContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(AppColors.surfaceFor(darkContext), AppColors.darkSurface);
      expect(AppColors.cardSurfaceFor(darkContext), AppColors.darkSurfaceCard);
      expect(AppColors.borderFor(darkContext), AppColors.darkBorder);
      expect(AppColors.textPrimaryFor(darkContext), AppColors.darkTextPrimary);
    });
  });

  group('Theme Switch Widget Tests in App Settings', () {
    testWidgets(
      'Toggling theme switch in AppSettingsScreen updates ThemeProvider',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final themeProvider = ThemeProvider(autoLoad: false);

        await tester.pumpWidget(
          ChangeNotifierProvider<ThemeProvider>.value(
            value: themeProvider,
            child: MaterialApp(
              theme: AppTheme.academicTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeProvider.themeMode,
              home: const AppSettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final switchFinder = find.byKey(const Key('theme_mode_switch'));
        expect(switchFinder, findsOneWidget);

        final switchWidget = tester.widget<Switch>(switchFinder);
        expect(switchWidget.value, false);
        expect(
          find.text('Light theme active (classic academic ivory)'),
          findsOneWidget,
        );

        // Tap the switch to toggle to dark mode
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect(themeProvider.isDarkMode, true);
        expect(
          find.text('Dark theme active (comfortable for night study)'),
          findsOneWidget,
        );

        final switchWidgetAfter = tester.widget<Switch>(switchFinder);
        expect(switchWidgetAfter.value, true);

        // Tap again to revert to light mode
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect(themeProvider.isDarkMode, false);
        expect(
          find.text('Light theme active (classic academic ivory)'),
          findsOneWidget,
        );
      },
    );
  });

  group('Night Study Mode Widget Tests in Student Profile', () {
    testWidgets(
      'Toggling night study mode in StudentProfileScreen updates ThemeProvider',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final themeProvider = ThemeProvider(autoLoad: false);
        final fakeAuth = FakeProfileAuthProvider();
        final fakeCourseRepo = FakeCourseRepository();
        final courseProvider = CourseProvider(repository: fakeCourseRepo);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
              ChangeNotifierProvider<AuthProvider>.value(value: fakeAuth),
              ChangeNotifierProvider<CourseProvider>.value(
                value: courseProvider,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.academicTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeProvider.themeMode,
              home: const StudentProfileScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final studentSwitchFinder = find.byKey(
          const Key('student_theme_mode_switch'),
        );
        expect(studentSwitchFinder, findsOneWidget);

        final switchWidget = tester.widget<Switch>(studentSwitchFinder);
        expect(switchWidget.value, false);
        expect(find.text('Light academic theme active'), findsOneWidget);

        // Tap night study switch
        await tester.tap(studentSwitchFinder);
        await tester.pumpAndSettle();

        expect(themeProvider.isDarkMode, true);
        expect(find.text('Dark theme active (easier on eyes)'), findsOneWidget);
      },
    );
  });
}
