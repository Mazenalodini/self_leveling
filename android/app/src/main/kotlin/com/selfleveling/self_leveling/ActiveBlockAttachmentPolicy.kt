package com.selfleveling.self_leveling

data class ActiveBlockAttachmentDecision(
    val shouldKeepBlockState: Boolean,
    val shouldAttachOverlay: Boolean,
    val shouldClearExpiredBlock: Boolean,
)

object ActiveBlockAttachmentPolicy {
    fun decide(
        blockedPackageName: String?,
        blockExpiresAtMs: Long,
        foregroundPackageName: String?,
        now: Long,
    ): ActiveBlockAttachmentDecision {
        if (blockedPackageName.isNullOrBlank() || blockExpiresAtMs <= 0L) {
            return ActiveBlockAttachmentDecision(
                shouldKeepBlockState = false,
                shouldAttachOverlay = false,
                shouldClearExpiredBlock = false,
            )
        }

        if (now >= blockExpiresAtMs) {
            return ActiveBlockAttachmentDecision(
                shouldKeepBlockState = false,
                shouldAttachOverlay = false,
                shouldClearExpiredBlock = true,
            )
        }

        return ActiveBlockAttachmentDecision(
            shouldKeepBlockState = true,
            shouldAttachOverlay = foregroundPackageName == blockedPackageName,
            shouldClearExpiredBlock = false,
        )
    }
}
