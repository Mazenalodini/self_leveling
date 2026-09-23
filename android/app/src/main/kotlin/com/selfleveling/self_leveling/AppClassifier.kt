package com.selfleveling.self_leveling

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.os.Build

/**
 * App Classification Layer — categorizes packages into behavioral categories.
 *
 * Categories:
 *   0 = PRODUCTIVE   — contributes to goals (IDE, notes, books, learning)
 *   1 = NEUTRAL      — neither helps nor harms (calculator, weather, maps)
 *   2 = DISTRACTING  — known time-sinks (social media, games, streaming)
 *   3 = ESSENTIAL    — system-critical, NEVER blocked (launcher, keyboard, settings)
 *   4 = USER_DEFINED — user manually classified via app_list (overrides automatic)
 *
 * Design:
 *   - Essential apps are hard-coded and take absolute priority
 *   - User-defined overrides (blacklist/whitelist) take second priority
 *   - Automatic classification uses package-name pattern matching
 *   - Interface is ready for future TFLite classifier swap
 */
object AppClassifier {

    // Must stay aligned with RuntimeContract.AppCategory codes in the shared contract.
    const val PRODUCTIVE = 0
    const val NEUTRAL = 1
    const val DISTRACTING = 2
    const val ESSENTIAL = 3
    const val USER_DEFINED = 4

    // ═══════════════════════════════════════════════
    // Essential / System — NEVER BLOCKED, NEVER ESCALATED
    // ═══════════════════════════════════════════════

    private val essentialPackages = setOf(
        "com.android.launcher",
        "com.android.launcher2",
        "com.android.launcher3",
        "com.google.android.apps.nexuslauncher",
        "com.sec.android.app.launcher",          // Samsung
        "com.huawei.android.launcher",
        "com.miui.home",                         // Xiaomi
        "com.oppo.launcher",
        "com.realme.launcher.lite",
        "com.android.systemui",
        "com.android.settings",
        "com.android.phone",
        "com.android.dialer",
        "com.google.android.dialer",
        "com.android.contacts",
        "com.google.android.contacts",
        "com.android.mms",
        "com.google.android.apps.messaging",
        "com.android.camera",
        "com.android.camera2",
        "com.google.android.GoogleCamera",
        "com.android.packageinstaller",
        "com.google.android.packageinstaller",
        "com.android.permissioncontroller",
        "com.google.android.permissioncontroller",
        "com.android.emergency",
        "com.android.incallui",
        "com.android.server.telecom",
        "com.android.providers.settings",
        "com.android.stk",                       // SIM Toolkit
        "com.selfleveling.self_leveling",         // This app itself
    )

    /** Patterns for essential apps that may vary by OEM */
    private val essentialPatterns = listOf(
        "inputmethod", "keyboard", "ime",
        "launcher", "systemui",
        "permissioncontroller", "packageinstaller",
        "settings",  // OEM settings (Samsung, Xiaomi, Oppo, etc.)
    )

    // ═══════════════════════════════════════════════
    // Known Distracting Apps
    // ═══════════════════════════════════════════════

    private val distractingPackages = setOf(
        // ── Social Media ──
        "com.zhiliaoapp.musically",    // TikTok
        "com.ss.android.ugc.trill",    // TikTok (alt)
        "com.instagram.android",
        "com.instagram.barcelona",     // Threads
        "com.twitter.android",
        "com.twitter.android.lite",
        "com.facebook.katana",
        "com.facebook.lite",
        "com.facebook.orca",           // Messenger
        "com.snapchat.android",
        "com.pinterest",
        "com.reddit.frontpage",
        "com.tumblr",
        "com.linkedin.android",
        "com.discord",                 // Discord
        "com.bereal.ft",               // BeReal
        "com.vk.im",                   // VK Messenger
        "com.vkontakte.android",       // VK
        "com.clubhouse.app",           // Clubhouse
        "com.lemon8.app",              // Lemon8
        // ── Video / Streaming ──
        "com.google.android.youtube",
        "com.google.android.apps.youtube.music",
        "com.netflix.mediaclient",
        "com.amazon.avod.thirdpartyclient",  // Prime Video
        "tv.twitch.android.app",
        "com.disney.disneyplus",
        "com.hulu.livingroomplus",
        "com.shahid.vod",              // Shahid
        "com.spotify.music",           // Spotify (streaming)
        "com.anghami",                 // Anghami
        // ── Gaming (known popular) ──
        "com.supercell.clashofclans",
        "com.supercell.clashroyale",
        "com.supercell.brawlstars",
        "com.kiloo.subwaysurf",
        "com.king.candycrushsaga",
        "com.epicgames.fortnite",
        "com.activision.callofduty.shooter",
        "com.mojang.minecraftpe",
        "com.roblox.client",
        "com.pubg.krmobile",
        "com.tencent.ig",              // PUBG
        "com.garena.game.freefire",
        "com.ea.games.r3_row",
        "com.miHoYo.GenshinImpact",
        "com.dts.freefireth",
        // ── Dating ──
        "com.tinder",
        "com.bumble.app",
        // ── Short content / memes ──
        "com.kwai.video",
        "likee.real.video",
        "com.bigo.live",
    )

