package com.recallthat.Views

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.recallthat.App.AppEnvironment
import com.recallthat.ViewModels.HomeViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(env: AppEnvironment, onMemoryClick: (String) -> Unit) {
    val vm: HomeViewModel = viewModel()
    val memories by vm.memories.collectAsState()
    val isLoading by vm.isLoading.collectAsState()
    val isRunningOCR by vm.isRunningOCR.collectAsState()
    val ocrProgress by vm.ocrProgress.collectAsState()
    val hasPermission by vm.hasPhotoPermission.collectAsState()
    val errorMessage by vm.errorMessage.collectAsState()
    val isSelecting by vm.isSelecting.collectAsState()
    val selectedIDs by vm.selectedIDs.collectAsState()
    val isSyncing by vm.isSyncing.collectAsState()

    var showSafeDeleteConfirm by remember { mutableStateOf(false) }
    var showHardDeleteConfirm by remember { mutableStateOf(false) }

    // Track whether the current sync was user-initiated (pull gesture)
    var pullRefreshActive by remember { mutableStateOf(false) }
    LaunchedEffect(isSyncing) {
        if (!isSyncing) pullRefreshActive = false
    }

    val permissionToRequest = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
        Manifest.permission.READ_MEDIA_IMAGES
    else
        Manifest.permission.READ_EXTERNAL_STORAGE

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted -> vm.onPermissionResult(granted) }

    LaunchedEffect(Unit) { vm.checkPermission(env) }
    LaunchedEffect(hasPermission) { if (hasPermission) vm.runFullSync(env) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("RecallThat") },
                actions = {
                    if (isSelecting) {
                        TextButton(onClick = { vm.selectAll() }) { Text("All") }
                        TextButton(onClick = { vm.toggleSelecting() }) { Text("Cancel") }
                    } else {
                        TextButton(onClick = { vm.toggleSelecting() }) { Text("Select") }
                    }
                }
            )
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize()) {
            when {
                !hasPermission -> PhotoPermissionView(
                    onRequestPermission = { permissionLauncher.launch(permissionToRequest) }
                )

                isLoading -> CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))

                else -> {
                    Column(modifier = Modifier.fillMaxSize()) {
                        // OCR progress — only shown when indexing
                        if (isRunningOCR) {
                            ocrProgress?.let { p ->
                                LinearProgressIndicator(
                                    progress = { p.completed.toFloat() / p.total.coerceAtLeast(1) },
                                    modifier = Modifier.fillMaxWidth()
                                )
                                Text(
                                    "Indexing ${p.completed} / ${p.total}",
                                    style = MaterialTheme.typography.bodySmall,
                                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                                )
                            } ?: LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
                        }

                        PullToRefreshBox(
                            isRefreshing = pullRefreshActive,
                            onRefresh = {
                                pullRefreshActive = true
                                vm.runFullSync(env)
                            },
                            modifier = Modifier.weight(1f)
                        ) {
                            if (memories.isEmpty()) {
                                Box(
                                    modifier = Modifier.fillMaxSize(),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        "No memories yet.\nPull down to sync.",
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        textAlign = TextAlign.Center
                                    )
                                }
                            } else {
                                LazyColumn(
                                    contentPadding = PaddingValues(
                                        start = 16.dp, end = 16.dp, top = 8.dp,
                                        bottom = if (isSelecting) 88.dp else 16.dp
                                    ),
                                    verticalArrangement = Arrangement.spacedBy(10.dp),
                                    modifier = Modifier.fillMaxSize()
                                ) {
                                    items(memories, key = { it.id.toString() }) { memory ->
                                        MemoryCardView(
                                            memory = memory,
                                            isSelecting = isSelecting,
                                            isSelected = memory.id in selectedIDs,
                                            onLongClick = {
                                                if (!isSelecting) vm.toggleSelecting()
                                                vm.toggleSelection(memory.id)
                                            },
                                            onClick = {
                                                if (isSelecting) vm.toggleSelection(memory.id)
                                                else onMemoryClick(memory.id.toString())
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // Batch action bar — floats above list when selecting
                    if (isSelecting) {
                        Surface(
                            modifier = Modifier
                                .align(Alignment.BottomCenter)
                                .fillMaxWidth(),
                            tonalElevation = 8.dp,
                            shadowElevation = 8.dp
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                val hasSelection = selectedIDs.isNotEmpty()
                                OutlinedButton(
                                    onClick = { showSafeDeleteConfirm = true },
                                    enabled = hasSelection,
                                    modifier = Modifier.weight(1f),
                                    colors = ButtonDefaults.outlinedButtonColors(
                                        contentColor = Color(0xFF34C759)
                                    )
                                ) { Text("Safe Delete") }
                                Button(
                                    onClick = { showHardDeleteConfirm = true },
                                    enabled = hasSelection,
                                    modifier = Modifier.weight(1f),
                                    colors = ButtonDefaults.buttonColors(
                                        containerColor = MaterialTheme.colorScheme.error
                                    )
                                ) { Text("Hard Delete") }
                            }
                        }
                    }
                }
            }

            errorMessage?.let { msg ->
                Snackbar(
                    modifier = Modifier.align(Alignment.BottomCenter).padding(16.dp),
                    action = { TextButton(onClick = { vm.dismissError() }) { Text("Dismiss") } }
                ) { Text(msg) }
            }
        }
    }

    if (showSafeDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { showSafeDeleteConfirm = false },
            title = { Text("Safe Delete") },
            text = {
                Text(
                    "Remove ${selectedIDs.size} original photo(s) from your library? " +
                    "The indexed text is kept so you can still search it."
                )
            },
            confirmButton = {
                TextButton(onClick = { vm.safeDeleteSelected(env); showSafeDeleteConfirm = false }) {
                    Text("Delete Photos", color = Color(0xFF34C759))
                }
            },
            dismissButton = {
                TextButton(onClick = { showSafeDeleteConfirm = false }) { Text("Cancel") }
            }
        )
    }

    if (showHardDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { showHardDeleteConfirm = false },
            title = { Text("Delete Everything") },
            text = {
                Text(
                    "Permanently delete ${selectedIDs.size} item(s) and their original photos? " +
                    "This cannot be undone."
                )
            },
            confirmButton = {
                TextButton(onClick = { vm.hardDeleteSelected(env); showHardDeleteConfirm = false }) {
                    Text("Delete All", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showHardDeleteConfirm = false }) { Text("Cancel") }
            }
        )
    }
}
