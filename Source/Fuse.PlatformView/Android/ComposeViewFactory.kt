package com.fuse.android.kt

import android.content.Context
import android.util.AttributeSet
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.findViewTreeLifecycleOwner
import com.fuse.Activity
import org.json.JSONArray
import org.json.JSONObject

/**
 * Jetpack Compose View Factory for Fuse Platform Views
 *
 * This file contains the core components for integrating Jetpack Compose views into Fuse
 * applications. It provides a factory pattern for creating and managing Compose views with two-way
 * data binding using Android's LiveData architecture for reactive programming.
 */

/**
 * ViewModel that manages data synchronization between Fuse and Jetpack Compose views. This class
 * uses MutableLiveData to automatically notify Compose views when data changes, and includes
 * callback functions to notify Fuse when data is modified from the Compose side.
 *
 * The ViewModel follows Android's MVVM architecture pattern and ensures data persistence across
 * configuration changes while maintaining the connection to Fuse's data layer.
 */
class PlatformViewData() : ViewModel() {

    /** General event callback for custom events from Compose views */
    var onCallbackReceived: (String, String) -> Unit = { key: String, value: String -> }

    /** LiveData containing object/map data passed between Fuse and Compose */
    val get: MutableLiveData<Map<String, Any>> = MutableLiveData(mapOf())

    /** LiveData containing array/list data passed between Fuse and Compose */
    val getArray: MutableLiveData<List<Any>> = MutableLiveData(listOf())

    /** LiveData containing string data passed between Fuse and Compose */
    val getString: MutableLiveData<String> = MutableLiveData("")

    /** LiveData containing integer data passed between Fuse and Compose */
    val getInteger: MutableLiveData<Int> = MutableLiveData(0)

    /** LiveData containing float data passed between Fuse and Compose */
    val getFloat: MutableLiveData<Float> = MutableLiveData(0.0f)

    /** LiveData containing boolean data passed between Fuse and Compose */
    val getBool: MutableLiveData<Boolean> = MutableLiveData(false)

    /**
     * Sets up observers for all LiveData properties and establishes callback connections to Fuse.
     * This method connects the Android LiveData system with Fuse's callback system, enabling
     * two-way data binding between Compose views and Fuse.
     *
     * @param lifecycleOwner The lifecycle owner to bind observers to (typically the Activity)
     * @param onIntegerReceived Callback invoked when integer data changes in Compose
     * @param onFloatReceived Callback invoked when float data changes in Compose
     * @param onBoolReceived Callback invoked when boolean data changes in Compose
     * @param onStringReceived Callback invoked when string data changes in Compose
     * @param onObjectReceived Callback invoked when object data changes in Compose
     * @param onArrayReceived Callback invoked when array data changes in Compose
     * @param onCallbackReceived Callback invoked for custom events from Compose
     */
    fun installCallback(
            lifecycleOwner: LifecycleOwner,
            onIntegerReceived: (Int) -> Unit,
            onFloatReceived: (Float) -> Unit,
            onBoolReceived: (Boolean) -> Unit,
            onStringReceived: (String) -> Unit,
            onObjectReceived: (Map<String, Any>) -> Unit,
            onArrayReceived: (List<Any>) -> Unit,
            onCallbackReceived: (String, String) -> Unit
    ) {
        getInteger.observe(lifecycleOwner, onIntegerReceived)
        getFloat.observe(lifecycleOwner, onFloatReceived)
        getBool.observe(lifecycleOwner, onBoolReceived)
        getString.observe(lifecycleOwner, onStringReceived)
        get.observe(lifecycleOwner, onObjectReceived)
        getArray.observe(lifecycleOwner, onArrayReceived)
        this.onCallbackReceived = onCallbackReceived
    }

    /**
     * Triggers a custom event callback to Fuse with the specified key-value pair.
     *
     * @param key The event name/key
     * @param value The event value/data
     */
    fun eventCallback(key: String, value: String) {
        onCallbackReceived(key, value)
    }

    /** Updates the integer LiveData value, triggering observers and Fuse callbacks */
    fun updateInteger(newInt: Int) {
        getInteger.value = newInt
    }

    /** Updates the float LiveData value, triggering observers and Fuse callbacks */
    fun updateFloat(newFloat: Float) {
        getFloat.value = newFloat
    }

    /** Updates the boolean LiveData value, triggering observers and Fuse callbacks */
    fun updateBool(newBool: Boolean) {
        getBool.value = newBool
    }

    /** Updates the string LiveData value, triggering observers and Fuse callbacks */
    fun updateString(newString: String) {
        getString.value = newString
    }

    /** Updates the object/map LiveData value, triggering observers and Fuse callbacks */
    fun updateObject(newObject: Map<String, Any>) {
        get.value = newObject
    }

    /** Updates the array/list LiveData value, triggering observers and Fuse callbacks */
    fun updateList(newList: List<Any>) {
        getArray.value = newList
    }
}

/**
 * Container view that hosts Jetpack Compose content within Fuse applications. This class extends
 * FrameLayout and contains a ComposeView that renders Compose UI.
 *
 * The container manages the lifecycle of Compose content, handles data synchronization between Fuse
 * and Compose through PlatformViewData, and provides methods for updating data from the Fuse side.
 * It uses ViewCompositionStrategy to ensure proper disposal of Compose content when the view tree
 * is destroyed.
 *
 * @param context The Android context for view creation
 * @param attrs Optional attributes for the view (default: null)
 */
