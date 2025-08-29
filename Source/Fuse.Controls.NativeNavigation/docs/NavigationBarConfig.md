# NavigationBarConfig

A behavior class that enables customization of the navigation bar appearance when used within a `NativeNavigationView` template.

## Overview

`NavigationBarConfig` provides a declarative way to customize the native navigation bar appearance on iOS (and potentially other platforms in the future). It allows you to set properties like title, colors, translucency, and other navigation bar features directly from UX markup.

## Usage

Place the `NavigationBarConfig` as a child element within a template that is used with `NativeNavigationView`:

```xml
<NativeNavigationView ux:Name="nav" DefaultTemplate="Home">
    <Panel ux:Template="Home">
        <NavigationBarConfig
            Navigation="nav"
            Title="Home"
            BackgroundColor="0.13, 0.59, 0.95, 1"
            ForegroundColor="1, 1, 1, 1"
            LargeTitle="true"
        />
        
        <StackPanel Alignment="Center" ItemSpacing="20">
            <Text Value="Welcome to Home" FontSize="24" TextAlignment="Center" />
            <!-- Your content here -->
        </StackPanel>
    </Panel>
    
    <Panel ux:Template="Settings">
        <NavigationBarConfig
            Navigation="nav"
            Title="Settings"
            BackgroundColor="0.30, 0.69, 0.31, 1"
            ForegroundColor="1, 1, 1, 1"
            BackButtonTitle="Back"
        />
        
        <!-- Settings content -->
    </Panel>
</NativeNavigationView>
```

## Properties

### Navigation
- **Type**: `NativeNavigationView`
- **Description**: Reference to the NativeNavigationView that contains this template
- **Required**: Yes
- **Example**: `Navigation="nav"`
- **Note**: This is required because NavigationBarConfig is rendered in a separate context from the NativeNavigationView

### Title
- **Type**: `string`
- **Description**: The title to display in the navigation bar
- **Example**: `Title="Home"`

### BackgroundColor
- **Type**: `float4`
- **Description**: The background color of the navigation bar
- **Format**: RGBA values from 0.0 to 1.0
- **Example**: `BackgroundColor="0.13, 0.59, 0.95, 1"` (blue)

### ForegroundColor
- **Type**: `float4`
- **Description**: The foreground color (text and button color) of the navigation bar. This also sets the tint color for interactive elements like buttons and icons.
- **Format**: RGBA values from 0.0 to 1.0
- **Example**: `ForegroundColor="1, 1, 1, 1"` (white)
- **Note**: If TintColor is not explicitly set, the navigation bar's tint color will automatically match this value for consistent appearance

### TintColor
- **Type**: `float4`
- **Description**: The tint color for interactive elements (buttons, icons) in the navigation bar
- **Format**: RGBA values from 0.0 to 1.0
- **Example**: `TintColor="0.2, 0.8, 0.3, 1"` (green buttons)
- **Default**: Falls back to ForegroundColor if not set
- **Note**: This allows you to have different colors for text and interactive elements

### LargeTitle
- **Type**: `bool`
- **Description**: Whether to display the title in large format (iOS 11+ feature)
- **Default**: `false`
- **Note**: On older iOS versions or other platforms, this may be ignored
- **Example**: `LargeTitle="true"`

### Translucent
- **Type**: `bool`
- **Description**: Whether the navigation bar should be translucent
- **Default**: `false`
- **Note**: When false, content will not appear behind the navigation bar
- **Example**: `Translucent="true"`

### Hidden
- **Type**: `bool`
- **Description**: Whether to hide the navigation bar for this view
- **Default**: `false`
- **Example**: `Hidden="true"`

### BackButtonTitle
- **Type**: `string`
- **Description**: Custom title for the back button. If not set, uses default behavior
- **Example**: `BackButtonTitle="Cancel"`

## Platform Support

