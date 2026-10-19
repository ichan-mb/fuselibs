# Fuse.Controls.NativeNavigation

`Fuse.Controls.NativeNavigation` gives a Fuse app a real native navigation stack, a native
navigation bar and native modal presentation.

- iOS uses `UINavigationController`.
- Android uses the androidx `FragmentManager` (one `Fragment` per page) with an appcompat
  `Toolbar` as the navigation bar.

Each page is a Fuse template rendered into its own native view. Push and pop, the toolbar back
arrow, the Android system back button and the iOS swipe-back gesture all run through the
platform's own navigation.

## Installation

Reference the library from your app's project file:

```json
{
  "projects": [
    "path/to/fuselibs/Source/Fuse.Controls.NativeNavigation/Fuse.Controls.NativeNavigation.unoproj"
  ]
}
```

The controls are in `Fuse.Controls`, so no XML namespace prefix is needed.

## Quick start

```xml
<App>
    <NativeNavigationView ux:Name="nav" DefaultTemplate="Home">
        <Page ux:Template="Home">
            <NavigationBarConfig Navigation="nav" Title="Home">
                <ToolbarItem Title="Add" Position="Right" Clicked="{addItem}" />
            </NavigationBarConfig>

            <StackPanel>
                <Text Value="Home" />
                <Button Text="Open details">
                    <Clicked>
                        <PushView To="Details" Navigation="nav" />
                    </Clicked>
                </Button>
            </StackPanel>
        </Page>

        <Page ux:Template="Details">
            <NavigationBarConfig Navigation="nav" Title="Details" BackButtonTitle="Home" />

            <StackPanel>
                <Text Value="Details" />
                <Button Text="Back">
                    <Clicked>
                        <PopView Navigation="nav" />
                    </Clicked>
                </Button>
            </StackPanel>
        </Page>
    </NativeNavigationView>
</App>
```

Templates are ordinary visuals declared as direct children of the view with `ux:Template`.
`DefaultTemplate` selects the initial page; when it is omitted the first template is used.

### Managing pages from FuseJS

The `Pages` array is the JavaScript-driven alternative to `PushView` and `PopView`. Bind it to
an observable array; the highest index is the active page, and adding or removing entries
pushes or pops the native stack. When `Pages` is bound it supplies the initial page, so
`DefaultTemplate` is not used.

```javascript
var Observable = require("FuseJS/Observable");

var pages = Observable({ $path: "Home", title: "Home" });

function openDetails(item) {
    pages.add({ $path: "Details", title: item.name, item: item });
}

function goBack() {
    if (pages.length > 1)
        pages.removeAt(pages.length - 1);
}

module.exports = { pages: pages, openDetails: openDetails, goBack: goBack };
```

```xml
<NativeNavigationView Pages="{pages}">
    <Page ux:Template="Home">
        <Text Value="{title}" />
        <Button Text="Open details" Clicked="{openDetails}" />
    </Page>

    <Page ux:Template="Details">
        <Text Value="{title}" />
        <Button Text="Back" Clicked="{goBack}" />
    </Page>
</NativeNavigationView>
```

Each entry needs a `$path` naming a template, and the whole entry becomes that page's data
context. Going back with a native gesture or button truncates the array to the native stack.

## Navigation

Every template is instantiated separately, so the same template can be pushed more than once;
each stack entry gets its own view and data context.

### Actions

Navigation actions are trigger actions, usually placed in a `<Clicked>` handler.

| Action | Attributes | Effect |
| --- | --- | --- |
| `PushView` | `To` | Pushes the named template onto the stack. |
| `PopView` | none | Pops the top page. |
| `PresentView` | `To`, `Style`, `DragToDismiss`, `Expandable` | Presents the named template modally. |
| `DismissView` | none | Dismisses the top-most modal. |
| `ExpandModal` | `Value` | Expands or restores the top-most sheet (`Value` defaults to `true`). |

All actions accept an optional `Navigation` attribute. When it is omitted, the navigation view the
action's page belongs to is used (falling back to the nearest `NativeNavigationView` in the parent
hierarchy). See [docs/USAGE.md](docs/USAGE.md) for the complete action and JavaScript reference.

```xml
<Button Text="Filters">
    <Clicked>
        <PresentView To="Filters" Style="Sheet" Navigation="nav" />
    </Clicked>
</Button>
```

### Native back

The navigation bar's back arrow and the iOS swipe-back gesture are handled by the platform.
On Android the system back button is also routed to the navigation view. If a modal is open it
is dismissed first; otherwise the top page is popped. Only the most recently rooted
`NativeNavigationView` handles the system back button, so nested or embedded views do not
compete for it.

Pages can animate their content alongside the native transition with the usual Fuse triggers:

