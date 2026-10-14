package tl.knyt.mimonik

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class SeznamTest {
    @Test
    fun parsujSeznamASerad() {
        val json = """[
            {"id":"a","nazev":"Číslo 1","pdf":"pdf/a.pdf","poradi":1},
            {"id":"c","nazev":"Číslo 3","pdf":"pdf/c.pdf","poradi":3},
            {"id":"b","nazev":"Číslo 2","pdf":"pdf/b.pdf","poradi":2}
        ]"""
        val s = CislaStore.parsuj(json)
        assertEquals(listOf("c", "b", "a"), s.map { it.id })
        assertEquals(Cislo("c", "Číslo 3", "pdf/c.pdf", 3), s.first())
    }

    @Test
    fun prazdnySeznam() {
        assertEquals(emptyList<Cislo>(), CislaStore.parsuj("[]"))
    }

    @Test
    fun chybejiciPoleJeChyba() {
        assertThrows(Exception::class.java) { CislaStore.parsuj("""[{"id":"a"}]""") }
    }

    @Test
    fun neplatnyJsonJeChyba() {
        assertThrows(Exception::class.java) { CislaStore.parsuj("není json") }
    }
}
