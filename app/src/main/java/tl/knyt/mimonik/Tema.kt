package tl.knyt.mimonik

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val Svetle = lightColorScheme(
    primary = Color(0xFF1C6FB5),
    secondary = Color(0xFFF2C300),
    tertiary = Color(0xFFF2C300)
)
private val Tmave = darkColorScheme(
    primary = Color(0xFF7DB8EE),
    secondary = Color(0xFFF2C300),
    tertiary = Color(0xFFF2C300)
)

@Composable
fun MimonikTema(obsah: @Composable () -> Unit) {
    MaterialTheme(colorScheme = if (isSystemInDarkTheme()) Tmave else Svetle, content = obsah)
}
