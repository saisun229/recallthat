package com.recallthat.Models

import java.util.Date
import java.util.UUID

data class Memory(
    val id: UUID,
    val sourceType: MemorySourceType,
    val photoAssetUri: String?,          // content:// URI string (mirrors iOS photoAssetIdentifier)
    val localThumbnailPath: String?,
    val createdAt: Date,
    val importedAt: Date,
    val title: String,
    val ocrText: String,
    val ocrStatus: OCRStatus,
    val searchText: String,              // denormalized: (title + ocrText).lowercase()
    val originalExists: Boolean,
    val deletedOriginalAt: Date?,
    val sourceUrl: String?
)
