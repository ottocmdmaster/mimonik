package tl.knyt.mimonik

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class StavTest {
    private val ctx = FakeContext()
    private val cisla = listOf(
        Cislo("a", "Číslo 1", "a.pdf", 1),
        Cislo("b", "Číslo 2", "b.pdf", 2),
        Cislo("c", "Číslo 3", "c.pdf", 3)
    )

    @Test
    fun prectenaANeprectena() {
        assertEquals(3, Stav.pocetNeprectenych(ctx, cisla))
        Stav.oznacPrectene(ctx, "b")
        assertTrue(Stav.jePrectene(ctx, "b"))
        assertFalse(Stav.jePrectene(ctx, "a"))
        assertEquals(2, Stav.pocetNeprectenych(ctx, cisla))
        Stav.oznacPrectene(ctx, "b") // dvakrát nic nezmění
        assertEquals(2, Stav.pocetNeprectenych(ctx, cisla))
    }

    @Test
    fun poziceSeUlozi() {
        assertNull(Stav.pozice(ctx, "a"))
        Stav.ulozPozici(ctx, "a", 0)
        assertEquals(0, Stav.pozice(ctx, "a"))
        Stav.ulozPozici(ctx, "a", 17)
        assertEquals(17, Stav.pozice(ctx, "a"))
        assertNull(Stav.pozice(ctx, "b"))
    }

    @Test
    fun oblibenePrepinani() {
        assertFalse(Stav.jePoblibene(ctx, "a"))
        Stav.prepniOblibene(ctx, "a")
        assertTrue(Stav.jePoblibene(ctx, "a"))
        Stav.prepniOblibene(ctx, "a")
        assertFalse(Stav.jePoblibene(ctx, "a"))
    }

    @Test
    fun zalozkyJsouSerazeneABezDuplicit() {
        assertTrue(Stav.prepniZalozku(ctx, "a", 5))
        assertTrue(Stav.prepniZalozku(ctx, "a", 2))
        assertEquals(listOf(2, 5), Stav.zalozky(ctx, "a"))
        assertFalse(Stav.prepniZalozku(ctx, "a", 5)) // odebrání
        assertEquals(listOf(2), Stav.zalozky(ctx, "a"))
        assertEquals(emptyList<Int>(), Stav.zalozky(ctx, "b"))
    }

    @Test
    fun anotaceSeUlozi() {
        val a = Anotace("1", Anotace.POZNAMKA, 3, 0.2f, 0.4f, 0f, 0f, 0xFFFFEB3B.toInt(), "Text")
        val z = Anotace("2", Anotace.ZVYRAZNENI, 1, 0.1f, 0.2f, 0.5f, 0.05f, 0xFF8BC34A.toInt())
        Stav.ulozAnotace(ctx, "a", listOf(a, z))
        assertEquals(listOf(a, z), Stav.anotace(ctx, "a"))
        assertEquals(emptyList<Anotace>(), Stav.anotace(ctx, "b"))
    }

    @Test
    fun poslednOtevreneASvitit() {
        assertNull(Stav.posledniOtevrene(ctx))
        Stav.nastavPosledniOtevrene(ctx, "b")
        assertEquals("b", Stav.posledniOtevrene(ctx))
        assertTrue(Stav.svitit(ctx)) // výchozí je zapnuto
        Stav.ulozSvitit(ctx, false)
        assertFalse(Stav.svitit(ctx))
    }

    @Test
    fun statistikyCteni() {
        var s = Stav.statistiky(ctx, cisla)
        assertEquals(0, s.prectena); assertEquals(3, s.celkem); assertNull(s.nejctenejsi)

        Stav.oznacPrectene(ctx, "a"); Stav.oznacPrectene(ctx, "c")
        Stav.zaznamenejStranu(ctx, "a", 0); Stav.zaznamenejStranu(ctx, "a", 1); Stav.zaznamenejStranu(ctx, "a", 1)
        Stav.zaznamenejStranu(ctx, "c", 4)
        Stav.zaznamenejOtevreni(ctx, "a"); Stav.zaznamenejOtevreni(ctx, "c"); Stav.zaznamenejOtevreni(ctx, "c")
        Stav.pridejDobuCteni(ctx, "a", 120_000); Stav.pridejDobuCteni(ctx, "c", 30_000)
        Stav.pridejDobuCteni(ctx, "a", -5) // záporné se ignoruje

        s = Stav.statistiky(ctx, cisla)
        assertEquals(2, s.prectena)
        assertEquals(3, s.otevreneStrany)
        assertEquals(150_000L, s.dobaMs)
        assertEquals("a", s.nejctenejsi?.id) // delší doba čtení
        assertEquals(120_000L, s.nejctenejsiDobaMs)
        assertEquals(1, s.nejctenejsiOtevreni)
    }

    @Test
    fun zobrazeniSeUlozi() {
        assertEquals(RezimCteni.NORMALNI, Stav.rezim(ctx))
        Stav.ulozRezim(ctx, RezimCteni.TMAVY)
        assertEquals(RezimCteni.TMAVY, Stav.rezim(ctx))
        Stav.ulozZoom(ctx, 9f)
        assertEquals(4f, Stav.zoom(ctx), 0f) // zoom se ořízne na 1..4
    }

    @Test
    fun velikostSeznamuAVychozi() {
        assertEquals(VelikostSeznamu.NORMALNI, Nastaveni.velikostSeznamu(ctx))
        Nastaveni.nastavVelikostSeznamu(ctx, VelikostSeznamu.VELKE)
        assertEquals(VelikostSeznamu.VELKE, Nastaveni.velikostSeznamu(ctx))
    }
}
