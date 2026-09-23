import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/app_picker_dialog.dart';
import '../../../services/app_list_service.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';

/// App Blacklist/Whitelist — wired to SQLite.
class AppBlacklistScreen extends StatefulWidget {
  const AppBlacklistScreen({super.key});

  @override
  State<AppBlacklistScreen> createState() => _AppBlacklistScreenState();
}

class _AppBlacklistScreenState extends State<AppBlacklistScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = AppListService();

  List<Map<String, dynamic>> _blacklist = [];
  List<Map<String, dynamic>> _whitelist = [];
  Map<String, AppInfo> _appInfoMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final bl = await _service.getByType('blacklist');
    final wl = await _service.getByType('whitelist');
    
    if (_appInfoMap.isEmpty) {
      try {
        final apps = await InstalledApps.getInstalledApps(true, true, '');
        _appInfoMap = { for (var a in apps) a.packageName: a };
      } catch (e) {
        // Ignore error if it fails to load apps
      }
    }

    if (mounted) {
      setState(() {
        _blacklist = bl;
        _whitelist = wl;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddDialog(String listType) async {
    // Step 1: Pick an app from installed apps
    final selectedApp = await showAppPicker(
      context,
      title: listType == 'blacklist' ? AppStrings.addToBlacklist : AppStrings.addToWhitelist,
    );
    if (selectedApp == null || !mounted) return;

    // Step 2: Ask for a tag
    final tagController = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AppColors.primaryBlue.withOpacity(0.1),
            ),
            child: selectedApp.icon != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(selectedApp.icon!, fit: BoxFit.cover),
                  )
                : const Icon(Icons.apps, color: AppColors.primaryBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(selectedApp.name, style: AppTextStyles.h4)),
        ]),
        content: TextField(
          controller: tagController,
          style: AppTextStyles.bodySmall,
          decoration: InputDecoration(
            hintText: AppStrings.tagHint,
            hintStyle: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.cardBackground.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryBlue.withOpacity(0.2)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.cancel, style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, tagController.text.trim()),
            child: Text(AppStrings.addBtn, style: const TextStyle(color: AppColors.primaryBlue)),
          ),
        ],
      ),
    );
    if (tag == null || !mounted) return;

    await _service.addApp(
      name: selectedApp.name,
      packageName: selectedApp.packageName,
      listType: listType,
      tag: tag,
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SystemBackground(
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  children: [
                    Row(children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.cardBackground.withOpacity(0.5),
                          ),
                          child: const Icon(Icons.arrow_back,
                              color: AppColors.primaryBlue, size: 24),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppStrings.appManagement, style: AppTextStyles.h2),
                            Row(children: [
                              Container(width: 32, height: 1,
                                  color: AppColors.primaryBlue),
                              const SizedBox(width: 8),
                              const Icon(Icons.apps,
                                  color: AppColors.primaryBlue, size: 12),
                            ]),
                          ],
                        ),
                      ),
                    ]).animate().fadeIn().slideY(begin: -0.2),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryCyan.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.primaryCyan.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome,
                              color: AppColors.primaryCyan, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            AppStrings.aiWillAnalyzeApp,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryCyan,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 16),

                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.primaryBlue.withOpacity(0.15)),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.primaryBlue.withOpacity(0.4)),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelStyle: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        labelColor: AppColors.primaryBlue,
                        unselectedLabelColor: AppColors.textTertiary,
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.block, size: 16),
                                const SizedBox(width: 6),
                                Text('${AppStrings.blacklist} (${_blacklist.length})'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline, size: 16),
                                const SizedBox(width: 6),
                                Text('${AppStrings.whitelist} (${_whitelist.length})'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 300.ms),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAppList(_blacklist, isBlacklist: true),
                        _buildAppList(_whitelist, isBlacklist: false),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppList(List<Map<String, dynamic>> apps, {required bool isBlacklist}) {
    final listType = isBlacklist ? 'blacklist' : 'whitelist';
    final accentColor = isBlacklist ? AppColors.danger : AppColors.success;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
      itemCount: apps.length + 1,
      itemBuilder: (context, index) {
        if (index == apps.length) {
          return GestureDetector(
            onTap: () => _showAddDialog(listType),
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryBlue.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline,
                      color: AppColors.primaryBlue.withOpacity(0.5), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    isBlacklist ? AppStrings.addAppToBlacklist : AppStrings.addAppToWhitelist,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primaryBlue.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: Duration(milliseconds: 300 + apps.length * 60));
        }

        final app = apps[index];
        final name = app['name'] as String;
        final tag = app['tag'] as String? ?? '';
        final packageName = app['package_name'] as String? ?? '';
        final enabled = (app['is_enabled'] as int?) == 1;
        final id = app['id'] as int;
        final appInfo = _appInfoMap[packageName];

        return Dismissible(
          key: Key('app_$id'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete, color: AppColors.danger),
          ),
          onDismissed: (_) async {
            await _service.deleteApp(id);
            _loadData();
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: appInfo?.icon != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(appInfo!.icon!, fit: BoxFit.cover),
                        )
                      : Icon(
                          isBlacklist ? Icons.block : Icons.check_circle,
                          color: accentColor, size: 22,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
                      if (tag.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(tag, style: AppTextStyles.caption.copyWith(
                          color: accentColor.withOpacity(0.7),
                          fontSize: 10,
                        )),
                      ],
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: (v) async {
                    await _service.toggleApp(id, v);
                    _loadData();
                  },
                  activeColor: accentColor,
                  activeTrackColor: accentColor.withOpacity(0.3),
                  inactiveThumbColor: AppColors.textTertiary,
                  inactiveTrackColor: AppColors.cardBackground,
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: 300 + index * 60));
      },
    );
  }
}
