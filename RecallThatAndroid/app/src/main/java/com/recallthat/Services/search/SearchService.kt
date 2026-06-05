package com.recallthat.Services.search

import com.recallthat.Models.Memory

interface SearchService {
    fun search(query: String, memories: List<Memory>): List<Memory>
}
