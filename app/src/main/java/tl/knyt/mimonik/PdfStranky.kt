package tl.knyt.mimonik

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import android.util.LruCache
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.io.File

/** Obálka nad PdfRenderer: vykresluje jednotlivé stránky do bitmap s cache. PdfRenderer smí mít otevřenou jen jednu stránku, proto Mutex. */
class PdfStranky(file: File) : AutoCloseable {
    private val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    private val renderer = PdfRenderer(pfd)
    private val mutex = Mutex()
    private val cache = object : LruCache<String, Bitmap>((Runtime.getRuntime().maxMemory() / 6).toInt().coerceAtLeast(8 shl 20)) {
        override fun sizeOf(key: String, value: Bitmap) = value.byteCount
    }

    val pocet: Int = renderer.pageCount

    /** Poměr výška/šířka každé stránky. */
    val pomery: List<Float> = (0 until pocet).map {
        renderer.openPage(it).use { s -> s.height.toFloat() / s.width.toFloat() }
    }

    suspend fun vykresli(index: Int, sirkaPx: Int): Bitmap = mutex.withLock {
        val klic = "$index@$sirkaPx"
        cache.get(klic)?.let { return it }
        val vyska = (sirkaPx * pomery[index]).toInt().coerceAtLeast(1)
        val bmp = Bitmap.createBitmap(sirkaPx, vyska, Bitmap.Config.ARGB_8888)
        bmp.eraseColor(Color.WHITE)
        renderer.openPage(index).use { it.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY) }
        cache.put(klic, bmp)
        bmp
    }

    override fun close() {
        try { renderer.close() } catch (_: Exception) {}
        try { pfd.close() } catch (_: Exception) {}
    }
}
