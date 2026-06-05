package com.recallthat.Services.photos

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class DefaultPhotoLibraryService(private val context: Context) : PhotoLibraryService {

    override fun hasPermission(): Boolean {
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
            android.Manifest.permission.READ_MEDIA_IMAGES
        else
            android.Manifest.permission.READ_EXTERNAL_STORAGE
        return context.checkSelfPermission(permission) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    override suspend fun fetchScreenshotUris(): List<String> = withContext(Dispatchers.IO) {
        val uris = mutableListOf<String>()
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        else
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI

        val projection = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.DATE_TAKEN
        )

        // On API 29+, filter by RELATIVE_PATH containing "Screenshots"
        // On API 26-28, filter by DISPLAY_NAME prefix
        val (selection, selectionArgs) = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            "${MediaStore.Images.Media.RELATIVE_PATH} LIKE ?" to arrayOf("%Screenshots%")
        } else {
            "${MediaStore.Images.Media.DISPLAY_NAME} LIKE ?" to arrayOf("Screenshot%")
        }

        context.contentResolver.query(
            collection, projection, selection, selectionArgs,
            "${MediaStore.Images.Media.DATE_TAKEN} DESC"
        )?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            while (cursor.moveToNext()) {
                val id = cursor.getLong(idCol)
                val uri = ContentUris.withAppendedId(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id
                )
                uris.add(uri.toString())
            }
        }
        uris
    }

    override suspend fun deleteAsset(uri: String): Boolean =
        deleteAssets(listOf(uri))

    override suspend fun deleteAssets(uris: List<String>): Boolean = withContext(Dispatchers.IO) {
        try {
            uris.forEach { uriString ->
                val uri = Uri.parse(uriString)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val values = ContentValues().apply {
                        put(MediaStore.Images.Media.IS_PENDING, 1)
                    }
                    context.contentResolver.update(uri, values, null, null)
                }
                context.contentResolver.delete(uri, null, null)
            }
            true
        } catch (e: Exception) {
            false
        }
    }
}