class ComposeContainer @JvmOverloads constructor(context: Context, attrs: AttributeSet? = null) :
        FrameLayout(context, attrs) {

    /** Data model managing synchronization between Fuse and Compose */
    private var platformData: PlatformViewData = PlatformViewData()

    /** ComposeView that renders the actual Jetpack Compose content */
    private var composeView: ComposeView = ComposeView(Activity.getRootActivity())

    init {
        // Configure the ComposeView to fill the container and handle lifecycle properly
        composeView.layoutParams =
                LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT
                )
        composeView.setViewCompositionStrategy(
                ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed
        )
        addView(composeView)
    }

    /**
     * Displays the specified Compose view and establishes data binding callbacks. This method looks
     * up the registered Compose view by name and sets it as the content of the ComposeView. It also
     * establishes all necessary callback connections for two-way data binding between the Compose
     * view and Fuse.
     *
     * @param name The name of the registered Compose view to display
     * @param integerCallback Callback for integer data changes from Compose to Fuse
     * @param floatCallback Callback for float data changes from Compose to Fuse
     * @param boolCallback Callback for boolean data changes from Compose to Fuse
     * @param stringCallback Callback for string data changes from Compose to Fuse
     * @param objectCallback Callback for object data changes from Compose to Fuse (JSON serialized)
     * @param arrayCallback Callback for array data changes from Compose to Fuse (JSON serialized)
     * @param eventCallback Callback for custom events from Compose to Fuse
     */
    fun showView(
            name: String,
            integerCallback: (Int) -> Unit,
            floatCallback: (Float) -> Unit,
            boolCallback: (Boolean) -> Unit,
            stringCallback: (String) -> Unit,
            objectCallback: (String) -> Unit,
            arrayCallback: (String) -> Unit,
            eventCallback: (String, String) -> Unit
    ) {
        viewRegistration[name]?.let { it ->
            composeView.setContent {
                composeView.findViewTreeLifecycleOwner()?.let { lifeCycleOwner ->
                    platformData.installCallback(
                            lifeCycleOwner,
                            integerCallback,
                            floatCallback,
                            boolCallback,
                            stringCallback,
                            { data: Map<String, Any> ->
                                objectCallback(JSONObject(data).toString())
                            },
                            { data: List<Any> -> arrayCallback(JSONArray(data).toString()) },
                            eventCallback
                    )
                }
                it(platformData)
            }
        }
    }

    /** Updates integer data from Fuse side, triggering Compose view updates */
    fun setDataInteger(data: Int) {
        platformData.updateInteger(data)
    }

    /** Updates float data from Fuse side, triggering Compose view updates */
    fun setDataFloat(data: Float) {
        platformData.updateFloat(data)
    }

    /** Updates boolean data from Fuse side, triggering Compose view updates */
    fun setDataBool(data: Boolean) {
        platformData.updateBool(data)
    }

    /** Updates string data from Fuse side, triggering Compose view updates */
    fun setDataString(data: String) {
        platformData.updateString(data)
    }

    /**
     * Updates object data from Fuse side by parsing JSON string to Map. The JSON is deserialized
     * and passed to Compose views as a Map<String, Any>.
     *
     * @param data JSON string representing the object data
     */
    fun setDataObject(data: String) {
        val jsonObj = JSONObject(data)
        val map = jsonObj.toMap()
        platformData.updateObject(map)
    }

    /**
     * Updates array data from Fuse side by parsing JSON string to List. The JSON array is
     * deserialized and passed to Compose views as a List<Any>.
     *
     * @param data JSON string representing the array data
     */
    fun setDataArray(data: String) {
        val jsonArray = JSONArray(data)
        val list = jsonArray.toArrayList()
        platformData.updateList(list)
    }
}

/**
 * Extension function to convert JSONArray to ArrayList for easier use in Compose. Handles nested
 * JSONObjects by recursively converting them to Maps.
 *
 * @return ArrayList containing the converted JSON array elements
 */
fun JSONArray.toArrayList(): ArrayList<Any> {
    val list = ArrayList<Any>()
    for (i in 0 until this.length()) {
        val obj = this.optJSONObject(i)
        if (obj != null) list.add(obj.toMap()) else list.add(this.get(i))
    }
    return list
}

/**
 * Extension function to convert JSONObject to Map for easier use in Compose. Handles nested
 * structures including nested JSONArrays and JSONObjects. Also handles JSONObject.NULL values by
 * converting them to Kotlin null.
 *
 * @return Map<String, Any> containing the converted JSON object data
 */
fun JSONObject.toMap(): Map<String, Any> =
        keys().asSequence().associateWith {
            when (val value = this[it]) {
                is JSONArray -> {
                    val map = (0 until value.length()).associate { Pair(it.toString(), value[it]) }
                    JSONObject(map).toMap().values.toList()
                }
                is JSONObject -> value.toMap()
                JSONObject.NULL -> null
                else -> value
            } as
                    Any
        }
