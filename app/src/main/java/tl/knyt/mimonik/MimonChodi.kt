package tl.knyt.mimonik

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

/** Počet variant mimoně: 0 obyčejný, 1 sluneční brýle, 2 červená čepice, 3 párty klobouk. */
const val MIMON_VARIANTY = 4

/** Poměr stran obrázku mimoně (šířka / výška). */
private const val POMER = 227f / 400f

fun nahodnaVarianta(): Int = Random.nextInt(MIMON_VARIANTY)

/** Mimoň s doplňkem nakresleným přes obrázek (souřadnice jsou v poměru k jeho velikosti). */
@Composable
private fun MimonObrazek(varianta: Int, modifier: Modifier = Modifier, ruka: Float? = null) {
    Box(modifier) {
        Image(
            painter = painterResource(R.drawable.mimon),
            contentDescription = "Mimoň",
            modifier = Modifier.fillMaxSize()
        )
        Canvas(Modifier.fillMaxSize()) {
            when (varianta) {
                1 -> bryle()
                2 -> capice()
                3 -> klobouk()
            }
            if (ruka != null) mavajiciRuka(ruka)
        }
    }
}

private fun DrawScope.bryle() {
    val w = size.width; val h = size.height
    val cerna = Color(0xFF111111)
    val ry = h * 0.065f; val rx = w * 0.20f; val cy = h * 0.275f
    drawOval(cerna, Offset(w * 0.30f - rx, cy - ry), Size(rx * 2, ry * 2))
    drawOval(cerna, Offset(w * 0.68f - rx, cy - ry), Size(rx * 2, ry * 2))
    drawLine(cerna, Offset(w * 0.45f, cy), Offset(w * 0.53f, cy), h * 0.012f)
    // odlesk
    drawLine(Color(0x66FFFFFF), Offset(w * 0.22f, cy - ry * 0.4f), Offset(w * 0.30f, cy - ry * 0.7f), h * 0.008f, StrokeCap.Round)
    drawLine(Color(0x66FFFFFF), Offset(w * 0.60f, cy - ry * 0.4f), Offset(w * 0.68f, cy - ry * 0.7f), h * 0.008f, StrokeCap.Round)
}

private fun DrawScope.capice() {
    val w = size.width; val h = size.height
    val cervena = Color(0xFFD32F2F)
    val tmava = Color(0xFF7F1D1D)
    // kupole
    drawArc(cervena, 180f, 180f, true, Offset(w * 0.14f, h * 0.02f), Size(w * 0.72f, h * 0.20f))
    // kšilt
    drawRoundRect(tmava, Offset(w * 0.46f, h * 0.105f), Size(w * 0.50f, h * 0.035f), androidx.compose.ui.geometry.CornerRadius(h * 0.02f))
    drawCircle(tmava, h * 0.012f, Offset(w * 0.50f, h * 0.02f))
}

private fun DrawScope.klobouk() {
    val w = size.width; val h = size.height
    val trojuhelnik = Path().apply {
        moveTo(w * 0.28f, h * 0.10f)
        lineTo(w * 0.72f, h * 0.10f)
        lineTo(w * 0.52f, h * -0.07f)
        close()
    }
    drawPath(trojuhelnik, Color(0xFF8E24AA))
    drawLine(Color(0xFFFFEB3B), Offset(w * 0.36f, h * 0.075f), Offset(w * 0.56f, h * 0.003f), h * 0.014f, StrokeCap.Round)
    drawLine(Color(0xFFFFEB3B), Offset(w * 0.44f, h * 0.09f), Offset(w * 0.62f, h * 0.035f), h * 0.014f, StrokeCap.Round)
    drawCircle(Color(0xFFFFEB3B), h * 0.02f, Offset(w * 0.52f, h * -0.07f))
}

/** Ruka s rukavicí na pravém rameni; úhel 0..1 se mění při mávání. */
private fun DrawScope.mavajiciRuka(faze: Float) {
    val w = size.width; val h = size.height
    val rameno = Offset(w * 0.90f, h * 0.55f)
    val uhel = (-80.0 - 35.0 * sin(faze * 2.0 * PI * 2.5)) * PI / 180.0
    val delka = h * 0.30f
    val ruka = Offset(rameno.x + (cos(uhel) * delka).toFloat(), rameno.y + (sin(uhel) * delka).toFloat())
    drawLine(Color(0xFFFFEB3B), rameno, ruka, h * 0.045f, StrokeCap.Round)
    drawCircle(Color(0xFF111111), h * 0.05f, ruka)
}

/** Mimoň chodí ze strany na stranu, dokud se číslo stahuje. */
@Composable
fun MimonChodi(modifier: Modifier = Modifier, varianta: Int = remember { nahodnaVarianta() }) {
    val vyska = 90.dp
    val prechod = rememberInfiniteTransition(label = "mimon")
    // 0..2: první polovina doprava, druhá doleva
    val t by prechod.animateFloat(
        initialValue = 0f, targetValue = 2f,
        animationSpec = infiniteRepeatable(tween(4500, easing = LinearEasing), RepeatMode.Restart),
        label = "chuze"
    )
    val krokT by prechod.animateFloat(
        initialValue = 0f, targetValue = (2 * Math.PI).toFloat() * 8,
        animationSpec = infiniteRepeatable(tween(4500, easing = LinearEasing), RepeatMode.Restart),
        label = "krok"
    )
    val doprava = t < 1f
    val pozice = if (doprava) t else 2f - t
    BoxWithConstraints(modifier.fillMaxWidth().height(vyska + 12.dp).padding(horizontal = 16.dp)) {
        val sirkaMimona = vyska * POMER
        val dosah = maxWidth - sirkaMimona
        MimonObrazek(
            varianta,
            Modifier
                .height(vyska)
                .aspectRatio(POMER)
                .offset(x = dosah * pozice, y = vyska * 0.12f * -abs(sin(krokT)) + 12.dp)
                .rotate(sin(krokT) * 6f)
                .scale(if (doprava) 1f else -1f, 1f)
        )
    }
}

/** Mimoň po dokončení stahování zamává (poskočí, nakloní se a mává rukou). */
@Composable
fun MimonZamava(modifier: Modifier = Modifier, varianta: Int) {
    val vyska = 90.dp
    val prechod = rememberInfiniteTransition(label = "zamavani")
    val faze by prechod.animateFloat(
        initialValue = 0f, targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(800, easing = LinearEasing), RepeatMode.Restart),
        label = "faze"
    )
    val skok by prechod.animateFloat(
        initialValue = 0f, targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(400, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "skok"
    )
    Box(modifier.fillMaxWidth().height(vyska + 24.dp), contentAlignment = Alignment.BottomCenter) {
        MimonObrazek(
            varianta,
            Modifier
                .height(vyska)
                .aspectRatio(POMER)
                .offset(y = -(vyska * 0.18f * skok))
                .rotate(sin(faze * 2f * PI.toFloat()) * 8f),
            ruka = faze
        )
    }
}
