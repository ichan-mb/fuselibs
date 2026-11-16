# Fuse.PlatformView Module

## Overview

The **Fuse.PlatformView** module enables developers to embed native platform-specific UI components directly into their Fuse applications. This powerful module provides a bridge between Fuse's cross-platform framework and native UI frameworks:

- **iOS**: Integrates SwiftUI views seamlessly
- **Android**: Integrates Jetpack Compose views seamlessly

## Key Features

### 🔄 Two-Way Data Binding

- Automatic synchronization between Fuse and native views
- Support for multiple data types (string, bool, int, float, objects, arrays)
- Real-time updates when data changes on either side

### 📱 Cross-Platform Native Integration

- SwiftUI views on iOS using UIHostingController
- Jetpack Compose views on Android using ComposeView
- Consistent API across both platforms

### 🎯 Event System

- Custom events from native views back to Fuse
- Type-safe event handling with serialization support
- JavaScript integration through IScriptEvent

### 📊 Data Type Support

- **Primitive types**: string, boolean, integer, float, double
- **Complex types**: objects and arrays (JSON serialized)
- **Dates and binary**: send via `DataObject`/`DataString` (ISO 8601 or base64), or epoch
  milliseconds via `DataDouble`
- **Type-safe**: Automatic conversion and validation

## Architecture

### Core Components

#### 1. PlatformViewBase (PlatformView.uno)

The main abstract class that provides:

- Data binding properties for all supported types
- Event handling infrastructure
- Property change notifications
- UX binding support

#### 2. Platform-Specific Native Views

- **iOS**: `PlatformNativeView` integrates with SwiftUIViewFactory
- **Android**: `PlatformNativeView` integrates with ComposeViewFactory

#### 3. View Factories

- **SwiftUIViewFactory**: Manages SwiftUI view creation and data synchronization
- **ComposeViewFactory**: Manages Jetpack Compose view creation and data synchronization
- **PlatformViewRegistry**: Registers native views so `PlatformView` can look them up by `ViewName`

#### 4. Data Models

- **iOS**: `PlatformViewData` (ObservableObject with @Published properties)
- **Android**: `PlatformViewData` (ViewModel with MutableLiveData)

### Data Flow

```
Fuse Application
       ↕️ (Two-way binding)
PlatformViewBase
       ↕️ (Platform detection)
PlatformNativeView (iOS/Android)
       ↕️ (Factory communication)
ViewFactory (SwiftUI/Compose)
       ↕️ (Data synchronization)
Native View (SwiftUI/Compose)
```

## Usage

### Basic Usage

```xml
<PlatformView ViewName="MyCustomView"
              DataString="Hello from Fuse"
              DataInteger="42"
              DataBool="true" />
```

### With Event Handling

```xml
<PlatformView ViewName="InteractiveView"
              DataObject="{someObject}"
              EventHandler="{onNativeEvent}" />
```

### Sending Commands to the Native View

Use `Invoke` to call into the native view imperatively. Arguments are serialized to JSON.

```xml
<PlatformView ux:Name="MyView" ViewName="InteractiveView" />
```

```javascript
// From JavaScript (arguments are optional)
MyView.invoke("scrollToTop");
MyView.invoke("selectItem", { index: 3 });
```

The native view receives commands through `PlatformViewData.onCommand`:

```swift
// SwiftUI
.onAppear {
    data.onCommand = { command, arguments in
        if command == "scrollToTop" { /* ... */ }
    }
}
```

```kotlin
// Compose
DisposableEffect(Unit) {
    data.onCommand = { command, arguments ->
        if (command == "scrollToTop") { /* ... */ }
    }
    onDispose { data.onCommand = { _, _ -> } }
}
```

### Lifecycle Events

`PlatformView` raises lifecycle events that can be bound in UX:

```xml
<PlatformView ViewName="MyCustomView"
              Loaded="{onLoaded}"
              Appeared="{onAppeared}"
              Disappeared="{onDisappeared}"
              Unloaded="{onUnloaded}" />
```

- `Loaded` — the native view was created and is ready for data and commands.
- `Appeared` — the native view became visible.
- `Disappeared` — the native view is no longer visible.
- `Unloaded` — the native view was disposed.

### Sizing

The native view reports its intrinsic content size, so dimensions can be set to `Auto`:

```xml
<PlatformView ViewName="MyCustomView" Height="Auto" />
```

### Arguments

