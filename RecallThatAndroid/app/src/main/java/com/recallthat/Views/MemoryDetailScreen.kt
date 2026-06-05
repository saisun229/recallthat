package com.recallthat.Views

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.recallthat.App.AppEnvironment
import com.recallthat.Models.Memory
import com.recallthat.ViewModels.MemoryDetailViewModel
import java.text.SimpleDateFormat
import java.util.Locale

private val dateFormatter = SimpleDateFormat("MMM d, yyyy 'at' h:mm a", Locale.getDefault())

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MemoryDetailScreen(
    memory: Memory,
    env: AppEnvironment,
    onBack: () -> Unit
) {
    val vm = remember { MemoryDetailViewModel(memory) }
    val current by vm.currentMemory.collectAsState()
    val showConfirm by vm.showDeleteConfirmation.collectAsState()
    val isDeleting by vm.isDeleting.collectAsState()
    val deleteError by vm.deleteError.collectAsState()

    if (showConfirm) {
        AlertDialog(
            onDismissRequest = { vm.cancelDelete() },
            title = { Text("Delete Original?") },
            text = { Text("The screenshot will be removed from your gallery. The indexed text stays in RecallThat.") },
            confirmButton = {
                TextButton(onClick = { vm.deleteOriginal(env) }) { Text("Delete") }
            },
            dismissButton = {
                TextButton(onClick = { vm.cancelDelete() }) { Text("Cancel") }
            }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(current.title.ifBlank { "Memory" }) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            if (current.photoAssetUri != null) {
                ThumbnailView(
                    uri = current.photoAssetUri,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(220.dp)
                )
            }

            // Metadata
            Text("Captured: ${dateFormatter.format(current.createdAt)}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text("Status: ${current.ocrStatus.label}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant)

            HorizontalDivider()

            // OCR text
            if (current.ocrText.isBlank()) {
                Text("No text indexed yet.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            } else {
                Text(current.ocrText, style = MaterialTheme.typography.bodyMedium)
            }

            HorizontalDivider()

            // Actions
            if (current.originalExists && current.photoAssetUri != null) {
                OutlinedButton(
                    onClick = { vm.requestDeleteOriginal() },
                    enabled = !isDeleting,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("Delete Original Screenshot")
                }
            }

            Button(
                onClick = { vm.hardDelete(env) { onBack() } },
                enabled = !isDeleting,
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.error
                ),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Remove from RecallThat")
            }

            if (isDeleting) {
                LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
            }

            deleteError?.let { err ->
                Text(err, color = MaterialTheme.colorScheme.error)
                TextButton(onClick = { vm.dismissError() }) { Text("Dismiss") }
            }
        }
    }
}
