package tl.knyt.mimonik

import org.json.JSONArray
import org.json.JSONObject
import java.text.Normalizer

private val ZNACKY = Regex("\\p{M}+")

/** Zjednoduší text pro hledání: bez diakritiky a velikosti písmen. */
fun normalizuj(s: String): String =
    Normalizer.normalize(s, Normalizer.Form.NFD).replace(ZNACKY, "").lowercase()

/** Text jednoho čísla po stránkách; velikost a čas změny souboru slouží k zneplatnění cache. */
class IndexCisla(
    val id: String,
    val velikost: Long,
    val upraveno: Long,
    val stranky: List<String>
) {
    /** Jestli index odpovídá dané verzi souboru PDF. */
    fun jeAktualni(velikostSouboru: Long, upravenoSouboru: Long) =
        velikost == velikostSouboru && upraveno == upravenoSouboru

    // normalizovaný text a mapování zpět na původní pozice, ať se dá vystřihnout úryvek
    private val norm: List<Pair<String, IntArray>> by lazy { stranky.map { normalizujSMapou(it) } }

    internal fun normStrana(i: Int) = norm[i]

    fun toJson(): String = JSONObject().apply {
        put("id", id); put("velikost", velikost); put("upraveno", upraveno)
        put("stranky", JSONArray(stranky))
    }.toString()

    companion object {
        fun zJsonu(text: String): IndexCisla? = try {
            val o = JSONObject(text)
            val a = o.getJSONArray("stranky")
            IndexCisla(
                o.getString("id"), o.getLong("velikost"), o.getLong("upraveno"),
                (0 until a.length()).map { a.getString(it) }
            )
        } catch (e: Exception) {
            null
        }
    }
}

/** Normalizuje po znacích a pamatuje si, ze které pozice původního textu každý znak pochází. */
internal fun normalizujSMapou(s: String): Pair<String, IntArray> {
    val sb = StringBuilder()
    val mapa = ArrayList<Int>()
    var i = 0
    while (i < s.length) {
        val cp = s.codePointAt(i)
        val delka = Character.charCount(cp)
        val n = normalizuj(String(Character.toChars(cp)))
        for (ch in n) { sb.append(ch); mapa.add(i) }
        i += delka
    }
    return sb.toString() to mapa.toIntArray()
}

/** Jeden nález: číslo, strana (od 0) a úryvek textu kolem nálezu. */
data class NalezVCisle(val cisloId: String, val strana: Int, val uryvek: String)

object Vyhledavac {
    const val MAX_NALEZU = 500
    private const val OKOLI = 45

    /** Najde dotaz ve všech indexech; výsledky v pořadí daném seznamem indexů a stran. */
    fun najdi(indexy: List<IndexCisla>, dotaz: String): List<NalezVCisle> {
        val q = normalizuj(dotaz.trim()).replace(Regex("\\s+"), " ")
        if (q.isEmpty()) return emptyList()
        val vysledky = ArrayList<NalezVCisle>()
        for (idx in indexy) {
            for (strana in idx.stranky.indices) {
                val (text, mapa) = idx.normStrana(strana)
                var od = 0
                var naStrane = 0
                while (vysledky.size < MAX_NALEZU && naStrane < 3) {
                    val i = text.indexOf(q, od)
                    if (i < 0) break
                    od = i + q.length
                    naStrane++
                    vysledky.add(NalezVCisle(idx.id, strana, uryvek(idx.stranky[strana], mapa, i, q.length)))
                }
            }
        }
        return vysledky
    }

    private fun uryvek(original: String, mapa: IntArray, i: Int, delka: Int): String {
        if (mapa.isEmpty()) return ""
        val zacatek = (mapa[i] - OKOLI).coerceAtLeast(0)
        val posledni = mapa[(i + delka - 1).coerceAtMost(mapa.size - 1)]
        val konec = (posledni + 1 + OKOLI).coerceAtMost(original.length)
        val text = original.substring(zacatek, konec).replace(Regex("\\s+"), " ").trim()
        return (if (zacatek > 0) "…" else "") + text + (if (konec < original.length) "…" else "")
    }
}
