import '../../domain/entities/poi.dart';

/// Custom local test POIs modeled after the Vienna OGD schema for field
/// verification at reachable Vienna locations.
abstract final class CustomTestPois {
  static final List<Poi> entries = List<Poi>.unmodifiable([
    const Poi(
      id: 'CUSTOM_TEST.ROETZERGASSE_73',
      name: 'Rötzergasse 73 (Test Residence)',
      category: 'Landmark',
      address: 'Rötzergasse 73, 1170 Wien',
      latitude: 48.2205,
      longitude: 16.3280,
    ),
    Poi(
      id: 'CUSTOM_TEST.FHTW_WIEN',
      name: 'FHTW — University of Applied Sciences Technikum Wien',
      category: 'Landmark',
      address: 'Höchstädtplatz 6, 1200 Wien',
      latitude: 48.23916,
      longitude: 16.37744,
      infoUrl: Uri.parse('https://www.technikum-wien.at'),
    ),
  ]);
}
