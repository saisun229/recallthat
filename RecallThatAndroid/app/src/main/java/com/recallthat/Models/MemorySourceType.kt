package com.recallthat.Models

enum class MemorySourceType(val raw: String) {
    SCREENSHOT("screenshot"),
    SHARED_TEXT("sharedText"),
    SHARED_URL("sharedURL"),
    SHARED_IMAGE("sharedImage"),
    SHARED_PDF("sharedPDF"),
    SHARED_VIDEO("sharedVideo"),
    SHARED_AUDIO("sharedAudio");

    companion object {
        fun from(raw: String): MemorySourceType =
            entries.firstOrNull { it.raw == raw } ?: SCREENSHOT
    }
}
