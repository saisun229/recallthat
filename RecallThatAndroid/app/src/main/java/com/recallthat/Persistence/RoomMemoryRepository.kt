package com.recallthat.Persistence

import com.recallthat.Models.Memory
import java.util.UUID

class RoomMemoryRepository(private val dao: MemoryDao) : MemoryRepository {

    override suspend fun fetchAll(): List<Memory> =
        dao.queryAll().map { it.toDomain() }

    override suspend fun fetch(id: UUID): Memory? =
        dao.queryById(id.toString())?.toDomain()

    override suspend fun save(memory: Memory) =
        dao.insertOrReplace(MemoryEntity.fromDomain(memory))

    override suspend fun update(memory: Memory) =
        dao.update(MemoryEntity.fromDomain(memory))

    override suspend fun delete(id: UUID) =
        dao.deleteById(id.toString())
}
