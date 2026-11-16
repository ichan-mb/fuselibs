package com.fuse.android.kt

import android.content.Context
import android.util.AttributeSet
import android.view.View.MeasureSpec
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.compose.ui.unit.LayoutDirection
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import com.fuse.Activity
import org.json.JSONArray
import org.json.JSONObject

/** A composable that renders a native view for a Fuse `PlatformView`. */
typealias PlatformViewContent = @Composable (PlatformViewData) -> Unit

/**
 * Registry of Compose views available to Fuse `PlatformView`s, keyed by `ViewName`.
 *
 * Prefer `PlatformViewRegistry.register` over assigning directly.
 */
val viewRegistration: MutableMap<String, PlatformViewContent> = LinkedHashMap()

/**
 * Registration API for Compose views embedded in Fuse.
 *
 * Views should be registered before a `PlatformView` with the same `ViewName` is created.
 *
 * ```kotlin
 * PlatformViewRegistry.register("MyView") { data -> MyView(data) }
 * ```
 */
object PlatformViewRegistry {
    private var didBootstrap = false

    /**
     * Runs the app-provided `com.fuse.platformview.PlatformViewSetup.install()` hook once, if present.
     *
     * Apps register their views in that object:
     * ```kotlin
     * package com.fuse.platformview
     *
     * object PlatformViewSetup {
     *     @JvmStatic fun install() {
     *         PlatformViewRegistry.register("MyView") { data -> MyView(data) }
     *     }
     * }
     * ```
     */
    private fun bootstrapIfNeeded() {
        if (didBootstrap) return
        didBootstrap = true

        try {
            val setup = Class.forName("com.fuse.platformview.PlatformViewSetup")
            setup.getMethod("install").invoke(null)
        } catch (e: ClassNotFoundException) {
            // The app did not provide a setup object.
        } catch (e: Throwable) {
            android.util.Log.e("PlatformView", "PlatformViewSetup.install() failed", e)
        }
    }

    /** Registers a Compose view under the given name. */
    fun register(name: String, content: PlatformViewContent) {
        bootstrapIfNeeded()
        viewRegistration[name] = content
    }

    /** Removes the view registered under the given name. */
    fun unregister(name: String) {
        bootstrapIfNeeded()
        viewRegistration.remove(name)
    }

    /** Returns the view registered under the given name, if any. */
    internal fun find(name: String): PlatformViewContent? {
        bootstrapIfNeeded()
        return viewRegistration[name]
    }
}

/**
 * Jetpack Compose View Factory for Fuse Platform Views
 *
 * This file contains the core components for integrating Jetpack Compose views into Fuse
 * applications. It provides a factory pattern for creating and managing Compose views with two-way
 * data binding using Android's LiveData architecture for reactive programming.
 */

/**
 * ViewModel that manages data synchronization between Fuse and Jetpack Compose views. This class
 * uses MutableLiveData to notify Compose views when data changes, and holds callback functions used
 * to notify Fuse when data is modified from the Compose side.
 *
 * Fuse-to-native updates go through `set*`, which only updates the LiveData. Native-to-Fuse updates
 * go through `update*`, which updates the LiveData and invokes the matching callback. Keeping these
 * paths separate prevents data pushed from Fuse from being echoed back to Fuse.
 */
class PlatformViewData() : ViewModel() {

    /** General event callback for custom events from Compose views */
    var onCallbackReceived: (String, String) -> Unit = { _, _ -> }

    /**
     * Invoked when Fuse sends a command to this native view via `PlatformView.Invoke`.
     * The first argument is the command name, the second is the JSON arguments (or an empty string).
     */
    var onCommand: (String, String) -> Unit = { _, _ -> }

    /** Invoked when this native view becomes visible. */
    var onAppeared: () -> Unit = {}

    /** Invoked when this native view is no longer visible. */
    var onDisappeared: () -> Unit = {}

    /** Environment overrides supplied by Fuse (for example `colorScheme` and `layoutDirection`). */
    var environment: Map<String, Any?> by mutableStateOf(emptyMap())
        private set

    /** LiveData containing object/map data passed between Fuse and Compose */
    val get: MutableLiveData<Map<String, Any?>> = MutableLiveData<Map<String, Any?>>(emptyMap<String, Any?>())

    /** LiveData containing array/list data passed between Fuse and Compose */
    val getArray: MutableLiveData<List<Any?>> = MutableLiveData<List<Any?>>(emptyList<Any?>())

