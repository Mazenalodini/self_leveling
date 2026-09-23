import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/glow_button.dart';
import '../../../widgets/input_field.dart';
import '../../../services/gamification_service.dart';

/// Identity Builder Screen — "من تريد أن تكون؟"
/// Users select 2-3 identities that define their self-leveling journey.
class IdentityBuilderScreen extends StatefulWidget {
  const IdentityBuilderScreen({super.key});

  @override
  State<IdentityBuilderScreen> createState() => _IdentityBuilderScreenState();
}

class _IdentityBuilderScreenState extends State<IdentityBuilderScreen>
    with TickerProviderStateMixin {
  final Set<int> _selected = {};
  late AnimationController _pulseController;

  final GamificationService _gamificationService = GamificationService();
  List<_IdentityOption> _identities = [];

  // Static templates
  static List<_IdentityOption> get _baseIdentities => [
    _IdentityOption(
      id: 'base_0',
      title: AppStrings.baseIdReaderName,
      subtitle: AppStrings.baseIdReaderSub,
      iconCode: 0xe0ef, // Icons.auto_stories_rounded.codePoint
      colorHex: 0xFF8B5CF6,
      skills: AppStrings.baseIdReaderSkills,
    ),
    _IdentityOption(
      id: 'base_1',
      title: AppStrings.baseIdAthleteName,
      subtitle: AppStrings.baseIdAthleteSub,
      iconCode: 0xebfa, // Icons.fitness_center_rounded
      colorHex: 0xFFF97316,
      skills: AppStrings.baseIdAthleteSkills,
    ),
    _IdentityOption(
      id: 'base_2',
      title: AppStrings.baseIdDeveloperName,
      subtitle: AppStrings.baseIdDeveloperSub,
      iconCode: 0xe176, // Icons.code_rounded
      colorHex: 0xFF06B6D4,
      skills: AppStrings.baseIdDeveloperSkills,
    ),
    _IdentityOption(
      id: 'base_3',
      title: AppStrings.baseIdDisciplinedName,
      subtitle: AppStrings.baseIdDisciplinedSub,
      iconCode: 0xe58b, // Icons.shield_rounded
      colorHex: 0xFF22C55E,
      skills: AppStrings.baseIdDisciplinedSkills,
    ),
    _IdentityOption(
      id: 'base_4',
      title: AppStrings.baseIdSpiritualName,
      subtitle: AppStrings.baseIdSpiritualSub,
      iconCode: 0xe25b, // Icons.favorite_rounded
      colorHex: 0xFFEC4899,
      skills: AppStrings.baseIdSpiritualSkills,
    ),
    _IdentityOption(
      id: 'base_5',
      title: AppStrings.baseIdCreatorName,
      subtitle: AppStrings.baseIdCreatorSub,
      iconCode: 0xe104, // Icons.brush_rounded
      colorHex: 0xFFEAB308,
      skills: AppStrings.baseIdCreatorSkills,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadCustomIdentities();
  }

  Future<void> _loadCustomIdentities() async {
    final customDB = <_IdentityOption>[];
    // Normally, GamificationService.getIdentities() gets only selected. We map custom ones
    // But since IdentityBuilder is meant to define globals, when saving we clear and write.
    // So we will just show _baseIdentities + whatever is already in DB as selected.
    final rows = await _gamificationService.getIdentities();
    
    if (rows.isNotEmpty) {
      customDB.addAll(rows.map((r) => _IdentityOption(
        id: r['id'] as String,
        title: r['title'] as String,
        subtitle: r['subtitle'] as String,
        iconCode: r['icon_code'] as int? ?? 0xe532, 
        colorHex: r['color_hex'] as int? ?? 0xFF06B6D4,
        skills: [], // DB skills are attached directly in SkillService
      )));
    }
    
    // Merge without duplicates by title
    final combined = List<_IdentityOption>.from(_baseIdentities);
    for (var custom in customDB) {
      if (!combined.any((base) => base.title == custom.title)) {
        combined.add(custom);
      }
    }

    if (mounted) {
      setState(() {
        _identities = combined;
        // Pre-select the ones that were in the DB
        for (int i = 0; i < _identities.length; i++) {
          if (customDB.any((c) => c.title == _identities[i].title)) {
            _selected.add(i);
          }
        }
      });
    }
  }

  Future<void> _showAddIdentityDialog() async {
    final titleCtrl = TextEditingController();
    final subtitleCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(AppStrings.addCustomIdentity, style: AppTextStyles.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InputField(controller: titleCtrl, label: AppStrings.identityName, prefixIcon: Icons.badge),
            const SizedBox(height: 12),
            InputField(controller: subtitleCtrl, label: AppStrings.subtitle, prefixIcon: Icons.subtitles),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.cancel, style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            onPressed: () async {
              if (titleCtrl.text.isEmpty) return;
              await _gamificationService.addCustomIdentity(
                titleCtrl.text.trim(), 
                subtitleCtrl.text.trim(), 
                Icons.star.codePoint, 
                AppColors.primaryCyan.value
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadCustomIdentities();
            },
            child: Text(AppStrings.addCustomIdentity),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool get _canProceed => _selected.length >= 2 && _selected.length <= 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SystemBackground(
        child: Column(
          children: [
            // Header
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppStrings.identityBuilder,
                                style: AppTextStyles.h2),
                            Row(children: [
                              Container(width: 32, height: 1,
                                  color: AppColors.primaryBlue),
                              const SizedBox(width: 8),
                              const Icon(Icons.person_outline,
                                  color: AppColors.primaryBlue, size: 12),
                            ]),
                          ],
                        ),
                      ],
                    ).animate().fadeIn().slideY(begin: -0.2),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.whoDoYouWantToBe,
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.primaryCyan,
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.selectIdentitiesHint,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ).animate().fadeIn(delay: 300.ms),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Identity Map Visualization (when items selected)
            if (_selected.isNotEmpty)
              _IdentityMap(
                selectedIdentities: _selected
                    .map((i) => _identities[i])
                    .toList(),
                pulseController: _pulseController,
              ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),

            if (_selected.isNotEmpty) const SizedBox(height: 12),

            // Selection counter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(
                    _canProceed ? Icons.check_circle : Icons.info_outline,
                    color: _canProceed
                        ? AppColors.success
                        : AppColors.primaryBlue,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.selectedCount(_selected.length, 3),
                    style: AppTextStyles.caption.copyWith(
                      color: _canProceed
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Identity Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemCount: _identities.length,
                itemBuilder: (context, index) {
                  final identity = _identities[index];
                  final isSelected = _selected.contains(index);
                  return _IdentityCard(
                    identity: identity,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selected.remove(index);
                        } else if (_selected.length < 3) {
                          _selected.add(index);
                        }
                      });
                    },
                  ).animate(delay: Duration(milliseconds: 200 + index * 80))
                      .fadeIn()
                      .scale(begin: const Offset(0.9, 0.9));
                },
              ),
            ),

            // Confirm button
            Container(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.background,
                    AppColors.background.withOpacity(0),
                  ],
                ),
              ),
              child: GlowButton(
                text: AppStrings.confirmIdentity,
                icon: Icons.arrow_forward_rounded,
                enabled: _canProceed,
                onPressed: _canProceed
                    ? () async {
                        final selectedItems = _selected.map((index) => {
                          'id': _identities[index].id,
                          'title': _identities[index].title,
                          'subtitle': _identities[index].subtitle,
                          'icon_code': _identities[index].iconCode,
                          'color_hex': _identities[index].colorHex,
                          'skills': _identities[index].skills,
                        }).toList();
                        await _gamificationService.saveIdentities(selectedItems);
                        if (!context.mounted) return;
                        context.pop();
                      }
                    : null,
              ),
            ).animate().fadeIn(delay: 800.ms),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddIdentityDialog,
        backgroundColor: AppColors.primaryCyan,
        icon: const Icon(Icons.add),
        label: Text(AppStrings.customIdentity, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
      ),
    );
  }
}

