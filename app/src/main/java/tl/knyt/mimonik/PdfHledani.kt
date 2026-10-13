package tl.knyt.mimonik

import android.content.Context
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import com.tom_roush.pdfbox.text.TextPosition
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.text.Normalizer
import kotlin.math.abs

/** Obdélník v normalizovaných souřadnicích stránky (0..1, počátek vlevo nahoře). */
data class NRect(val x: Float, val y: Float, val w: Float, val h: Float)

/** Jeden výskyt hledaného textu: na stránce může mít víc obdélníků (zalomení řádku). */
data class Nalez(val strana: Int, val rects: List<NRect>)

private val DIAKRITIKA = Regex("\\p{M}+")

private fun norm(s: String): String =
    Normalizer.normalize(s, Normalizer.Form.NFD).replace(DIAKRITIKA, "").lowercase()

/** Textový index PDF (PdfBox-Android) pro hledání; staví se líně a jen jednou. */
class PdfHledani(private val file: File, private val ctx: Context) {
    private class StranaText(val text: String, val pozice: List<NRect?>)

    private var index: List<StranaText>? = null

    private fun postav(): List<StranaText> {
        PDFBoxResourceLoader.init(ctx.applicationContext)
        val vysledek = ArrayList<StranaText>()
        PDDocument.load(file).use { doc ->
            for (p in 0 until doc.numberOfPages) {
                val strana = doc.getPage(p)
                val box = strana.cropBox
                val otocena = strana.rotation % 180 != 0
                val sirka = if (otocena) box.height else box.width
                val vyska = if (otocena) box.width else box.height
                val sb = StringBuilder()
                val pos = ArrayList<NRect?>()
                val stripper = object : PDFTextStripper() {
                    override fun writeString(text: String?, textPositions: MutableList<TextPosition>?) {
                        if (textPositions == null) return
                        for (tp in textPositions) {
                            val u = norm(tp.unicode ?: continue)
                            val r = NRect(
                                tp.xDirAdj / sirka, (tp.yDirAdj - tp.heightDir) / vyska,
                                tp.widthDirAdj / sirka, tp.heightDir / vyska
                            )
                            for (ch in u) { sb.append(ch); pos.add(r) }
                        }
                        sb.append(' '); pos.add(null)
                    }
                }
                stripper.startPage = p + 1
                stripper.endPage = p + 1
                try { stripper.getText(doc) } catch (_: Exception) {}
                vysledek.add(StranaText(sb.toString(), pos))
            }
        }
        return vysledek
    }

    suspend fun najdi(dotaz: String): List<Nalez> = withContext(Dispatchers.Default) {
        val q = norm(dotaz.trim())
        if (q.isEmpty()) return@withContext emptyList<Nalez>()
        val idx = index ?: postav().also { index = it }
        val vysledky = ArrayList<Nalez>()
        for ((strana, st) in idx.withIndex()) {
            var od = 0
            while (vysledky.size < 2000) {
                val i = st.text.indexOf(q, od)
                if (i < 0) break
                od = i + q.length
                val rects = ArrayList<NRect>()
                var cur: NRect? = null
                for (k in i until i + q.length) {
                    val r = st.pozice.getOrNull(k) ?: continue
                    val c = cur
                    if (c != null && abs(r.y - c.y) < c.h * 0.5f) {
                        val x2 = maxOf(c.x + c.w, r.x + r.w)
                        val x1 = minOf(c.x, r.x)
                        cur = NRect(x1, minOf(c.y, r.y), x2 - x1, maxOf(c.h, r.h))
                    } else {
                        if (c != null) rects.add(c)
                        cur = r
                    }
                }
                cur?.let { rects.add(it) }
                if (rects.isNotEmpty()) vysledky.add(Nalez(strana, rects))
            }
        }
        vysledky
    }
}
