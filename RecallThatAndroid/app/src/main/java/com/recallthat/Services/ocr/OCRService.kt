package com.recallthat.Services.ocr

import android.net.Uri

interface OCRService {
    suspend fun extractText(uri: Uri): String
}
