package com.recallthat.Services.ocr

import android.net.Uri
import com.recallthat.Models.OCRStatus
import com.recallthat.Persistence.MemoryRepository

data class OCRProgress(val completed: Int, val total: Int)

class OCRPipelineService(
    private val ocrService: OCRService,
    private val repository: MemoryRepository
) {
    suspend fun processQueue(onProgress: (OCRProgress) -> Unit) {
        val pending = repository.fetchAll().filter { it.ocrStatus == OCRStatus.NOT_STARTED }
        val total = pending.size
        var completed = 0

        for (memory in pending) {
            val uri = memory.photoAssetUri ?: continue
            val withPending = memory.copy(ocrStatus = OCRStatus.PENDING)
            repository.update(withPending)

            val (newStatus, text) = try {
                val extracted = ocrService.extractText(Uri.parse(uri))
                OCRStatus.COMPLETE to extracted
            } catch (e: Exception) {
                OCRStatus.FAILED to ""
            }

            val title = text.lines()
                .firstOrNull { it.trim().length >= 3 }
                ?.trim()
                ?: ""
            val searchText = "$title $text".lowercase()

            repository.update(
                memory.copy(
                    ocrStatus = newStatus,
                    ocrText = text,
                    title = title,
                    searchText = searchText
                )
            )
            completed++
            onProgress(OCRProgress(completed, total))
        }
    }
}