    /** Package name patterns that strongly indicate distracting apps */
    private val distractingPatterns = listOf(
        // Social media
        "tiktok", "instagram", "snapchat", "facebook",
        "twitter", "reddit", "tumblr", "pinterest",
        "discord", "bereal", "threads",
        // Streaming
        "youtube", "netflix", "twitch", "hulu", "disney",
        // Games — catch-all patterns
        "game", "games", "gaming", "puzzle", "casino", "slots",
        "arcade", "rpg", "moba", "battleroyal",
        // Dating
        "dating", "tinder", "bumble",
    )

    // ═══════════════════════════════════════════════
    // Game categories for dynamic detection (Android O+)
    // ═══════════════════════════════════════════════

    /**
     * Cache of packages confirmed as games via PackageManager.
     * Prevents repeated PM queries for the same package.
     */
    private val gamePackageCache = mutableMapOf<String, Boolean>()
    private var appContext: Context? = null

    /** Set the app context for dynamic game detection */
    fun setContext(ctx: Context) {
        appContext = ctx.applicationContext
    }

    /**
     * Check if a package is a game via Android's PackageManager category.
     * Works on Android O+ (API 26+). Returns false on older versions.
     */
    private fun isGamePackage(packageName: String): Boolean {
        // Check cache first
        gamePackageCache[packageName]?.let { return it }

        val ctx = appContext ?: return false
        val isGame = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val appInfo = ctx.packageManager.getApplicationInfo(packageName, 0)
                appInfo.category == ApplicationInfo.CATEGORY_GAME
            } else {
                false
            }
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }

        gamePackageCache[packageName] = isGame
        return isGame
    }

    // ═══════════════════════════════════════════════
    // Known Productive / Daily-Use Apps
    // ═══════════════════════════════════════════════

    private val productivePackages = setOf(
        // Notes / Writing
        "com.google.android.keep",
        "com.microsoft.office.onenote",
        "com.evernote",
        "org.wordpress.android",
        // Office / Docs
        "com.google.android.apps.docs",
        "com.google.android.apps.docs.editors.docs",
        "com.google.android.apps.docs.editors.sheets",
        "com.google.android.apps.docs.editors.slides",
        "com.microsoft.office.word",
        "com.microsoft.office.excel",
        "com.microsoft.office.powerpoint",
        "com.microsoft.teams",
        // Learning
        "com.duolingo",
        "com.coursera.app",
        "com.udemy.android",
        "com.khan.academy",
        "com.quizlet.quizletandroid",
        "com.anki",
        "com.ankidroid",
        // Reading
        "com.google.android.apps.books",
        "com.amazon.kindle",
        "com.audible.application",
        "com.medium.reader",
        // Productivity
        "com.google.android.calendar",
        "com.microsoft.outlook",
        "com.google.android.gm",         // Gmail
        "com.todoist",
        "com.ticktick.task",
        "com.notion.id",
        "com.trello",
        "com.asana.app",
        "com.slack",
        "com.github.android",
        // IDE / Dev
        "com.termux",
        "com.aide.ui",
        // ── Google AI / Search / Productivity ──
        "com.google.android.apps.bard",                 // Gemini
        "com.google.android.googlequicksearchbox",      // Google Search / Assistant
        "com.google.android.apps.maps",                 // Maps
        "com.google.android.apps.photos",               // Photos
        "com.google.android.apps.nbu.files",            // Files
        "com.google.android.apps.translate",            // Translate
        "com.google.android.apps.youtube.creator",      // YouTube Studio (creator tool)
        // ── Browsers (productive/research usage) ──
        "com.android.chrome",
        "com.chrome.beta",
        "com.chrome.dev",
        "org.mozilla.firefox",
        "org.mozilla.firefox_beta",
        "com.microsoft.emmx",              // Edge
        "com.opera.browser",
        "com.opera.mini.native",
        "com.sec.android.app.sbrowser",    // Samsung Internet
        "com.brave.browser",
        // ── Messaging (daily communication) ──
        "com.whatsapp",
        "com.whatsapp.w4b",               // WhatsApp Business
        "org.telegram.messenger",
        "org.thoughtcrime.securesms",      // Signal
        "com.viber.voip",
        "jp.naver.line.android",           // LINE
        "com.imo.android.imoim",           // IMO
    )

    private val productivePatterns = listOf(
        "office", "docs", "editor", "notes", "calendar",
        "learn", "study", "course", "academy", "education",
        "book", "read", "kindle", "bible", "quran",
        "task", "todo", "planner", "organizer",
        "code", "terminal", "ide", "dev",
    )

    // ═══════════════════════════════════════════════
    // Public API
    // ═══════════════════════════════════════════════

    /**
     * Classify a package, respecting: Essential > User-defined > Known > Pattern > Neutral
     *
     * @param packageName The Android package name
     * @param userOverrides Map of packageName -> category from app_list table
     * @return Category int (PRODUCTIVE, NEUTRAL, DISTRACTING, ESSENTIAL, USER_DEFINED)
     */
    fun classify(packageName: String, userOverrides: Map<String, Int>): Int {
        // Priority 1: Essential (absolute protection)
        if (isEssential(packageName)) return ESSENTIAL

        // Priority 2: User-defined override
        val userCategory = userOverrides[packageName]
        if (userCategory != null) return userCategory

        // Priority 3: Known packages
        if (distractingPackages.contains(packageName)) return DISTRACTING
        if (productivePackages.contains(packageName)) return PRODUCTIVE

        // Priority 4: Pattern matching
        val lower = packageName.lowercase()
        if (distractingPatterns.any { lower.contains(it) }) return DISTRACTING
        if (productivePatterns.any { lower.contains(it) }) return PRODUCTIVE

        // Priority 5: Dynamic game detection via Android PackageManager
        // This catches ALL games registered in Play Store regardless of package name
        if (isGamePackage(packageName)) return DISTRACTING

        // Default: neutral
        return NEUTRAL
    }

    /**
     * Check if a package is essential/system and must NEVER be blocked.
     */
    fun isEssential(packageName: String): Boolean {
        if (essentialPackages.contains(packageName)) return true
        val lower = packageName.lowercase()
        return essentialPatterns.any { lower.contains(it) }
    }

    /**
     * Build user-override map from SQLite app_list table.
     * category_override entries take priority, otherwise:
     * blacklist entries → DISTRACTING, whitelist entries → PRODUCTIVE
     */
    fun loadUserOverrides(db: SQLiteDatabase): Map<String, Int> {
        val overrides = mutableMapOf<String, Int>()
        try {
            val cursor = db.rawQuery(
                "SELECT package_name, list_type, category_override FROM app_list WHERE is_enabled = 1 AND package_name != ''",
                null
            )
            while (cursor.moveToNext()) {
                val pkg = cursor.getString(0)
                val listType = cursor.getString(1)
                val categoryOverride =
                    if (cursor.isNull(2)) null else cursor.getInt(2)
                when {
                    categoryOverride != null && categoryOverride in PRODUCTIVE..USER_DEFINED ->
                        overrides[pkg] = categoryOverride
                    listType == "blacklist" -> overrides[pkg] = DISTRACTING
                    listType == "whitelist" -> overrides[pkg] = PRODUCTIVE
                }
            }
            cursor.close()
        } catch (_: Exception) {}
        return overrides
    }

    /**
     * Human-readable category name (for intervention messages).
     */
    fun categoryName(category: Int): String = when (category) {
        PRODUCTIVE  -> "Productive"
        NEUTRAL     -> "Neutral"
        DISTRACTING -> "Distracting"
        ESSENTIAL   -> "System"
        USER_DEFINED -> "User-Defined"
        else -> "Unknown"
    }
}
