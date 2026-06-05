package com.recallthat.App

import android.content.Context
import com.recallthat.Persistence.MemoryDatabase
import com.recallthat.Persistence.MemoryRepository
import com.recallthat.Persistence.RoomMemoryRepository
import com.recallthat.Services.ocr.DefaultOCRService
import com.recallthat.Services.ocr.OCRPipelineService
import com.recallthat.Services.ocr.OCRService
import com.recallthat.Services.photos.DefaultPhotoLibraryService
import com.recallthat.Services.photos.PhotoImportService
import com.recallthat.Services.photos.PhotoLibraryService
import com.recallthat.Services.search.DefaultSearchService
import com.recallthat.Services.search.SearchService

class AppEnvironment(context: Context) {
    private val db = MemoryDatabase.getInstance(context)

    val memoryRepository: MemoryRepository = RoomMemoryRepository(db.memoryDao())
    val photoLibraryService: PhotoLibraryService = DefaultPhotoLibraryService(context)
    val photoImportService = PhotoImportService(photoLibraryService, memoryRepository)
    val ocrService: OCRService = DefaultOCRService(context)
    val ocrPipelineService = OCRPipelineService(ocrService, memoryRepository)
    val searchService: SearchService = DefaultSearchService()
}
