import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_strings.dart';

/// Helper widget to pick an installed app from the device.
class AppPickerDialog extends StatefulWidget {
  final String? title;
  const AppPickerDialog({super.key, this.title});

  @override
  State<AppPickerDialog> createState() => _AppPickerDialogState();
}

class _AppPickerDialogState extends State<AppPickerDialog> {
  List<AppInfo> _allApps = [];
  List<AppInfo> _filteredApps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      // Get non-system (user-installed) apps only
      final apps = await InstalledApps.getInstalledApps(true, true, '');
      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (mounted) {
        setState(() {
          _allApps = apps;
          _filteredApps = apps;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterApps(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredApps = _allApps;
      } else {
        _filteredApps = _allApps
            .where((app) =>
                app.name.toLowerCase().contains(query.toLowerCase()) ||
                app.packageName.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(widget.title ?? AppStrings.selectApp, style: AppTextStyles.h3),
            const SizedBox(height: 12),

            // Search bar
            TextField(
              onChanged: _filterApps,
              style: AppTextStyles.bodySmall,
              decoration: InputDecoration(
                hintText: 'Search apps...',
                hintStyle: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary, size: 20),
                filled: true,
                fillColor: AppColors.cardBackground.withOpacity(0.5),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.primaryBlue.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.primaryBlue.withOpacity(0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primaryBlue),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Results count
            Text(
              _isLoading ? 'Loading...' : '${_filteredApps.length} apps',
              style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
            ),
            const SizedBox(height: 8),

            // App list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
                  : _filteredApps.isEmpty
                      ? Center(child: Text(AppStrings.noAppsFound, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)))
                      : ListView.builder(
                          itemCount: _filteredApps.length,
                          itemBuilder: (context, index) {
                            final app = _filteredApps[index];
                            return _AppTile(
                              app: app,
                              onTap: () => Navigator.pop(context, app),
                            );
                          },
                        ),
            ),

            // Cancel button
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppStrings.cancel, style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  final AppInfo app;
  final VoidCallback onTap;
  const _AppTile({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.cardBackground.withOpacity(0.3),
        ),
        child: Row(
          children: [
            // App icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.primaryBlue.withOpacity(0.08),
              ),
              child: app.icon != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(app.icon!, fit: BoxFit.cover),
                    )
                  : const Icon(Icons.apps, color: AppColors.primaryBlue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.name,
                    style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    app.packageName,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Show the app picker dialog and return the selected app.
Future<AppInfo?> showAppPicker(BuildContext context, {String title = 'Select App'}) {
  return showDialog<AppInfo>(
    context: context,
    builder: (_) => AppPickerDialog(title: title),
  );
}
