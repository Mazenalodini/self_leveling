package com.selfleveling.self_leveling

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OverlayRequestSequencerTest {

    @Test
    fun `newer hide invalidates older show request`() {
        val sequencer = OverlayRequestSequencer()

        val showRequest = sequencer.nextRequestId()
        val hideRequest = sequencer.nextRequestId()

        assertFalse(sequencer.isCurrent(showRequest))
        assertTrue(sequencer.isCurrent(hideRequest))
    }

    @Test
    fun `newer show invalidates older hide request`() {
        val sequencer = OverlayRequestSequencer()

        val hideRequest = sequencer.nextRequestId()
        val showRequest = sequencer.nextRequestId()

        assertFalse(sequencer.isCurrent(hideRequest))
        assertTrue(sequencer.isCurrent(showRequest))
    }
}