    /** LiveData containing string data passed between Fuse and Compose */
    val getString: MutableLiveData<String> = MutableLiveData("")

    /** LiveData containing integer data passed between Fuse and Compose */
    val getInteger: MutableLiveData<Int> = MutableLiveData(0)

    /** LiveData containing float data passed between Fuse and Compose */
    val getFloat: MutableLiveData<Float> = MutableLiveData(0.0f)

    /** LiveData containing double data passed between Fuse and Compose */
    val getDouble: MutableLiveData<Double> = MutableLiveData(0.0)

    /** LiveData containing boolean data passed between Fuse and Compose */
    val getBool: MutableLiveData<Boolean> = MutableLiveData(false)

    /** Callback invoked when integer data changes in Compose */
    private var onIntegerReceived: (Int) -> Unit = {}
    /** Callback invoked when double data changes in Compose */
    private var onDoubleReceived: (Double) -> Unit = {}
    /** Callback invoked when float data changes in Compose */
    private var onFloatReceived: (Float) -> Unit = {}
    /** Callback invoked when boolean data changes in Compose */
    private var onBoolReceived: (Boolean) -> Unit = {}
    /** Callback invoked when string data changes in Compose */
    private var onStringReceived: (String) -> Unit = {}
    /** Callback invoked when object/map data changes in Compose */
    private var onObjectReceived: (Map<String, Any?>) -> Unit = {}
    /** Callback invoked when array/list data changes in Compose */
    private var onArrayReceived: (List<Any?>) -> Unit = {}

    /**
     * Registers the callbacks used to propagate native changes back to Fuse.
     *
     * @param onIntegerReceived Callback invoked when integer data changes in Compose
     * @param onFloatReceived Callback invoked when float data changes in Compose
     * @param onBoolReceived Callback invoked when boolean data changes in Compose
     * @param onStringReceived Callback invoked when string data changes in Compose
     * @param onObjectReceived Callback invoked when object data changes in Compose
     * @param onArrayReceived Callback invoked when array data changes in Compose
     * @param onCallbackReceived Callback invoked for custom events from Compose
     */
    fun installCallback(
            onIntegerReceived: (Int) -> Unit,
            onDoubleReceived: (Double) -> Unit,
            onFloatReceived: (Float) -> Unit,
            onBoolReceived: (Boolean) -> Unit,
            onStringReceived: (String) -> Unit,
            onObjectReceived: (Map<String, Any?>) -> Unit,
            onArrayReceived: (List<Any?>) -> Unit,
            onCallbackReceived: (String, String) -> Unit
    ) {
        this.onIntegerReceived = onIntegerReceived
        this.onDoubleReceived = onDoubleReceived
        this.onFloatReceived = onFloatReceived
        this.onBoolReceived = onBoolReceived
        this.onStringReceived = onStringReceived
        this.onObjectReceived = onObjectReceived
        this.onArrayReceived = onArrayReceived
        this.onCallbackReceived = onCallbackReceived
    }

