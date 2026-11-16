import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/app.dart';
import 'package:poi_map_android/application/providers/catalogue_provider.dart';
import 'package:poi_map_android/domain/entities/point_of_interest.dart';
import 'package:poi_map_android/domain/repositories/poi_repository.dart';

class _EmptyPoiRepository implements PoiRepository {
  @override
  Future<List<PointOfInterest>> fetchPointsOfInterest() async => const [];
}

void main() {
  testWidgets('HomeShell renders Explore, Map and Favourites tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          poiRepositoryProvider.overrideWithValue(_EmptyPoiRepository()),
        ],
        child: const ViennaPoiExplorerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explore'), findsWidgets);
    expect(find.text('Map'), findsWidgets);
    expect(find.text('Favourites'), findsWidgets);
    expect(find.text('Saved places'), findsOneWidget);
    expect(find.text('Mosudi Isiaka O., FHTW © 2026'), findsOneWidget);
  });
}
