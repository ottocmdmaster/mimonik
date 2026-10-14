package tl.knyt.mimonik

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlin.math.abs
import kotlin.math.min

/** Nástroj pro anotace: nic, zvýraznění zvolenou barvou, nebo přidání poznámky klepnutím. */
sealed class Nastroj {
    object Nic : Nastroj()
    data class Zvyrazneni(val barva: Int) : Nastroj()
    object Poznamka : Nastroj()
}

fun filtrRezimu(rezim: RezimCteni): ColorFilter? = when (rezim) {
    RezimCteni.NORMALNI -> null
    // jako násobení teplou barvou papíru
    RezimCteni.SEPIE -> ColorFilter.colorMatrix(ColorMatrix(floatArrayOf(
        0.98f, 0f, 0f, 0f, 0f,
        0f, 0.90f, 0f, 0f, 0f,
        0f, 0f, 0.72f, 0f, 0f,
        0f, 0f, 0f, 1f, 0f
    )))
    // inverze, ale ne do čistě černé/bílé
    RezimCteni.TMAVY -> ColorFilter.colorMatrix(ColorMatrix(floatArrayOf(
        -0.88f, 0f, 0f, 0f, 235f,
        0f, -0.88f, 0f, 0f, 235f,
        0f, 0f, -0.88f, 0f, 235f,
        0f, 0f, 0f, 1f, 0f
    )))
}

@Composable
fun StranaPdf(
    index: Int,
    stranky: PdfStranky,
    sirka: Dp,
    rezim: RezimCteni,
    anotace: List<Anotace>,
    nalezy: List<NRect>,
    aktualniNalez: List<NRect>,
    nastroj: Nastroj,
    onZvyrazneni: (NRect) -> Unit,
    onPoznamka: (x: Float, y: Float) -> Unit,
    onKlepnutiNaAnotaci: (Anotace) -> Unit,
    onDvojklik: () -> Unit = {},
    /** Klepnutí do prázdného místa; parametr je vodorovná pozice v rámci stránky (0..1). */
    onVolnyKlepnuti: (Float) -> Unit = {}
) {
    val dvojklik by rememberUpdatedState(onDvojklik)
    val volnyKlepnuti by rememberUpdatedState(onVolnyKlepnuti)
    val hustota = LocalDensity.current
    val sirkaPx = with(hustota) { sirka.roundToPx() }
    // zaokrouhlení nahoru, ať se při zoomu nepřekresluje při každém pixelu
    val kbelik = (((sirkaPx + 255) / 256) * 256).coerceAtMost(2560)
    val vyska = sirka * stranky.pomery[index]
    val bitmapa by produceState<ImageBitmap?>(null, index, kbelik) {
        value = try { stranky.vykresli(index, kbelik).asImageBitmap() } catch (e: Exception) { null }
    }
    var tahStart by remember { mutableStateOf<Offset?>(null) }
    var tahKonec by remember { mutableStateOf<Offset?>(null) }

    Box(
        Modifier
            .width(sirka)
            .height(vyska)
            .background(Color.White)
            .pointerInput(anotace, nastroj) {
                detectTapGestures(onDoubleTap = { if (nastroj == Nastroj.Nic) dvojklik() }) { p ->
                    val w = size.width.toFloat(); val h = size.height.toFloat()
                    val poznamkaSirka = 28.dp.toPx() / w
                    val zasah = anotace.firstOrNull {
                        if (it.typ == Anotace.POZNAMKA)
                            abs(p.x / w - it.x) < poznamkaSirka && abs(p.y / h - it.y) < 28.dp.toPx() / h
                        else nastroj == Nastroj.Nic && p.x / w in it.x..(it.x + it.w) && p.y / h in it.y..(it.y + it.h)
                    }
                    when {
                        zasah != null -> onKlepnutiNaAnotaci(zasah)
                        nastroj == Nastroj.Poznamka -> onPoznamka(p.x / w, p.y / h)
                        nastroj == Nastroj.Nic -> volnyKlepnuti(p.x / w)
                    }
                }
            }
            .pointerInput(nastroj) {
                if (nastroj is Nastroj.Zvyrazneni) {
                    detectDragGestures(
                        onDragStart = { tahStart = it; tahKonec = it },
                        onDrag = { zmena, _ -> tahKonec = zmena.position },
                        onDragEnd = {
                            val a = tahStart; val b = tahKonec
                            tahStart = null; tahKonec = null
                            if (a != null && b != null) {
                                val w = size.width.toFloat(); val h = size.height.toFloat()
                                val x1 = (min(a.x, b.x) / w).coerceIn(0f, 1f)
                                val y1 = (min(a.y, b.y) / h).coerceIn(0f, 1f)
                                val x2 = (maxOf(a.x, b.x) / w).coerceIn(0f, 1f)
                                val y2 = (maxOf(a.y, b.y) / h).coerceIn(0f, 1f)
                                if (x2 - x1 > 0.01f && y2 - y1 > 0.003f) onZvyrazneni(NRect(x1, y1, x2 - x1, y2 - y1))
                            }
                        },
                        onDragCancel = { tahStart = null; tahKonec = null }
                    )
                }
            }
    ) {
        bitmapa?.let {
            Image(
                bitmap = it,
                contentDescription = "Strana ${index + 1}",
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.FillBounds,
                colorFilter = filtrRezimu(rezim)
            )
        }
        Canvas(Modifier.fillMaxSize()) {
            fun kresli(r: NRect, barva: Color) = drawRect(
                barva, Offset(r.x * size.width, r.y * size.height), Size(r.w * size.width, r.h * size.height)
            )
            for (a in anotace) {
                if (a.typ == Anotace.ZVYRAZNENI) kresli(NRect(a.x, a.y, a.w, a.h), Color(a.barva).copy(alpha = 0.40f))
            }
            nalezy.forEach { kresli(it, Color(0xFFFFEB3B).copy(alpha = 0.55f)) }
            aktualniNalez.forEach { kresli(it, Color(0xFFFF9800).copy(alpha = 0.65f)) }
            val a = tahStart; val b = tahKonec
            if (a != null && b != null && nastroj is Nastroj.Zvyrazneni) {
                drawRect(
                    Color(nastroj.barva).copy(alpha = 0.40f),
                    Offset(min(a.x, b.x), min(a.y, b.y)), Size(abs(a.x - b.x), abs(a.y - b.y))
                )
                drawRect(
                    Color(nastroj.barva), Offset(min(a.x, b.x), min(a.y, b.y)),
                    Size(abs(a.x - b.x), abs(a.y - b.y)), style = Stroke(2.dp.toPx())
                )
            }
            for (a2 in anotace) {
                if (a2.typ != Anotace.POZNAMKA) continue
                val c = Offset(a2.x * size.width, a2.y * size.height)
                drawCircle(Color(0xFFFFC107), 13.dp.toPx(), c)
                drawCircle(Color(0xFF5D4037), 13.dp.toPx(), c, style = Stroke(1.5.dp.toPx()))
                // tři „řádky textu" v bublině
                for (i in -1..1) drawLine(
                    Color(0xFF5D4037), Offset(c.x - 6.dp.toPx(), c.y + i * 4.dp.toPx()),
                    Offset(c.x + 6.dp.toPx(), c.y + i * 4.dp.toPx()), 1.5.dp.toPx()
                )
            }
        }
    }
}
