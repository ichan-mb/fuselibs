# Fuse.Controls.NativeNavigation

A Fuse library that provides native navigation controls for iOS and Android, wrapping platform-specific navigation components to provide a native look and feel.

## Overview

`Fuse.Controls.NativeNavigation` allows you to use native navigation patterns in your Fuse applications:
- **iOS**: Wraps `UINavigationController` for native iOS navigation with back buttons, navigation bars, and transitions
- **Android**: Will wrap Android Fragment navigation (to be implemented)

Unlike Fuse's built-in navigation system which uses a single view with modified content, this library uses true native navigation stacks provided by the platform.

## Features

- **iOS native navigation** using UINavigationController 
- **Template-based navigation** with automatic view management
- Native navigation transitions and animations
- Platform-specific navigation bars and back buttons
- **Navigation bar customization** with NavigationBarConfig
- **Toolbar items** - JavaScript event handlers for navigation bar buttons
- **Proper navigation bar restoration** on PopView operations
- **Native back button synchronization** - internal navigation stack stays in sync with iOS navigation stack
- Template-based page definition
- Programmatic navigation through trigger actions
- **FuseJS Pages support** - Manage navigation with JavaScript observable arrays like Navigator
- Integration with Fuse's UX markup system

## Basic Usage

### Template-based Navigation (Traditional)

```xml
<NativeNavigationView ux:Name="nav" DefaultTemplate="Home">
    <Panel ux:Template="Home">
        <NavigationBarConfig
            Navigation="nav"
            Title="Home"
            BackgroundColor="0.13, 0.59, 0.95, 1"
            ForegroundColor="1, 1, 1, 1"
        >
            <ToolbarItem Title="New" Clicked="{newClicked}" />
            <ToolbarItem Title="Edit" Clicked="{editClicked}" />
        </NavigationBarConfig>
        <Text>Home Page</Text>
        <Button Text="Go to Details">
            <Clicked>
                <PushView To="Details" Navigation="nav" />
            </Clicked>
        </Button>
    </Panel>
    <Panel ux:Template="Details">
        <NavigationBarConfig
            Navigation="nav"
            Title="Details"
            BackgroundColor="0.30, 0.69, 0.31, 1"
            ForegroundColor="1, 1, 1, 1"
            BackButtonTitle="Back"
        />
        <Text>Details Page</Text>
        <Button Text="Back">
            <Clicked>
                <PopView Navigation="nav" />
            </Clicked>
        </Button>
    </Panel>
</NativeNavigationView>
```

### FuseJS Pages Navigation (Recommended)

Manage navigation entirely from JavaScript using observable arrays, similar to Navigator:

```javascript
// PageModel.js
var Observable = require("FuseJS/Observable");

export default class PageModel {
    constructor() {
        this.pages = Observable({
            $path: "Home",
            title: "Welcome Home"
        });
    }

    navigateToDetails(item) {
        this.pages.add({
            $path: "Details",
            item: item,
            title: item.name
        });
    }

    goBack() {
        if (this.pages.length > 1) {
            this.pages.removeAt(this.pages.length - 1);
        }
    }
}
```

```xml
<App Model="PageModel">
    <NativeNavigationView Pages="{pages}">
        <Page ux:Template="Home">
            <StackPanel>
                <Text Value="{title}" FontSize="24" />
                <Button Text="Go to Details" Clicked="{navigateToDetails}" />
            </StackPanel>
        </Page>
        <Page ux:Template="Details">
            <StackPanel>
                <Text Value="{title}" FontSize="24" />
                <Text Value="{item.description}" />
                <Button Text="Back" Clicked="{goBack}" />
            </StackPanel>
        </Page>
    </NativeNavigationView>
</App>
```

For detailed documentation on FuseJS Pages support, see [FUSEJS_PAGES.md](docs/FUSEJS_PAGES.md).

## Components

### NativeNavigationView

The main container that manages native navigation. All templates should be defined as direct children.

**Properties:**

### NavigationBarConfig

A behavior class that allows customization of the navigation bar appearance when used within templates.