```xml
<Page ux:Template="Details">
    <EnteringAnimation>
        <Scale Factor="0.9" Duration="0.25" Easing="QuadraticOut" />
    </EnteringAnimation>
    <ExitingAnimation>
        <Scale Factor="0.9" Duration="0.25" Easing="QuadraticOut" />
    </ExitingAnimation>
</Page>
```

## Navigation bar

`NavigationBarConfig` is placed inside a template and configures that template's native bar.
A template that declares no `NavigationBarConfig` has no bar at all; bars are never inherited
from the previous page.

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `Navigation` | `NativeNavigationView` | containing view | The navigation view to configure. |
| `Title` | `string` | empty | Title shown in the bar. |
| `BackgroundColor` | `float4` | white | Bar background, RGBA in the range 0-1. |
| `ForegroundColor` | `float4` | black | Text and button color. |
| `TintColor` | `float4` | `ForegroundColor` | Color of interactive items such as icons and buttons. |
| `LargeTitle` | `bool` | `false` | Large title on iOS 11+; ignored on Android. |
| `Translucent` | `bool` | `false` | When false, content does not appear behind the bar. |
| `Hidden` | `bool` | `false` | Hides the bar for this template. |
| `BackButtonTitle` | `string` | platform default | Labels the back button shown on this page. |
| `ApplyInsets` | `bool` | `false` | Insets page content clear of the bar and system bars; off by default (edge-to-edge), set to `true` to inset it. |

```xml
<NavigationBarConfig
    Navigation="nav"
    Title="Inbox"
    BackgroundColor="#1565C0"
    ForegroundColor="#ffffff"
    TintColor="#ffd54f"
    LargeTitle="true"
    ApplyInsets="true"
>
    <ToolbarItem Title="Edit" Position="Left" Clicked="{edit}" />
    <ToolbarItem Symbols="plus" />
    <ToolbarItem Symbols="ellipsis.circle">
        <ToolbarMenuItem Title="Sort by name" Clicked="{sortByName}" />
        <ToolbarMenuItem Title="Clear completed" Clicked="{clearCompleted}" />
    </ToolbarItem>
</NavigationBarConfig>
```

### Toolbar items and menus

A `ToolbarItem` is a button on the bar. A `ToolbarMenuItem` is an entry in a pull-down menu
attached to its parent `ToolbarItem`.

| Element | Properties |
| --- | --- |
| `ToolbarItem` | `Title`, `Position` (`Leading`/`Trailing`, or the older `Left`/`Right`; default `Right`), `Enabled`, `Visible`, `AccessibilityLabel`, `Symbols`, `IsFilled`, `File`, `Url`, `Source`, `Color`, `Clicked` |
| `ToolbarMenuItem` | `Title`, `Enabled`, `Visible`, `AccessibilityLabel`, `Symbols`, `IsFilled`, `File`, `Url`, `Source`, `Clicked` |

Positions are logical: `Leading` is the left side in a left-to-right layout and the right side in
an RTL layout, `Trailing` the reverse. `Left` and `Right` are the older names for the same two
sides, so existing sources keep working and also mirror in RTL.

Specify at most one icon source (`Symbols`, `File`, `Url` or `Source`). Symbols resolve to SF
Symbols on iOS and Material Symbols on Android. Give an icon-only item an `AccessibilityLabel`
so screen readers can announce it; when it is unset, `Title` is used. `Clicked` is an event
binding, written as `Clicked="{handler}"`; a `<Clicked>` action child is not supported on
toolbar entries.

See [docs/NavigationBarConfig.md](docs/NavigationBarConfig.md) for the complete reference and
platform notes.

## Modals

`PresentView` presents a template modally. Modal presentation is independent of the push/pop
stack: the presented page is not part of the navigation history and is closed with
`DismissView` (or the equivalent FuseJS call).

| `Style` | iOS | Android |
| --- | --- | --- |
| `FullScreen` (default) | Full-screen presentation | Full-screen dialog |
| `PageSheet` | Card inset from the top | Full-height card inset from the top |
| `FormSheet` | Smaller centered card (regular width only) | Card inset on all sides |
| `Sheet` | Bottom sheet with medium and large sizes (iOS 15+) | Bottom-anchored card, about half the screen |

`DragToDismiss` (default `true`) lets the user drag a `PageSheet` or `Sheet` down to dismiss it
and shows a grabber on Android. `Expandable` (default `true`) lets a `Sheet` be dragged up to
fill the screen; `ExpandModal` does the same from code. Only an expandable sheet has two sizes,
so `ExpandModal` does nothing for other modals. `FullScreen` cannot be dragged.

Give a sheet's template a layout that adapts to the card size rather than one that assumes the
full screen height. A modal also follows the bar rule above: its template gets a bar only if it
declares a `NavigationBarConfig`.

### FuseJS module

`require("NativeNavigation")` exposes modal presentation for the most recently rooted
`NativeNavigationView`:

