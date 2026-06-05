package com.recallthat.Services.ocr

import android.content.Context
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

class DefaultOCRService(private val context: Context) : OCRService {

    private val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    override suspend fun extractText(uri: Uri): String {
        val image = InputImage.fromFilePath(context, uri)
        return suspendCancellableCoroutine { cont ->
            recognizer.process(image)
                .addOnSuccessListener { result ->
                    cont.resume(result.textBlocks.joinToString("\n") { it.text })
                }
                .addOnFailureListener { e ->
                    cont.resumeWithException(e)
                }
        }
    }
}
