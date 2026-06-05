package com.recallthat.ViewModels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.recallthat.App.AppEnvironment
import com.recallthat.Models.Memory
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import java.util.Date

class MemoryDetailViewModel(val memory: Memory) : ViewModel() {

    private val _currentMemory = MutableStateFlow(memory)
    val currentMemory: StateFlow<Memory> = _currentMemory

    private val _showDeleteConfirmation = MutableStateFlow(false)
    val showDeleteConfirmation: StateFlow<Boolean> = _showDeleteConfirmation

    private val _isDeleting = MutableStateFlow(false)
    val isDeleting: StateFlow<Boolean> = _isDeleting

    private val _deleteError = MutableStateFlow<String?>(null)
    val deleteError: StateFlow<String?> = _deleteError

    private val _deleted = MutableStateFlow(false)
    val deleted: StateFlow<Boolean> = _deleted

    fun requestDeleteOriginal() { _showDeleteConfirmation.value = true }
    fun cancelDelete() { _showDeleteConfirmation.value = false }

    fun deleteOriginal(env: AppEnvironment) {
        val uri = _currentMemory.value.photoAssetUri ?: return
        viewModelScope.launch {
            _isDeleting.value = true
            _showDeleteConfirmation.value = false
            try {
                env.photoLibraryService.deleteAsset(uri)
                val updated = _currentMemory.value.copy(
                    originalExists = false,
                    deletedOriginalAt = Date()
                )
                env.memoryRepository.update(updated)
                _currentMemory.value = updated
            } catch (e: Exception) {
                _deleteError.value = "Could not delete photo"
            } finally {
                _isDeleting.value = false
            }
        }
    }

    fun hardDelete(env: AppEnvironment, onDeleted: () -> Unit) {
        viewModelScope.launch {
            _isDeleting.value = true
            try {
                env.memoryRepository.delete(_currentMemory.value.id)
                _deleted.value = true
                onDeleted()
            } catch (e: Exception) {
                _deleteError.value = "Could not delete memory"
            } finally {
                _isDeleting.value = false
            }
        }
    }

    fun dismissError() { _deleteError.value = null }
}
