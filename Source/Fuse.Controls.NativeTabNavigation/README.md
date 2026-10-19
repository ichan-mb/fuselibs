# Fuse.Controls.NativeTabNavigation

`Fuse.Controls.NativeTabNavigation` gives a Fuse app a native tab bar with one native page per tab.

- iOS uses `UITabBarController` (its system tab bar, including the floating style on recent iOS).
- Android uses a bottom tab bar (Material Symbols icons and titles) over a page container. Android has
  no Compose tabs host usable from Fuse's Uno/Java layer, so this is the closest native equivalent and
  keeps the library dependency-free.

Each tab is a `ux:Template` child whose content is rendered in its own native view, so a tab may hold
a `Page`, a `Panel`, or a `NativeNavigationView` with its own navigation bar and back stack. Tabs keep
their state while another tab is shown.

## Quick start

```xml
<NativeTabNavigationView ux:Name="tabs" DefaultTab="Home">
    <Page ux:Template="Home">
        <TabConfig Title="Home" Symbols="house" />
        <Text Value="Home" />
    </Page>

    <Page ux:Template="Search">
        <TabConfig Title="Search" Symbols="magnifyingglass" />
        <NativeNavigationView DefaultTemplate="SearchHome">
            <Page ux:Template="SearchHome">
                <NavigationBarConfig Title="Search" />
                <Button Text="Push a page">
                    <Clicked>
                        <PushView To="SearchDetail" />
                    </Clicked>
                </Button>
            </Page>
            <Page ux:Template="SearchDetail">
                <NavigationBarConfig Title="Detail" />
                <Button Text="Back"><Clicked><PopView /></Clicked></Button>
            </Page>
        </NativeNavigationView>
    </Page>

    <Page ux:Template="Profile">
        <TabConfig Title="Profile" Symbols="person" />
        <Text Value="Profile" />
    </Page>
</NativeTabNavigationView>
```

Reference both packages from the app's project file:

```json
{
  "Packages": [
    "Fuse.Controls.NativeTabNavigation",
    "Fuse.Controls.NativeNavigation"
  ]
}
```

`Fuse.Controls.NativeNavigation` is required only when a tab hosts a `NativeNavigationView`; it is
listed explicitly because the app's UX uses its types directly.

## Tabs

- Every `ux:Template` child is a tab, in declaration order (subject to `Placement`). Content can be any visual.
- `TabConfig` sets a tab's `Title`, `Symbols`, `IsFilled`, `AccessibilityLabel`, `Placement`, `Badge`,
  `Enabled` and `AutoAdd`. A tab without one, or whose config leaves `Title` unset, is titled with its
  template name.
- `DefaultTab` selects the initial tab (the first template when unset).

## Placement

`TabConfig.Placement` sets where a tab sits. The values mirror UIKit's `UITabPlacement`:

| Placement | iOS 18+ | Android |
| --- | --- | --- |
| `Automatic`, `Default` | normal tab | normal tab |
| `Optional` | customizable tab, not shown by default | normal tab |
| `Movable` | movable during customization | normal tab |
| `Fixed` | fixed, before the customizable tabs | normal tab |
| `Pinned` | trailing edge of the bar | trailing edge, separated by a gap |
| `Search` | the separate trailing search button (iOS 26+) | round, elevated trailing button |
| `SidebarOnly` | sidebar only; shown as a normal tab on iPhone | hidden |

```xml
<TabConfig Title="Search" Symbols="magnifyingglass" Placement="Search" />
```

Use `Search` for the tab that opens search: iOS 26 renders it as the round button beside the tab
bar, and Android as a round, elevated button (a FAB-like trailing action) with no label. On iOS 18-25
a `Search` tab is an ordinary trailing tab. UIKit has a single system search tab, so use at most one
`Search` tab.

Placement is ignored before iOS 18 (the older `viewControllers` API has no equivalent). Tabs that
are not separated share the bar's width on Android.

## Lazy tabs

Set `Lazy="true"` to defer each tab's page until it is first selected. The template instance is still
created at startup, to read its `TabConfig` (title, icon, badge, enabled), but it is not rooted and has
no native page until the tab is shown. This keeps heavy tabs cheap when the user never visits them.

```xml
<NativeTabNavigationView Lazy="true" DefaultTab="Home">
    ...
</NativeTabNavigationView>
```

Tabs added later (with `AddTab`, and `AutoAdd="false"` templates) are lazy in the same way.

## Badges

Give a tab a badge with `TabConfig`. Set `Badge` to a count, an empty string for a dot, or leave it
unset (the default) for no badge; changing it at runtime updates the tab.

```xml
<Page ux:Template="Search">
    <TabConfig Title="Search" Symbols="magnifyingglass" Badge="3" BadgeColor="#f44336" />
    ...
</Page>
```

| Property | Default | Description |
| --- | --- | --- |
| `Color` | bar `TintColor` | The tab's icon colour (and its title on Android). |
| `SelectedColor` | bar `SelectedTintColor` | The tab's icon colour when selected (and its title on Android). |
| `Badge` | none | Badge text; `""` shows a dot. |
| `BadgeColor` | red | The badge's background. |
| `BadgeTextColor` | white | The badge's text colour. |

On iOS, `Color`/`SelectedColor` tint the tab's icon; its title follows the bar appearance (UIKit
ignores per-item title colours with the `UITab` API). On Android both the icon and the title use
them.

On iOS the badge is the `UITabBarItem`'s `badgeValue` (a dot uses the smallest badge UIKit draws);
on Android it is drawn over the icon's top-right, and is included in the item's accessibility
description.

