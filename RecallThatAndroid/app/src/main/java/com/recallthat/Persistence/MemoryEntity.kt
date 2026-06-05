package com.recallthat.Persistence

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.recallthat.Models.Memory
import com.recallthat.Models.MemorySourceType
import com.recallthat.Models.OCRStatus
import java.util.Date
import java.util.UUID

@Entity(tableName = "memories")
data class MemoryEntity(
    @PrimaryKey val id: String,
    val sourceTypeRaw: String,
    val photoAssetUri: String?,
    val localThumbnailPath: String?,
    val createdAt: Long,           // epoch millis
    val importedAt: Long,
    val title: String,
    val ocrText: String,
    val ocrStatusRaw: String,
    val searchText: String,
    val originalExists: Boolean,
    val deletedOriginalAt: Long?,
    val sourceUrl: String?
) {
    fun toDomain(): Memory = Memory(
        id = UUID.fromString(id),
        sourceType = MemorySourceType.from(sourceTypeRaw),
        photoAssetUri = photoAssetUri,
        localThumbnailPath = localThumbnailPath,
        createdAt = Date(createdAt),
        importedAt = Date(importedAt),
        title = title,
        ocrText = ocrText,
        ocrStatus = OCRStatus.from(ocrStatusRaw),
        searchText = searchText,
        originalExists = originalExists,
        deletedOriginalAt = deletedOriginalAt?.let { Date(it) },
        sourceUrl = sourceUrl
    )

    companion object {
        fun fromDomain(m: Memory) = MemoryEntity(
            id = m.id.toString(),
            sourceTypeRaw = m.sourceType.raw,
            photoAssetUri = m.photoAssetUri,
            localThumbnailPath = m.localThumbnailPath,
            createdAt = m.createdAt.time,
            importedAt = m.importedAt.time,
            title = m.title,
            ocrText = m.ocrText,
            ocrStatusRaw = m.ocrStatus.raw,
            searchText = m.searchText,
            originalExists = m.originalExists,
            deletedOriginalAt = m.deletedOriginalAt?.time,
            sourceUrl = m.sourceUrl
        )
    }
}
