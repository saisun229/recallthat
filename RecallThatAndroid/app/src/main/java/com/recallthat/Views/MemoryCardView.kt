package com.recallthat.Views

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.recallthat.Models.Memory
import com.recallthat.Models.OCRStatus
import java.text.SimpleDateFormat
import java.util.Locale

private val dateFormatter = SimpleDateFormat("MMM d, yyyy", Locale.getDefault())

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun MemoryCardView(
    memory: Memory,
    isSelecting: Boolean = false,
    isSelected: Boolean = false,
    onLongClick: () -> Unit = {},
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .combinedClickable(onLongClick = onLongClick, onClick = onClick),
        shape = RoundedCornerShape(12.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = if (isSelected) 0.dp else 2.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (isSelected)
                MaterialTheme.colorScheme.primaryContainer
            else
                MaterialTheme.colorScheme.surface
        )
    ) {
        Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            if (isSelecting) {
                Checkbox(
                    checked = isSelected,
                    onCheckedChange = null,
                    modifier = Modifier.padding(end = 4.dp)
                )
            }
            ThumbnailView(
                uri = memory.photoAssetUri,
                modifier = Modifier
                    .size(56.dp)
                    .clip(RoundedCornerShape(8.dp))
            )
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = memory.title.ifBlank { "Untitled" },
                    style = MaterialTheme.typography.bodyLarge,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    text = dateFormatter.format(memory.createdAt),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Spacer(Modifier.width(8.dp))
            Box(
                modifier = Modifier
                    .size(10.dp)
                    .background(ocrStatusColor(memory.ocrStatus), CircleShape)
            )
        }
    }
}

private fun ocrStatusColor(status: OCRStatus): Color = when (status) {
    OCRStatus.COMPLETE    -> Color(0xFF34C759)
    OCRStatus.PENDING     -> Color(0xFFFF9500)
    OCRStatus.FAILED      -> Color(0xFFFF3B30)
    OCRStatus.NOT_STARTED -> Color(0xFFAAAAAA)
}
