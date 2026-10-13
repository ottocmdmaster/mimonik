package tl.knyt.mimonik

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController

class MainActivity : ComponentActivity() {
    private var zNotifikace by mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Notifier.vytvorKanal(this)
        Notifier.naplanujKontrolu(this)
        zNotifikace = intent?.getStringExtra(Notifier.EXTRA_CISLO)
        val store = CislaStore.get(this)
        setContent {
            MimonikTema {
                Surface(modifier = Modifier.fillMaxSize()) {
                    Aplikace(store, zNotifikace) { zNotifikace = null }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.getStringExtra(Notifier.EXTRA_CISLO)?.let { zNotifikace = it }
    }
}

@Composable
private fun Aplikace(store: CislaStore, cisloZNotifikace: String?, hotovo: () -> Unit) {
    val nav = rememberNavController()
    val cisla by store.cisla.collectAsState()

    // klepnutí na upozornění otevře dané číslo
    LaunchedEffect(cisloZNotifikace, cisla) {
        val id = cisloZNotifikace ?: return@LaunchedEffect
        if (cisla.any { it.id == id }) {
            nav.navigate("cislo/$id") { launchSingleTop = true }
            hotovo()
        }
    }

    NavHost(navController = nav, startDestination = "domu") {
        composable("domu") {
            HomeScreen(
                store = store,
                onOtevrit = { nav.navigate("cislo/${it.id}") },
                onNastaveni = { nav.navigate("nastaveni") }
            )
        }
        composable("nastaveni") {
            NastaveniScreen(store = store, onBack = { nav.popBackStack() })
        }
        composable("cislo/{id}") { zaznam ->
            val id = zaznam.arguments?.getString("id")
            val cislo = cisla.firstOrNull { it.id == id }
            if (cislo != null) {
                CisloScreen(cislo = cislo, store = store, onBack = { nav.popBackStack() })
            } else {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text("Číslo nenalezeno.")
                }
            }
        }
    }
}