```javascript
var nav = require("NativeNavigation");

nav.present("Filters", { closeModal: function () { nav.dismiss(); } });
nav.present("Filters", { closeModal: function () { nav.dismiss(); } }, "sheet");
nav.present("Filters", data, "sheet", false);       // cannot be dragged away
nav.present("Filters", data, "sheet", true, false); // one size only
nav.setExpanded(true);                              // expand the sheet on screen
nav.setExpanded(false);                             // give it its own size back
nav.dismiss();
```

The signature is `present(templateName, data?, style?, dragToDismiss?, expandable?)`. Style
names are `fullScreen` (default), `pageSheet`, `formSheet` and `sheet`, case-insensitively; an
unknown name warns and falls back to `fullScreen`. Push and pop are performed by changing the
`Pages` array.

## Layout

`NativeNavigationView` is itself a native control and can be placed anywhere in the UI;
`NativeViewHost` is not required.

- A page is laid out at the size its own view is given. When the navigation view fills the
  window, that is the app frame.
- Embedded in a smaller container, pages stay inside that container: content docked to an
  edge, centered or scrolling remains within the box, and the bar follows the same box.
- A modal is presented at the app frame/window size even when it is presented from an embedded
  view.
- A page's safe-area insets come from the window. A host that already insets its content (for
  example with padding or a card) applies those insets a second time.

```xml
<StackPanel>
    <Text Value="Fuse content above" />

    <NativeNavigationView ux:Name="nav" DefaultTemplate="Home" Height="320">
        <Page ux:Template="Home">
            <!-- Laid out inside the 320-point tall view. -->
        </Page>
    </NativeNavigationView>

    <Text Value="Fuse content below" />
</StackPanel>
```

## How it works

1. `NativeNavigationView` creates the platform implementation through a factory.
2. Each template instance is rendered into an isolated `ViewControllerRoot` with its own native view.
3. The native view is wrapped in a `UIViewController` on iOS or a `Fragment` on Android.
4. The platform's navigation controller or fragment manager owns the stack and transitions.
5. A page is laid out at the size its native view is given; a modal follows the size its presentation
gives it, with its insets derived from the app frame.

## Platform notes

- iOS and Android are both implemented. Other platforms use a no-op stub, so navigation
  actions do not throw but have no visible effect.
- iOS: symbol icons require iOS 13+, pull-down menus iOS 14+, and large titles iOS 11+.
- Android: system-bar insets use the window insets API on API 23+, and fall back to the
  framework's dimension resources below that.
- `LargeTitle` is an iOS 11+ presentation feature; Android ignores it.
- Replacing the platform transition itself is not supported. `EnteringAnimation` and
  `ExitingAnimation` animate the page content alongside the native transition.
- Android: a sheet or card resizes for the soft keyboard, and the page follows the new height;
  a full-screen modal keeps its layout and pans the focused field into view.
- Only the most recently rooted `NativeNavigationView` handles the system back button, so
  split or nested navigation needs its own back routing (`GoBack` / `DismissModal`).

## API stability

The public API is `NativeNavigationView`, `NavigationBarConfig`, `ToolbarItem`,
`ToolbarMenuItem`, `ModalPresentationStyle`, the navigation actions (`PushView`, `PopView`,
`PresentView`, `DismissView`, `ExpandModal`) and the `"NativeNavigation"` FuseJS module.
Everything else -- the platform interfaces, rendering contexts and helpers -- is internal and
may change.

## Troubleshooting

- **A page has no bar.** Add a `NavigationBarConfig` inside that template. A bar is never
  inherited from the previous page.
- **Content is under the bar or the status bar.** Content is edge-to-edge by default; set
  `ApplyInsets="true"` on the `NavigationBarConfig` to inset it, or keep it off and add your own
  padding.
- **A navigation action does nothing.** Set `Navigation` on the action, or place the action in
  the hierarchy of the intended `NativeNavigationView`.
- **`DefaultTemplate` is not used.** Check that a template with that exact name exists; if it
  does not, the first available template is used.
- **Modal content is cropped.** A modal is laid out to its card, not the app frame. Use an
  adapting layout (a scrolling body or docked controls) instead of fixed full-screen heights.
- **A toolbar item does not respond.** Bind `Clicked="{handler}"`; do not use a `<Clicked>`
  action child.
- **A form sheet looks like a page sheet on iOS.** The smaller `FormSheet` card needs a regular
  width class (an iPad, or a Max/Plus phone in landscape); compact width uses the page sheet.

The manual test page covers the bar rules, toolbar items and menus, every modal style, dragging
and expanding sheets, embedded layout, transitions and stack depth:
[Tests/ManualTests/ManualTestingApp/NativeNavigation/NativeNavigationPage.ux](../../Tests/ManualTests/ManualTestingApp/NativeNavigation/NativeNavigationPage.ux). It is built by CI and is the reference for working scenarios.
