package tl.knyt.mimonik

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.clickable
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Zvýrazní hledaný text v úryvku (bez ohledu na diakritiku a velikost písmen). */
private fun zvyrazniUryvek(uryvek: String, dotaz: String, barva: Color) = buildAnnotatedString {
    val q = normalizuj(dotaz.trim()).replace(Regex("\\s+"), " ")
    val (text, mapa) = normalizujSMapou(uryvek)
    var od = 0
    var vykresleno = 0
    while (q.isNotEmpty()) {
        val i = text.indexOf(q, od)
        if (i < 0) break
        val z = mapa[i]
        val k = (mapa[i + q.length - 1] + 1).coerceAtMost(uryvek.length)
        if (z >= vykresleno) {
            append(uryvek.substring(vykresleno, z))
            withStyle(SpanStyle(fontWeight = FontWeight.Bold, background = barva)) { append(uryvek.substring(z, k)) }
            vykresleno = k
        }
        od = i + q.length
    }
    append(uryvek.substring(vykresleno))
}

/** Hledání textu napříč všemi staženými čísly. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HledaniScreen(store: CislaStore, onOtevrit: (Cislo, Int, String) -> Unit, onBack: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val cisla by store.cisla.collectAsStateWithLifecycle()
    val stazena by store.stazena.collectAsStateWithLifecycle()

    var dotaz by rememberSaveable { mutableStateOf("") }
    var indexy by remember { mutableStateOf<List<IndexCisla>>(emptyList()) }
    var indexPrubeh by remember { mutableStateOf<Pair<Int, Int>?>(null) }
    var vysledky by remember { mutableStateOf<List<NalezVCisle>>(emptyList()) }
    var stahuje by remember { mutableStateOf<Pair<Int, Int>?>(null) }
    var selhaloStazeni by remember { mutableStateOf(0) }

    // index se staví na pozadí pro všechna stažená čísla (cache na disku, takže podruhé je okamžitý)
    LaunchedEffect(cisla, stazena) {
        indexPrubeh = 0 to 0
        indexy = IndexStore.zajistiVse(ctx, cisla) { h, c -> indexPrubeh = h to c }
        indexPrubeh = null
    }

    LaunchedEffect(indexy, dotaz) {
        if (dotaz.isBlank()) { vysledky = emptyList(); return@LaunchedEffect }
        delay(250)
        vysledky = withContext(Dispatchers.Default) { Vyhledavac.najdi(indexy, dotaz) }
    }

    val chybejici = cisla.filter { it.id !in stazena }
    val poradi = cisla.withIndex().associate { it.value.id to it.index }
    val skupiny = vysledky.groupBy { it.cisloId }.entries.sortedBy { poradi[it.key] ?: Int.MAX_VALUE }
    val zvyraznena = MaterialTheme.colorScheme.tertiaryContainer

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    TextField(
                        value = dotaz, onValueChange = { dotaz = it },
                        placeholder = { Text("Hledat ve všech číslech") }, singleLine = true,
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                        colors = TextFieldDefaults.colors(
                            focusedContainerColor = Color.Transparent, unfocusedContainerColor = Color.Transparent
                        ),
                        modifier = Modifier.fillMaxWidth()
                    )
                },
                navigationIcon = { IconButton(onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Zpět") } },
                actions = {
                    if (dotaz.isNotEmpty()) IconButton({ dotaz = "" }) { Icon(Icons.Default.Close, "Smazat") }
                }
            )
        }
    ) { pad ->
        LazyColumn(Modifier.padding(pad).fillMaxSize(), contentPadding = PaddingValues(bottom = 24.dp)) {
            item {
                Column(Modifier.padding(horizontal = 16.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    indexPrubeh?.let { (h, c) ->
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                            CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
                            Text("Připravuji hledání… $h z $c", style = MaterialTheme.typography.bodySmall)
                        }
                    }
                    if (chybejici.isNotEmpty()) {
                        Text(
                            "Hledá se jen ve stažených číslech (${cisla.size - chybejici.size} z ${cisla.size}).",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        val s = stahuje
                        if (s == null) {
                            Button(onClick = {
                                scope.launch {
                                    selhaloStazeni = 0
                                    for ((i, c) in chybejici.withIndex()) {
                                        stahuje = i to chybejici.size
                                        try {
                                            CislaStore.stahniPDF(ctx, c, jenWifi = false)
                                        } catch (e: CancellationException) {
                                            throw e
                                        } catch (e: Exception) {
                                            selhaloStazeni++
                                        }
                                        store.obnovStazena()
                                    }
                                    stahuje = null
                                }
                            }) { Text("Stáhnout všechna čísla (${chybejici.size})") }
                        } else {
                            Text("Stahuji ${s.first + 1} z ${s.second}…", style = MaterialTheme.typography.bodySmall)
                            LinearProgressIndicator(progress = { s.first.toFloat() / s.second }, modifier = Modifier.fillMaxWidth())
                        }
                        if (selhaloStazeni > 0 && stahuje == null) {
                            Text(
                                "$selhaloStazeni čísel se nepodařilo stáhnout. Zkontroluj připojení.",
                                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error
                            )
                        }
                    }
                    if (dotaz.isNotBlank() && vysledky.isEmpty() && indexPrubeh == null) {
                        Text("Nic nenalezeno.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    if (vysledky.size >= Vyhledavac.MAX_NALEZU) {
                        Text("Zobrazeno prvních ${Vyhledavac.MAX_NALEZU} nálezů, upřesni hledání.", style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
            for ((id, nalezy) in skupiny) {
                val cislo = cisla.firstOrNull { it.id == id } ?: continue
                item(key = "h_$id") {
                    Text(
                        "${cislo.nazev}  ·  ${nalezy.size}×",
                        style = MaterialTheme.typography.titleSmall,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)
                    )
                }
                items(nalezy, key = { "${it.cisloId}_${it.strana}_${it.uryvek.hashCode()}" }) { n ->
                    Column(
                        Modifier.fillMaxWidth()
                            .clickable { onOtevrit(cislo, n.strana, dotaz.trim()) }
                            .padding(horizontal = 16.dp, vertical = 8.dp)
                    ) {
                        Text("Strana ${n.strana + 1}", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(zvyrazniUryvek(n.uryvek, dotaz, zvyraznena), style = MaterialTheme.typography.bodyMedium)
                    }
                    HorizontalDivider()
                }
            }
        }
    }
}
