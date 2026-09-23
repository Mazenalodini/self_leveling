import 'package:flutter_test/flutter_test.dart';
import 'package:installed_apps/app_info.dart';
import 'package:self_leveling/features/stats/services/app_info_cache_service.dart';

void main() {
  test('app info cache warms catalog once and avoids duplicate lookups',
      () async {
    var catalogReads = 0;
    var perPackageReads = 0;

    final service = AppInfoCacheService(
      catalogLoader: () async {
        catalogReads++;
        return [
          _appInfo(packageName: 'com.catalog.app', name: 'Catalog'),
        ];
      },
      appInfoLoader: (packageName) async {
        perPackageReads++;
        return _appInfo(packageName: packageName, name: 'Loaded');
      },
    );

    await service.warmCatalog();
    await service.warmCatalog();
    await service.prefetchPackages([
      'com.catalog.app',
      'com.loaded.app',
      'com.loaded.app',
    ]);

    expect(catalogReads, 1);
    expect(perPackageReads, 1);
    expect(service.infoFor('com.catalog.app')?.name, 'Catalog');
    expect(service.infoFor('com.loaded.app')?.name, 'Loaded');
  });

  test(
      'app info cache remembers missing packages and keeps fallback path cheap',
      () async {
    var misses = 0;
    final service = AppInfoCacheService(
      catalogLoader: () async => const [],
      appInfoLoader: (packageName) async {
        misses++;
        return null;
      },
    );

    await service.prefetchPackages(['com.missing.app']);
    await service.prefetchPackages(['com.missing.app']);

    expect(misses, 1);
    expect(service.infoFor('com.missing.app'), isNull);
  });
}

AppInfo _appInfo({
  required String packageName,
  required String name,
}) {
  return AppInfo(
    packageName: packageName,
    name: name,
    icon: null,
    versionName: '1.0.0',
    versionCode: 1,
    builtWith: BuiltWith.native_or_others,
    installedTimestamp: 0,
  );
}
