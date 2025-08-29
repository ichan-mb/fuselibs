# NavigationBarConfig Usage Guide

This guide shows how to use the `NavigationBarConfig` to customize navigation bar appearance in your NativeNavigationView.

## Quick Start

The `NavigationBarConfig` allows you to customize the native navigation bar appearance by placing it inside your navigation templates:

```xml
<App>
    <NativeNavigationView ux:Name="nav" DefaultTemplate="Home">
        <Panel ux:Template="Home">
            <NavigationBarConfig
                Navigation="nav"
                Title="Home"
                BackgroundColor="0.13, 0.59, 0.95, 1"
                ForegroundColor="1, 1, 1, 1"
                LargeTitle="true"
            />
            
            <!-- Your page content here -->
            <StackPanel Alignment="Center">
                <Text Value="Welcome!" FontSize="24" />
                <Button Text="Go to Settings">
                    <Clicked>
                        <PushView To="Settings" Navigation="nav" />
                    </Clicked>
                </Button>
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
</App>
```

## Key Properties

### Navigation
Reference to the containing NativeNavigationView:
```xml
<NavigationBarConfig Navigation="nav" Title="My Page" />
```
**Note**: This property is required because NavigationBarConfig is rendered in a separate context from the NativeNavigationView.

### Title
Set the navigation bar title:
```xml
<NavigationBarConfig Navigation="nav" Title="My Page" />
```

### Colors
Colors use RGBA format with values from 0.0 to 1.0:
```xml
<!-- Blue background, white text -->
<NavigationBarConfig
    Navigation="nav"
    BackgroundColor="0.13, 0.59, 0.95, 1"
    ForegroundColor="1, 1, 1, 1"
/>

<!-- Black background, white text -->
<NavigationBarConfig
    Navigation="nav"
    BackgroundColor="0, 0, 0, 1"
    ForegroundColor="1, 1, 1, 1"
/>

<!-- Black background, white text, green buttons -->
<NavigationBarConfig
    Navigation="nav"
    BackgroundColor="0, 0, 0, 1"
    ForegroundColor="1, 1, 1, 1"
    TintColor="0.2, 0.8, 0.3, 1"
/>
```

### TintColor
Customize the color of interactive elements (buttons, icons):
```xml
<NavigationBarConfig
    Navigation="nav"
    Title="My Page"
    BackgroundColor="0, 0, 0, 1"
    ForegroundColor="1, 1, 1, 1"
    TintColor="0.2, 0.8, 0.3, 1"
/>
```
**Note**: If not set, TintColor automatically uses the ForegroundColor value for consistent appearance.

### Large Title (iOS 11+)
Enable large title display:
```xml
<NavigationBarConfig
    Navigation="nav"
    Title="Home"
    LargeTitle="true"
/>
```

### Custom Back Button
Customize the back button text:
```xml
<NavigationBarConfig
    Navigation="nav"
    Title="Edit Profile"
    BackButtonTitle="Cancel"
/>
```

### Translucent Navigation Bar
Make the navigation bar translucent:
```xml
<NavigationBarConfig
    Navigation="nav"
    Title="Photo Viewer"
    Translucent="true"
    BackgroundColor="0, 0, 0, 0.5"
/>
```

### Hidden Navigation Bar
Hide the navigation bar completely:
```xml
<NavigationBarConfig Navigation="nav" Hidden="true" />
```

## Common Use Cases

### Dark Theme
```xml
<NavigationBarConfig
    Navigation="nav"
    Title="Dark Mode"
    BackgroundColor="0.1, 0.1, 0.1, 1"
    ForegroundColor="1, 1, 1, 1"
/>
```

### Light Theme
```xml
<NavigationBarConfig
    Navigation="nav"
    Title="Light Mode"
    BackgroundColor="0.95, 0.95, 0.95, 1"
    ForegroundColor="0, 0, 0, 1"
/>
```

### Photo/Media Viewer
```xml
<NavigationBarConfig
    Navigation="nav"
    Title="Photos"
    BackgroundColor="0, 0, 0, 0.8"
    ForegroundColor="1, 1, 1, 1"
    Translucent="true"
/>
```

### Form/Edit Screen
```xml
<NavigationBarConfig
    Navigation="nav"
    Title="Edit Contact"
    BackgroundColor="0.2, 0.6, 1, 1"
    ForegroundColor="1, 1, 1, 1"
    BackButtonTitle="Cancel"
/>
```

### Creative App with Accent Color
```xml
<NavigationBarConfig
    Navigation="nav"
    Title="Photo Editor"
    BackgroundColor="0.1, 0.1, 0.1, 1"
    ForegroundColor="1, 1, 1, 1"
    TintColor="1, 0.3, 0.6, 1"
/>
```

## Color Reference

Common colors in RGBA format:

| Color | RGBA Values |
|-------|-------------|
| Red | `1, 0, 0, 1` |
| Green | `0, 1, 0, 1` |
| Blue | `0, 0, 1, 1` |
| White | `1, 1, 1, 1` |
| Black | `0, 0, 0, 1` |
| Gray | `0.5, 0.5, 0.5, 1` |
| Light Gray | `0.8, 0.8, 0.8, 1` |
| Dark Gray | `0.2, 0.2, 0.2, 1` |
| Orange | `1, 0.6, 0, 1` |
| Pink | `1, 0.3, 0.6, 1` |
| Purple | `0.6, 0.3, 1, 1` |
| Transparent | `0, 0, 0, 0` |
| Semi-transparent Black | `0, 0, 0, 0.5` |

## Platform Support

- **iOS**: Full support with native UINavigationController
- **Android**: Planned for future implementation
- **Other platforms**: Graceful fallback (properties ignored)

## Best Practices

1. **Consistency**: Use consistent colors across related screens
2. **Contrast**: Ensure good contrast between background and foreground colors
3. **Accessibility**: Consider accessibility guidelines for color choices
4. **Platform conventions**: Follow platform-specific design guidelines
5. **Interactive Elements**: Use TintColor to make buttons and icons stand out when needed
6. **Brand Colors**: Use custom TintColor to incorporate your brand colors into the navigation

## Troubleshooting

**Problem**: NavigationBarConfig not found
**Solution**: Make sure you're using the latest version and that the behavior is in the `Fuse.Controls` namespace.

**Problem**: Colors not applying
**Solution**: Check that color values are between 0.0 and 1.0, and ensure you're testing on iOS.

**Problem**: Large titles not working
**Solution**: LargeTitle requires iOS 11+. On older versions, it will be ignored.

## Complete Example

See `Examples/NavigationBarConfigExample.ux` for a comprehensive demonstration showing all features.

## Migration from Basic NavigationBar

If you were using the basic NavigationBar control, you can enhance it with NavigationBarConfig:

**Before:**
```xml
<Panel ux:Template="MyPage">
    <!-- Basic navigation bar (limited customization) -->
    <Text Value="My Page" />
</Panel>
```

**After:**
```xml
<Panel ux:Template="MyPage">
    <NavigationBarConfig
        Navigation="nav"
        Title="My Page"
        BackgroundColor="0.2, 0.4, 0.8, 1"
        ForegroundColor="1, 1, 1, 1"
    />
    <!-- Your content -->
</Panel>
```

The NavigationBarConfig provides much more control over the native navigation bar appearance while maintaining the same ease of use.