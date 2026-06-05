package com.recallthat.ViewModels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.recallthat.App.AppEnvironment
import com.recallthat.Models.Memory
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class SearchViewModel : ViewModel() {

    private val _query = MutableStateFlow("")
    val query: StateFlow<String> = _query

    private val _results = MutableStateFlow<List<Memory>>(emptyList())
    val results: StateFlow<List<Memory>> = _results

    private var allMemories: List<Memory> = emptyList()

    fun loadMemories(env: AppEnvironment) {
        viewModelScope.launch {
            allMemories = env.memoryRepository.fetchAll()
            applySearch(env)
        }
    }

    fun onQueryChange(newQuery: String, env: AppEnvironment) {
        _query.value = newQuery
        applySearch(env)
    }

    private fun applySearch(env: AppEnvironment) {
        _results.value = env.searchService.search(_query.value, allMemories)
    }
}
