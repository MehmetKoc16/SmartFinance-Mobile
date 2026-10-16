import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/screens/dashboard_screen.dart';
import 'package:smartfinance_mobile/screens/categories_screen.dart';
import 'helpers/test_app.dart';

void main() {
  tearDown(tearDownFakeApi);
  testWidgets('Dashboard 150 islemin ozet tutarini sunucudan gosterir', (tester) async {
    await setUpFakeApi(categorySummary: [
      {'categoryId': 5, 'categoryName': 'Deneme Market', 'total': 9876.0, 'count': 150},
      {'categoryId': null, 'categoryName': null, 'total': 321.0, 'count': 2},
    ]);
    await tester.pumpWidget(testApp(const DashboardScreen()));
    await settle(tester);
    expect(fakeApiRequests.any((u) => u.path.contains('/transaction/category-summary/') && u.queryParameters['type'] == '2'), true);
    expect(fakeApiRequests.any((u) => u.queryParameters['pageSize'] == '100'), false);
    expect(find.text('Deneme Market'), findsOneWidget);
    expect(find.text('Kategorisiz'), findsOneWidget);
    expect(find.textContaining('9.876'), findsWidgets);
  });
  testWidgets('Ozet ucu hataliysa dagilim karti gizlenir', (tester) async {
    await setUpFakeApi(categorySummary: {'error': 'Ozet alinamadi'});
    await tester.pumpWidget(testApp(const DashboardScreen()));
    await settle(tester);
    expect(find.text('Deneme Market'), findsNothing);
    expect(find.text('Kategoriye Göre Harcama'), findsNothing);
  });
  testWidgets('Kategoriler de tum ayin ozet tutarini kullanir', (tester) async {
    await setUpFakeApi(categories: [
      {'id': 5, 'name': 'Deneme Market', 'type': 2},
    ], categorySummary: [
      {'categoryId': 5, 'categoryName': 'Deneme Market', 'total': 9876.0, 'count': 150},
    ]);
    await tester.pumpWidget(testApp(const CategoriesScreen()));
    await settle(tester);
    expect(fakeApiRequests.any((u) => u.path.contains('/transaction/category-summary/')), true);
    expect(find.textContaining('9.876'), findsWidgets);
  });
}