`DataObject` is the generic argument bag. For convenience you can set individual keys:

```javascript
MyView.setArgument("title", "Hello");
MyView.setArgument("count", 3);
MyView.removeArgument("title");
MyView.clearArguments();
```

The native view reads the same map (`data.get` on iOS, `data.get` on Android).
Avoid mixing `setArgument` with a bound `DataObject` on the same view — they share one channel.

### Update Batching

By default every data change is pushed to the native view immediately. For high-frequency
updates (for example animation-driven values), set `DataUpdateMode="Batched"` to coalesce
changes and push the latest values once per frame:

```xml
<PlatformView ViewName="MyView" DataUpdateMode="Batched" />
```

Local Fuse property changes and bindings still update immediately; only the native push is
coalesced. `DataObject`/`DataArray` are serialized once per frame instead of on every change.

### Environment Overrides

Override the color scheme and layout direction used by the native view:

```xml
<PlatformView ViewName="MyView"
              ColorScheme="Dark"
              LayoutDirection="RightToLeft" />
```

- `ColorScheme`: `Unspecified` (default, inherits system), `Light`, `Dark`.
- `LayoutDirection`: `Unspecified` (default, inherits system), `LeftToRight`, `RightToLeft`.

On iOS these are applied as SwiftUI environment values. On Android the layout direction is
provided through `LocalLayoutDirection`, and the color scheme is exposed as
`data.environment["colorScheme"]` so the Compose view can react to it.

### Accessibility

```xml
<PlatformView ViewName="MyView"
              AccessibilityLabel="Playback controls"
              AccessibilityHint="Double tap to open the player" />
```

On iOS these are applied as SwiftUI accessibility modifiers. On Android the label is applied as
the container's `contentDescription`.

### Layering with Graphics

`PlatformView` renders as a native view. Native views are always drawn in front of Fuse graphics,
so to layer graphics content over one, host it in a `NativeViewHost` (optionally with
`RenderToTexture`, at the documented performance/ interaction cost):

```xml
<NativeViewHost>
    <PlatformView ViewName="MyView" />
</NativeViewHost>
```

### JavaScript Integration

```javascript
function onNativeEvent(args) {
  console.log("Event:", args.eventName);
  console.log("Raw value:", args.eventValue);
  console.log("Structured value:", args.eventData);
}
```

`args.eventValue` is always the raw string sent from native code. `args.eventData` is
available when that string is valid JSON, so native views can send structured payloads:

```swift
// Send a structured event by passing JSON as the value
data.callback("selectionChanged", "{\"index\": 2, \"label\": \"Two\"}")
```

```kotlin
data.eventCallback("selectionChanged", """{"index": 2, "label": "Two"}""")
```

## Platform Implementation

### iOS (SwiftUI)

#### 1. Register Your SwiftUI View

Create a SwiftUI view that accepts a `PlatformViewData` environment object:

```swift
struct MyCustomView: View {
    @EnvironmentObject var data: PlatformViewData

    var body: some View {
        VStack {
            Text(data.getString)
            Button("Update") {
                data.getString = "Updated from SwiftUI"
            }
        }
    }
}

// Register the view (typically in App initialization)
PlatformViewRegistry.register("MyCustomView", MyCustomView())
```

To avoid depending on a specific app-init hook, export the setup symbol instead — the package
calls it on first use:

```swift
@_cdecl("FusePlatformViewSetup")
public func fusePlatformViewSetup() {
    PlatformViewRegistry.register("MyCustomView", MyCustomView())
}
```

#### 2. Access Data Properties

- `data.getString` - String data from Fuse
- `data.getInteger` - Integer data from Fuse
- `data.getBool` - Boolean data from Fuse
- `data.getFloat` - Float data from Fuse
- `data.getDouble` - Double data from Fuse
- `data.get` - Dictionary/Object data from Fuse
- `data.getArray` - Array data from Fuse

#### 3. Send Events to Fuse

```swift
data.callback("buttonPressed", "someValue")
```

### Android (Jetpack Compose)

#### 1. Register Your Compose View

Create a Composable function that accepts a `PlatformViewData` parameter:

```kotlin
@Composable
fun MyCustomView(data: PlatformViewData) {
    val stringValue by data.getString.observeAsState("")

    Column {
        Text(text = stringValue)
        Button(onClick = {
            data.updateString("Updated from Compose")
        }) {
            Text("Update")
        }
    }
}

// Register the view (typically in Application class)
PlatformViewRegistry.register("MyCustomView") { data -> MyCustomView(data) }
```

