package com.selfleveling.self_leveling

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ActiveBlockAttachmentPolicyTest {

    @Test
    fun `leaving to home keeps block state but detaches overlay`() {
        val decision = ActiveBlockAttachmentPolicy.decide(
            blockedPackageName = "com.example.blocked",
            blockExpiresAtMs = 10_000L,
            foregroundPackageName = null,
            now = 1_000L,
        )

        assertTrue(decision.shouldKeepBlockState)
        assertFalse(decision.shouldAttachOverlay)
        assertFalse(decision.shouldClearExpiredBlock)
    }

    @Test
    fun `returning to blocked app reattaches overlay before expiry`() {
        val decision = ActiveBlockAttachmentPolicy.decide(
            blockedPackageName = "com.example.blocked",
            blockExpiresAtMs = 10_000L,
            foregroundPackageName = "com.example.blocked",
            now = 1_000L,
        )

        assertTrue(decision.shouldKeepBlockState)
        assertTrue(decision.shouldAttachOverlay)
        assertFalse(decision.shouldClearExpiredBlock)
    }

    @Test
    fun `opening recents or another app keeps block state detached`() {
        val decision = ActiveBlockAttachmentPolicy.decide(
            blockedPackageName = "com.example.blocked",
            blockExpiresAtMs = 10_000L,
            foregroundPackageName = "com.android.systemui",
            now = 1_000L,
        )

        assertTrue(decision.shouldKeepBlockState)
        assertFalse(decision.shouldAttachOverlay)
        assertFalse(decision.shouldClearExpiredBlock)
    }

    @Test
    fun `switching to another app does not cancel timed block on original app`() {
        val decision = ActiveBlockAttachmentPolicy.decide(
            blockedPackageName = "com.example.blocked",
            blockExpiresAtMs = 10_000L,
            foregroundPackageName = "com.example.safe",
            now = 1_000L,
        )

        assertTrue(decision.shouldKeepBlockState)
        assertFalse(decision.shouldAttachOverlay)
        assertFalse(decision.shouldClearExpiredBlock)
    }

    @Test
    fun `expired block clears instead of reattaching`() {
        val decision = ActiveBlockAttachmentPolicy.decide(
            blockedPackageName = "com.example.blocked",
            blockExpiresAtMs = 2_000L,
            foregroundPackageName = "com.example.blocked",
            now = 2_500L,
        )

        assertFalse(decision.shouldKeepBlockState)
        assertFalse(decision.shouldAttachOverlay)
        assertTrue(decision.shouldClearExpiredBlock)
    }
}
