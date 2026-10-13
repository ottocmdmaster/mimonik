package tl.knyt.mimonik

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.view.WindowManager
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.util.UUID

private tailrec fun Context.najdiAktivitu(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.najdiAktivitu()
    else -> null
}

private val ZLUTA = 0xFFFFEB3B.toInt()
private val ZELENA = 0xFF8BC34A.toInt()
private val RUZOVA = 0xFFF48FB1.toInt()

/** Čtečka jednoho čísla: stáhne PDF (pokud ještě není v zařízení) a zobrazí ho. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CisloScreen(cislo: Cislo, store: CislaStore, onBack: () -> Unit) {
    var soubor by remember { mutableStateOf<File?>(null) }
    var selhalo by remember { mutableStateOf(false) }
    var pokus by remember { mutableIntStateOf(0) }

    LaunchedEffect(cislo.id, pokus) {
        selhalo = false
        try {
            soubor = store.pdf(cislo)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            selhalo = true
        }
    }

    val f = soubor
    if (f != null) {
        Ctecka(cislo, f, onBack)
        return
    }
    Scaffold(topBar = {
        TopAppBar(
            title = { Text(cislo.nazev) },
            navigationIcon = { IconButton(onBack) { Icon(Icons.Default.ArrowBack, "Zpět") } }
        )
    }) { pad ->
        Column(
            Modifier.padding(pad).fillMaxSize(),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            if (selhalo) {
                Text("Číslo se nepodařilo stáhnout.")
                Button({ pokus++ }, Modifier.padding(top = 12.dp)) { Text("Zkusit znovu") }
            } else {
                MimonChodi()
                Text("Stahuji číslo…")
            }
        }
    }
}

private data class DialogPoznamky(val anotace: Anotace?, val strana: Int, val x: Float, val y: Float)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun Ctecka(cislo: Cislo, soubor: File, onBack: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val id = cislo.id

    var otevrenoSelhalo by remember { mutableStateOf(false) }
    val stranky by produceState<PdfStranky?>(null, soubor) {
        val s = try { withContext(Dispatchers.IO) { PdfStranky(soubor) } } catch (e: Exception) { otevrenoSelhalo = true; null }
        value = s
        awaitDispose { s?.close() }
    }
    val hledani = remember(soubor) { PdfHledani(soubor, ctx) }
    val listState = rememberLazyListState()

    var zoom by remember { mutableFloatStateOf(Stav.zoom(ctx)) }
    var rezim by remember { mutableStateOf(Stav.rezim(ctx)) }
    var jas by remember { mutableFloatStateOf(Stav.jas(ctx)) }
    val anotace = remember { mutableStateListOf<Anotace>().also { it.addAll(Stav.anotace(ctx, id)) } }
    var nastroj by remember { mutableStateOf<Nastroj>(Nastroj.Nic) }
    var menu by remember { mutableStateOf(false) }
    var sheetZalozky by remember { mutableStateOf(false) }
    var sheetZobrazeni by remember { mutableStateOf(false) }
    var dialog by remember { mutableStateOf<DialogPoznamky?>(null) }
    var smazZvyrazneni by remember { mutableStateOf<Anotace?>(null) }

    var hledaniAktivni by remember { mutableStateOf(false) }
    var dotaz by remember { mutableStateOf("") }
    var nalezy by remember { mutableStateOf<List<Nalez>>(emptyList()) }
    var aktNalez by remember { mutableIntStateOf(0) }
    var hledano by remember { mutableStateOf(false) }
    var hledaSe by remember { mutableStateOf(false) }

    val verze = Stav.verze // překreslení po změně záložek/oblíbených
    val zalozky = remember(verze) { Stav.zalozky(ctx, id) }
    val oblibene = remember(verze) { Stav.jePoblibene(ctx, id) }
    val aktualniStrana by remember { androidx.compose.runtime.derivedStateOf { listState.firstVisibleItemIndex } }

    fun ulozAnotace() = Stav.ulozAnotace(ctx, id, anotace.toList())

    // jas okna; při odchodu z čtečky se vrátí původní
    val okno = remember { ctx.najdiAktivitu()?.window }
    val puvodniJas = remember { okno?.attributes?.screenBrightness ?: WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE }
    LaunchedEffect(jas) {
        okno?.let { w -> w.attributes = w.attributes.also { it.screenBrightness = if (jas < 0f) puvodniJas else jas } }
        Stav.ulozJas(ctx, jas)
    }
    DisposableEffect(Unit) {
        onDispose { okno?.let { w -> w.attributes = w.attributes.also { it.screenBrightness = puvodniJas } } }
    }
    LaunchedEffect(zoom) { Stav.ulozZoom(ctx, zoom) }

    // obnovení pozice, označení za přečtené, ukládání pozice
    LaunchedEffect(stranky) {
        val s = stranky ?: return@LaunchedEffect
        Stav.pozice(ctx, id)?.let { listState.scrollToItem(it.coerceIn(0, s.pocet - 1)) }
        Stav.oznacPrectene(ctx, id)
        snapshotFlow { listState.firstVisibleItemIndex }.collect { Stav.ulozPozici(ctx, id, it) }
    }

    fun hledej() {
        if (dotaz.isBlank()) return
        scope.launch {
            hledaSe = true
            nalezy = try { hledani.najdi(dotaz) } catch (e: Exception) { emptyList() }
            hledaSe = false
            hledano = true
            aktNalez = 0
            nalezy.firstOrNull()?.let { listState.scrollToItem(it.strana) }
        }
    }

    fun jdiNaNalez(i: Int) {
        if (nalezy.isEmpty()) return
        aktNalez = (i + nalezy.size) % nalezy.size
        scope.launch { listState.scrollToItem(nalezy[aktNalez].strana) }
    }

    fun zavriHledani() {
        hledaniAktivni = false; dotaz = ""; nalezy = emptyList(); hledano = false
    }

    BackHandler(enabled = hledaniAktivni || nastroj != Nastroj.Nic) {
        if (hledaniAktivni) zavriHledani() else nastroj = Nastroj.Nic
    }

    val tmavy = rezim == RezimCteni.TMAVY
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    if (hledaniAktivni) {
                        TextField(
                            value = dotaz, onValueChange = { dotaz = it },
                            placeholder = { Text("Hledat v čísle") }, singleLine = true,
                            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                            keyboardActions = KeyboardActions(onSearch = { hledej() }),
                            colors = TextFieldDefaults.colors(
                                focusedContainerColor = Color.Transparent, unfocusedContainerColor = Color.Transparent
                            ),
                            modifier = Modifier.fillMaxWidth()
                        )
                    } else Text(cislo.nazev, maxLines = 1)
                },
                navigationIcon = {
                    IconButton({ if (hledaniAktivni) zavriHledani() else onBack() }) {
                        Icon(if (hledaniAktivni) Icons.Default.Close else Icons.Default.ArrowBack, "Zpět")
                    }
                },
                actions = {
                    if (hledaniAktivni) {
                        if (hledano) {
                            Text(if (nalezy.isEmpty()) "0" else "${aktNalez + 1}/${nalezy.size}",
                                style = MaterialTheme.typography.labelLarge)
                            IconButton({ jdiNaNalez(aktNalez - 1) }) { Icon(Icons.Default.KeyboardArrowUp, "Předchozí") }
                            IconButton({ jdiNaNalez(aktNalez + 1) }) { Icon(Icons.Default.KeyboardArrowDown, "Další") }
                        }
                    } else {
                        IconButton({ hledaniAktivni = true }) { Icon(Icons.Default.Search, "Hledat") }
                        IconButton({ Stav.prepniOblibene(ctx, id) }) {
                            Icon(
                                Icons.Default.Star, if (oblibene) "Odebrat z oblíbených" else "Přidat do oblíbených",
                                tint = if (oblibene) MaterialTheme.colorScheme.primary
                                else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f)
                            )
                        }
                        TextButton({ sheetZobrazeni = true }) { Text("Aa") }
                        Box {
                            IconButton({ menu = true }) { Icon(Icons.Default.MoreVert, "Nabídka") }
                            DropdownMenu(menu, { menu = false }) {
                                val jeZal = aktualniStrana in zalozky
                                DropdownMenuItem(
                                    text = { Text(if (jeZal) "Odebrat záložku (str. ${aktualniStrana + 1})" else "Přidat záložku (str. ${aktualniStrana + 1})") },
                                    onClick = { menu = false; Stav.prepniZalozku(ctx, id, aktualniStrana) }
                                )
                                DropdownMenuItem(text = { Text("Záložky a poznámky") }, onClick = { menu = false; sheetZalozky = true })
                                DropdownMenuItem(text = { Text("Zvýraznit žlutě") }, onClick = { menu = false; nastroj = Nastroj.Zvyrazneni(ZLUTA) })
                                DropdownMenuItem(text = { Text("Zvýraznit zeleně") }, onClick = { menu = false; nastroj = Nastroj.Zvyrazneni(ZELENA) })
                                DropdownMenuItem(text = { Text("Zvýraznit růžově") }, onClick = { menu = false; nastroj = Nastroj.Zvyrazneni(RUZOVA) })
                                DropdownMenuItem(text = { Text("Přidat poznámku") }, onClick = { menu = false; nastroj = Nastroj.Poznamka })
                            }
                        }
                    }
                }
            )
        },
        bottomBar = {
            if (nastroj != Nastroj.Nic) {
                Surface(tonalElevation = 3.dp) {
                    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            if (nastroj == Nastroj.Poznamka) "Klepni na místo pro poznámku" else "Táhni prstem přes text, který chceš zvýraznit",
                            Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium
                        )
                        TextButton({ nastroj = Nastroj.Nic }) { Text("Hotovo") }
                    }
                }
            }
        }
    ) { pad ->
        val s = stranky
        Box(Modifier.padding(pad).fillMaxSize().background(if (tmavy) Color(0xFF202020) else Color(0xFFE0E0E0))) {
            when {
                otevrenoSelhalo -> Text("PDF se nepodařilo otevřít.", Modifier.align(Alignment.Center))
                s == null -> MimonChodi(Modifier.align(Alignment.Center))
                else -> BoxWithConstraints(
                    Modifier.fillMaxSize().pointerInput(Unit) {
                        // pinch-zoom: reaguje jen na dva prsty, jeden prst nechá rolovat
                        awaitEachGesture {
                            awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
                            do {
                                val ev = awaitPointerEvent(PointerEventPass.Initial)
                                if (ev.changes.size >= 2) {
                                    val z = ev.calculateZoom()
                                    if (z != 1f) {
                                        zoom = (zoom * z).coerceIn(1f, 4f)
                                        ev.changes.forEach { it.consume() }
                                    }
                                }
                            } while (ev.changes.any { it.pressed })
                        }
                    }
                ) {
                    val zaklad = maxWidth
                    val sirka = zaklad * zoom
                    val nalezyPoStranach = remember(nalezy) { nalezy.groupBy { it.strana } }
                    Box(Modifier.fillMaxSize().horizontalScroll(rememberScrollState())) {
                        LazyColumn(
                            state = listState,
                            modifier = Modifier.width(sirka).fillMaxHeight(),
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                            contentPadding = PaddingValues(vertical = 8.dp)
                        ) {
                            items(s.pocet, key = { it }) { i ->
                                val anotaceStrany = anotace.filter { it.strana == i }
                                StranaPdf(
                                    index = i, stranky = s, sirka = sirka, rezim = rezim,
                                    anotace = anotaceStrany,
                                    nalezy = nalezyPoStranach[i]?.flatMap { it.rects } ?: emptyList(),
                                    aktualniNalez = nalezy.getOrNull(aktNalez)?.takeIf { it.strana == i }?.rects ?: emptyList(),
                                    nastroj = nastroj,
                                    onZvyrazneni = { r ->
                                        val barva = (nastroj as? Nastroj.Zvyrazneni)?.barva ?: ZLUTA
                                        anotace.add(Anotace(UUID.randomUUID().toString(), Anotace.ZVYRAZNENI, i, r.x, r.y, r.w, r.h, barva))
                                        ulozAnotace()
                                    },
                                    onPoznamka = { x, y -> dialog = DialogPoznamky(null, i, x, y) },
                                    onKlepnutiNaAnotaci = { a ->
                                        if (a.typ == Anotace.POZNAMKA) dialog = DialogPoznamky(a, a.strana, a.x, a.y)
                                        else smazZvyrazneni = a
                                    }
                                )
                            }
                        }
                    }
                }
            }
            if (hledaSe) MimonChodi(Modifier.align(Alignment.TopCenter))
            if (hledano && nalezy.isEmpty() && !hledaSe) {
                Surface(Modifier.align(Alignment.BottomCenter).padding(16.dp), shape = MaterialTheme.shapes.medium, tonalElevation = 6.dp) {
                    Text("Nic nenalezeno", Modifier.padding(horizontal = 16.dp, vertical = 8.dp))
                }
            }
        }
    }

    if (sheetZobrazeni) ZobrazeniSheet(
        rezim = rezim, onRezim = { rezim = it; Stav.ulozRezim(ctx, it) },
        jas = jas, onJas = { jas = it },
        zoom = zoom, onZoom = { zoom = it },
        onZavri = { sheetZobrazeni = false }
    )

    if (sheetZalozky) ZalozkyListSheet(
        zalozky = zalozky, anotace = anotace.toList(),
        onJdi = { strana -> scope.launch { listState.scrollToItem(strana) } },
        onSmazZalozku = { Stav.prepniZalozku(ctx, id, it) },
        onSmazAnotaci = { a -> anotace.removeAll { it.id == a.id }; ulozAnotace() },
        onZavri = { sheetZalozky = false }
    )

    dialog?.let { d ->
        PoznamkaDialog(
            puvodni = d.anotace?.text ?: "", novaPoznamka = d.anotace == null,
            onUloz = { text ->
                val stara = d.anotace
                if (stara == null) anotace.add(Anotace(UUID.randomUUID().toString(), Anotace.POZNAMKA, d.strana, d.x, d.y, 0f, 0f, ZLUTA, text))
                else { val i = anotace.indexOfFirst { it.id == stara.id }; if (i >= 0) anotace[i] = stara.copy(text = text) }
                ulozAnotace(); dialog = null
            },
            onSmaz = { d.anotace?.let { a -> anotace.removeAll { it.id == a.id }; ulozAnotace() }; dialog = null },
            onZrus = { dialog = null }
        )
    }

    smazZvyrazneni?.let { a ->
        AlertDialog(
            onDismissRequest = { smazZvyrazneni = null },
            title = { Text("Smazat zvýraznění?") },
            confirmButton = { TextButton({ anotace.removeAll { it.id == a.id }; ulozAnotace(); smazZvyrazneni = null }) { Text("Smazat") } },
            dismissButton = { TextButton({ smazZvyrazneni = null }) { Text("Ponechat") } }
        )
    }
}
