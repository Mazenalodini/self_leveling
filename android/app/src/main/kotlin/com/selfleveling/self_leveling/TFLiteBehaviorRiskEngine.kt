package com.selfleveling.self_leveling

import android.content.Context
import android.util.Log
import org.json.JSONObject
import org.tensorflow.lite.Interpreter
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.abs

class TFLiteBehaviorRiskEngine(
    context: Context?,
    private val fallbackEngine: BehaviorRiskEngine = RuleBasedBehaviorRiskEngine(),
) : BehaviorRiskEngine {

    internal data class ModelConfig(
        val inputFeatureOrder: List<String>,
        val categoryMapping: Map<String, Int>,
        val threshold: Double,
        val version: String,
    )

    internal data class NormalizationStats(
        val mean: Map<String, Double>,
        val std: Map<String, Double>,
    )

    internal data class SupplementalFeatures(
        val launchCountToday: Int,
        val sessionIndexToday: Int,
        val totalAppUsageTodayMinutes: Double?,
        val dailyLimitMinutes: Double,
        val isWhitelisted: Boolean,
    )

    data class TFLiteScore(
        val score: Double,
        val riskClass: BehaviorRiskClass,
        val modelVersion: String,
        val threshold: Double,
        val inputVectorSize: Int,
    )

    private data class LoadedRuntime(
        val interpreter: Interpreter,
        val config: ModelConfig,
        val normalizationStats: NormalizationStats,
    )

    private data class SupplementalCache(
        val packageName: String,
        val dateKey: String,
        val loadedAt: Long,
        val features: SupplementalFeatures,
    )

    companion object {
        private const val TAG = "TFLiteRiskEngine"
        private const val MODEL_ASSET = "behavior_model_quantized.tflite"
        private const val CONFIG_ASSET = "model_config.json"
        private const val NORMALIZATION_ASSET = "normalization_stats.json"
        private const val DB_CACHE_TTL_MS = 15_000L

        internal fun mapStage(stage: Int): Int = stage.coerceIn(0, 5)

        internal fun mapDayOfWeek(dayOfWeek: Int): Int = when {
            dayOfWeek in 1..7 -> dayOfWeek - 1
            dayOfWeek in 0..6 -> dayOfWeek
            else -> 0
        }

        internal fun resolveModelCategoryKey(input: BehaviorAssessmentInput): String {
            val packageName = input.facts.packageName.lowercase(Locale.US)
            return when {
                input.facts.appCategoryCode == AppClassifier.ESSENTIAL -> "system"
                containsAny(packageName, "tiktok", "musically", "trill", "youtube", "reels", "shorts", "kwai", "likee") -> "short_video"
                containsAny(packageName, "instagram", "facebook", "twitter", "reddit", "linkedin", "pinterest", "snapchat", "discord", "threads", "tumblr", "social") -> "social"
                containsAny(packageName, "netflix", "twitch", "spotify", "primevideo", "disney", "hulu", "shahid", "stream") -> "streaming"
                containsAny(packageName, "whatsapp", "telegram", "signal", "messenger", "viber", "line", "imo", "messaging") -> "messaging"
                containsAny(packageName, "chrome", "firefox", "browser", "edge", "opera", "brave", "sbrowser") -> "browser"
                containsAny(packageName, "duolingo", "coursera", "udemy", "khan", "quizlet", "education", "academy", "learn", "study") -> "education"
                containsAny(packageName, "reader", "reading", "kindle", "books", "medium", "quran", "bible") -> "reading"
                containsAny(packageName, "health", "fit", "fitness", "calm", "medit", "sleep") -> "health"
                containsAny(packageName, "game", "games", "gaming", "roblox", "minecraft", "pubg", "fortnite", "clash", "genshin", "freefire", "puzzle", "casino", "slots") -> "games"
                input.facts.appCategoryCode == AppClassifier.PRODUCTIVE -> "productivity"
                input.facts.appCategoryCode == AppClassifier.DISTRACTING -> "social"
                else -> "unknown"
            }
        }

        internal fun buildFeatureMap(
            input: BehaviorAssessmentInput,
            supplemental: SupplementalFeatures,
            categoryMapping: Map<String, Int>,
        ): Map<String, Double> {
            val defaultLaunchCount = if (input.facts.sessionSeconds > 0L) 1 else 0
            val launchCountToday = supplemental.launchCountToday.coerceAtLeast(defaultLaunchCount)
            val sessionIndexToday = supplemental.sessionIndexToday.coerceAtLeast(launchCountToday)
            val totalAppUsageTodayMinutes = (
                supplemental.totalAppUsageTodayMinutes ?: input.features.sessionMinutes
            ).coerceAtLeast(0.0)
            val dailyLimitMinutes = supplemental.dailyLimitMinutes.coerceAtLeast(0.0)
            val dailyLimitExceeded = dailyLimitMinutes > 0.0 &&
                totalAppUsageTodayMinutes > dailyLimitMinutes
            val categoryKey = resolveModelCategoryKey(input)
            val categoryValue = categoryMapping[categoryKey] ?:
                categoryMapping["unknown"] ?:
                0

            return mapOf(
                "duration_minutes" to input.features.sessionMinutes.coerceAtLeast(0.0),
                "launch_count_today" to launchCountToday.toDouble(),
                "session_index_today" to sessionIndexToday.toDouble(),
                "total_app_usage_today_minutes" to totalAppUsageTodayMinutes,
                "total_distracting_today_minutes" to
                    (input.facts.dailyDistractingSeconds / 60.0).coerceAtLeast(0.0),
                "daily_limit_minutes" to dailyLimitMinutes,
                "ignored_warning_count" to input.facts.ignoredWarnings.coerceAtLeast(0).toDouble(),
                "reentry_count" to input.facts.reentryCount.coerceAtLeast(0).toDouble(),
                "hour_of_day" to input.facts.hourOfDay.coerceIn(0, 23).toDouble(),
                "day_of_week" to mapDayOfWeek(input.facts.dayOfWeek).toDouble(),
                "user_sensitivity" to input.facts.sensitivity.coerceIn(0.0, 1.0),
                "escalation_strength" to input.facts.strength.coerceIn(0.0, 1.0),
                "is_focus_mode" to if (input.facts.isFocusModeActive) 1.0 else 0.0,
                "is_blacklisted" to if (input.facts.isBlacklisted) 1.0 else 0.0,
                "is_whitelisted" to if (supplemental.isWhitelisted) 1.0 else 0.0,
                "daily_limit_exceeded" to if (dailyLimitExceeded) 1.0 else 0.0,
                "returned_after_block" to if (input.facts.postLockReturnCount > 0) 1.0 else 0.0,
                "current_escalation_stage" to mapStage(input.facts.currentStage).toDouble(),
                "app_category_enc" to categoryValue.toDouble(),
            )
        }

        internal fun buildInputVector(
            featureOrder: List<String>,
            normalizationStats: NormalizationStats,
            featureValues: Map<String, Double>,
        ): FloatArray {
            val means = normalizationStats.mean
            val stds = normalizationStats.std
            return FloatArray(featureOrder.size) { index ->
                val featureName = featureOrder[index]
                val rawValue = featureValues[featureName] ?: 0.0
                val normalized = if (means.containsKey(featureName)) {
                    val mean = means[featureName] ?: 0.0
                    val std = stds[featureName]?.takeIf { it > 0.0 } ?: 1.0
                    (rawValue - mean) / std
                } else {
                    rawValue
                }
                normalized.toFloat()
            }
        }

        private fun containsAny(value: String, vararg candidates: String): Boolean =
            candidates.any { value.contains(it) }
    }

    private val appContext = context?.applicationContext
    private val runtimeLock = Any()

    @Volatile
    private var loadedRuntime: LoadedRuntime? = null

    @Volatile
    private var supplementalCache: SupplementalCache? = null

    @Volatile
    var modelLoaded: Boolean = false
        private set

    @Volatile
    var modelVersion: String? = null
        private set

    @Volatile
    var lastTfliteScore: Double? = null
        private set

    @Volatile
    var lastModelError: String? = null
        private set

    override fun assess(
        input: BehaviorAssessmentInput,
        createdAt: Long,
    ): BehaviorAssessment {
        val tfliteScore = inferRiskScoreOrNull(input, createdAt)
        if (tfliteScore == null) {
            return fallbackEngine.assess(input, createdAt)
        }

        val appRiskTier = BehaviorRiskAssessor.getAppRiskTier(
            packageName = input.facts.packageName,
            appCategory = input.facts.appCategoryCode,
        )
        val scoreText = formatScore(tfliteScore.score)
        val thresholdText = formatScore(tfliteScore.threshold)
        val reasoning = buildString {
            append("model_source=tflite")
            append(" score=")
            append(scoreText)
            append(" threshold=")
            append(thresholdText)
            append(" vector_size=")
            append(tfliteScore.inputVectorSize)
            append(" model_version=")
            append(tfliteScore.modelVersion)
        }

        return BehaviorAssessment(
            createdAt = createdAt,
            source = BehaviorAssessmentSource.FUTURE_MODEL,
            assessorKind = "tflite",
            assessorVersion = tfliteScore.modelVersion,
            targetPackageName = input.facts.packageName,
            targetAppName = input.facts.appName,
            facts = input.facts,
            features = input.features,
            inference = BehaviorRiskInference(
                riskScore = tfliteScore.score,
                riskClass = tfliteScore.riskClass,
                appRiskTier = appRiskTier,
                confidence = abs(tfliteScore.score - tfliteScore.threshold),
                sessionFactor = 0.0,
                behavioralFactor = 0.0,
                reasoning = reasoning,
                predictedDistractionLikelihood = tfliteScore.score,
            ),
        )
    }

    internal fun inferRiskScoreOrNull(
        input: BehaviorAssessmentInput,
        createdAt: Long,
    ): TFLiteScore? {
        return try {
            val runtime = ensureRuntime() ?: return null
            val supplementalFeatures = loadSupplementalFeatures(
                packageName = input.facts.packageName,
                sessionSeconds = input.facts.sessionSeconds,
                createdAt = createdAt,
            )
            val featureMap = buildFeatureMap(
                input = input,
                supplemental = supplementalFeatures,
                categoryMapping = runtime.config.categoryMapping,
            )
            val inputVector = buildInputVector(
                featureOrder = runtime.config.inputFeatureOrder,
                normalizationStats = runtime.normalizationStats,
                featureValues = featureMap,
            )
            val rawOutput = Array(1) { FloatArray(1) }
            runtime.interpreter.run(arrayOf(inputVector), rawOutput)
            val score = rawOutput[0][0].toDouble().coerceIn(0.0, 1.0)

            modelVersion = runtime.config.version
            lastModelError = null
            lastTfliteScore = score

            TFLiteScore(
                score = score,
                riskClass = BehaviorRiskClass.fromRiskScore(score),
                modelVersion = runtime.config.version,
                threshold = runtime.config.threshold,
                inputVectorSize = inputVector.size,
            )
        } catch (e: Exception) {
            lastModelError = e.message ?: e.javaClass.simpleName
            lastTfliteScore = null
            Log.w(TAG, "TFLite inference failed", e)
            null
        }
    }

    private fun ensureRuntime(): LoadedRuntime? {
        loadedRuntime?.let { return it }
        val safeContext = appContext ?: run {
            lastModelError = "Android context unavailable"
            return null
        }

        synchronized(runtimeLock) {
            loadedRuntime?.let { return it }
            return try {
                val interpreter = Interpreter(loadModelBuffer(safeContext))
                val config = parseModelConfig(readJsonAsset(safeContext, CONFIG_ASSET))
                val normalizationStats = parseNormalizationStats(
                    readJsonAsset(safeContext, NORMALIZATION_ASSET),
                )
                LoadedRuntime(
                    interpreter = interpreter,
                    config = config,
                    normalizationStats = normalizationStats,
                ).also { runtime ->
                    loadedRuntime = runtime
                    modelLoaded = true
                    modelVersion = config.version
                    lastModelError = null
                    Log.i(TAG, "TFLite model loaded successfully (version=${config.version})")
                }
            } catch (e: Exception) {
                modelLoaded = false
                lastModelError = e.message ?: e.javaClass.simpleName
                Log.w(TAG, "Failed to load TFLite model assets", e)
                null
            }
        }
    }

    private fun loadSupplementalFeatures(
        packageName: String,
        sessionSeconds: Long,
        createdAt: Long,
    ): SupplementalFeatures {
        val dateKey = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(createdAt))
        val cached = supplementalCache
        if (
            cached != null &&
            cached.packageName == packageName &&
            cached.dateKey == dateKey &&
            createdAt - cached.loadedAt < DB_CACHE_TTL_MS
        ) {
            return cached.features
        }

        val safeContext = appContext ?: return defaultSupplementalFeatures(sessionSeconds)
        val db = NativeDatabaseAccess.openReadable(safeContext) ?: return defaultSupplementalFeatures(
            sessionSeconds,
        )

        return try {
            var totalAppUsageTodayMinutes: Double? = null
            var launchCountToday = 0
            db.rawQuery(
                """
                SELECT duration_seconds, launch_count
                FROM app_usage
                WHERE package_name = ? AND date_key = ?
                LIMIT 1
                """.trimIndent(),
                arrayOf(packageName, dateKey),
            ).use { cursor ->
                if (cursor.moveToFirst()) {
                    totalAppUsageTodayMinutes = cursor.getLong(0) / 60.0
                    launchCountToday = cursor.getInt(1)
                }
            }

            var sessionIndexToday = launchCountToday
            db.rawQuery(
                """
                SELECT session_count
                FROM behavior_records
                WHERE date_key = ?
                LIMIT 1
                """.trimIndent(),
                arrayOf(dateKey),
            ).use { cursor ->
                if (cursor.moveToFirst()) {
                    sessionIndexToday = maxOf(sessionIndexToday, cursor.getInt(0))
                }
            }

            var dailyLimitMinutes = 0.0
            var isWhitelisted = false
            db.rawQuery(
                """
                SELECT
                    MAX(CASE WHEN daily_limit_minutes > 0 THEN daily_limit_minutes ELSE 0 END),
                    MAX(CASE WHEN list_type = 'whitelist' THEN 1 ELSE 0 END)
                FROM app_list
                WHERE package_name = ? AND is_enabled = 1
                """.trimIndent(),
                arrayOf(packageName),
            ).use { cursor ->
                if (cursor.moveToFirst()) {
                    dailyLimitMinutes = cursor.getDoubleOrZero(0)
                    isWhitelisted = cursor.getInt(1) == 1
                }
            }

            SupplementalFeatures(
                launchCountToday = launchCountToday.coerceAtLeast(if (sessionSeconds > 0L) 1 else 0),
                sessionIndexToday = sessionIndexToday.coerceAtLeast(if (sessionSeconds > 0L) 1 else 0),
                totalAppUsageTodayMinutes = totalAppUsageTodayMinutes,
                dailyLimitMinutes = dailyLimitMinutes,
                isWhitelisted = isWhitelisted,
            ).also { features ->
                supplementalCache = SupplementalCache(
                    packageName = packageName,
                    dateKey = dateKey,
                    loadedAt = createdAt,
                    features = features,
                )
            }
        } catch (e: Exception) {
            lastModelError = e.message ?: e.javaClass.simpleName
            Log.w(TAG, "Failed to read supplemental behavior features", e)
            defaultSupplementalFeatures(sessionSeconds)
        } finally {
            db.close()
        }
    }

    private fun defaultSupplementalFeatures(sessionSeconds: Long): SupplementalFeatures {
        val fallbackLaunchCount = if (sessionSeconds > 0L) 1 else 0
        return SupplementalFeatures(
            launchCountToday = fallbackLaunchCount,
            sessionIndexToday = fallbackLaunchCount,
            totalAppUsageTodayMinutes = null,
            dailyLimitMinutes = 0.0,
            isWhitelisted = false,
        )
    }

    private fun loadModelBuffer(context: Context): ByteBuffer {
        val modelBytes = context.assets.open(MODEL_ASSET).use { it.readBytes() }
        return ByteBuffer.allocateDirect(modelBytes.size)
            .order(ByteOrder.nativeOrder())
            .apply {
                put(modelBytes)
                rewind()
            }
    }

    private fun readJsonAsset(context: Context, assetName: String): JSONObject {
        val jsonText = context.assets.open(assetName).bufferedReader().use { it.readText() }
        return JSONObject(jsonText)
    }

    private fun parseModelConfig(json: JSONObject): ModelConfig {
        val featureArray = json.optJSONArray("input_feature_order")
            ?: throw IllegalStateException("model_config.json missing input_feature_order")
        val featureOrder = buildList(featureArray.length()) {
            for (index in 0 until featureArray.length()) {
                add(featureArray.getString(index))
            }
        }
        val categoryMapping = jsonObjectToIntMap(json.optJSONObject("category_mapping"))
        return ModelConfig(
            inputFeatureOrder = featureOrder,
            categoryMapping = categoryMapping,
            threshold = json.optDouble("selected_threshold", 0.5),
            version = json.optString("version", "unknown"),
        )
    }

    private fun parseNormalizationStats(json: JSONObject): NormalizationStats {
        return NormalizationStats(
            mean = jsonObjectToDoubleMap(json.optJSONObject("mean")),
            std = jsonObjectToDoubleMap(json.optJSONObject("std")),
        )
    }

    private fun jsonObjectToDoubleMap(json: JSONObject?): Map<String, Double> {
        if (json == null) return emptyMap()
        val result = mutableMapOf<String, Double>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            result[key] = json.optDouble(key, 0.0)
        }
        return result
    }

    private fun jsonObjectToIntMap(json: JSONObject?): Map<String, Int> {
        if (json == null) return emptyMap()
        val result = mutableMapOf<String, Int>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            result[key] = json.optInt(key, 0)
        }
        return result
    }

    private fun android.database.Cursor.getDoubleOrZero(index: Int): Double {
        return if (isNull(index)) 0.0 else getDouble(index)
    }

    private fun formatScore(score: Double): String =
        String.format(Locale.US, "%.4f", score)
}
