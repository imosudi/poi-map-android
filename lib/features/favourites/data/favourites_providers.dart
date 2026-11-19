import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/repositories/favourites_repository.dart';
import 'datasources/favourites_local_storage.dart';
import 'repositories/local_favourites_repository.dart';

final favouritesStorageProvider = Provider<FavouritesLocalStorage>((ref) {
  return FavouritesLocalStorage(logger: ref.watch(appLoggerProvider));
});

final favouritesRepositoryProvider = Provider<FavouritesRepository>((ref) {
  return LocalFavouritesRepository(ref.watch(favouritesStorageProvider));
});
