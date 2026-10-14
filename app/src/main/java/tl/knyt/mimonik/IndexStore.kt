package tl.knyt.mimonik

import android.content.Context
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import java.io.File

/** Disková cache textového indexu čísel (filesDir/index/<id>.json); staví se jen pro stažená čísla. */
object IndexStore {
    private fun soubor(ctx: Context, c: Cislo) = File(ctx.filesDir, "index/${c.id}.json")

    /** Index čísla: z cache, pokud sedí velikost a čas změny PDF, jinak se vytvoří znovu. */
    suspend fun zajisti(ctx: Context, cislo: Cislo): IndexCisla? = withContext(Dispatchers.Default) {
        val pdf = CislaStore.souborPDF(ctx, cislo)
        if (!pdf.exists()) return@withContext null
        val cache = soubor(ctx, cislo)
        if (cache.exists()) {
            val stary = IndexCisla.zJsonu(cache.readText())
            if (stary != null && stary.jeAktualni(pdf.length(), pdf.lastModified())) return@withContext stary
        }
        try {
            val novy = IndexCisla(cislo.id, pdf.length(), pdf.lastModified(), extrahuj(ctx, pdf))
            cache.parentFile?.mkdirs()
            cache.writeText(novy.toJson())
            novy
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            null
        }
    }

    /** Zajistí indexy všech daných čísel (jen stažených); průběh hlásí po každém čísle. */
    suspend fun zajistiVse(ctx: Context, cisla: List<Cislo>, prubeh: (hotovo: Int, celkem: Int) -> Unit): List<IndexCisla> {
        val stazena = cisla.filter { CislaStore.souborPDF(ctx, it).exists() }
        val vysledek = ArrayList<IndexCisla>()
        prubeh(0, stazena.size)
        for ((i, c) in stazena.withIndex()) {
            currentCoroutineContext().ensureActive()
            zajisti(ctx, c)?.let { vysledek.add(it) }
            prubeh(i + 1, stazena.size)
        }
        return vysledek
    }

    private fun extrahuj(ctx: Context, pdf: File): List<String> {
        PDFBoxResourceLoader.init(ctx.applicationContext)
        PDDocument.load(pdf).use { doc ->
            val stripper = PDFTextStripper()
            return (1..doc.numberOfPages).map { p ->
                stripper.startPage = p
                stripper.endPage = p
                try { stripper.getText(doc) } catch (_: Exception) { "" }
            }
        }
    }
}