    /** Removes all callbacks so a disposed view does not notify Fuse anymore. */
    fun clearCallbacks() {
        onIntegerReceived = {}
        onDoubleReceived = {}
        onFloatReceived = {}
        onBoolReceived = {}
        onStringReceived = {}
        onObjectReceived = {}
        onArrayReceived = {}
        onCallbackReceived = { _, _ -> }
        onCommand = { _, _ -> }
        onAppeared = {}
        onDisappeared = {}
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

    /** Delivers a command sent from Fuse to this native view. */
    fun invoke(command: String, arguments: String) {
        onCommand(command, arguments)
    }

    /** Applies environment overrides supplied by Fuse. */
    fun setEnvironment(newEnvironment: Map<String, Any?>) {
        environment = newEnvironment
    }

    // Native -> Fuse

    /** Updates the integer value and notifies Fuse */
    fun updateInteger(newInt: Int) {
        getInteger.value = newInt
        onIntegerReceived(newInt)
    }

    /** Updates the float value and notifies Fuse */
    fun updateFloat(newFloat: Float) {
        getFloat.value = newFloat
        onFloatReceived(newFloat)
    }

    /** Updates the double value and notifies Fuse */
    fun updateDouble(newDouble: Double) {
        getDouble.value = newDouble
        onDoubleReceived(newDouble)
    }

    /** Updates the boolean value and notifies Fuse */
    fun updateBool(newBool: Boolean) {
        getBool.value = newBool
        onBoolReceived(newBool)
    }

    /** Updates the string value and notifies Fuse */
    fun updateString(newString: String) {
        getString.value = newString
        onStringReceived(newString)
    }

    /** Updates the object/map value and notifies Fuse */
    fun updateObject(newObject: Map<String, Any?>) {
        get.value = newObject
        onObjectReceived(newObject)
    }

    /** Updates the array/list value and notifies Fuse */
    fun updateList(newList: List<Any?>) {
        getArray.value = newList
        onArrayReceived(newList)
    }

    // Fuse -> native (no callback, so updates are not echoed back)

    /** Updates integer data from Fuse, without notifying Fuse. */
    fun setInteger(newInt: Int) {
        getInteger.value = newInt
    }

    /** Updates float data from Fuse, without notifying Fuse. */
    fun setFloat(newFloat: Float) {
        getFloat.value = newFloat
    }

    /** Updates double data from Fuse, without notifying Fuse. */
    fun setDouble(newDouble: Double) {
        getDouble.value = newDouble
    }

    /** Updates boolean data from Fuse, without notifying Fuse. */
    fun setBool(newBool: Boolean) {
        getBool.value = newBool
    }

    /** Updates string data from Fuse, without notifying Fuse. */
    fun setString(newString: String) {
        getString.value = newString
    }

    /** Updates object/map data from Fuse, without notifying Fuse. */
    fun setObject(newObject: Map<String, Any?>) {
        get.value = newObject
    }

    /** Updates array/list data from Fuse, without notifying Fuse. */
    fun setList(newList: List<Any?>) {
        getArray.value = newList
    }

    protected override fun onCleared() {
        clearCallbacks()
        super.onCleared()
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
     * @param onViewNotFound Callback invoked when no view is registered under `name`
     */
    fun showView(
            name: String,
            integerCallback: (Int) -> Unit,
            doubleCallback: (Double) -> Unit,
            floatCallback: (Float) -> Unit,
            boolCallback: (Boolean) -> Unit,
            stringCallback: (String) -> Unit,
            objectCallback: (String) -> Unit,
            arrayCallback: (String) -> Unit,
            eventCallback: (String, String) -> Unit,
            onViewNotFound: (String) -> Unit,
            loadedCallback: () -> Unit,
            appearedCallback: () -> Unit,
            disappearedCallback: () -> Unit
    ) {
        val content = PlatformViewRegistry.find(name)
        if (content == null) {
            onViewNotFound(name)
            composeView.setContent { }
            return
        }

        // Callbacks are installed once, outside of composition, so they are not
        // re-registered on every recomposition.
        platformData.installCallback(
                integerCallback,
                doubleCallback,
                floatCallback,
                boolCallback,
                stringCallback,
                { data -> objectCallback(data.toJsonString()) },
                { data -> arrayCallback(data.toJsonString()) },
                eventCallback
        )
        platformData.onAppeared = appearedCallback
        platformData.onDisappeared = disappearedCallback

        composeView.setContent {
            val layoutDirection = when (platformData.environment["layoutDirection"]) {
                "rtl" -> LayoutDirection.Rtl
                "ltr" -> LayoutDirection.Ltr
                else -> LocalLayoutDirection.current
            }

            CompositionLocalProvider(LocalLayoutDirection provides layoutDirection) {
                DisposableEffect(Unit) {
                    platformData.onAppeared()
                    onDispose { platformData.onDisappeared() }
                }
                content(platformData)
            }
        }

        loadedCallback()
    }

    /** Updates integer data from Fuse side, triggering Compose view updates */
    fun setDataInteger(data: Int) {
        platformData.setInteger(data)
    }

    /** Updates float data from Fuse side, triggering Compose view updates */
    fun setDataFloat(data: Float) {
        platformData.setFloat(data)
    }

    /** Updates double data from Fuse side, triggering Compose view updates */
    fun setDataDouble(data: Double) {
        platformData.setDouble(data)
    }

    /** Updates boolean data from Fuse side, triggering Compose view updates */
    fun setDataBool(data: Boolean) {
        platformData.setBool(data)
    }

    /** Updates string data from Fuse side, triggering Compose view updates */
    fun setDataString(data: String) {
        platformData.setString(data)
    }

    /**
     * Measures the container. When a dimension is unspecified (for example `Height="Auto"`),
     * the size reported by the hosted Compose content is used.
     */
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        composeView.measure(widthMeasureSpec, heightMeasureSpec)

        val width = when (MeasureSpec.getMode(widthMeasureSpec)) {
            MeasureSpec.UNSPECIFIED -> composeView.measuredWidth
            MeasureSpec.AT_MOST -> minOf(composeView.measuredWidth, MeasureSpec.getSize(widthMeasureSpec))
            else -> MeasureSpec.getSize(widthMeasureSpec)
        }

        val height = when (MeasureSpec.getMode(heightMeasureSpec)) {
            MeasureSpec.UNSPECIFIED -> composeView.measuredHeight
            MeasureSpec.AT_MOST -> minOf(composeView.measuredHeight, MeasureSpec.getSize(heightMeasureSpec))
            else -> MeasureSpec.getSize(heightMeasureSpec)
        }

        setMeasuredDimension(width, height)
    }

    /** Delivers a command from Fuse to the current Compose content. */
    fun invoke(command: String, arguments: String) {
        platformData.invoke(command, arguments)
    }

    /** Applies environment overrides (color scheme, layout direction) from Fuse. */
    fun setEnvironment(json: String) {
        val map: Map<String, Any?> = try {
            JSONObject(json).toMap()
        } catch (e: Exception) {
            emptyMap()
        }
        platformData.setEnvironment(map)
        contentDescription = map["accessibilityLabel"] as? String
    }

    /**
     * Updates object data from Fuse side by parsing JSON string to Map. The JSON is deserialized
     * and passed to Compose views as a Map<String, Any?>.
     *
     * @param data JSON string representing the object data
     */
    fun setDataObject(data: String) {
        val map: Map<String, Any?> = try {
            JSONObject(data).toMap()
        } catch (e: Exception) {
            emptyMap()
        }
        platformData.setObject(map)
    }

    /**
     * Updates array data from Fuse side by parsing JSON string to List. The JSON array is
     * deserialized and passed to Compose views as a List<Any?>.
     *
     * @param data JSON string representing the array data
     */
    fun setDataArray(data: String) {
        val list: List<Any?> = try {
            JSONArray(data).toArrayList()
        } catch (e: Exception) {
            emptyList()
        }
        platformData.setList(list)
    }

    /** Removes the current Compose content and stops notifying Fuse. */
    fun clearView() {
        platformData.clearCallbacks()
        composeView.setContent { }
    }

    /** Releases all callbacks and content associated with this container. */
    fun dispose() {
        clearView()
        removeAllViews()
    }
}

/**
 * Converts a [JSONArray] to an [ArrayList]. Nested objects and arrays are converted recursively,
 * and `JSONObject.NULL` is converted to Kotlin `null`.
 *
 * @return ArrayList containing the converted JSON array elements
 */
fun JSONArray.toArrayList(): ArrayList<Any?> {
    val list = ArrayList<Any?>(length())
    for (i in 0 until length()) {
        list.add(opt(i).toKotlinValue())
    }
    return list
}

/**
 * Converts a [JSONObject] to a [Map]. Nested objects and arrays are converted recursively, and
 * `JSONObject.NULL` is converted to Kotlin `null`.
 *
 * @return Map containing the converted JSON object data
 */
fun JSONObject.toMap(): Map<String, Any?> {
    val map = LinkedHashMap<String, Any?>()
    val keys = keys()
    while (keys.hasNext()) {
        val key = keys.next()
        map[key] = opt(key).toKotlinValue()
    }
    return map
}

/** Converts a raw JSON value to its Kotlin equivalent. */
private fun Any?.toKotlinValue(): Any? = when (this) {
    null, JSONObject.NULL -> null
    is JSONObject -> toMap()
    is JSONArray -> toArrayList()
    else -> this
}

/** Converts a Kotlin value to a JSON-safe value that [JSONObject] and [JSONArray] accept. */
private fun Any?.toJsonValue(): Any {
    if (this == null || this == JSONObject.NULL) return JSONObject.NULL

    if (this is Map<*, *>) {
        val json = JSONObject()
        for ((key, value) in this) {
            json.put(key.toString(), value.toJsonValue())
        }
        return json
    }

    if (this is Iterable<*>) {
        val json = JSONArray()
        for (value in this) {
            json.put(value.toJsonValue())
        }
        return json
    }

    if (this is Array<*>) {
        val json = JSONArray()
        for (value in this) {
            json.put(value.toJsonValue())
        }
        return json
    }

    return this
}

/** Serializes a map to a JSON string for notifying Fuse. */
private fun Map<String, Any?>.toJsonString(): String = this.toJsonValue().toString()

/** Serializes a list to a JSON string for notifying Fuse. */
private fun List<Any?>.toJsonString(): String = this.toJsonValue().toString()