**Properties:**
- `Navigation` (NativeNavigationView): Reference to the containing NativeNavigationView (required)
- `Title` (string): The title to display in the navigation bar
- `BackgroundColor` (float4): The background color of the navigation bar (RGBA values 0.0-1.0)
- `ForegroundColor` (float4): The foreground color for text and buttons (RGBA values 0.0-1.0). Used as fallback for TintColor if not set.
- `TintColor` (float4): The tint color for interactive elements like buttons and icons (RGBA values 0.0-1.0). Falls back to ForegroundColor if not set.
- `LargeTitle` (bool): Whether to display the title in large format (iOS 11+)
- `Translucent` (bool): Whether the navigation bar should be translucent
- `Hidden` (bool): Whether to hide the navigation bar
- `BackButtonTitle` (string): Custom title for the back button

**Usage:**
```xml
<Panel ux:Template="MyPage">
    <NavigationBarConfig
        Navigation="nav"
        Title="My Page"
        BackgroundColor="0.2, 0.4, 0.8, 1"
        ForegroundColor="1, 1, 1, 1"
        LargeTitle="true"
    />
    <!-- Your content -->
</Panel>
```

**With Custom Tint Color:**
```xml
<Panel ux:Template="MyPage">
    <NavigationBarConfig
        Navigation="nav"
        Title="My Page"
        BackgroundColor="0.2, 0.4, 0.8, 1"
        ForegroundColor="1, 1, 1, 1"
        TintColor="0.2, 0.8, 0.3, 1"
        LargeTitle="true"
    >
        <ToolbarItem Title="Save" Position="Right" Clicked="{saveClicked}" />
        <ToolbarItem Title="Cancel" Position="Left" Clicked="{cancelClicked}" />
    </NavigationBarConfig>
    <!-- Your content -->
</Panel>
```

### ToolbarItem

ToolbarItem allows you to add clickable buttons to the navigation bar using JavaScript event handlers. ToolbarItems are defined as child elements within NavigationBarConfig and support left/right positioning with native iOS UIBarButtonItem integration.

**Properties:**
- `Title` (string): The text displayed on the button
- `Position` (ToolbarItemPosition): Either `Left` or `Right` (default: `Right`)
- `Enabled` (bool): Whether the button is enabled and clickable (default: `true`)
- `Clicked` (event VisualEventHandler): JavaScript function to call when the button is clicked

**Usage:**
```xml
<NavigationBarConfig Navigation="nav" Title="My Page">
    <ToolbarItem Title="Add" Position="Right" Clicked="{addItem}" />
    <ToolbarItem Title="Menu" Position="Left" Clicked="{showMenu}" />
</NavigationBarConfig>
```

**JavaScript Event Handler:**
```javascript
function addItem() {
    console.log("Add button was clicked!");
    // Your logic here
}

function showMenu() {
    console.log("Menu button was clicked!");
    // Your logic here
}

module.exports = {
    addItem: addItem,
    showMenu: showMenu
};
```

## Available Properties
**Navigation Actions**
- Automatically collects child templates and manages navigation stack

### Templates

Use `ux:Template` to define different pages/screens:

```xml
<Panel ux:Template="PageName">
    <!-- Your page content -->
</Panel>
```

### Navigation Actions

### NativeNavigationView Properties
- Inherits from `Panel`
- `DefaultTemplate` - Specifies which template to use as the initial root view (optional)
- `VisualContext` - Always returns `Native` to ensure proper native rendering

### PushView
Navigate to a new page by pushing it onto the navigation stack.

```xml
<PushView To="TemplateName" Navigation="nav" />
```

**Properties:**
- `To`: The name of the template to navigate to (required)
- `Navigation`: Reference to the NativeNavigationView (optional if used within the navigation hierarchy)

#### PopView
Go back to the previous page by popping the current page from the stack.

```xml
<PopView Navigation="nav" />
```

**Properties:**
- `Navigation`: Reference to the NativeNavigationView (optional if used within the navigation hierarchy)

## Platform Implementation Status

### iOS ✅ (Implemented)
- Wraps `UINavigationController`
- Native navigation bar with back buttons
- Native transitions and animations
- Proper view controller lifecycle management

### Android ⏳ (Planned)
- Will wrap Android Fragment navigation
- Native ActionBar/Toolbar integration
- Material Design transitions

## Technical Details

### iOS Implementation
- Uses `UINavigationController` as the underlying navigation system
- Each Fuse template is wrapped in a `UIViewController`
- Fuse views are rendered into native `UIView` containers
- Navigation delegate handles lifecycle events

