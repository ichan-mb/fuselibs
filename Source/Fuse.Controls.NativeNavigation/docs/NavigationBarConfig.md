# NavigationBarConfig

`NavigationBarConfig` customizes a template's native navigation bar and adds toolbar items and
pull-down menus. Place it inside the template it applies to.

Bars are not inherited: a template (page or modal) that declares no `NavigationBarConfig` has no
bar at all. See [the README](../README.md) for navigation and modal usage, or
[USAGE.md](USAGE.md) for the actions and JavaScript reference.

## Properties

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `Navigation` | `NativeNavigationView` | containing view | The navigation view this config belongs to. Set it explicitly when the config is not inside that view's hierarchy. |
| `Title` | `string` | empty | Title shown in the bar. |
| `BackgroundColor` | `float4` | white | Bar background as RGBA, each component in the range 0-1. |
| `ForegroundColor` | `float4` | black | Text and button color. |
| `TintColor` | `float4` | `ForegroundColor` | Color of interactive elements such as buttons and icons. |
| `LargeTitle` | `bool` | `false` | Displays the title in large format. iOS 11+; ignored on Android. |
| `Translucent` | `bool` | `false` | Makes the bar translucent. When false, content does not appear behind the bar. |
| `Hidden` | `bool` | `false` | Hides the bar for this template. |
| `BackButtonTitle` | `string` | platform default | Custom title for the back button shown on this page. |
| `ApplyInsets` | `bool` | `false` | Insets page content to keep it clear of the bar and system bars. Off by default (edge to edge); set `true` to inset it. |

`TintColor` is optional; when it is not set, it returns (and applies) `ForegroundColor`. The
read-only `HasTintColor` property reports whether `TintColor` was explicitly set.

## Usage

```xml
<NativeNavigationView ux:Name="nav" DefaultTemplate="Home">
    <Page ux:Template="Home">
        <NavigationBarConfig
            Navigation="nav"
            Title="Home"
            BackgroundColor="#1565C0"
            ForegroundColor="#ffffff"
            LargeTitle="true"
            ApplyInsets="true"
        />

        <StackPanel>
            <Text Value="Home" />
            <Button Text="Open settings">
                <Clicked>
                    <PushView To="Settings" Navigation="nav" />
                </Clicked>
            </Button>
        </StackPanel>
    </Page>

    <Page ux:Template="Settings">
        <NavigationBarConfig
            Navigation="nav"
            Title="Settings"
            BackgroundColor="#2e7d32"
            ForegroundColor="#ffffff"
            BackButtonTitle="Home"
        />

        <!-- Settings content -->
    </Page>
</NativeNavigationView>
```

For content that should draw under a translucent bar, turn the automatic inset off and add your
own spacing:

```xml
<NavigationBarConfig
    Navigation="nav"
    Title="Photo"
    Translucent="true"
    ApplyInsets="false"
    BackgroundColor="#00000080"
    ForegroundColor="#ffffff"
/>
```

## Toolbar items

A `ToolbarItem` adds a button to the bar. A `ToolbarMenuItem` adds an entry to the pull-down menu
of its parent `ToolbarItem` (a `UIMenu` on iOS 14+, a `SubMenu` on Android).

| Property | Type | Default | Applies to | Description |
| --- | --- | --- | --- | --- |
| `Title` | `string` | empty | both | Text for the button or menu entry. |
| `AccessibilityLabel` | `string` | `Title` | both | Screen-reader name; needed for an icon-only entry. |
| `Position` | `ToolbarItemPosition` | `Right` | `ToolbarItem` | `Leading`/`Trailing` (or the older `Left`/`Right`) side of the bar; logical, so it mirrors in RTL. |
| `Enabled` | `bool` | `true` | both | Whether the entry can be clicked. |
| `Visible` | `bool` | `true` | both | Whether the entry is shown. A hidden item takes no room, and menu entries close up. |
| `Symbols` | `string` | none | both | Symbol name: SF Symbols on iOS, Material Symbols on Android. |
| `IsFilled` | `bool` | `false` | both | Uses the filled variant of `Symbols` when available. |
| `File` | `FileSource` | none | both | Icon loaded from a file. |
| `Url` | `string` | none | both | Icon loaded from a URL. |
| `Source` | `ImageSource` | none | both | Icon supplied as an image source. |
| `Color` | `float4` | bar tint | `ToolbarItem` | Tints this item's icon and title. |
| `Clicked` | event | none | both | JavaScript handler, bound as `Clicked="{handler}"`. |

Specify only one of `Symbols`, `File`, `Url` or `Source`. If no icon is set, the entry shows its
`Title`. Icon images are drawn as template images, so they use the bar's tint unless `Color` is
set on the item. An icon-only entry has no text, so set `AccessibilityLabel` to name it for
screen readers (it falls back to `Title` when unset).

`Clicked` is a `VisualEventHandler` binding. A `<Clicked>` action child of a `ToolbarItem` or
`ToolbarMenuItem` is not supported.

```xml
<NavigationBarConfig Navigation="nav" Title="Todos">
    <ToolbarItem Title="Edit" Position="Left" Clicked="{edit}" />
    <ToolbarItem Symbols="plus" Clicked="{add}" />
    <ToolbarItem Symbols="ellipsis.circle" Color="#ff5252">
        <ToolbarMenuItem Title="Sort by name" Clicked="{sortByName}" />
        <ToolbarMenuItem Title="Clear completed" Clicked="{clearCompleted}" />
        <ToolbarMenuItem Title="Delete all" Enabled="false" Clicked="{deleteAll}" />
        <ToolbarMenuItem Title="Internal" Visible="false" Clicked="{internal}" />
    </ToolbarItem>
</NavigationBarConfig>
```

```javascript
function add() {
    console.log("Add clicked");
}

module.exports = {
    edit: function () { /* ... */ },
    add: add,
    sortByName: function () { /* ... */ },
    clearCompleted: function () { /* ... */ },
    deleteAll: function () { /* ... */ },
    internal: function () { /* ... */ }
};
```

Items appear in declaration order: `Position="Left"` items first, then `Position="Right"` items.

## Colors

Colors are RGBA `float4` values with each component between 0 and 1:

```xml
<NavigationBarConfig
    Navigation="nav"
    Title="Example"
    BackgroundColor="0.1, 0.1, 0.1, 1"
    ForegroundColor="1, 1, 1, 1"
    TintColor="1, 0.3, 0.6, 1"
/>
```

This gives a dark bar with white text and pink interactive elements.

## Platform notes

- iOS uses `UINavigationController` and `UIBarButtonItem`. Pull-down menus require iOS 14+; on
  older versions the item is a plain button. Symbols require iOS 13+. Images loaded over HTTP
  appear once the download completes.
- Android uses an appcompat `Toolbar`. A `Position="Left"` item is placed just after the back
  arrow; a left item with `ToolbarMenuItem` children is rendered on the right so its popup menu
  can be anchored. `LargeTitle` is ignored on Android. `BackButtonTitle` labels the back arrow
  (Android has no room for text beside it).
- Other platforms use a no-op stub; the properties are accepted but have no visible effect.