### iOS
Full support with all properties implemented using native UINavigationController APIs:
- Title customization
- Background and foreground color customization
- Customizable tint color for interactive elements (buttons, icons) with automatic fallback to foreground color
- Large title support (iOS 11+)
- Translucency control
- Navigation bar hiding
- Custom back button titles

### Other Platforms
On platforms other than iOS, the behavior acts as a stub and properties are ignored gracefully without causing errors.

## Implementation Details

The `NavigationBarConfig` works by:

1. **Discovery**: When rooted, it searches up the parent hierarchy to find the containing `NativeNavigationView`
2. **Template Association**: It determines which template it belongs to based on the parent visual's name
3. **Configuration**: It creates a `NavigationBarConfig` object with the current property values
4. **Communication**: It passes this configuration to the native implementation via the `INativeNavigationView.ConfigureNavigationBar()` method
5. **Application**: The native implementation applies these settings to the platform-specific navigation bar

## Color Format

Colors are specified as `float4` values with RGBA components ranging from 0.0 to 1.0:
- Red: 0.0 to 1.0
- Green: 0.0 to 1.0
- Blue: 0.0 to 1.0
- Alpha: 0.0 to 1.0

### Common Colors
```xml
<!-- Red -->
BackgroundColor="1, 0, 0, 1"

<!-- Green -->
BackgroundColor="0, 1, 0, 1"

<!-- Blue -->
BackgroundColor="0, 0, 1, 1"

<!-- White -->
BackgroundColor="1, 1, 1, 1"

<!-- Black -->
BackgroundColor="0, 0, 0, 1"

<!-- Transparent -->
BackgroundColor="0, 0, 0, 0"
```

## Best Practices

1. **Consistent Styling**: Use consistent colors across related views for better user experience
2. **Accessibility**: Ensure sufficient contrast between background and foreground colors
3. **Platform Consistency**: Consider platform conventions when choosing colors and styles
4. **Performance**: The behavior automatically handles configuration updates, so changing properties at runtime is supported

## Troubleshooting

### NavigationBarConfig not found
If you get an error that `NavigationBarConfig` is not found, make sure:
- The `Fuse.Controls.NativeNavigation` package is properly referenced
- You're using the correct namespace (it's in `Fuse.Controls`)

### Properties not applying
If navigation bar customization isn't working:
- Ensure the NavigationBarConfig is placed inside a template that's used with `NativeNavigationView`
- Check that the template name is properly set
- Verify you're running on a supported platform (iOS)

### Colors not displaying correctly
- Ensure color values are in the range 0.0 to 1.0
- Check that alpha values are set appropriately (1.0 for opaque)
- Consider the translucency setting which may affect color appearance

## Examples

### Basic Usage
```xml
<NavigationBarConfig
    Navigation="nav"
    Title="My Page"
    BackgroundColor="0.2, 0.4, 0.8, 1"
    ForegroundColor="1, 1, 1, 1"
/>
```

### Custom Tint Color
```xml
<NavigationBarConfig
    Navigation="nav"
    Title="Photo Editor"
    BackgroundColor="0, 0, 0, 1"
    ForegroundColor="1, 1, 1, 1"
    TintColor="0.2, 0.8, 0.3, 1"
/>
```
This creates a black navigation bar with white text but green buttons and icons.

### Large Title with Custom Back Button
```xml
<NavigationBarConfig
    Navigation="nav"
    Title="Settings"
    LargeTitle="true"
    BackButtonTitle="Done"
    BackgroundColor="0.95, 0.95, 0.95, 1"
    ForegroundColor="0, 0, 0, 1"
/>
```

### Hidden Navigation Bar
```xml
<NavigationBarConfig
    Navigation="nav"
    Hidden="true"
/>
```

### Translucent Navigation Bar
```xml
<NavigationBarConfig
    Navigation="nav"
    Title="Photo Viewer"
    Translucent="true"
    BackgroundColor="0, 0, 0, 0.5"
    ForegroundColor="1, 1, 1, 1"
/>
```
