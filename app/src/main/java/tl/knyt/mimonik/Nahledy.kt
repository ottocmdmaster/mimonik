package tl.knyt.mimonik

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.produceState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.dp

/** Šířka miniatury v pixelech; stránky se renderují přes sdílenou cache PdfStranky. */
private const val NAHLED_PX = 220

/** Mřížka miniatur všech stran; klepnutí skočí na stranu, aktuální je zvýrazněná. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NahledySheet(
    stranky: PdfStranky,
    aktualni: Int,
    rezim: RezimCteni,
    onJdi: (Int) -> Unit,
    onZavri: () -> Unit
) {
    val vyska = (LocalConfiguration.current.screenHeightDp * 0.65f).dp
    val stav = rememberLazyGridState(initialFirstVisibleItemIndex = (aktualni - 3).coerceAtLeast(0))
    ModalBottomSheet(onDismissRequest = onZavri) {
        LazyVerticalGrid(
            columns = GridCells.Adaptive(96.dp),
            state = stav,
            modifier = Modifier.fillMaxWidth().height(vyska),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(12.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            items((0 until stranky.pocet).toList(), key = { it }) { i ->
                val bitmapa by produceState<ImageBitmap?>(null, i) {
                    value = try { stranky.vykresli(i, NAHLED_PX).asImageBitmap() } catch (e: Exception) { null }
                }
                val jeAktualni = i == aktualni
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    androidx.compose.foundation.layout.Box(
                        Modifier
                            .fillMaxWidth()
                            .aspectRatio(1f / stranky.pomery[i])
                            .background(Color.White)
                            .border(
                                if (jeAktualni) BorderStroke(3.dp, MaterialTheme.colorScheme.primary)
                                else BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
                            )
                            .clickable { onJdi(i); onZavri() }
                    ) {
                        bitmapa?.let {
                            Image(
                                it, "Strana ${i + 1}", Modifier.fillMaxWidth(),
                                contentScale = ContentScale.FillBounds, colorFilter = filtrRezimu(rezim)
                            )
                        }
                    }
                    Text(
                        "${i + 1}",
                        style = MaterialTheme.typography.labelMedium,
                        color = if (jeAktualni) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 2.dp)
                    )
                }
            }
        }
    }
}
