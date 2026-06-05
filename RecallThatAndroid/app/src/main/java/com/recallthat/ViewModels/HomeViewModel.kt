package com.recallthat.ViewModels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.recallthat.App.AppEnvironment
import com.recallthat.Models.Memory
import com.recallthat.Models.OCRStatus
import com.recallthat.Services.ocr.OCRProgress
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import java.util.UUID

class HomeViewModel : ViewModel() {

    private val _memories = MutableStateFlow<List<Memory>>(emptyList())
    val memories: StateFlow<List<Memory>> = _memories

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading

    private val _isImporting = MutableStateFlow(false)
    val isImporting: StateFlow<Boolean> = _isImporting

    private val _isRunningOCR = MutableStateFlow(false)
    val isRunningOCR: StateFlow<Boolean> = _isRunningOCR

    private val _ocrProgress = MutableStateFlow<OCRProgress?>(null)
    val ocrProgress: StateFlow<OCRProgress?> = _ocrProgress

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage

    private val _hasPhotoPermission = MutableStateFlow(false)
    val hasPhotoPermission: StateFlow<Boolean> = _hasPhotoPermission

    private val _isSelecting = MutableStateFlow(false)
    val isSelecting: StateFlow<Boolean> = _isSelecting

    private val _selectedIDs = MutableStateFlow<Set<UUID>>(emptySet())
    val selectedIDs: StateFlow<Set<UUID>> = _selectedIDs

    fun checkPermission(env: AppEnvironment) {
        _hasPhotoPermission.value = env.photoLibraryService.hasPermission()
    }

    fun onPermissionResult(granted: Boolean) {
        _hasPhotoPermission.value = granted
    }

    fun load(env: AppEnvironment) {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                _memories.value = env.memoryRepository.fetchAll()
            } catch (e: Exception) {
                _errorMessage.value = "Failed to load memories"
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun importScreenshots(env: AppEnvironment) {
        viewModelScope.launch {
            _isImporting.value = true
            try {
                env.photoImportService.importNewScreenshots()
                _memories.value = env.memoryRepository.fetchAll()
            } catch (e: Exception) {
                _errorMessage.value = "Import failed"
            } finally {
                _isImporting.value = false
            }
        }
    }

    fun runOCR(env: AppEnvironment) {
        viewModelScope.launch {
            _isRunningOCR.value = true
            _ocrProgress.value = null
            try {
                env.ocrPipelineService.processQueue { progress ->
                    _ocrProgress.value = progress
                }
                _memories.value = env.memoryRepository.fetchAll()
            } catch (e: Exception) {
                _errorMessage.value = "OCR failed"
            } finally {
                _isRunningOCR.value = false
                _ocrProgress.value = null
            }
        }
    }

    fun toggleSelecting() {
        _isSelecting.value = !_isSelecting.value
        if (!_isSelecting.value) _selectedIDs.value = emptySet()
    }

    fun toggleSelection(id: UUID) {
        val current = _selectedIDs.value.toMutableSet()
        if (id in current) current.remove(id) else current.add(id)
        _selectedIDs.value = current
    }

    fun selectAll() {
        _selectedIDs.value = _memories.value.map { it.id }.toSet()
    }

    fun hardDeleteSelected(env: AppEnvironment) {
        val ids = _selectedIDs.value.toSet()
        viewModelScope.launch {
            try {
                ids.forEach { env.memoryRepository.delete(it) }
                _memories.value = env.memoryRepository.fetchAll()
                _selectedIDs.value = emptySet()
                _isSelecting.value = false
            } catch (e: Exception) {
                _errorMessage.value = "Delete failed"
            }
        }
    }

    fun safeDeleteSelected(env: AppEnvironment) {
        val ids = _selectedIDs.value.toSet()
        viewModelScope.launch {
            try {
                val toDelete = _memories.value.filter { it.id in ids && it.originalExists }
                val uris = toDelete.mapNotNull { it.photoAssetUri }
                env.photoLibraryService.deleteAssets(uris)
                toDelete.forEach { memory ->
                    env.memoryRepository.update(
                        memory.copy(originalExists = false, deletedOriginalAt = java.util.Date())
                    )
                }
                _memories.value = env.memoryRepository.fetchAll()
                _selectedIDs.value = emptySet()
                _isSelecting.value = false
            } catch (e: Exception) {
                _errorMessage.value = "Delete failed"
            }
        }
    }

    fun dismissError() { _errorMessage.value = null }
}
