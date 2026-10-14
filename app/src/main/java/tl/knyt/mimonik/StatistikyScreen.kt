package tl.knyt.mimonik

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

/** „1 h 05 min“, „12 min“, „méně než minuta“. */
fun formatDoba(ms: Long): String {
    val min = ms / 60_000
    return when {
        min >= 60 -> "${min / 60} h ${"%02d".format(min % 60)} min"
        min >= 1 -> "$min min"
        ms > 0 -> "méně než minuta"
        else -> "0 min"
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StatistikyScreen(store: CislaStore, onBack: () -> Unit) {
    val ctx = LocalContext.current
    val cisla by store.cisla.collectAsStateWithLifecycle()
    val s = Stav.statistiky(ctx, cisla)

    Scaffold(topBar = {
        TopAppBar(
            title = { Text("Statistiky čtení") },
            navigationIcon = { IconButton(onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Zpět") } }
        )
    }) { pad ->
        Column(
            Modifier.padding(pad).fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Karta("Přečtená čísla", "${s.prectena} z ${s.celkem}") {
                LinearProgressIndicator(
                    progress = { if (s.celkem == 0) 0f else s.prectena.toFloat() / s.celkem },
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
                )
            }
            Karta("Otevřené stránky", "${s.otevreneStrany}")
            Karta("Doba čtení", formatDoba(s.dobaMs))
            Karta(
                "Nejčtenější číslo",
                s.nejctenejsi?.nazev ?: "Zatím žádné",
                s.nejctenejsi?.let { "${formatDoba(s.nejctenejsiDobaMs)}, otevřeno ${s.nejctenejsiOtevreni}×" }
            )
        }
    }
}

@Composable
private fun Karta(nadpis: String, hodnota: String, podtitul: String? = null, obsah: @Composable () -> Unit = {}) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Text(nadpis, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
            Text(hodnota, style = MaterialTheme.typography.headlineSmall)
            podtitul?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant) }
            obsah()
        }
    }
}
