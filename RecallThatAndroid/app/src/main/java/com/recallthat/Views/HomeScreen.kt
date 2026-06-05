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
    val isImporting by vm.isImporting.collectAsState()
    val isRunningOCR by vm.isRunningOCR.collectAsState()
    val ocrProgress by vm.ocrProgress.collectAsState()
    val hasPermission by vm.hasPhotoPermission.collectAsState()
    val errorMessage by vm.errorMessage.collectAsState()

    val permissionToRequest = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
        Manifest.permission.READ_MEDIA_IMAGES
    else
        Manifest.permission.READ_EXTERNAL_STORAGE

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted -> vm.onPermissionResult(granted) }

    LaunchedEffect(Unit) {
        vm.checkPermission(env)
        vm.load(env)
    }

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("RecallThat") })
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize()) {
            when {
                !hasPermission -> PhotoPermissionView(
                    onRequestPermission = { permissionLauncher.launch(permissionToRequest) }
                )

                isLoading -> CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))

                else -> Column(modifier = Modifier.fillMaxSize()) {
                    // Action bar
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedButton(
                            onClick = { vm.importScreenshots(env) },
                            enabled = !isImporting && !isRunningOCR,
                            modifier = Modifier.weight(1f)
                        ) {
                            if (isImporting)
                                CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                            else
                                Text("Import")
                        }
                        Button(
                            onClick = { vm.runOCR(env) },
                            enabled = !isRunningOCR && !isImporting,
                            modifier = Modifier.weight(1f)
                        ) {
                            if (isRunningOCR)
                                CircularProgressIndicator(
                                    modifier = Modifier.size(16.dp),
                                    strokeWidth = 2.dp,
                                    color = MaterialTheme.colorScheme.onPrimary
                                )
                            else
                                Text("Index")
                        }
                    }

                    // OCR progress
                    ocrProgress?.let { p ->
                        LinearProgressIndicator(
                            progress = { p.completed.toFloat() / p.total.coerceAtLeast(1) },
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)
                        )
                        Text(
                            text = "Indexing ${p.completed} / ${p.total}",
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                        )
                    }

                    if (memories.isEmpty()) {
                        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            Text("No memories yet. Tap Import to get started.",
                                color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    } else {
                        LazyColumn(
                            contentPadding = PaddingValues(16.dp),
                            verticalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            items(memories, key = { it.id.toString() }) { memory ->
                                MemoryCardView(memory = memory) {
                                    onMemoryClick(memory.id.toString())
                                }
                            }
                        }
                    }
                }
            }

            // Error snackbar
            errorMessage?.let { msg ->
                Snackbar(
                    modifier = Modifier.align(Alignment.BottomCenter).padding(16.dp),
                    action = {
                        TextButton(onClick = { vm.dismissError() }) { Text("Dismiss") }
                    }
                ) { Text(msg) }
            }
        }
    }
}