## Dynamic tabs

Tabs can be added and removed at runtime. `AutoAdd="false"` keeps a declared template out of the
initial set until it is added:

```xml
<Page ux:Template="Settings">
    <TabConfig Title="Settings" Symbols="settings" AutoAdd="false" />
    ...
</Page>

<Button Text="Add Settings">
    <Clicked>
        <AddTab To="Settings" Navigation="tabs" />
    </Clicked>
</Button>
```

| API | Description |
| --- | --- |
| `AddTab("Name")` | Adds a declared template as a tab. |
| `RemoveTab("Name")` | Removes a tab and disposes its page. |
| `<AddTab To="Name" />` | The same as a trigger action. |
| `<RemoveTab To="Name" />` | The same as a trigger action. |
| `TabsChanged` | Fires when tabs are added or removed. |

From FuseJS: `tabs.add("Settings")` and `tabs.remove("Settings")`.

A tab with `Enabled="false"` is shown but cannot be selected by the user; changing `Enabled` at runtime
updates it.

## Selection

| API | Description |
| --- | --- |
| `SelectedIndex` (`int`) | The selected tab; setting it selects that tab. |
| `SelectedTab` (`string`) | The selected tab's template name. |
| `SelectTab("Name")` | Selects a tab by template name. |
| `<SelectTab To="Name" />` | The same as a trigger action. |
| `SelectedIndexChanged` | Fires when the selected tab changes, in code or by the user; `SelectedIndex` also notifies UX bindings. |

From FuseJS:

```javascript
var tabs = require("NativeTabNavigation");
tabs.select("Search");
tabs.selectIndex(1);
tabs.add("Settings");
tabs.remove("Settings");

// Observe selection changes (also reported immediately for the current selection)
tabs.onSelected(function(index) { console.log("tab " + index); });
```

The module acts on the most recently rooted `NativeTabNavigationView`.

## Appearance

| Property | Default | Description |
| --- | --- | --- |
| `BackgroundColor` | white | The tab bar's background. |
| `TintColor` | grey | Unselected icons and titles. |
| `SelectedTintColor` | blue | The selected tab's icon and title. |
| `Translucent` | `false` | Blurred instead of opaque (iOS; Android uses the background's alpha). |
| `Hidden` | `false` | Hides the whole bar; the tab pages fill the view. |
| `ShowLabels` | `Always` | When a tab's title is shown: `Always`, `Selected` or `Never`. A `Search` tab is always icon-only. |
| `ApplyInsets` | `true` | Pads the tab pages clear of the status bar / safe area; set `false` for edge-to-edge content. |

On iOS 13+ these are applied with a `UITabBarAppearance`, including `scrollEdgeAppearance` — so the
configured background stays visible while content is scrolled to its edge (where UIKit would
otherwise use a transparent bar). `Translucent="true"` uses `configureWithDefaultBackground` (the
system blur); otherwise `configureWithOpaqueBackground`.

## Platform notes

- iOS: `Symbols` are SF Symbols (iOS 13+). The tab item's accessibility label comes from
  `AccessibilityLabel` (falling back to `Title`), so it stays meaningful when labels are hidden. On
  iOS 18+ tabs are built with the `UITab` API (which is what supports `Placement`); older systems use
  `viewControllers`. Labels follow the system Dynamic Type settings automatically.
- Only one `Search` tab is supported: iOS has a single system search tab (`UISearchTab`).
- Android: `Symbols` are Material Symbols ligatures from the font bundled by `Fuse.Controls.Native`,
  and the item's content description is `AccessibilityLabel` (falling back to `Title`). The bar grows
  with the system font scale so its labels stay readable and are not clipped.
- A tab page fills the tab view's content area (its bounds minus the tab bar on Android; the tab
  controller's content area on iOS). With `ApplyInsets` (the default) the page is padded for the
  status bar / safe area, and the padding follows rotation and window changes. On Android the app
  window already starts below the status bar, so only the sides can add anything; set
  `ApplyInsets="false"` for edge-to-edge content.
- Embedding: place the view in any sized visual (a `DockPanel` slot, a `Panel` with a height, a
  `NativeNavigationView` page). The bar and pages use the view's bounds, not the app frame, and the
  insets only cover the part of the system bars that overlaps the view, so a view below a header is
  not padded for the status bar again. Verified on Android; iOS uses view-local safe-area insets and
  the same container layout as `NativeNavigationView`.
- Switching tabs keeps each tab's state (including a nested navigation's stack); there are no swipe
  gestures between tabs.
- Only the most recently rooted view is used by the FuseJS module.
- Android RTL: the bar mirrors its items, but the app's manifest must set
  `android:supportsRtl="true"` (Uno's default template does not), otherwise Android keeps the
  layout direction LTR and nothing mirrors.
- Android: `BackBehavior` chooses what the system back button does on a tab other than the first:
  `Exit` (default, leaves it to the app) or `ReturnToFirst`. A `NativeNavigationView` inside the
  active tab always handles Back first while it can pop; only then does the tab view act.
- Verified: Android 15 emulator (including a dark bar) and iOS 26 on an iPhone 17 Pro: tab pages,
  the separate search tab, badges and per-tab icon colours. iOS 18's iPad top tab bar, the iPad
  sidebar modes, and Android 15's enforced edge-to-edge (apps targeting SDK 35) are not verified
  here. Landscape is verified on Android only.
- iOS on iPhone shows a built-in **More** tab when more than five tabs are present. That list is
  UIKit's; keep the set at five or fewer tabs to avoid it.
