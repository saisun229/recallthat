package com.recallthat.Services.photos

interface PhotoLibraryService {
    fun hasPermission(): Boolean
    suspend fun fetchScreenshotUris(): List<String>
    suspend fun deleteAsset(uri: String): Boolean
    suspend fun deleteAssets(uris: List<String>): Boolean
}
