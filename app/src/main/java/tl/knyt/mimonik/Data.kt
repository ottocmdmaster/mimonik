package tl.knyt.mimonik

data class Cislo(
    val id: String,
    val nazev: String,
    val pdf: String,
    val poradi: Int
)

object Config {
    /** Adresy webu Mimoníku; použije se první, která odpoví. */
    val adresy = listOf(
        "https://mimonik.knyt.tl/",
        "https://preview.mimonik.knyt.tl/"
    )
}
