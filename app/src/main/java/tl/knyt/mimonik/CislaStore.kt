package tl.knyt.mimonik

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

class SpojeniChyba : Exception("Server není dostupný")

/** Načítá seznam čísel z webu a stahuje PDF do zařízení (aby šla číst i bez signálu). */
class CislaStore private constructor(ctx: Context) {
    private val app = ctx.applicationContext

    private val _cisla = MutableStateFlow(ulozenySeznam(app))
    val cisla: StateFlow<List<Cislo>> = _cisla.asStateFlow()

    private val _nacita = MutableStateFlow(false)
    val nacita: StateFlow<Boolean> = _nacita.asStateFlow()

    private val _chyba = MutableStateFlow<String?>(null)
    val chyba: StateFlow<String?> = _chyba.asStateFlow()

    private val _stazena = MutableStateFlow(zjistiStazena(_cisla.value))
    val stazena: StateFlow<Set<String>> = _stazena.asStateFlow()

    private fun zjistiStazena(c: List<Cislo>) = c.filter { souborPDF(app, it).exists() }.map { it.id }.toSet()

    fun obnovStazena() {
        _stazena.value = zjistiStazena(_cisla.value)
    }

    suspend fun obnov() {
        _nacita.value = true
        try {
            val seznam = nactiSeznam(app)
            _cisla.value = seznam
            _chyba.value = null
            obnovStazena()
            seznam.firstOrNull()?.let {
                Notifier.autoStahni(app, it)
                obnovStazena()
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            _chyba.value = if (_cisla.value.isEmpty())
                "Seznam čísel se nepodařilo načíst. Zkontroluj připojení."
            else
                "Jsi offline, zobrazuji uložená čísla."
        } finally {
            _nacita.value = false
        }
    }

    /** Vrátí lokální soubor s PDF; když tam není, stáhne ho. */
    suspend fun pdf(cislo: Cislo): File {
        val f = stahniPDF(app, cislo, jenWifi = false)
        obnovStazena()
        return f
    }

    fun smazStazene() {
        _cisla.value.forEach { souborPDF(app, it).delete() }
        _stazena.value = emptySet()
    }

    companion object {
        @Volatile
        private var instance: CislaStore? = null

        fun get(ctx: Context): CislaStore =
            instance ?: synchronized(this) {
                instance ?: CislaStore(ctx.applicationContext).also { instance = it }
            }

        private fun seznamSoubor(ctx: Context) = File(ctx.filesDir, "cisla.json")

        fun souborPDF(ctx: Context, c: Cislo) = File(ctx.filesDir, "pdf/${c.id}.pdf")

        internal fun parsuj(text: String): List<Cislo> {
            val pole = JSONArray(text)
            return (0 until pole.length()).map {
                val o = pole.getJSONObject(it)
                Cislo(o.getString("id"), o.getString("nazev"), o.getString("pdf"), o.getInt("poradi"))
            }.sortedByDescending { it.poradi }
        }

        fun ulozenySeznam(ctx: Context): List<Cislo> = try {
            val f = seznamSoubor(ctx)
            if (f.exists()) parsuj(f.readText()) else emptyList()
        } catch (e: Exception) {
            emptyList()
        }

        suspend fun nactiSeznam(ctx: Context): List<Cislo> = withContext(Dispatchers.IO) {
            for (adresa in Config.adresy) {
                try {
                    val c = URL(adresa + "cisla.json").openConnection() as HttpURLConnection
                    c.connectTimeout = 20_000
                    c.readTimeout = 20_000
                    c.useCaches = false
                    c.setRequestProperty("Cache-Control", "no-cache")
                    try {
                        if (c.responseCode != 200) continue
                        val text = c.inputStream.bufferedReader().use { it.readText() }
                        val seznam = parsuj(text)
                        seznamSoubor(ctx).writeText(text)
                        return@withContext seznam
                    } finally {
                        c.disconnect()
                    }
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Exception) {
                    continue
                }
            }
            throw SpojeniChyba()
        }

        private fun jeNaMobilnichDatech(ctx: Context): Boolean {
            val cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val net = cm.activeNetwork ?: return true
            val caps = cm.getNetworkCapabilities(net) ?: return true
            val wifi = caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
            return !wifi || cm.isActiveNetworkMetered
        }

        /**
         * Stáhne PDF čísla do filesDir/pdf/<id>.pdf. Už stažené PDF nikdy nepřepíše
         * (mohou v něm být poznámky). Při jenWifi odmítne mobilní data a zpoplatněné sítě.
         */
        suspend fun stahniPDF(ctx: Context, cislo: Cislo, jenWifi: Boolean): File = withContext(Dispatchers.IO) {
            val cil = souborPDF(ctx, cislo)
            if (cil.exists()) return@withContext cil
            if (jenWifi && jeNaMobilnichDatech(ctx)) throw SpojeniChyba()
            stahniSouborPDF(cil, cislo, Config.adresy)
        }

        /** Jádro stahování bez Contextu (kvůli testům): zkusí adresy popořadě, existující soubor nepřepíše. */
        internal suspend fun stahniSouborPDF(cil: File, cislo: Cislo, adresy: List<String>): File = withContext(Dispatchers.IO) {
            if (cil.exists()) return@withContext cil
            cil.parentFile?.mkdirs()
            for (adresa in adresy) {
                val tmp = File(cil.parentFile, "${cislo.id}.pdf.part")
                try {
                    val c = URL(adresa + cislo.pdf).openConnection() as HttpURLConnection
                    c.connectTimeout = 20_000
                    c.readTimeout = 30_000
                    try {
                        if (c.responseCode != 200) continue
                        c.inputStream.use { vstup ->
                            tmp.outputStream().use { vystup ->
                                val buf = ByteArray(64 * 1024)
                                while (true) {
                                    currentCoroutineContext().ensureActive()
                                    val n = vstup.read(buf)
                                    if (n < 0) break
                                    vystup.write(buf, 0, n)
                                }
                            }
                        }
                    } finally {
                        c.disconnect()
                    }
                    if (cil.exists()) {
                        tmp.delete()
                    } else if (!tmp.renameTo(cil)) {
                        tmp.delete()
                        continue
                    }
                    return@withContext cil
                } catch (e: CancellationException) {
                    tmp.delete()
                    throw e
                } catch (e: Exception) {
                    tmp.delete()
                    continue
                }
            }
            throw SpojeniChyba()
        }
    }
}
