import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/features/auth/logic/auth_provider.dart';
import 'package:modern_classes_patna/features/auth/data/models/user_model.dart';
import 'package:modern_classes_patna/features/study_materials/data/models/study_material_model.dart';
import 'package:modern_classes_patna/screens/student/document_reader_screen.dart';

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  UserModel get currentUser => UserModel(
        id: 'usr_student_test',
        name: 'Aarav Sharma',
        email: 'aarav@test.com',
        phone: '+91 9876543210',
        role: UserRole.student,
        joinedDate: DateTime.now(),
      );

  @override
  bool get isAuthenticated => true;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('DocumentReaderScreen renders fallback overview when no remote PDF exists', (tester) async {
    final mockAuth = MockAuthProvider();
    final testMaterial = StudyMaterialModel(
      id: 'mat_test_1',
      courseId: 'c1',
      batchId: 'b1',
      title: 'Modern History: 1857 Revolt & Champaran Movement',
      subject: 'History',
      chapter: 'Indian National Movement',
      type: StudyDocType.pdf,
      pageCount: 15,
      fileSize: '2.4 MB',
      fileUrl: '', // empty triggers overview
      previewPages: [
        'Detailed causes of 1857 Revolt and political consequences.',
        'Gandhi’s Champaran Satyagraha in 1917 and impact on tenant farmers.',
      ],
      uploadedAt: DateTime.now(),
      uploaderName: 'Prof. R. K. Singh',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        ],
        child: MaterialApp(
          home: DocumentReaderScreen(material: testMaterial),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title and details are visible
    expect(find.text('Modern History: 1857 Revolt & Champaran Movement'), findsWidgets);
    expect(find.text('Key Topics & Notes Outline'), findsOneWidget);
    expect(find.text('Detailed causes of 1857 Revolt and political consequences.'), findsOneWidget);
    expect(find.text('Gandhi’s Champaran Satyagraha in 1917 and impact on tenant farmers.'), findsOneWidget);

    // Verify navigation capsule with page count
    expect(find.text('Page 1 of 15'), findsOneWidget);

    // Verify Document Info button opens bottom sheet
    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Document Information'), findsNothing); // In bottom sheet:
    expect(find.text('Faculty'), findsOneWidget);
    expect(find.text('Prof. R. K. Singh'), findsOneWidget);
    expect(find.text('Total Pages'), findsOneWidget);
  });
}
