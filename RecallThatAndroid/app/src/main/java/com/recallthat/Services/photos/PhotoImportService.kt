package com.recallthat.Services.photos

import com.recallthat.Models.Memory
import com.recallthat.Models.MemorySourceType
import com.recallthat.Models.OCRStatus
import com.recallthat.Persistence.MemoryRepository
import java.util.Date
import java.util.UUID

class PhotoImportService(
    private val photoLibraryService: PhotoLibraryService,
    private val repository: MemoryRepository
) {
    suspend fun importNewScreenshots(): Int {
        if (!photoLibraryService.hasPermission()) return 0

        val allUris = photoLibraryService.fetchScreenshotUris()
        val existing = repository.fetchAll().mapNotNull { it.photoAssetUri }.toSet()
        val newUris = allUris.filter { it !in existing }

        newUris.forEach { uri ->
            val now = Date()
            val memory = Memory(
                id = UUID.randomUUID(),
                sourceType = MemorySourceType.SCREENSHOT,
                photoAssetUri = uri,
                localThumbnailPath = null,
                createdAt = now,
                importedAt = now,
                title = "",
                ocrText = "",
                ocrStatus = OCRStatus.NOT_STARTED,
                searchText = "",
                originalExists = true,
                deletedOriginalAt = null,
                sourceUrl = null
            )
            repository.save(memory)
        }
        return newUris.size
    }
}
