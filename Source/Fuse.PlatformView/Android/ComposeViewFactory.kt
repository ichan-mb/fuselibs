package com.fuse.android.kt;

import android.content.Context;
import android.util.AttributeSet;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import androidx.compose.ui.platform.ComposeView;
import androidx.compose.ui.platform.ViewCompositionStrategy;
import com.fuse.Activity;
import androidx.lifecycle.ViewModel
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.findViewTreeLifecycleOwner
import org.json.JSONArray
import org.json.JSONObject


class PlatformViewData() : ViewModel() {

    var onCallbackReceived: (String, String) -> Unit = { key: String, value: String -> }
    val get: MutableLiveData<Map<String, Any>> = MutableLiveData(mapOf())
    val getArray: MutableLiveData<List<Any>> = MutableLiveData(listOf())
    val getString: MutableLiveData<String> = MutableLiveData("")
    val getInteger: MutableLiveData<Int> = MutableLiveData(0)
    val getFloat: MutableLiveData<Float> = MutableLiveData(0.0f)
    val getBool: MutableLiveData<Boolean> = MutableLiveData(false)


    fun installCallback(lifecycleOwner: LifecycleOwner, onIntegerReceived: (Int) -> Unit, onFloatReceived: (Float) -> Unit, onBoolReceived: (Boolean) -> Unit,onStringReceived: (String) -> Unit, onObjectReceived: (Map<String, Any>) -> Unit, onArrayReceived: (List<Any>) -> Unit, onCallbackReceived: (String, String) -> Unit) {
        getInteger.observe(lifecycleOwner, onIntegerReceived)
        getFloat.observe(lifecycleOwner, onFloatReceived)
        getBool.observe(lifecycleOwner, onBoolReceived)
        getString.observe(lifecycleOwner, onStringReceived)
        get.observe(lifecycleOwner, onObjectReceived)
        getArray.observe(lifecycleOwner, onArrayReceived)
        this.onCallbackReceived = onCallbackReceived
    }

    fun eventCallback(key: String, value: String) {
        onCallbackReceived(key, value)
    }

    fun updateInteger(newInt: Int) {
        getInteger.value = newInt
    }

    fun updateFloat(newFloat: Float) {
        getFloat.value = newFloat
    }

    fun updateBool(newBool: Boolean) {
        getBool.value = newBool
    }

    fun updateString(newString: String) {
        getString.value = newString
    }

    fun updateObject(newObject: Map<String, Any>) {
        get.value = newObject
    }

    fun updateList(newList: List<Any>) {
        getArray.value = newList
    }

}

class ComposeContainer @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : FrameLayout(context, attrs) {

    private var platformData: PlatformViewData = PlatformViewData();
    private var composeView: ComposeView = ComposeView(Activity.getRootActivity());

    init {
        composeView.layoutParams =
            LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        composeView.setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
        addView(composeView)
    }

    fun showView(name: String, integerCallback: (Int) -> Unit, floatCallback: (Float) -> Unit, boolCallback: (Boolean) -> Unit, stringCallback: (String) -> Unit, objectCallback: (String) -> Unit, arrayCallback: (String) -> Unit, eventCallback: (String, String) -> Unit) {
        viewRegistration[name]?.let { it ->
            composeView.setContent {
                composeView.findViewTreeLifecycleOwner()?.let { lifeCycleOwner ->
                    platformData.installCallback(lifeCycleOwner, integerCallback, floatCallback, boolCallback, stringCallback, { data: Map<String, Any> -> objectCallback(JSONObject(data).toString()) }, { data: List<Any> -> arrayCallback(JSONArray(data).toString()) }, eventCallback)
                }
                it(platformData)
            }
        }
    }


    fun setDataInteger(data: Int) {
        platformData.updateInteger(data)
    }

    fun setDataFloat(data: Float) {
        platformData.updateFloat(data)
    }
    fun setDataBool(data: Boolean) {
        platformData.updateBool(data)
    }

    fun setDataString(data: String) {
        platformData.updateString(data)
    }

    fun setDataObject(data: String) {
        val jsonObj = JSONObject(data)
        val map = jsonObj.toMap()
        platformData.updateObject(map)
    }

    fun setDataArray(data: String) {
        val jsonArray = JSONArray(data)
        val list = jsonArray.toArrayList()
        platformData.updateList(list)
    }

}

fun JSONArray.toArrayList(): ArrayList<Any> {
    val list = ArrayList<Any>()
    for (i in 0 until this.length()) {
        val obj = this.optJSONObject(i)
        if (obj != null)
            list.add(obj.toMap())
        else
            list.add(this.get(i))
    }
    return list
}

fun JSONObject.toMap(): Map<String, Any> = keys().asSequence().associateWith {
    when (val value = this[it])
    {
        is JSONArray ->
        {
            val map = (0 until value.length()).associate { Pair(it.toString(), value[it]) }
            JSONObject(map).toMap().values.toList()
        }
        is JSONObject -> value.toMap()
        JSONObject.NULL -> null
        else  -> value
    } as Any
}
