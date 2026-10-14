package tl.knyt.mimonik

import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences

/** SharedPreferences v paměti, aby šel Stav testovat bez Androidu. */
class FakePrefs : SharedPreferences {
    private val data = HashMap<String, Any?>()

    override fun getAll(): MutableMap<String, *> = HashMap(data)
    override fun getString(key: String, defValue: String?) = data[key] as? String ?: defValue
    @Suppress("UNCHECKED_CAST")
    override fun getStringSet(key: String, defValues: MutableSet<String>?) = (data[key] as? Set<String>)?.toMutableSet() ?: defValues
    override fun getInt(key: String, defValue: Int) = data[key] as? Int ?: defValue
    override fun getLong(key: String, defValue: Long) = data[key] as? Long ?: defValue
    override fun getFloat(key: String, defValue: Float) = data[key] as? Float ?: defValue
    override fun getBoolean(key: String, defValue: Boolean) = data[key] as? Boolean ?: defValue
    override fun contains(key: String) = key in data
    override fun registerOnSharedPreferenceChangeListener(l: SharedPreferences.OnSharedPreferenceChangeListener?) {}
    override fun unregisterOnSharedPreferenceChangeListener(l: SharedPreferences.OnSharedPreferenceChangeListener?) {}

    override fun edit(): SharedPreferences.Editor = object : SharedPreferences.Editor {
        private val zmeny = HashMap<String, Any?>()
        private var smazat = false
        override fun putString(key: String, value: String?) = apply { zmeny[key] = value }
        override fun putStringSet(key: String, values: MutableSet<String>?) = apply { zmeny[key] = values?.toSet() }
        override fun putInt(key: String, value: Int) = apply { zmeny[key] = value }
        override fun putLong(key: String, value: Long) = apply { zmeny[key] = value }
        override fun putFloat(key: String, value: Float) = apply { zmeny[key] = value }
        override fun putBoolean(key: String, value: Boolean) = apply { zmeny[key] = value }
        override fun remove(key: String) = apply { zmeny[key] = null }
        override fun clear() = apply { smazat = true }
        override fun commit(): Boolean { apply(); return true }
        override fun apply() {
            if (smazat) data.clear()
            for ((k, v) in zmeny) if (v == null) data.remove(k) else data[k] = v
        }
    }
}

class FakeContext : ContextWrapper(null) {
    private val prefs = HashMap<String, FakePrefs>()
    override fun getApplicationContext(): Context = this
    override fun getSharedPreferences(name: String, mode: Int): SharedPreferences = prefs.getOrPut(name) { FakePrefs() }
}
