package com.recallthat.Models

enum class OCRStatus(val raw: String) {
    NOT_STARTED("notStarted"),
    PENDING("pending"),
    COMPLETE("complete"),
    FAILED("failed");

    val label: String get() = when (this) {
        NOT_STARTED -> "Not indexed"
        PENDING     -> "Processing"
        COMPLETE    -> "Indexed"
        FAILED      -> "Failed"
    }

    companion object {
        fun from(raw: String): OCRStatus =
            entries.firstOrNull { it.raw == raw } ?: NOT_STARTED
    }
}
