import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sancharya/core/localization/app_localizations.dart';
import 'package:sancharya/core/location/app_location_provider.dart';
import 'package:sancharya/models/ngo_record.dart';
import 'package:sancharya/screens/ngo/ngo_donation_screen.dart';
import 'package:sancharya/services/resources/ngo_service.dart';
import 'package:sancharya/widgets/loading_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'preferred_language': 'en'});
    await NgoService().getAllNgos();
  });

  Widget buildTestScreen({String? initialCrop, String? initialLocation, Locale locale = const Locale('en')}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppLocationProvider>(
          create: (_) => AppLocationProvider(),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: NgoDonationScreen(
          initialCrop: initialCrop,
          initialLocation: initialLocation,
        ),
      ),
    );
  }

  Future<void> pumpUntilLoaded(WidgetTester tester) async {
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(LoadingIndicator).evaluate().isEmpty) {
        break;
      }
    }
  }

  testWidgets('NgoDonationScreen loads and displays NGO cards from dataset in English', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestScreen());
    await pumpUntilLoaded(tester);

    // Verify title in English
    expect(find.text('NGO Donation Support'), findsOneWidget);

    // Verify count badge shows 827 NGOs
    expect(find.textContaining('827'), findsWidgets);

    // Verify location search TextField is present
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('NgoDonationScreen loads and displays NGO cards from dataset in Hindi', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestScreen(locale: const Locale('hi')));
    await pumpUntilLoaded(tester);

    // Verify title in Hindi
    expect(find.text('एनजीओ व दान सहायता'), findsOneWidget);

    // Verify count badge shows 827
    expect(find.textContaining('827'), findsWidgets);
  });

  testWidgets('NgoDonationScreen filters NGOs by location query', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestScreen());
    await pumpUntilLoaded(tester);

    // Enter Ludhiana in the location field (filters in real time via onChanged)
    await tester.enterText(find.byType(TextField), 'Ludhiana');
    await pumpUntilLoaded(tester);

    // Verify filtered count and presence of Ludhiana
    expect(find.textContaining('6'), findsWidgets);
    expect(find.textContaining('Ludhiana'), findsWidgets);

    // Clear search button test
    expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.clear_rounded));
    await pumpUntilLoaded(tester);
    expect(find.textContaining('827'), findsWidgets);
  });

  testWidgets('NgoDonationScreen shows empty state for unmatched location', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestScreen());
    await pumpUntilLoaded(tester);

    await tester.enterText(find.byType(TextField), 'Atlantis Ocean City XYZ');
    await pumpUntilLoaded(tester);

    // Verify empty state message
    expect(find.text('No matching NGOs found'), findsOneWidget);
  });

  testWidgets('NgoDonationScreen initial crop and location pre-populates and filters', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestScreen(
      initialCrop: 'Tomato',
      initialLocation: 'Ludhiana, Punjab',
    ));
    await pumpUntilLoaded(tester);

    expect(find.textContaining('6'), findsWidgets);
    expect(find.textContaining('Ludhiana'), findsWidgets);
  });

  testWidgets('NgoRecord correctly identifies missing or invalid phone numbers', (WidgetTester tester) async {
    Map<String, dynamic> makeNgoJson(String contact) => {
      'id': 'test-ngo',
      'name_en': 'Sample NGO',
      'name_hi': 'नमूना एनजीओ',
      'state': 'Uttar Pradesh',
      'state_hi': 'उत्तर प्रदेश',
      'district': 'Agra',
      'district_hi': 'आगरा',
      'address': 'Agra, UP',
      'latitude': 27.18,
      'longitude': 78.02,
      'accepted_produce': ['Tomato'],
      'demand_level': 'High',
      'pickup_available': true,
      'contact': contact,
      'source_url': 'https://example.org',
      'last_verified_date': '2026-10-24',
      'data_quality': 'verified',
    };

    final emptyNgo = NgoRecord.fromJson(makeNgoJson(''));
    expect(emptyNgo.hasValidContact, false);
    expect(emptyNgo.contactDisplay(false), 'No mobile number available');
    expect(emptyNgo.contactDisplay(true), 'मोबाइल नंबर उपलब्ध नहीं है');

    final nullNgo = NgoRecord.fromJson(makeNgoJson('null'));
    expect(nullNgo.hasValidContact, false);
    expect(nullNgo.contactDisplay(false), 'No mobile number available');

    final naNgo = NgoRecord.fromJson(makeNgoJson('N/A'));
    expect(naNgo.hasValidContact, false);
    expect(naNgo.contactDisplay(false), 'No mobile number available');

    final zeroesNgo = NgoRecord.fromJson(makeNgoJson('0000000000'));
    expect(zeroesNgo.hasValidContact, false);
    expect(zeroesNgo.contactDisplay(false), 'No mobile number available');

    final elevenDigitNgo = NgoRecord.fromJson(makeNgoJson('+91 111754 71744'));
    expect(elevenDigitNgo.hasValidContact, false);
    expect(elevenDigitNgo.contactDisplay(false), 'No mobile number available');

    final validNgo = NgoRecord.fromJson(makeNgoJson('+91 98765 43210'));
    expect(validNgo.hasValidContact, true);
    expect(validNgo.contactDisplay(false), '+91 98765 43210');
  });
}
