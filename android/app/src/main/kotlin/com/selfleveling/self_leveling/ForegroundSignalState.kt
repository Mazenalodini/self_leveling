package com.selfleveling.self_leveling

data class ForegroundSignalResolution(
    val effectiveForegroundPackage: String?,
    val exitedPackage: String?,
    val enteredPackage: String?,
    val shouldHideOverlayImmediately: Boolean,
)

object ForegroundSignalState {
    fun resolve(
        previousForegroundPackage: String?,
        signaledPackage: String?,
        ownPackage: String,
        isEssentialPackage: (String) -> Boolean,
        shouldPreservePreviousPackage: (String) -> Boolean = { false },
    ): ForegroundSignalResolution {
        val normalizedPackage = signaledPackage
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
        val effectivePackage = when {
            normalizedPackage == null -> null
            normalizedPackage == ownPackage -> null
            shouldPreservePreviousPackage(normalizedPackage) -> previousForegroundPackage
            isEssentialPackage(normalizedPackage) -> null
            else -> normalizedPackage
        }

        return ForegroundSignalResolution(
            effectiveForegroundPackage = effectivePackage,
            exitedPackage = if (
                previousForegroundPackage != null &&
                previousForegroundPackage != effectivePackage
            ) {
                previousForegroundPackage
            } else {
                null
            },
            enteredPackage = if (
                effectivePackage != null &&
                effectivePackage != previousForegroundPackage
            ) {
                effectivePackage
            } else {
                null
            },
            shouldHideOverlayImmediately = effectivePackage == null,
        )
    }
}