### Architecture
- `NativeNavigationView`: Base cross-platform class
- Platform-specific implementations in `iOS/` and `Android/` directories
- Template system for defining page content
- Action-based navigation triggers

## Limitations

### Current Version
1. **iOS Only**: Android implementation is not yet available
2. **Basic Rendering**: Complex Fuse visual trees may not render perfectly in native containers
3. **No Navigation Bar Customization**: Navigation bar styling is limited to platform defaults
4. **Limited Navigation Options**: No support for modal presentation or custom transitions yet

### Future Enhancements
- Android Fragment navigation support
- Navigation bar customization
- Modal presentation modes
- Custom transition animations
- Deep linking support
- Navigation state persistence

## Development Status

This is an initial implementation focused on iOS. The core architecture is designed to support Android, but the Android implementation is pending.

### Building
1. Include `Fuse.Controls.NativeNavigation.unoproj` in your project references
2. Use iOS build targets for testing
3. Android builds will use stub implementations (no-op)

### Testing
See `Example.ux` for a complete usage example demonstrating:
- Multiple templates
- Push/pop navigation
- Navigation stack management
- Mixed content types

## Contributing

## Installation

1. **Add to your project**: Include the `Fuse.Controls.NativeNavigation.unoproj` in your app's project references:

```json
{
  "projects": [
    "path/to/fuselibs/Source/Fuse.Controls.NativeNavigation/Fuse.Controls.NativeNavigation.unoproj"
  ]
}
```

2. **Import in UX**: Add the namespace to your UX files:

```xml
<App xmlns:nav="Fuse.Controls.NativeNavigation">
    <nav:NativeNavigationView ux:Name="navigation">
        <!-- Your templates here -->
    </nav:NativeNavigationView>
</App>
```

Or use without namespace prefix by using the default namespace:

```xml
<App>
    <NativeNavigationView ux:Name="navigation" DefaultTemplate="Home">
        <!-- Your templates here -->
    </NativeNavigationView>
</App>
```

## Quick Start

Here's a minimal working example:

```xml
<App>
    <NativeNavigationView ux:Name="nav" DefaultTemplate="Home">
        <StackPanel ux:Template="Home" Padding="20">
            <Text>Welcome Home!</Text>
            <Button Text="Go to Details">
                <Clicked>
                    <PushView To="Details" Navigation="nav" />
                </Clicked>
            </Button>
        </StackPanel>

        <StackPanel ux:Template="Details" Padding="20">
            <Text>Details Page</Text>
            <Button Text="Go Back">
                <Clicked>
                    <PopView Navigation="nav" />
                </Clicked>
            </Button>
        </StackPanel>
    </NativeNavigationView>
</App>
```

## Final API Example

Here's a complete example showing the NavigationBarConfig in action:

```xml
<App>
    <NativeNavigationView ux:Name="nav" DefaultTemplate="Home">
        <!-- Home screen with large blue title -->
        <Panel ux:Template="Home">
            <NavigationBarConfig
                Navigation="nav"
                Title="Home"
                BackgroundColor="0.13, 0.59, 0.95, 1"
                ForegroundColor="1, 1, 1, 1"
                LargeTitle="true"
            />
            
            <StackPanel Alignment="Center" ItemSpacing="20">
                <Text Value="Welcome!" FontSize="24" />
                <Button Text="Settings">
                    <Clicked>
                        <PushView To="Settings" Navigation="nav" />
                    </Clicked>
                </Button>
                <Button Text="Profile">
                    <Clicked>
                        <PushView To="Profile" Navigation="nav" />
                    </Clicked>
                </Button>
            </StackPanel>
        </Panel>

        <!-- Settings screen with green navigation bar -->
        <Panel ux:Template="Settings">
            <NavigationBarConfig
                Navigation="nav"
                Title="Settings"
                BackgroundColor="0.30, 0.69, 0.31, 1"
                ForegroundColor="1, 1, 1, 1"
                BackButtonTitle="Done"
            />
            
            <StackPanel Alignment="Center">
                <Text Value="App Settings" FontSize="20" />
                <Button Text="Back">
                    <Clicked>
                        <PopView Navigation="nav" />
                    </Clicked>
                </Button>
            </StackPanel>
        </Panel>

        <!-- Profile with translucent dark navigation -->
        <Panel ux:Template="Profile">
            <NavigationBarConfig
                Navigation="nav"
                Title="Profile"
                BackgroundColor="0, 0, 0, 0.8"
                ForegroundColor="1, 1, 1, 1"
                Translucent="true"
            />
            
            <Panel Color="#222">
                <StackPanel Alignment="Center">
                    <Text Value="User Profile" FontSize="20" Color="#fff" />
                    <Button Text="Back">
                        <Clicked>
                            <PopView Navigation="nav" />
                        </Clicked>
                    </Button>
                </StackPanel>
            </Panel>
        </Panel>
    </NativeNavigationView>
</App>
```