// ─── Identity Map Visualization ───
class _IdentityMap extends StatelessWidget {
  final List<_IdentityOption> selectedIdentities;
  final AnimationController pulseController;

  const _IdentityMap({
    required this.selectedIdentities,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < selectedIdentities.length; i++) ...[
              if (i > 0)
                Container(
                  width: 32,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Color(selectedIdentities[i - 1].colorHex).withOpacity(0.5),
                      Color(selectedIdentities[i].colorHex).withOpacity(0.5),
                    ]),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              AnimatedBuilder(
                animation: pulseController,
                builder: (_, __) {
                  final pulse = 1.0 + pulseController.value * 0.15;
                  return Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(selectedIdentities[i].colorHex).withOpacity(0.12),
                      border: Border.all(
                        color: Color(selectedIdentities[i].colorHex).withOpacity(0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(selectedIdentities[i].colorHex).withOpacity(0.3 * pulse.clamp(0.0, 1.0)),
                          blurRadius: 20 * pulse,
                          spreadRadius: 2 * pulse,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(IconData(selectedIdentities[i].iconCode, fontFamily: 'MaterialIcons'),
                            color: Color(selectedIdentities[i].colorHex), size: 24),
                        const SizedBox(height: 2),
                        Text(
                          selectedIdentities[i].title,
                          style: AppTextStyles.caption.copyWith(
                            color: Color(selectedIdentities[i].colorHex),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Identity Card Widget ───
class _IdentityCard extends StatelessWidget {
  final _IdentityOption identity;
  final bool isSelected;
  final VoidCallback onTap;

  const _IdentityCard({
    required this.identity,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected
              ? Color(identity.colorHex).withOpacity(0.08)
              : AppColors.cardBackground.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Color(identity.colorHex).withOpacity(0.6)
                : AppColors.primaryBlue.withOpacity(0.15),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Color(identity.colorHex).withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(identity.colorHex).withOpacity(isSelected ? 0.2 : 0.08),
                border: Border.all(
                  color: Color(identity.colorHex).withOpacity(isSelected ? 0.5 : 0.2),
                ),
              ),
              child: Icon(
                IconData(identity.iconCode, fontFamily: 'MaterialIcons'),
                color: isSelected ? Color(identity.colorHex) : AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              identity.title,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),

            // Subtitle (Arabic)
            Text(
              identity.subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: isSelected
                    ? Color(identity.colorHex).withOpacity(0.8)
                    : AppColors.textTertiary,
                fontSize: 11,
              ),
            ),

            // Selected indicator + skill count
            if (isSelected) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Color(identity.colorHex), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    AppStrings.selectedLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: Color(identity.colorHex),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Data Class ───
class _IdentityOption {
  final String id;
  final String title;
  final String subtitle;
  final int iconCode;
  final int colorHex;
  final List<String> skills;

  const _IdentityOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconCode,
    required this.colorHex,
    required this.skills,
  });
}
