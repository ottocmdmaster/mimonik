package tl.knyt.mimonik

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/** Sheet se záložkami a poznámkami; klepnutí přejde na stranu. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ZalozkyListSheet(
    zalozky: List<Int>,
    anotace: List<Anotace>,
    onJdi: (Int) -> Unit,
    onSmazZalozku: (Int) -> Unit,
    onSmazAnotaci: (Anotace) -> Unit,
    onZavri: () -> Unit
) {
    ModalBottomSheet(onDismissRequest = onZavri) {
        LazyColumn(Modifier.padding(horizontal = 16.dp).padding(bottom = 24.dp)) {
            item { Text("Záložky", style = MaterialTheme.typography.titleMedium) }
            if (zalozky.isEmpty()) item {
                Text("Zatím žádné. V nabídce „…“ přidáš záložku na aktuální stranu.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(vertical = 8.dp))
            }
            items(zalozky) { s ->
                Row(Modifier.fillMaxWidth().clickable { onJdi(s); onZavri() }.padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically) {
                    Text("Strana ${s + 1}", Modifier.weight(1f))
                    IconButton({ onSmazZalozku(s) }) { Icon(Icons.Default.Delete, "Smazat") }
                }
            }
            item { Text("Zvýraznění a poznámky", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 16.dp)) }
            if (anotace.isEmpty()) item {
                Text("Zatím žádné.", color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(vertical = 8.dp))
            }
            items(anotace.sortedWith(compareBy({ it.strana }, { it.y }))) { a ->
                Row(Modifier.fillMaxWidth().clickable { onJdi(a.strana); onZavri() }.padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(if (a.typ == Anotace.POZNAMKA) (a.text.ifBlank { "Poznámka" }) else "Zvýraznění")
                        Text("Strana ${a.strana + 1}", style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    IconButton({ onSmazAnotaci(a) }) { Icon(Icons.Default.Delete, "Smazat") }
                }
            }
        }
    }
}

/** Panel „Zobrazení": režim čtení, jas a zoom. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ZobrazeniSheet(
    rezim: RezimCteni,
    onRezim: (RezimCteni) -> Unit,
    jas: Float,
    onJas: (Float) -> Unit,
    zoom: Float,
    onZoom: (Float) -> Unit,
    onZavri: () -> Unit
) {
    ModalBottomSheet(onDismissRequest = onZavri) {
        Column(Modifier.padding(horizontal = 16.dp).padding(bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Režim čtení", style = MaterialTheme.typography.titleMedium)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(RezimCteni.NORMALNI to "Normální", RezimCteni.SEPIE to "Sépie", RezimCteni.TMAVY to "Tmavý").forEach { (r, n) ->
                    FilterChip(selected = rezim == r, onClick = { onRezim(r) }, label = { Text(n) })
                }
            }
            Text("Jas", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 8.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Slider(value = if (jas < 0f) 0.5f else jas, onValueChange = onJas, valueRange = 0.02f..1f, modifier = Modifier.weight(1f))
                TextButton({ onJas(-1f) }) { Text("Systém") }
            }
            Text("Zoom ${(zoom * 100).toInt()} %", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                OutlinedButton({ onZoom((zoom - 0.25f).coerceAtLeast(1f)) }) { Text("−") }
                OutlinedButton({ onZoom((zoom + 0.25f).coerceAtMost(4f)) }) { Text("+") }
                Button({ onZoom(1f) }) { Text("Na šířku") }
            }
        }
    }
}

/** Editor textu poznámky; prázdný text nebo „Smazat" poznámku odstraní. */
@Composable
fun PoznamkaDialog(
    puvodni: String,
    novaPoznamka: Boolean,
    onUloz: (String) -> Unit,
    onSmaz: () -> Unit,
    onZrus: () -> Unit
) {
    var text by remember { mutableStateOf(puvodni) }
    AlertDialog(
        onDismissRequest = onZrus,
        title = { Text(if (novaPoznamka) "Nová poznámka" else "Poznámka") },
        text = { OutlinedTextField(text, { text = it }, Modifier.fillMaxWidth(), minLines = 3) },
        confirmButton = { TextButton({ if (text.isBlank()) onSmaz() else onUloz(text.trim()) }) { Text("Uložit") } },
        dismissButton = {
            Row {
                if (!novaPoznamka) TextButton(onSmaz) { Text("Smazat") }
                TextButton(onZrus) { Text("Zrušit") }
            }
        }
    )
}
