package com.recallthat.Persistence

import com.recallthat.Models.Memory
import java.util.UUID

interface MemoryRepository {
    suspend fun fetchAll(): List<Memory>
    suspend fun fetch(id: UUID): Memory?
    suspend fun save(memory: Memory)
    suspend fun update(memory: Memory)
    suspend fun delete(id: UUID)
}
