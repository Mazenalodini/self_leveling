package com.selfleveling.self_leveling

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ForegroundSignalStateTest {

    @Test
    fun `entering a tracked app emits enter without immediate hide`() {
        val resolution = ForegroundSignalState.resolve(
            previousForegroundPackage = null,
            signaledPackage = "com.example.blocked",
            ownPackage = "com.selfleveling.self_leveling",
            isEssentialPackage = { false },
        )

        assertEquals("com.example.blocked", resolution.effectiveForegroundPackage)
        assertNull(resolution.exitedPackage)
        assertEquals("com.example.blocked", resolution.enteredPackage)
        assertFalse(resolution.shouldHideOverlayImmediately)
    }

    @Test
    fun `moving to launcher clears tracked foreground and hides overlay`() {
        val resolution = ForegroundSignalState.resolve(
            previousForegroundPackage = "com.example.blocked",
            signaledPackage = "com.android.launcher3",
            ownPackage = "com.selfleveling.self_leveling",
            isEssentialPackage = { pkg -> pkg == "com.android.launcher3" },
        )

        assertNull(resolution.effectiveForegroundPackage)
        assertEquals("com.example.blocked", resolution.exitedPackage)
        assertNull(resolution.enteredPackage)
        assertTrue(resolution.shouldHideOverlayImmediately)
    }

    @Test
    fun `moving to recents system ui clears tracked foreground and hides overlay`() {
        val resolution = ForegroundSignalState.resolve(
            previousForegroundPackage = "com.example.blocked",
            signaledPackage = "com.android.systemui",
            ownPackage = "com.selfleveling.self_leveling",
            isEssentialPackage = { pkg -> pkg == "com.android.systemui" },
        )

        assertNull(resolution.effectiveForegroundPackage)
        assertEquals("com.example.blocked", resolution.exitedPackage)
        assertNull(resolution.enteredPackage)
        assertTrue(resolution.shouldHideOverlayImmediately)
    }

    @Test
    fun `null foreground clears tracked foreground and hides overlay`() {
        val resolution = ForegroundSignalState.resolve(
            previousForegroundPackage = "com.example.blocked",
            signaledPackage = null,
            ownPackage = "com.selfleveling.self_leveling",
            isEssentialPackage = { false },
        )

        assertNull(resolution.effectiveForegroundPackage)
        assertEquals("com.example.blocked", resolution.exitedPackage)
        assertNull(resolution.enteredPackage)
        assertTrue(resolution.shouldHideOverlayImmediately)
    }

    @Test
    fun `ime package can stay associated with current blocked app handling`() {
        val resolution = ForegroundSignalState.resolve(
            previousForegroundPackage = "com.example.blocked",
            signaledPackage = "com.google.android.inputmethod.latin",
            ownPackage = "com.selfleveling.self_leveling",
            isEssentialPackage = { false },
            shouldPreservePreviousPackage = { it.contains("inputmethod") },
        )

        assertEquals("com.example.blocked", resolution.effectiveForegroundPackage)
        assertNull(resolution.exitedPackage)
        assertNull(resolution.enteredPackage)
        assertFalse(resolution.shouldHideOverlayImmediately)
    }

    @Test
    fun `same package does not produce duplicate transition`() {
        val resolution = ForegroundSignalState.resolve(
            previousForegroundPackage = "com.example.blocked",
            signaledPackage = "com.example.blocked",
            ownPackage = "com.selfleveling.self_leveling",
            isEssentialPackage = { false },
        )

        assertEquals("com.example.blocked", resolution.effectiveForegroundPackage)
        assertNull(resolution.exitedPackage)
        assertNull(resolution.enteredPackage)
        assertFalse(resolution.shouldHideOverlayImmediately)
    }

    @Test
    fun `rapid switch between tracked apps exits previous and enters next`() {
        val resolution = ForegroundSignalState.resolve(
            previousForegroundPackage = "com.example.one",
            signaledPackage = "com.example.two",
            ownPackage = "com.selfleveling.self_leveling",
            isEssentialPackage = { false },
        )

        assertEquals("com.example.one", resolution.exitedPackage)
        assertEquals("com.example.two", resolution.enteredPackage)
        assertEquals("com.example.two", resolution.effectiveForegroundPackage)
        assertFalse(resolution.shouldHideOverlayImmediately)
    }
}
