package com.selfleveling.self_leveling

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.CountDownTimer
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import java.util.Locale

/**
 * Manages the native system overlay displayed above other apps.
 *
 * Supports multiple visual modes:
 *   - USAGE_LIMIT:      Red/danger, daily block, no countdown
 *   - BEHAVIOR_WARNING:  Amber/warning, timed block with countdown
 *   - LIMITED_ACCESS:    Blue/enforced, restricted window with countdown
 *   - HARD_LOCK:         Deep red/punitive, extended lock with countdown
 *
 * All modes share the same WindowManager infrastructure but render
 * different layouts, colors, and behaviors.
 */
class OverlayManager(private val context: Context) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val requestSequencer = OverlayRequestSequencer()
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var countdownTimer: CountDownTimer? = null

    // Currently displayed mode
    private var currentMode: OverlayMode? = null
    private var currentPackage: String? = null
    private var titleTextView: TextView? = null
    private var messageTextView: TextView? = null
    private var fallbackMessageTextView: TextView? = null
    private var resetTextView: TextView? = null

    // Design tokens matching AppColors
    private val colorBackground   = Color.parseColor("#F50A0F1C")
    private val colorCard         = Color.parseColor("#FF121A2B")
    private val colorDanger       = Color.parseColor("#FFEF4444")
    private val colorDangerDeep   = Color.parseColor("#FFDC2626")
    private val colorWarning      = Color.parseColor("#FFF59E0B")
    private val colorWarningDeep  = Color.parseColor("#FFD97706")
    private val colorBlue         = Color.parseColor("#FF3B82F6")
    private val colorBlueDark     = Color.parseColor("#FF2563EB")
    private val colorTextPrimary  = Color.WHITE
    private val colorTextSecondary = Color.parseColor("#FF9CA3AF")
    private val colorTextTertiary = Color.parseColor("#FF6B7280")

    private fun dp(value: Int): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value.toFloat(),
            context.resources.displayMetrics).toInt()

    // ═══════════════════════════════════════════
    // Public API
    // ═══════════════════════════════════════════

    /**
     * Show overlay for a USAGE LIMIT block (existing behavior).
     * Backwards-compatible: keeps the same API as before.
     */
    fun showOverlay(message: String?) {
        showWithPayload(InterventionPayload(
            stage = 0,
            mode = OverlayMode.USAGE_LIMIT,
            title = context.getString(R.string.usage_limit_title),
            message = message ?: context.getString(R.string.usage_limit_message),
            appName = "",
            packageName = "",
            reason = context.getString(R.string.usage_limit_reason),
            resetText = context.getString(R.string.usage_limit_reset),
        ))
    }

    /**
     * Show overlay with a full intervention payload (behavior-based escalation).
     */
    fun showWithPayload(payload: InterventionPayload) {
        val requestId = requestSequencer.nextRequestId()
        mainHandler.post {
            if (!requestSequencer.isCurrent(requestId)) return@post
            showWithPayloadNow(payload, requestId)
        }
    }

    private fun showWithPayloadNow(payload: InterventionPayload, requestId: Long) {
        // If same mode/package already showing, update only the dynamic text
        // in-place to avoid any visible rebind/re-attach churn.
        if (overlayView != null && currentMode == payload.mode && currentPackage == payload.packageName) {
            updateOverlayContentInPlace(payload)
            attachedRequestId = requestId
            return
        }

        // Remove existing overlay before showing new one
        hideOverlayNow()

        windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager?

        val layout = buildOverlayLayout(payload)
        overlayView = layout
        currentMode = payload.mode
        currentPackage = payload.packageName
        attachedRequestId = requestId

        val layoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            layoutParams.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }

        try {
            windowManager?.addView(overlayView, layoutParams)

            // Start countdown timer if this is a timed lock
            if (payload.durationSeconds > 0) {
                startCountdown(payload.durationSeconds)
            }
        } catch (e: Exception) {
            e.printStackTrace()
            overlayView = null
            currentMode = null
            currentPackage = null
            attachedRequestId = 0L
        }
    }

    fun hideOverlay() {
        val requestId = requestSequencer.nextRequestId()
        mainHandler.post {
            if (!requestSequencer.isCurrent(requestId)) return@post
            hideOverlayNow()
        }
    }

    private var attachedRequestId: Long = 0L

    private fun hideOverlayNow() {
        try {
            countdownTimer?.cancel()
            countdownTimer = null
            if (overlayView != null) {
                windowManager?.removeViewImmediate(overlayView)
                overlayView = null
            }
        } catch (e: Exception) {
            e.printStackTrace()
            overlayView = null
        } finally {
            currentMode = null
            currentPackage = null
            titleTextView = null
            messageTextView = null
            fallbackMessageTextView = null
            resetTextView = null
            countdownTextView = null
            attachedRequestId = 0L
        }
    }

    // ═══════════════════════════════════════════
    // Countdown Timer
    // ═══════════════════════════════════════════

    private var countdownTextView: TextView? = null

    private fun startCountdown(durationSeconds: Int) {
        countdownTimer?.cancel()
        countdownTimer = object : CountDownTimer(durationSeconds * 1000L, 1000L) {
            override fun onTick(millisUntilFinished: Long) {
                val remaining = (millisUntilFinished / 1000).toInt()
                setTextIfChanged(countdownTextView, formatCountdown(remaining))
            }
            override fun onFinish() {
                setTextIfChanged(countdownTextView, formatCountdown(0))
                // AUTO-DISMISS: Safety net — hide overlay when countdown reaches zero.
                // The EscalationEvaluator is the authoritative source for lock expiry,
                // but this ensures the overlay never stays on screen showing 00:00
                // if there's a tick timing gap.
                hideOverlay()
            }
        }.start()
    }

    /**
     * Update countdown display without rebuilding the entire overlay.
     * Used by TrackingService to sync the timer with evaluator's remaining time.
     */
    fun updateCountdown(remainingSeconds: Int) {
        if (countdownTextView != null && remainingSeconds >= 0) {
            setTextIfChanged(countdownTextView, formatCountdown(remainingSeconds))
        }
    }

    private fun updateOverlayContentInPlace(payload: InterventionPayload) {
        setTextIfChanged(titleTextView, preferredHeadline(payload))
        setTextIfChanged(messageTextView, preferredBody(payload))
        setTextAndVisibility(fallbackMessageTextView, fallbackBody(payload))
        setTextIfChanged(resetTextView, visibleResetText(payload))
        if (payload.durationSeconds >= 0) {
            updateCountdown(payload.durationSeconds)
        }
    }

    private fun preferredHeadline(payload: InterventionPayload): String =
        payload.headline?.takeUnless { it.isBlank() } ?: payload.title

    private fun preferredBody(payload: InterventionPayload): String =
        payload.body?.takeUnless { it.isBlank() } ?: payload.message

    private fun fallbackBody(payload: InterventionPayload): String {
        val generated = payload.body?.takeUnless { it.isBlank() } ?: return ""
        val fallback = payload.message.takeUnless { it.isBlank() } ?: return ""
        return if (generated == fallback) "" else fallback
    }

    private fun visibleResetText(payload: InterventionPayload): String =
        if (payload.durationSeconds > 0) {
            buildCompactResetText(payload)
        } else {
            payload.resetText?.takeUnless { it.isBlank() } ?: ""
        }

    private fun buildCompactResetText(payload: InterventionPayload): String {
        val formatted = formatCountdown(payload.durationSeconds)
        return when (payload.stage) {
            3 -> if (isArabic()) "ينتهي القفل خلال $formatted" else "Lock expires in $formatted"
            4 -> if (isArabic()) "وصول محدود: $formatted متبقية" else "Limited access: $formatted remaining"
            5 -> if (isArabic()) "مغلق لمدة $formatted" else "Locked for $formatted"
            else -> payload.resetText?.takeUnless { it.isBlank() } ?: ""
        }
    }

    private fun isArabic(): Boolean =
        context.resources.configuration.layoutDirection == View.LAYOUT_DIRECTION_RTL

    private fun formatCountdown(remainingSeconds: Int): String {
        val safeSeconds = remainingSeconds.coerceAtLeast(0)
        val hours = safeSeconds / 3600
        val minutes = (safeSeconds % 3600) / 60
        val seconds = safeSeconds % 60
        return if (hours > 0) {
            String.format(Locale.US, "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            String.format(Locale.US, "%02d:%02d", minutes, seconds)
        }
    }

    private fun setTextIfChanged(view: TextView?, value: String) {
        if (view == null) return
        if (view.text?.toString() == value) return
        view.text = value
    }

    private fun setTextAndVisibility(view: TextView?, value: String) {
        if (view == null) return
        setTextIfChanged(view, value)
        view.visibility = if (value.isBlank()) View.GONE else View.VISIBLE
    }

    // ═══════════════════════════════════════════
    // Layout Builder
    // ═══════════════════════════════════════════

    private fun buildOverlayLayout(payload: InterventionPayload): View {
        // Select color scheme based on mode
        val (accentColor, accentDeep, iconEmoji) = when (payload.mode) {
            OverlayMode.USAGE_LIMIT      -> Triple(colorDanger, colorDangerDeep, "🛡️")
            OverlayMode.BEHAVIOR_WARNING  -> Triple(colorWarning, colorWarningDeep, "⚡")
            OverlayMode.LIMITED_ACCESS    -> Triple(colorBlue, colorBlueDark, "🔒")
            OverlayMode.HARD_LOCK         -> Triple(colorDanger, colorDangerDeep, "⛔")
        }

        val borderColor = Color.argb(102, Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor))

        // Detect RTL for Arabic layout
        val isRtl = context.resources.configuration.layoutDirection == View.LAYOUT_DIRECTION_RTL

        // Root container
        val root = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(colorBackground)
            gravity = Gravity.CENTER
            isClickable = true
            isFocusable = true
            isFocusableInTouchMode = true
            isLongClickable = true
            descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
            setOnTouchListener { _, _ -> true }
            setOnLongClickListener { true }
            setOnGenericMotionListener { _, _ -> true }
            setOnHoverListener { _, _ -> true }
            setPadding(dp(24), dp(32), dp(24), dp(20))
            layoutDirection = if (isRtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR
        }

        // ── Icon circle ──
        val iconContainer = FrameLayout(context).apply {
            val size = dp(80)
            layoutParams = LinearLayout.LayoutParams(size, size).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = dp(20)
            }
            val bg = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                colors = intArrayOf(accentColor, accentDeep)
                orientation = GradientDrawable.Orientation.TOP_BOTTOM
                setStroke(dp(2), accentColor)
            }
            background = bg
            elevation = dp(6).toFloat()
        }
        val iconText = TextView(context).apply {
            text = iconEmoji
            textSize = 36f
            gravity = Gravity.CENTER
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        iconContainer.addView(iconText)
        root.addView(iconContainer)

        // ── Stage badge ──
        val stageBadge = TextView(context).apply {
            text = when (payload.stage) {
                1 -> context.getString(R.string.badge_s1)
                2 -> context.getString(R.string.badge_s2)
                3 -> context.getString(R.string.badge_s3)
                4 -> context.getString(R.string.badge_s4)
                5 -> context.getString(R.string.badge_s5)
                else -> context.getString(R.string.badge_default)
            }
            textSize = 10f
            setTextColor(accentColor)
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            gravity = Gravity.CENTER
            letterSpacing = 0.12f
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = dp(12)
            }
        }
        root.addView(stageBadge)

        // ── Title ──
        val title = TextView(context).apply {
            text = preferredHeadline(payload)
            textSize = 26f
            setTextColor(colorTextPrimary)
            typeface = Typeface.create("sans-serif-black", Typeface.BOLD)
            gravity = Gravity.CENTER
            letterSpacing = 0.02f
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dp(6) }
        }
        titleTextView = title
        root.addView(title)

        // ── Decorative divider ──
        val divider = buildDivider(accentColor)
        root.addView(divider)

        // ── Message card ──
        val messageCard = buildMessageCard(payload, accentColor, borderColor)
        root.addView(messageCard)

        // ── Countdown timer card (if timed lock) ──
        if (payload.durationSeconds > 0) {
            val timerCard = buildTimerCard(payload, accentColor)
            root.addView(timerCard)
        }

        // ── Reminder card (if identity reminder available) ──
        if (!payload.reminderText.isNullOrBlank()) {
            val reminderCard = buildReminderCard(payload.reminderText!!)
            root.addView(reminderCard)
        }

        // ── Recommendation Hint card ──
        if (!payload.recommendationText.isNullOrBlank() && payload.stage >= 2) {
            val recText = if (!payload.recommendationTitle.isNullOrBlank()) 
                "${payload.recommendationTitle}: ${payload.recommendationText}" 
            else payload.recommendationText!!
            
            val actionCard = buildActionCard(recText)
            root.addView(actionCard)
        } else if (!payload.suggestedAction.isNullOrBlank() && payload.stage >= 2) {
            // Fallback to older suggested action
            val actionCard = buildActionCard(payload.suggestedAction!!)
            root.addView(actionCard)
        }

        // ── Reset info ──
        val resetText = visibleResetText(payload)
        if (resetText.isNotBlank()) {
            val resetInfo = buildResetInfo(resetText)
            root.addView(resetInfo)
        }

        if (payload.showExitAppAction) {
            val actionButton = buildExitAppButton(
                label = payload.actionLabel ?: context.getString(R.string.exit_app_action),
            )
            root.addView(actionButton)
        }

        // ── Bottom instruction + branding ──
        val instruction = TextView(context).apply {
            text = context.getString(R.string.overlay_instruction)
            textSize = 11f
            setTextColor(colorTextTertiary)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(16); bottomMargin = dp(8) }
        }
        root.addView(instruction)

        val branding = TextView(context).apply {
            text = context.getString(R.string.overlay_branding)
            textSize = 8f
            setTextColor(colorTextTertiary)
            alpha = 0.4f
            gravity = Gravity.CENTER
            letterSpacing = 0.1f
        }
        root.addView(branding)

        return root
    }

    private fun buildDivider(accentColor: Int): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dp(20) }

            val lineLeft = View(context).apply {
                layoutParams = LinearLayout.LayoutParams(dp(40), dp(1))
                setBackgroundColor(accentColor)
                alpha = 0.4f
            }
            val dot = View(context).apply {
                val s = dp(5)
                layoutParams = LinearLayout.LayoutParams(s, s).apply {
                    setMargins(dp(8), 0, dp(8), 0)
                }
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(accentColor)
                }
            }
            val lineRight = View(context).apply {
                layoutParams = LinearLayout.LayoutParams(dp(40), dp(1))
                setBackgroundColor(accentColor)
                alpha = 0.4f
            }
            addView(lineLeft)
            addView(dot)
            addView(lineRight)
        }
    }

    private fun buildMessageCard(payload: InterventionPayload, accentColor: Int, borderColor: Int): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(20), dp(16), dp(20), dp(16))
            background = GradientDrawable().apply {
                setColor(colorCard)
                cornerRadius = dp(18).toFloat()
                setStroke(dp(1), borderColor)
            }
            elevation = dp(3).toFloat()
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dp(16) }

            // Reason label
            val reasonLabel = TextView(context).apply {
                text = if (payload.appName.isNotBlank()) "🔍 ${payload.reason}" else payload.reason
                textSize = 11f
                setTextColor(accentColor)
                typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    gravity = Gravity.CENTER_HORIZONTAL
                    bottomMargin = dp(10)
                }
            }
            addView(reasonLabel)

            // Message text
            val msgText = TextView(context).apply {
                text = preferredBody(payload)
                textSize = 15f
                setTextColor(colorTextSecondary)
                gravity = Gravity.CENTER
                setLineSpacing(0f, 1.35f)
            }
            messageTextView = msgText
            addView(msgText)

            val fallbackText = TextView(context).apply {
                text = fallbackBody(payload)
                textSize = 13f
                setTextColor(colorTextTertiary)
                gravity = Gravity.CENTER
                setLineSpacing(0f, 1.3f)
                visibility = if (text.isNullOrBlank()) View.GONE else View.VISIBLE
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    topMargin = dp(10)
                }
            }
            fallbackMessageTextView = fallbackText
            addView(fallbackText)

            // XP penalty badge
            if (payload.xpPenalty > 0) {
                val penalty = TextView(context).apply {
                    text = context.getString(R.string.xp_penalty_format, payload.xpPenalty)
                    textSize = 12f
                    setTextColor(colorDanger)
                    typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
                    gravity = Gravity.CENTER
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        gravity = Gravity.CENTER_HORIZONTAL
                        topMargin = dp(10)
                    }
                }
                addView(penalty)
            }
        }
    }

    private fun buildTimerCard(payload: InterventionPayload, accentColor: Int): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(24), dp(20), dp(24), dp(20))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#1A3B82F6"))
                cornerRadius = dp(18).toFloat()
                setStroke(dp(1), Color.parseColor("#4D3B82F6"))
            }
            elevation = dp(2).toFloat()
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dp(12) }

            val timerLabel = TextView(context).apply {
                text = context.getString(R.string.timer_label)
                textSize = 10f
                setTextColor(colorTextSecondary)
                letterSpacing = 0.08f
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    gravity = Gravity.CENTER_HORIZONTAL
                    bottomMargin = dp(8)
                }
            }
            addView(timerLabel)

            val timerText = TextView(context).apply {
                text = formatCountdown(payload.durationSeconds)
                textSize = 36f
                setTextColor(colorBlue)
                typeface = Typeface.create("sans-serif-light", Typeface.NORMAL)
                gravity = Gravity.CENTER
                letterSpacing = 0.05f
            }
            countdownTextView = timerText
            addView(timerText)
        }
    }

    private fun buildReminderCard(reminderText: String): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(dp(14), dp(10), dp(14), dp(10))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#1A22D3EE"))  // cyan 10%
                cornerRadius = dp(14).toFloat()
                setStroke(dp(1), Color.parseColor("#3322D3EE"))
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dp(10) }

            val icon = TextView(context).apply { text = "🎯"; textSize = 14f }
            val text = TextView(context).apply {
                this.text = "  $reminderText"
                textSize = 12f
                setTextColor(Color.parseColor("#FF22D3EE"))
                typeface = Typeface.create("sans-serif-medium", Typeface.ITALIC)
            }
            addView(icon)
            addView(text)
        }
    }

    private fun buildActionCard(actionText: String): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(dp(14), dp(10), dp(14), dp(10))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#1A22C55E"))  // green 10%
                cornerRadius = dp(14).toFloat()
                setStroke(dp(1), Color.parseColor("#3322C55E"))
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dp(10) }

            val icon = TextView(context).apply { text = "💡"; textSize = 14f }
            val text = TextView(context).apply {
                this.text = "  $actionText"
                textSize = 12f
                setTextColor(Color.parseColor("#FF22C55E"))
            }
            addView(icon)
            addView(text)
        }
    }

    private fun buildResetInfo(resetText: String): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(dp(12), dp(8), dp(12), dp(8))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#1A3B82F6"))
                cornerRadius = dp(12).toFloat()
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = dp(8)
            }

            val icon = TextView(context).apply { text = "🕐"; textSize = 12f }
            val text = TextView(context).apply {
                this.text = "  $resetText"
                textSize = 11f
                setTextColor(colorBlue)
            }
            resetTextView = text
            addView(icon)
            addView(text)
        }
    }

    private fun buildExitAppButton(label: String): TextView {
        return TextView(context).apply {
            text = label
            textSize = 14f
            setTextColor(colorTextPrimary)
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            gravity = Gravity.CENTER
            isClickable = true
            isFocusable = true
            setPadding(dp(18), dp(14), dp(18), dp(14))
            background = GradientDrawable().apply {
                colors = intArrayOf(colorBlue, colorBlueDark)
                orientation = GradientDrawable.Orientation.LEFT_RIGHT
                cornerRadius = dp(16).toFloat()
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dp(8)
                bottomMargin = dp(8)
            }
            setOnClickListener { exitToHome() }
        }
    }

    private fun exitToHome() {
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        try {
            context.startActivity(homeIntent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
