package tl.knyt.mimonik

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue
import org.json.JSONArray
import org.json.JSONObject

/** Anotace nad stránkou; souřadnice jsou normalizované (0..1) k velikosti stránky. */
data class Anotace(
    val id: String,
    val typ: String,
    val strana: Int,
    val x: Float,
    val y: Float,
    val w: Float,
    val h: Float,
    val barva: Int,
    val text: String = ""
) {
    companion object {
        const val ZVYRAZNENI = "zvyrazneni"
        const val POZNAMKA = "poznamka"
    }
}

enum class RezimCteni { NORMALNI, SEPIE, TMAVY }

/** Stav čtení (přečtené, pozice, oblíbené, záložky, anotace, zobrazení) uložený v SharedPreferences. */
object Stav {
    /** Zvýší se po každé změně, aby se překreslily seznamy (čti ho v kompozici). */
    var verze by mutableIntStateOf(0)
        private set

    private fun p(ctx: Context): SharedPreferences =
        ctx.applicationContext.getSharedPreferences("stav", Context.MODE_PRIVATE)

    private fun zmena() { verze++ }

    private fun mnozina(ctx: Context, klic: String): MutableSet<String> =
        (p(ctx).getStringSet(klic, emptySet()) ?: emptySet()).toMutableSet()

    fun jePrectene(ctx: Context, id: String): Boolean = id in mnozina(ctx, "prectena")

    fun oznacPrectene(ctx: Context, id: String) {
        val s = mnozina(ctx, "prectena")
        if (s.add(id)) {
            p(ctx).edit().putStringSet("prectena", s).apply()
            zmena()
        }
    }

    fun pocetNeprectenych(ctx: Context, cisla: List<Cislo>): Int {
        val s = mnozina(ctx, "prectena")
        return cisla.count { it.id !in s }
    }

    fun pozice(ctx: Context, id: String): Int? =
        p(ctx).getInt("pozice_$id", -1).takeIf { it >= 0 }

    fun ulozPozici(ctx: Context, id: String, strana: Int) {
        p(ctx).edit().putInt("pozice_$id", strana).apply()
    }

    fun jePoblibene(ctx: Context, id: String): Boolean = id in mnozina(ctx, "oblibena")

    fun prepniOblibene(ctx: Context, id: String) {
        val s = mnozina(ctx, "oblibena")
        if (!s.remove(id)) s.add(id)
        p(ctx).edit().putStringSet("oblibena", s).apply()
        zmena()
    }

    // --- záložky na stránky ---

    fun zalozky(ctx: Context, id: String): List<Int> =
        (p(ctx).getString("zalozky_$id", "") ?: "")
            .split(',').mapNotNull { it.toIntOrNull() }.distinct().sorted()

    fun jeZalozka(ctx: Context, id: String, strana: Int) = strana in zalozky(ctx, id)

    /** Přidá nebo odebere záložku; vrací, jestli po změně existuje. */
    fun prepniZalozku(ctx: Context, id: String, strana: Int): Boolean {
        val z = zalozky(ctx, id).toMutableList()
        val existuje = if (z.remove(strana)) false else { z.add(strana); true }
        p(ctx).edit().putString("zalozky_$id", z.sorted().joinToString(",")).apply()
        zmena()
        return existuje
    }

    // --- anotace (zvýraznění a poznámky) ---

    fun anotace(ctx: Context, id: String): List<Anotace> {
        val txt = p(ctx).getString("anotace_$id", null) ?: return emptyList()
        return try {
            val a = JSONArray(txt)
            (0 until a.length()).map {
                val o = a.getJSONObject(it)
                Anotace(
                    o.getString("id"), o.getString("typ"), o.getInt("strana"),
                    o.getDouble("x").toFloat(), o.getDouble("y").toFloat(),
                    o.getDouble("w").toFloat(), o.getDouble("h").toFloat(),
                    o.getInt("barva"), o.optString("text", "")
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun ulozAnotace(ctx: Context, id: String, seznam: List<Anotace>) {
        val a = JSONArray()
        seznam.forEach {
            a.put(JSONObject().apply {
                put("id", it.id); put("typ", it.typ); put("strana", it.strana)
                put("x", it.x.toDouble()); put("y", it.y.toDouble())
                put("w", it.w.toDouble()); put("h", it.h.toDouble())
                put("barva", it.barva); put("text", it.text)
            })
        }
        p(ctx).edit().putString("anotace_$id", a.toString()).apply()
        zmena()
    }

    // --- zobrazení (režim, jas, zoom) ---

    fun rezim(ctx: Context): RezimCteni =
        RezimCteni.values().getOrElse(p(ctx).getInt("rezim", 0)) { RezimCteni.NORMALNI }

    fun ulozRezim(ctx: Context, r: RezimCteni) { p(ctx).edit().putInt("rezim", r.ordinal).apply() }

    /** Jas okna 0..1; záporné = systémový. */
    fun jas(ctx: Context): Float = p(ctx).getFloat("jas", -1f)

    fun ulozJas(ctx: Context, j: Float) { p(ctx).edit().putFloat("jas", j).apply() }

    fun zoom(ctx: Context): Float = p(ctx).getFloat("zoom", 1f).coerceIn(1f, 4f)

    fun ulozZoom(ctx: Context, z: Float) { p(ctx).edit().putFloat("zoom", z).apply() }
}
