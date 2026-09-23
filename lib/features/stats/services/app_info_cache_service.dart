import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

class AppInfoCacheService extends ChangeNotifier {
  final Future<List<AppInfo>> Function() _catalogLoader;
  final Future<AppInfo?> Function(String packageName) _appInfoLoader;

  final Map<String, AppInfo?> _cache = <String, AppInfo?>{};
  final Set<String> _missingPackages = <String>{};
  final Set<String> _pendingPackages = <String>{};

  Future<void>? _catalogFuture;
  bool _catalogAttempted = false;

  AppInfoCacheService({
    Future<List<AppInfo>> Function()? catalogLoader,
    Future<AppInfo?> Function(String packageName)? appInfoLoader,
  })  : _catalogLoader = catalogLoader ??
            (() => InstalledApps.getInstalledApps(false, true, '')),
        _appInfoLoader = appInfoLoader ??
            ((packageName) => InstalledApps.getAppInfo(packageName, null));

  AppInfo? infoFor(String packageName) => _cache[packageName];

  Future<void> warmCatalog() {
    if (_catalogFuture != null) return _catalogFuture!;
    if (_catalogAttempted) return Future.value();

    _catalogAttempted = true;
    _catalogFuture = _catalogLoader()
        .then((apps) {
          var changed = false;
          for (final app in apps) {
            if (!_cache.containsKey(app.packageName)) {
              _cache[app.packageName] = app;
              changed = true;
            }
          }
          if (changed) {
            notifyListeners();
          }
        })
        .catchError((_) {})
        .whenComplete(() {
          _catalogFuture = null;
        });

    return _catalogFuture!;
  }

  Future<void> prefetchPackages(Iterable<String> packages) async {
    await warmCatalog();

    final queue = packages
        .toSet()
        .where((packageName) => packageName.trim().isNotEmpty)
        .where(
          (packageName) =>
              !_cache.containsKey(packageName) &&
              !_missingPackages.contains(packageName) &&
              !_pendingPackages.contains(packageName),
        )
        .take(24)
        .toList();

    if (queue.isEmpty) return;

    _pendingPackages.addAll(queue);
    var changed = false;

    for (final packageName in queue) {
      try {
        final info = await _appInfoLoader(packageName);
        if (info != null) {
          _cache[packageName] = info;
          changed = true;
        } else {
          _missingPackages.add(packageName);
        }
      } catch (_) {
        _missingPackages.add(packageName);
      } finally {
        _pendingPackages.remove(packageName);
      }
    }

    if (changed) {
      notifyListeners();
    }
  }
}

final appInfoCacheProvider = ChangeNotifierProvider<AppInfoCacheService>((ref) {
  final service = AppInfoCacheService();
  ref.onDispose(service.dispose);
  return service;
});
