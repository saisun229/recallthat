package com.recallthat.Views

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
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

@Composable
fun MemoryCardView(memory: Memory, onClick: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(12.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
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
    OCRStatus.COMPLETE    -> Color(0xFF34C759)  // green
    OCRStatus.PENDING     -> Color(0xFFFF9500)  // amber
    OCRStatus.FAILED      -> Color(0xFFFF3B30)  // red
    OCRStatus.NOT_STARTED -> Color(0xFFAAAAAA)  // grey
}
