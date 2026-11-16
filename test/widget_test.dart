import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/app.dart';

void main() {
  testWidgets('HomeShell renders Explore, Map and Favourites tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ViennaPoiExplorerApp()));

    expect(find.text('Explore'), findsWidgets);
    expect(find.text('Map'), findsWidgets);
    expect(find.text('Favourites'), findsWidgets);
    expect(find.text('Mosudi Isiaka O., FHTW © 2026'), findsOneWidget);
  });
}
