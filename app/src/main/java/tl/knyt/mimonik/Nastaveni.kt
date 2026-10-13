package tl.knyt.mimonik

import android.content.Context
import android.content.SharedPreferences

/** Nastavení upozornění a stahování (SharedPreferences). */
object Nastaveni {
    private fun p(ctx: Context): SharedPreferences =
        ctx.applicationContext.getSharedPreferences("nastaveni", Context.MODE_PRIVATE)

    val intervaly = listOf(1, 3, 6, 12)

    fun zapnuto(ctx: Context) = p(ctx).getBoolean("oznameniZapnuta", false)
    fun nastavZapnuto(ctx: Context, v: Boolean) = p(ctx).edit().putBoolean("oznameniZapnuta", v).apply()

    /** Řada (poradi) posledního čísla, o kterém uživatel ví. */
    fun posledni(ctx: Context) = p(ctx).getInt("posledniZnameCislo", 0)
    fun nastavPosledni(ctx: Context, v: Int) = p(ctx).edit().putInt("posledniZnameCislo", v).apply()

    fun interval(ctx: Context) = p(ctx).getInt("intervalHodin", 3)
    fun nastavInterval(ctx: Context, v: Int) = p(ctx).edit().putInt("intervalHodin", v).apply()

    fun autoStahovat(ctx: Context) = p(ctx).getBoolean("autoStahovat", true)
    fun nastavAutoStahovat(ctx: Context, v: Boolean) = p(ctx).edit().putBoolean("autoStahovat", v).apply()

    fun jenWifi(ctx: Context) = p(ctx).getBoolean("autoStahovatJenWifi", true)
    fun nastavJenWifi(ctx: Context, v: Boolean) = p(ctx).edit().putBoolean("autoStahovatJenWifi", v).apply()

    fun tichoZapnuto(ctx: Context) = p(ctx).getBoolean("tichoZapnuto", false)
    fun nastavTichoZapnuto(ctx: Context, v: Boolean) = p(ctx).edit().putBoolean("tichoZapnuto", v).apply()

    /** Minuty od půlnoci (výchozí 22:00). */
    fun tichoOd(ctx: Context) = p(ctx).getInt("tichoOd", 22 * 60)
    fun nastavTichoOd(ctx: Context, v: Int) = p(ctx).edit().putInt("tichoOd", v).apply()

    /** Minuty od půlnoci (výchozí 7:00). */
    fun tichoDo(ctx: Context) = p(ctx).getInt("tichoDo", 7 * 60)
    fun nastavTichoDo(ctx: Context, v: Int) = p(ctx).edit().putInt("tichoDo", v).apply()
}