## JavaScript Event Handling

ToolbarItem uses the VisualEventHandler pattern for handling click events:

```xml
<NavigationBarConfig Navigation="nav" Title="Document Editor">
    <ToolbarItem Title="Save" Position="Right" Clicked="{saveDocument}" />
    <ToolbarItem Title="Undo" Position="Left" Clicked="{undoAction}" />
</NavigationBarConfig>
```

```javascript
function saveDocument() {
    console.log("Save button clicked!");
    // Your save logic here
}

function undoAction() {
    console.log("Undo button clicked!");
    // Your undo logic here
}

module.exports = {
    saveDocument: saveDocument,
    undoAction: undoAction
};
```

### Implementation Benefits

The ToolbarItem implementation provides several key advantages:

- **Native integration**: Uses UIBarButtonItem for optimal iOS performance
- **Clean syntax**: Simple JavaScript event handler pattern
- **Type safety**: Full IntelliSense support in UX markup
- **Natural markup**: ToolbarItems are defined as child elements
- **Automatic management**: Framework handles the relationship between toolbar items and navigation bars
- **Memory efficient**: Proper cleanup and lifecycle management

## Platform Support

| Platform | Status | Implementation |
|----------|--------|----------------|
| iOS | ✅ Implemented | UINavigationController |
| Android | ⏳ Planned | Fragment Navigation |
| Desktop | ❌ Not Supported | N/A |

## JavaScript Navigation Properties

When using FuseJS Pages, you can access read-only navigation information from JavaScript:

```javascript
// Get reference to navigation view
var nav = this.Parameter.navigation;

// Get navigation state (read-only)
var pageCount = nav.getPageCount();
var canGoBack = nav.getCanGoBack();

// For navigation operations, manipulate the Pages observable array directly:
// Push a new page
this.pages.add({
    $path: "NewPage",
    data: someData
});

// Pop current page
if (this.pages.length > 1) {
    this.pages.removeAt(this.pages.length - 1);
}

// Replace current page
this.pages.replaceAt(this.pages.length - 1, {
    $path: "ReplacementPage", 
    data: newData
});

// Go to root page
var rootPage = this.pages.getAt(0);
this.pages.clear();
this.pages.add(rootPage);
```

## Comparison with Fuse.Controls.Navigation

| Feature | Fuse.Controls.Navigation | Fuse.Controls.NativeNavigation |
|---------|--------------------------|------------------------|
| Navigation Style | Custom Fuse Implementation | Platform Native |
| Performance | Good | Excellent (Native) |
| Memory Usage | Higher | Lower (Native Management) |
| Customization | High | Limited to Platform Capabilities |
| Back Gestures | Custom Implementation | Native Platform Gestures |
| Navigation Bar | Custom | Native Platform Bar |
| Transitions | Custom Animations | Native Platform Animations |

## Native Rendering Context

`NativeNavigationView` integrates with Fuse's native view system through the `CreateNativeView()` method, similar to how `MapView` and other native controls work. This provides seamless integration with the platform's native rendering pipeline.

### Automatic Native Integration

The control automatically creates platform-specific native implementations:

- **iOS**: Creates `NativeNavigationViewImpl` that wraps `UINavigationController`
- **Android**: Will create Android-specific implementation (planned)

### Recommended Usage with NativeViewHost

For optimal performance and proper native integration, use `NativeNavigationView` within a `NativeViewHost`:

```xml
<App>
    <NativeViewHost>
        <NativeNavigationView ux:Name="nav" DefaultTemplate="Home">
            <Panel ux:Template="Home">
                <!-- Your content will be rendered natively -->
            </Panel>
        </NativeNavigationView>
    </NativeViewHost>
</App>
```

