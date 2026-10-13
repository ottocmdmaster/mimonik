package tl.knyt.mimonik

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DownloadForOffline
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.StarBorder
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlinx.coroutines.launch
import java.text.Normalizer

private fun bezDiakritiky(s: String): String =
    Normalizer.normalize(s, Normalizer.Form.NFD).replace(Regex("\\p{Mn}+"), "").lowercase()

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(store: CislaStore, onOtevrit: (Cislo) -> Unit, onNastaveni: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val cisla by store.cisla.collectAsStateWithLifecycle()
    val nacita by store.nacita.collectAsStateWithLifecycle()
    val chyba by store.chyba.collectAsStateWithLifecycle()
    val stazena by store.stazena.collectAsStateWithLifecycle()

    var hledani by rememberSaveable { mutableStateOf<String?>(null) }
    var jenOblibene by rememberSaveable { mutableStateOf(false) }

    // při otevření appky načíst seznam; uživatel o číslech ví, takže se neoznamují
    LaunchedEffect(Unit) {
        store.obnov()
        if (Nastaveni.zapnuto(ctx)) Notifier.oznacJakoVidene(ctx, store.cisla.value)
    }

    @Suppress("UNUSED_VARIABLE")
    val verzeStavu = Stav.verze // překreslí seznam po změně přečtených/oblíbených

    val filtr = cisla.filter { c ->
        (!jenOblibene || Stav.jePoblibene(ctx, c.id)) &&
            (hledani.isNullOrBlank() || bezDiakritiky(c.nazev).contains(bezDiakritiky(hledani!!.trim())))
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    if (hledani != null) {
                        TextField(
                            value = hledani ?: "",
                            onValueChange = { hledani = it },
                            placeholder = { Text("Hledat číslo") },
                            singleLine = true,
                            colors = TextFieldDefaults.colors(
                                focusedContainerColor = Color.Transparent,
                                unfocusedContainerColor = Color.Transparent
                            ),
                            modifier = Modifier.fillMaxWidth()
                        )
                    } else {
                        Text("Mimoník")
                    }
                },
                actions = {
                    if (hledani != null) {
                        IconButton(onClick = { hledani = null }) {
                            Icon(Icons.Default.Close, contentDescription = "Zavřít hledání")
                        }
                    } else {
                        IconButton(onClick = { hledani = "" }) {
                            Icon(Icons.Default.Search, contentDescription = "Hledat")
                        }
                    }
                    IconButton(onClick = { jenOblibene = !jenOblibene }) {
                        Icon(
                            if (jenOblibene) Icons.Default.Star else Icons.Outlined.StarBorder,
                            contentDescription = "Jen oblíbená",
                            tint = if (jenOblibene) MaterialTheme.colorScheme.secondary else MaterialTheme.colorScheme.onSurface
                        )
                    }
                    IconButton(onClick = onNastaveni) {
                        Icon(Icons.Default.Notifications, contentDescription = "Nastavení upozornění")
                    }
                }
            )
        }
    ) { pad ->
        PullToRefreshBox(
            isRefreshing = nacita,
            onRefresh = { scope.launch { store.obnov() } },
            modifier = Modifier.padding(pad).fillMaxSize()
        ) {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(bottom = 24.dp)
            ) {
                chyba?.let {
                    item {
                        Text(
                            it,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                        )
                    }
                }
                val nejnovejsi = cisla.firstOrNull()
                if (nejnovejsi != null && hledani == null && !jenOblibene) {
                    item {
                        Card(
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp)
                                .clickable { onOtevrit(nejnovejsi) }
                        ) {
                            Column(Modifier.padding(16.dp)) {
                                Text("Číst nejnovější číslo", style = MaterialTheme.typography.titleMedium)
                                Text(nejnovejsi.nazev, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
                item {
                    Text(
                        if (jenOblibene) "Oblíbená čísla" else "Všechna čísla",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                    )
                }
                if (filtr.isEmpty() && !nacita) {
                    item {
                        Text(
                            when {
                                cisla.isEmpty() -> "Zatím tu nic není."
                                jenOblibene -> "Žádná oblíbená čísla."
                                else -> "Nic nenalezeno."
                            },
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(16.dp)
                        )
                    }
                }
                items(filtr, key = { it.id }) { c ->
                    val prectene = Stav.jePrectene(ctx, c.id)
                    val oblibene = Stav.jePoblibene(ctx, c.id)
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onOtevrit(c) }
                            .padding(start = 16.dp, top = 4.dp, bottom = 4.dp)
                    ) {
                        Box(
                            Modifier
                                .size(10.dp)
                                .clip(CircleShape)
                                .let { if (!prectene) it.then(Modifier.background(MaterialTheme.colorScheme.primary)) else it }
                        )
                        Text(
                            c.nazev,
                            fontWeight = if (prectene) FontWeight.Normal else FontWeight.Bold,
                            modifier = Modifier.weight(1f)
                        )
                        if (c.id in stazena) {
                            Icon(
                                Icons.Default.DownloadForOffline,
                                contentDescription = "Staženo",
                                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                        IconButton(onClick = { Stav.prepniOblibene(ctx, c.id) }) {
                            Icon(
                                if (oblibene) Icons.Default.Star else Icons.Outlined.StarBorder,
                                contentDescription = "Oblíbené",
                                tint = if (oblibene) MaterialTheme.colorScheme.secondary else MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                    HorizontalDivider()
                }
            }
        }
    }
}
