package com.fuse.platformview

import androidx.compose.foundation.layout.Column
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.livedata.observeAsState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.fuse.android.kt.PlatformViewData
import com.fuse.android.kt.PlatformViewRegistry

/**
 * Registration bootstrap: Fuse.PlatformView looks up this object on first use.
 */
object PlatformViewSetup {
    @JvmStatic
    fun install() {
        PlatformViewRegistry.register("SampleView") { data -> SampleComposeView(data) }
    }
}

/** Sample Compose view used by the Fuse.PlatformView manual test app. */
@Composable
fun SampleComposeView(data: PlatformViewData) {
    val text by data.getString.observeAsState("")
    val count by data.getInteger.observeAsState(0)
    val doubleValue by data.getDouble.observeAsState(0.0)
    val profile by data.get.observeAsState(emptyMap())
    var lastCommand by remember { mutableStateOf("") }

    DisposableEffect(Unit) {
        data.onCommand = { command, arguments ->
            lastCommand = "$command $arguments"
            if (command == "bump") {
                data.updateInteger((data.getInteger.value ?: 0) + 1)
            }
        }
        onDispose { data.onCommand = { _, _ -> } }
    }

    Column {
        Text(text)
        Text("count: $count double: $doubleValue")
        (profile["name"] as? String)?.let { Text("profile: $it") }
        Button(onClick = { data.eventCallback("tapped", """{"source":"compose"}""") }) {
            Text("Native tap")
        }
        Text(lastCommand)
    }
}
