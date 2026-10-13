package tl.knyt.mimonik

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import kotlin.math.abs
import kotlin.math.sin

/** Mimoň chodí ze strany na stranu, dokud se číslo stahuje. */
@Composable
fun MimonChodi(modifier: Modifier = Modifier) {
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
        val sirkaMimona = vyska * 0.57f
        val dosah = maxWidth - sirkaMimona
        Image(
            painter = painterResource(R.drawable.mimon),
            contentDescription = "Mimoň",
            modifier = Modifier
                .height(vyska)
                .offset(x = dosah * pozice, y = vyska * 0.12f * -abs(sin(krokT)) + 12.dp)
                .rotate(sin(krokT) * 6f)
                .scale(if (doprava) 1f else -1f, 1f)
        )
    }
}
