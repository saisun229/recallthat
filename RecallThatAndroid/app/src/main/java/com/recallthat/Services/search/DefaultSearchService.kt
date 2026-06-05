package com.recallthat.Services.search

import com.recallthat.Models.Memory

class DefaultSearchService : SearchService {
    override fun search(query: String, memories: List<Memory>): List<Memory> {
        if (query.isBlank()) return memories
        return memories.filter { it.searchText.contains(query.trim(), ignoreCase = true) }
    }
}
