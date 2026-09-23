package com.selfleveling.self_leveling

class OverlayRequestSequencer {
    private var latestRequestId: Long = 0L

    @Synchronized
    fun nextRequestId(): Long {
        latestRequestId += 1L
        return latestRequestId
    }

    @Synchronized
    fun isCurrent(requestId: Long): Boolean = requestId == latestRequestId
}
