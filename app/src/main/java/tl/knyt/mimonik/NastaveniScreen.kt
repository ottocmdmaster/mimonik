package tl.knyt.mimonik

import android.Manifest
import android.app.TimePickerDialog
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

private fun cas(min: Int) = "%d:%02d".format(min / 60, min % 60)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NastaveniScreen(store: CislaStore, onBack: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()

    var oznameni by remember { mutableStateOf(Nastaveni.zapnuto(ctx)) }
    var zablokovano by remember { mutableStateOf(Nastaveni.zapnuto(ctx) && !Notifier.povoleno(ctx)) }
    var interval by remember { mutableIntStateOf(Nastaveni.interval(ctx)) }
    var ticho by remember { mutableStateOf(Nastaveni.tichoZapnuto(ctx)) }
    var tichoOd by remember { mutableIntStateOf(Nastaveni.tichoOd(ctx)) }
    var tichoDo by remember { mutableIntStateOf(Nastaveni.tichoDo(ctx)) }
    var autoStahovat by remember { mutableStateOf(Nastaveni.autoStahovat(ctx)) }
    var jenWifi by remember { mutableStateOf(Nastaveni.jenWifi(ctx)) }
    var kontroluji by remember { mutableStateOf(false) }
    var vysledek by remember { mutableStateOf<String?>(null) }

    suspend fun zapni() {
        val ok = Notifier.nastav(ctx, true)
        oznameni = ok
        zablokovano = !ok
    }

    val povoleniLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        scope.launch { zapni() }
    }

    fun volbaCasu(vychozi: Int, ulozit: (Int) -> Unit) {
        TimePickerDialog(ctx, { _, h, m -> ulozit(h * 60 + m) }, vychozi / 60, vychozi % 60, true).show()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Upozornění") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Zpět")
                    }
                }
            )
        }
    ) { pad ->
        Column(
            Modifier
                .padding(pad)
                .verticalScroll(rememberScrollState())
        ) {
            Radek("Upozornit na nové číslo", oznameni) { zapnout ->
                if (!zapnout) {
                    scope.launch { oznameni = Notifier.nastav(ctx, false); zablokovano = false }
                } else if (Notifier.potrebujePovoleni(ctx) && Build.VERSION.SDK_INT >= 33) {
                    povoleniLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                } else {
                    scope.launch { zapni() }
                }
            }
            Poznamka("Appka občas v pozadí zkontroluje, jestli nevyšlo nové číslo. Kdy přesně, určuje Android, takže upozornění může přijít s odstupem.")
            if (zablokovano) {
                TextButton(
                    onClick = {
                        ctx.startActivity(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                    },
                    modifier = Modifier.padding(horizontal = 8.dp)
                ) { Text("Povolit oznámení v Nastavení") }
            }

            if (oznameni) {
                HorizontalDivider()
                Nadpis("Jak často")
                Row(
                    Modifier.padding(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Nastaveni.intervaly.forEach { h ->
                        FilterChip(
                            selected = interval == h,
                            onClick = {
                                interval = h
                                Nastaveni.nastavInterval(ctx, h)
                                Notifier.naplanujKontrolu(ctx, prepsat = true)
                            },
                            label = { Text(if (h == 1) "1 h" else "$h h") }
                        )
                    }
                }
                Poznamka("Je to jen požadavek, Android kontrolu spustí, kdy uzná za vhodné.")

                HorizontalDivider()
                Nadpis("Tiché hodiny")
                Radek("Nerušit", ticho) { ticho = it; Nastaveni.nastavTichoZapnuto(ctx, it) }
                if (ticho) {
                    Row(
                        Modifier.padding(horizontal = 16.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedButton(onClick = { volbaCasu(tichoOd) { tichoOd = it; Nastaveni.nastavTichoOd(ctx, it) } }) {
                            Text("Od ${cas(tichoOd)}")
                        }
                        OutlinedButton(onClick = { volbaCasu(tichoDo) { tichoDo = it; Nastaveni.nastavTichoDo(ctx, it) } }) {
                            Text("Do ${cas(tichoDo)}")
                        }
                    }
                }
                Poznamka("V tichých hodinách upozornění nepřijde.")
            }

            HorizontalDivider()
            Nadpis("Stahování")
            Radek("Stahovat nové číslo automaticky", autoStahovat) { autoStahovat = it; Nastaveni.nastavAutoStahovat(ctx, it) }
            if (autoStahovat) {
                Radek("Jen na Wi-Fi", jenWifi) { jenWifi = it; Nastaveni.nastavJenWifi(ctx, it) }
            }
            Poznamka("Nové číslo se stáhne hned, jak ho appka najde (při kontrole na pozadí i po otevření), aby šlo číst bez signálu. Už stažené číslo se nikdy nepřepíše.")

            HorizontalDivider()
            Row(
                Modifier.padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Button(
                    enabled = !kontroluji,
                    onClick = {
                        scope.launch {
                            kontroluji = true
                            vysledek = null
                            val nove = Notifier.kontrola(ctx, rucne = true)
                            store.obnov()
                            store.obnovStazena()
                            kontroluji = false
                            vysledek = when (nove) {
                                null -> "Web se nepodařilo zkontrolovat. Zkus to později."
                                true -> "Vyšlo nové číslo: ${store.cisla.value.firstOrNull()?.nazev ?: ""}."
                                false -> "Žádné nové číslo, máš to nejnovější."
                            }
                        }
                    }
                ) { Text("Zkontrolovat teď") }
                if (kontroluji) CircularProgressIndicator(Modifier.size(24.dp), strokeWidth = 2.dp)
            }
            vysledek?.let { Poznamka(it) }

            HorizontalDivider()
            Nadpis("Baterie")
            Poznamka(
                "Samsung, Xiaomi a další výrobci appky na pozadí šetří a zabíjejí, takže kontrola " +
                    "nového čísla nemusí běžet. V nastavení appky otevři Baterie a vyber „Bez omezení“."
            )
            OutlinedButton(
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                onClick = {
                    ctx.startActivity(
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", ctx.packageName, null))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                }
            ) { Text("Otevřít nastavení appky") }
        }
    }
}

@Composable
private fun Radek(text: String, zapnuto: Boolean, zmena: (Boolean) -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text, Modifier.weight(1f))
        Switch(checked = zapnuto, onCheckedChange = zmena)
    }
}

@Composable
private fun Nadpis(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.labelLarge,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
    )
}

@Composable
private fun Poznamka(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
    )
}
