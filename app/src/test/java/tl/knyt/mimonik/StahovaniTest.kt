package tl.knyt.mimonik

import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import java.net.InetAddress
import java.net.ServerSocket
import kotlin.concurrent.thread
import java.nio.file.Files

class StahovaniTest {
    private lateinit var server: ServerSocket
    private lateinit var tmp: File
    private val obsah = ByteArray(200_000) { (it % 251).toByte() }
    private val cislo = Cislo("a", "Číslo 1", "pdf/a.pdf", 1)

    private val adresa get() = "http://127.0.0.1:${server.localPort}/"

    @Before
    fun start() {
        tmp = Files.createTempDirectory("mimonik").toFile()
        server = ServerSocket(0, 10, InetAddress.getByName("127.0.0.1"))
        // minimální HTTP server: /pdf/a.pdf vrátí obsah, cokoli jiného 404
        thread(isDaemon = true) {
            while (!server.isClosed) {
                try {
                    val klient = server.accept()
                    klient.use { k ->
                        val radek = k.getInputStream().bufferedReader().readLine() ?: return@use
                        val cesta = radek.split(" ").getOrNull(1)
                        val ven = k.getOutputStream()
                        if (cesta == "/pdf/a.pdf") {
                            ven.write("HTTP/1.1 200 OK\r\nContent-Length: ${obsah.size}\r\nConnection: close\r\n\r\n".toByteArray())
                            ven.write(obsah)
                        } else {
                            ven.write("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".toByteArray())
                        }
                        ven.flush()
                    }
                } catch (_: Exception) {
                }
            }
        }
    }

    @After
    fun konec() {
        server.close()
        tmp.deleteRecursively()
    }

    @Test
    fun stahneSoubor() = runBlocking {
        val cil = File(tmp, "pdf/a.pdf")
        val f = CislaStore.stahniSouborPDF(cil, cislo, listOf(adresa))
        assertEquals(cil, f)
        assertArrayEquals(obsah, cil.readBytes())
        assertFalse(File(tmp, "pdf/a.pdf.part").exists())
    }

    @Test
    fun existujiciSouborNeprepise() = runBlocking {
        val cil = File(tmp, "pdf/a.pdf")
        cil.parentFile!!.mkdirs()
        cil.writeText("moje poznámky")
        CislaStore.stahniSouborPDF(cil, cislo, listOf(adresa))
        assertEquals("moje poznámky", cil.readText())
    }

    @Test
    fun zkusiDalsiAdresuKdyzPrvniNeodpovi() = runBlocking {
        val cil = File(tmp, "pdf/a.pdf")
        CislaStore.stahniSouborPDF(cil, cislo, listOf(adresa + "neexistuje/", adresa))
        assertTrue(cil.exists())
        assertArrayEquals(obsah, cil.readBytes())
    }

    @Test
    fun bezDostupneAdresyJeChyba() {
        val cil = File(tmp, "pdf/b.pdf")
        assertThrows(SpojeniChyba::class.java) {
            runBlocking { CislaStore.stahniSouborPDF(cil, Cislo("b", "B", "pdf/b.pdf", 2), listOf(adresa)) }
        }
        assertFalse(cil.exists())
        assertFalse(File(tmp, "pdf/b.pdf.part").exists())
    }
}
