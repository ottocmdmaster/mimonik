package tl.knyt.mimonik

import android.Manifest
import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.Calendar
import java.util.concurrent.TimeUnit

/** Pravidelná kontrola nového čísla na pozadí (WorkManager). */
class KontrolaWorker(ctx: Context, params: WorkerParameters) : CoroutineWorker(ctx, params) {
    override suspend fun doWork(): Result {
        Notifier.kontrola(applicationContext)
        return Result.success()
    }
}

/**
 * Upozornění na nové číslo. Appka sama v pozadí občas zkontroluje web a pošle místní upozornění.
 */
object Notifier {
    private const val KANAL = "cisla"
    private const val PRACE = "kontrola-cisla"
    const val EXTRA_CISLO = "cisloId"

    fun potrebujePovoleni(ctx: Context): Boolean =
        Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED

    fun povoleno(ctx: Context): Boolean = NotificationManagerCompat.from(ctx).areNotificationsEnabled()

    fun jeTicho(ctx: Context, kdy: Calendar = Calendar.getInstance()): Boolean {
        if (!Nastaveni.tichoZapnuto(ctx)) return false
        val od = Nastaveni.tichoOd(ctx)
        val do_ = Nastaveni.tichoDo(ctx)
        if (od == do_) return false
        val n = kdy.get(Calendar.HOUR_OF_DAY) * 60 + kdy.get(Calendar.MINUTE)
        return if (od < do_) n in od until do_ else n >= od || n < do_
    }

    /** Zapne/vypne upozornění. Vrací, jestli jsou po změně zapnutá. */
    suspend fun nastav(ctx: Context, zapnout: Boolean): Boolean {
        val app = ctx.applicationContext
        if (!zapnout) {
            Nastaveni.nastavZapnuto(app, false)
            WorkManager.getInstance(app).cancelUniqueWork(PRACE)
            return false
        }
        val ok = povoleno(app)
        Nastaveni.nastavZapnuto(app, ok)
        if (ok) {
            // aby se neoznamovala čísla, která už existují
            if (Nastaveni.posledni(app) == 0) {
                val nej = try { CislaStore.nactiSeznam(app).firstOrNull() } catch (e: Exception) { null }
                if (nej != null) Nastaveni.nastavPosledni(app, nej.poradi)
            }
            naplanujKontrolu(app, prepsat = true)
        }
        return ok
    }

    /** Naplánuje periodickou kontrolu podle zvoleného intervalu (WorkManager má minimum 15 min). */
    fun naplanujKontrolu(ctx: Context, prepsat: Boolean = false) {
        val app = ctx.applicationContext
        if (!Nastaveni.zapnuto(app)) return
        val req = PeriodicWorkRequestBuilder<KontrolaWorker>(Nastaveni.interval(app).toLong(), TimeUnit.HOURS)
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .build()
        WorkManager.getInstance(app).enqueueUniquePeriodicWork(
            PRACE,
            if (prepsat) ExistingPeriodicWorkPolicy.UPDATE else ExistingPeriodicWorkPolicy.KEEP,
            req
        )
    }

    /** Stáhne PDF čísla, pokud je automatické stahování zapnuté. Vrací, jestli je číslo po volání v zařízení. */
    suspend fun autoStahni(ctx: Context, cislo: Cislo): Boolean {
        if (CislaStore.souborPDF(ctx, cislo).exists()) return true
        if (!Nastaveni.autoStahovat(ctx)) return false
        return try {
            CislaStore.stahniPDF(ctx, cislo, Nastaveni.jenWifi(ctx))
            true
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Porovná nejnovější číslo na webu s posledním známým a případně pošle upozornění
     * (mimo tiché hodiny). Při ruční kontrole upozornění neposílá, jen vrátí výsledek.
     * Vrací: null = web nedostupný, true = je nové číslo, false = nic nového.
     */
    suspend fun kontrola(ctx: Context, rucne: Boolean = false): Boolean? {
        val app = ctx.applicationContext
        if (!rucne && !Nastaveni.zapnuto(app)) return null
        val seznam = try { CislaStore.nactiSeznam(app) } catch (e: kotlinx.coroutines.CancellationException) { throw e } catch (e: Exception) { return null }
        val nej = seznam.firstOrNull() ?: return null
        val posledni = Nastaveni.posledni(app)
        if (posledni == 0) {
            Nastaveni.nastavPosledni(app, nej.poradi)
            return false
        }
        if (nej.poradi <= posledni) return false
        Nastaveni.nastavPosledni(app, nej.poradi)
        val stazeno = autoStahni(app, nej)
        if (!Nastaveni.zapnuto(app) || rucne || jeTicho(app)) return true
        posliUpozorneni(app, nej, Stav.pocetNeprectenych(app, seznam), stazeno)
        return true
    }

    @SuppressLint("MissingPermission")
    private fun posliUpozorneni(ctx: Context, cislo: Cislo, pocet: Int, stazeno: Boolean) {
        if (!povoleno(ctx)) return
        vytvorKanal(ctx)
        val otevri = Intent(ctx, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_CISLO, cislo.id)
        }
        val pi = PendingIntent.getActivity(
            ctx, cislo.id.hashCode(), otevri,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        var text = if (pocet > 1)
            "Vyšlo číslo ${cislo.nazev}. Nepřečtených čísel: $pocet."
        else
            "Vyšlo číslo ${cislo.nazev}. Klepni a přečti si ho."
        if (stazeno) text += " Je stažené, přečteš ho i bez signálu."
        val n = NotificationCompat.Builder(ctx, KANAL)
            .setSmallIcon(R.drawable.ic_stat_mimonik)
            .setContentTitle("Nový Mimoník")
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setNumber(pocet)
            .setAutoCancel(true)
            .setContentIntent(pi)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        NotificationManagerCompat.from(ctx).notify("cislo-${cislo.id}", 1, n)
    }

    fun vytvorKanal(ctx: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(KANAL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(KANAL, "Nová čísla", NotificationManager.IMPORTANCE_DEFAULT)
                    .apply { description = "Upozornění na nově vyšlé číslo Mimoníku" }
            )
        }
    }

    /** Čísla, o kterých už uživatel ví (otevřel appku), se neoznamují. */
    fun oznacJakoVidene(ctx: Context, cisla: List<Cislo>) {
        val n = cisla.firstOrNull()?.poradi ?: return
        if (n > Nastaveni.posledni(ctx)) Nastaveni.nastavPosledni(ctx, n)
    }
}