This ensures that:
- Templates are rendered using native views (UIView on iOS)
- Native navigation controller receives actual native views via isolated rendering contexts
- The navigation controller's view is embedded in Fuse's visual tree
- Performance is optimized for the platform
- System integration is maximized

### How It Works (Separate TreeRenderer Context Architecture)

1. **Interface Definition**: `INativeNavigationView` provides clean abstraction for platform implementations
2. **Native View Creation**: `CreateNativeView()` returns platform-specific implementation via factory
3. **Interface Communication**: Cross-platform code communicates through interface methods
4. **Container Setup**: iOS implementation creates UINavigationController and embeds its view
5. **Isolated Rendering Contexts**: Each template gets its own `ViewControllerRoot` with separate `TreeRendererPanel`
6. **Template Isolation**: Templates render in isolated contexts (not added to NativeNavigationView.Children)
7. **Native Handle Extraction**: Native view handles are extracted from isolated rendering contexts
8. **View Controller Creation**: Native handles are wrapped in UIViewController instances with proper layout constraints
9. **Navigation Bar Layout**: Content is positioned below navigation bar using safe area guides (iOS 11+) or layout guides (iOS 10-)
10. **Navigation Management**: UINavigationController manages the view controller stack
11. **Resource Cleanup**: Each context is properly disposed when navigation occurs

### Architecture Benefits

- **✅ No Double-Parent Issues**: Templates don't conflict between Fuse hierarchy and UIViewController
- **🔧 Clean Isolation**: Each view controller has its own native rendering context
- **📱 Navigation Bar Respect**: Content properly positioned to avoid navigation bar overlap
- **📐 Safe Area Integration**: Automatic handling of iOS safe areas and layout guides
- **💾 Proper Memory Management**: ViewControllerRoot handles cleanup automatically
- **🚀 Better Performance**: Isolated contexts reduce rendering conflicts
- **🏗️ Scalable Design**: Easy to extend for complex navigation scenarios

## Building and Testing

### iOS
```bash
# Build for iOS
uno build iOS

# Test in iOS Simulator
uno build iOS --run
```

### Testing Examples
The library includes several example files:
- `MinimalExample.ux` - Simple 3-page navigation demo
- `NativeContextExample.ux` - Example using NativeViewHost for proper native rendering
- `IntegrationTest.ux` - Test for interface-based native view system integration
- `SeparateContextTest.ux` - Test for separate TreeRenderer context architecture
- `NavigationBarTest.ux` - Test for navigation bar height accommodation and layout
- `TestApp.ux` - Comprehensive feature demonstration
- `Example.ux` - Original example from documentation

## Troubleshooting

### Common Issues

1. **Templates not found**: Ensure your templates have unique `ux:Template` names
2. **Navigation not working**: Verify the `Navigation` property points to the correct `NativeNavigationView`
3. **DefaultTemplate not found**: Check that the template name specified in `DefaultTemplate` exists
4. **Native views not rendering**: Use `NativeViewHost` to ensure proper native rendering context
5. **Double-parent issues**: Should be resolved with separate TreeRenderer context architecture
6. **Content hidden by navigation bar**: Should be resolved with safe area layout constraints
7. **iOS build errors**: Make sure you're building for iOS platform when testing

### Debug Tips

1. Use the iOS Simulator's debug menu to inspect the native navigation stack
2. Check the Uno build output for any missing dependencies
3. Verify that your UX templates are properly structured as Visual elements
4. Test both with and without `NativeViewHost` to compare rendering behavior
5. Use placeholder view controllers will show diagnostic information when native rendering fails
6. Check that interface methods are being called correctly through the abstraction layer
7. Verify that ViewControllerRoot contexts are being created and disposed properly
8. Test navigation depth to ensure isolated contexts work at multiple levels
9. Use NavigationBarTest.ux to verify content is properly positioned below navigation bar
10. Test on different iOS versions to ensure safe area/layout guide compatibility

This library is part of the FuseOpen project. Contributions welcome for:
- Android implementation
- Enhanced iOS features
- Bug fixes and improvements
- Documentation updates

## License

Copyright (c) Fuse Open
Licensed under the same terms as FuseOpen/fuselibs.
