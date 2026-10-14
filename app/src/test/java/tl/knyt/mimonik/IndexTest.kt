package tl.knyt.mimonik

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class IndexTest {
    private fun idx(id: String, vararg stranky: String) = IndexCisla(id, 100, 5, stranky.toList())

    @Test
    fun normalizujOdstraniDiakritikuAVelikost() {
        assertEquals("zluty kun", normalizuj("Žlutý KŮŇ"))
    }

    @Test
    fun najdeBezDiakritikyAVelikostiPisma() {
        val v = Vyhledavac.najdi(
            listOf(idx("a", "První strana", "Tramvaj číslo 15T jede přes Řepy"), idx("b", "nic", "TRAMVAJ")),
            "tramvaj"
        )
        assertEquals(listOf("a" to 1, "b" to 1), v.map { it.cisloId to it.strana })
    }

    @Test
    fun hledaSeIDiakritikou() {
        val v = Vyhledavac.najdi(listOf(idx("a", "Řepy a Praha")), "ŘEPY")
        assertEquals(1, v.size)
        assertEquals(0, v[0].strana)
    }

    @Test
    fun uryvekObsahujeNalezAJeOriginalnihoTextu() {
        val v = Vyhledavac.najdi(listOf(idx("a", "Ahoj. Tramvaj Škoda 15T přijíždí na zastávku.")), "skoda")
        assertEquals(1, v.size)
        assertTrue(v[0].uryvek.contains("Škoda"))
    }

    @Test
    fun uryvekSeOrizneAMaTriTecky() {
        val dlouhy = "x ".repeat(100) + "hledane" + " y".repeat(100)
        val u = Vyhledavac.najdi(listOf(idx("a", dlouhy)), "hledane").single().uryvek
        assertTrue(u.startsWith("…") && u.endsWith("…"))
        assertTrue(u.contains("hledane"))
        assertTrue(u.length < 130)
    }

    @Test
    fun prazdnyDotazNicNenajde() {
        assertTrue(Vyhledavac.najdi(listOf(idx("a", "text")), "   ").isEmpty())
    }

    @Test
    fun nenalezeno() {
        assertTrue(Vyhledavac.najdi(listOf(idx("a", "text")), "jiny").isEmpty())
    }

    @Test
    fun maxTriNalezyNaStrane() {
        val v = Vyhledavac.najdi(listOf(idx("a", "ab ab ab ab ab ab")), "ab")
        assertEquals(3, v.size)
    }

    @Test
    fun jsonObousmernne() {
        val i = idx("a", "První", "Druhá \"strana\"\nse řádkem")
        val zpet = IndexCisla.zJsonu(i.toJson())
        assertNotNull(zpet)
        assertEquals(i.stranky, zpet!!.stranky)
        assertEquals(i.id, zpet.id)
    }

    @Test
    fun poskozenyJsonJeNull() {
        assertNull(IndexCisla.zJsonu("{nejde"))
    }

    @Test
    fun invalidaceCachePodleVelikostiACasu() {
        val i = idx("a", "x")
        assertTrue(i.jeAktualni(100, 5))
        assertFalse(i.jeAktualni(101, 5))
        assertFalse(i.jeAktualni(100, 6))
    }

    @Test
    fun formatDobyCteni() {
        assertEquals("0 min", formatDoba(0))
        assertEquals("méně než minuta", formatDoba(30_000))
        assertEquals("12 min", formatDoba(12 * 60_000L))
        assertEquals("1 h 05 min", formatDoba(65 * 60_000L))
    }
}