To avoid depending on a specific app-init hook, provide the setup object — the package looks it
up on first use:

```kotlin
package com.fuse.platformview

object PlatformViewSetup {
    @JvmStatic
    fun install() {
        PlatformViewRegistry.register("MyCustomView") { data -> MyCustomView(data) }
    }
}
```

#### 2. Observe Data Properties

- `data.getString.observeAsState()` - String data from Fuse
- `data.getInteger.observeAsState()` - Integer data from Fuse
- `data.getBool.observeAsState()` - Boolean data from Fuse
- `data.getFloat.observeAsState()` - Float data from Fuse
- `data.getDouble.observeAsState()` - Double data from Fuse
- `data.get.observeAsState()` - Map data from Fuse
- `data.getArray.observeAsState()` - List data from Fuse

#### 3. Send Events to Fuse

```kotlin
data.eventCallback("buttonPressed", "someValue")
```

## Data Binding Examples

### Passing Complex Objects

#### Fuse Side

```xml
<PlatformView ViewName="DataView" DataObject="{userProfile}" />
```

```javascript
var userProfile = {
  name: "John Doe",
  age: 30,
  preferences: {
    theme: "dark",
    notifications: true,
  },
};
```

#### iOS Side

```swift
struct DataView: View {
    @EnvironmentObject var data: PlatformViewData

    var body: some View {
        VStack {
            if let name = data.get["name"] as? String {
                Text("Name: \(name)")
            }
            if let age = data.get["age"] as? Int {
                Text("Age: \(age)")
            }
        }
    }
}
```

#### Android Side

```kotlin
@Composable
fun DataView(data: PlatformViewData) {
    val userData by data.get.observeAsState(emptyMap())

    Column {
        userData["name"]?.let { name ->
            Text("Name: $name")
        }
        userData["age"]?.let { age ->
            Text("Age: $age")
        }
    }
}
```

## File Structure

```
Fuse.PlatformView/
├── PlatformView.uno                 # Main PlatformViewBase class
├── PlatformView.ux                  # UX template with platform switching
├── Fuse.PlatformView.unoproj        # Project configuration
├── iOS/
│   ├── PlatformNativeView.uno       # iOS-specific native view
│   ├── SwiftUIViewFactory.swift     # SwiftUI view factory and data management
│   ├── SwiftUIHostingContainer.h    # Native container header
│   └── SwiftUIHostingContainer.m    # Native container implementation
└── Android/
    ├── PlatformNativeView.uno       # Android-specific native view
    ├── ComposeViewFactory.kt        # Compose view factory and data management
    └── Compose.uxl                  # Gradle dependencies for Compose
```

## Dependencies

### iOS

- SwiftUI (iOS 13+)
- Swift 5.0+

### Android

- Jetpack Compose (1.7.5+)
- AndroidX Lifecycle components
- Kotlin compiler extension (1.5.15+)

## Best Practices

### 1. View Registration

- Register views early in the application lifecycle
- Use `PlatformViewRegistry.register` instead of declaring a `viewRegistration` map yourself — the module now provides it
- Use consistent naming conventions across platforms
- Consider lazy loading for better performance

### 2. Data Management

- Keep data models simple and JSON-serializable
- Use appropriate data types for better performance
- Minimize data updates to avoid unnecessary re-renders

### 3. Event Handling

- Use descriptive event names
- Include relevant data in event payloads
- Handle events asynchronously when needed

### 4. Error Handling

- Implement fallback views for missing registrations
- Validate data types before processing
- Log errors appropriately for debugging

## Limitations

- Views must be registered before use
- Complex object serialization may impact performance
- Platform-specific features may not translate directly
- Lifecycle management requires careful consideration

## Performance Considerations

- JSON serialization overhead for complex objects
- Native view creation and destruction costs
- Memory management for long-lived views
- Consider view recycling for list scenarios

## Troubleshooting

### Common Issues

1. **View not found**: Ensure the view is properly registered
2. **Data not updating**: Check callback connections and data binding
3. **Layout issues**: Verify container configuration and constraints
4. **Memory leaks**: Properly dispose of views and clear callbacks

### Debugging Tips

- Use console logging in view factories
- Monitor data flow between platforms
- Test with simple views first
- Verify JSON serialization/deserialization
