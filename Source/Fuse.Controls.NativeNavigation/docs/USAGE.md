# Native Navigation Usage

Reference for the actions, JavaScript API and layout rules of `Fuse.Controls.NativeNavigation`.
For an overview and a quick start, see [the README](../README.md).

## Templates

Templates are direct children of `NativeNavigationView`, declared with `ux:Template`. The initial
template is selected by `DefaultTemplate`; when it is not set, the first declared template is
used. Every push creates a fresh instance of the template.

```xml
<NativeNavigationView ux:Name="nav" DefaultTemplate="Home">
    <Page ux:Template="Home"><!-- ... --></Page>
    <Page ux:Template="Details"><!-- ... --></Page>
</NativeNavigationView>
```

## Navigation actions

| Action | Attributes | Description |
| --- | --- | --- |
| `PushView` | `To` | Pushes the template named by `To`. |
| `PopView` | none | Pops the top page. |
| `PresentView` | `To`, `Style`, `DragToDismiss`, `Expandable` | Presents a template modally. |
| `DismissView` | none | Dismisses the top-most modal. |
| `ExpandModal` | `Value` | Expands the top-most sheet, or restores its own size when `Value="false"`. |

`PushView`, `PopView`, `PresentView`, `DismissView` and `ExpandModal` all inherit `Navigation`
from `NativeNavigationAction`. When `Navigation` is not set, the navigation view the action's page
belongs to is used (falling back to the nearest one in the parent hierarchy).

```xml
<Button Text="Open details">
    <Clicked>
        <PushView To="Details" Navigation="nav" />
    </Clicked>
</Button>

<Button Text="Filters">
    <Clicked>
        <PresentView To="Filters" Style="Sheet" Navigation="nav" />
    </Clicked>
</Button>

<Button Text="Full height">
    <Clicked>
        <ExpandModal Navigation="nav" />
    </Clicked>
</Button>
```

`ExpandModal.Value` defaults to `true`. Only a `Sheet` presented with `Expandable="true"` has two
sizes; for any other modal `ExpandModal` has no effect.

## Pages array

`Pages` is the JavaScript-driven stack. Bind it to an observable array. The highest index is the
active page.

- Each entry is an object with a `$path` property naming the template. Any other properties on
  the entry become that page's data context.
- `pages.add(...)` pushes a page; removing the top entry pops.
- Replacing or inserting an entry updates the corresponding page.
- A native back gesture or button truncates the array to the native stack, so the bound data stays
  in sync.
- `Pages` expects an observable array; other array types produce a warning.

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
    <!-- templates -->
</NativeNavigationView>
```

## Modal presentation

`PresentView` attributes:

| Attribute | Type | Default | Description |
| --- | --- | --- | --- |
| `To` | `string` | required | Template to present. |
| `Style` | `ModalPresentationStyle` | `FullScreen` | Presentation style. |
| `DragToDismiss` | `bool` | `true` | Allows a `PageSheet` or `Sheet` to be dragged down to dismiss it; also controls the Android grabber. |
| `Expandable` | `bool` | `true` | Allows a `Sheet` to be dragged up to fill the screen. |
| `Navigation` | `NativeNavigationView` | nearest in hierarchy | Navigation view to act on. |

| Style | iOS | Android |
| --- | --- | --- |
| `FullScreen` | `UIModalPresentationFullScreen` | Full-screen dialog |
| `PageSheet` | `UIModalPresentationPageSheet`, inset from the top | Full-height card inset from the top |
| `FormSheet` | `UIModalPresentationFormSheet` (regular width only) | Card inset on all sides |
| `Sheet` | Medium detent on iOS 15+; falls back to `PageSheet` below iOS 15 | Bottom-anchored card, about half the screen |

`FullScreen` has no drag on either platform. On iOS, `FormSheet` uses the smaller centered card
only in a regular width class (an iPad, or a Max/Plus phone in landscape); compact width renders
it like `PageSheet`. A modal is laid out to its card, not the app frame, so use an adapting
layout.

A modal template gets a bar only when it declares its own `NavigationBarConfig`; a modal template
without one has no bar and its content fills the modal.

### FuseJS `NativeNavigation` module

The module operates on the most recently rooted `NativeNavigationView`.

```javascript
var nav = require("NativeNavigation");

nav.present(templateName, data?, style?, dragToDismiss?, expandable?);
nav.setExpanded(expanded);
nav.dismiss();
```

| Function | Arguments | Description |
| --- | --- | --- |
| `present` | `templateName`, optional `data`, optional `style`, optional `dragToDismiss`, optional `expandable` | Presents a template. `data` becomes the page's data context. |
| `setExpanded` | `expanded` (`bool`) | Expands the top-most sheet or restores its own size. |
| `dismiss` | none | Dismisses the top-most modal. |

Style names are `fullScreen` (default), `pageSheet`, `formSheet` and `sheet`, case-insensitively.
An unknown name warns and falls back to `fullScreen`. Push and pop are done through `Pages`; the
module has no `push` or `pop` function.

```javascript
nav.present("Filters", {
    closeModal: function () { nav.dismiss(); }
}, "sheet");

nav.present("Filters", data, "sheet", false);       // cannot be dragged away
nav.present("Filters", data, "sheet", true, false); // keeps one size
```

## Navigation bar

`NavigationBarConfig` is placed inside a template and applies to that template only. Bars are not
inherited: a template without a config has no bar at all. The full property reference, including
`ToolbarItem` and `ToolbarMenuItem`, is in
[NavigationBarConfig.md](NavigationBarConfig.md).

Compact form:

```xml
<NavigationBarConfig
    Navigation="nav"
    Title="Inbox"
    BackgroundColor="#1565C0"
    ForegroundColor="#ffffff"
    TintColor="#ffd54f"
    LargeTitle="true"
    Translucent="false"
    Hidden="false"
    BackButtonTitle="Back"
    ApplyInsets="true"
>
    <ToolbarItem Title="Edit" Position="Left" Clicked="{edit}" />
    <ToolbarItem Symbols="plus" Clicked="{add}" />
    <ToolbarItem Symbols="ellipsis.circle">
        <ToolbarMenuItem Title="Sort by name" Clicked="{sortByName}" />
        <ToolbarMenuItem Title="Clear completed" Clicked="{clearCompleted}" />
    </ToolbarItem>
</NavigationBarConfig>
```

`Clicked` is a `VisualEventHandler` binding (`Clicked="{handler}"`); a `<Clicked>` action child is
not supported on toolbar entries.

## Layout

- `NativeNavigationView` can be placed anywhere; `NativeViewHost` is not required.
- A page is laid out at the size its own view is given. Embedded in a smaller container, all page
  content stays inside that container, and the bar follows the same box.
- A modal is presented at the app frame/window size even when presented from an embedded view.
- Page insets come from the window. A host that already applies padding or a card inset applies
  those insets a second time.

## Platform notes

- iOS and Android are implemented. Other platforms use a no-op stub: navigation actions do not
  throw but have no visible effect.
- Pull-down menus require iOS 14+; on older versions the toolbar item is a plain button.
- `LargeTitle` is ignored on Android.
- The platform transition itself cannot be replaced. `EnteringAnimation` and `ExitingAnimation`
  animate the page content alongside it.

## Manual tests

The scenarios that are kept working are in
[Tests/ManualTests/ManualTestingApp/NativeNavigation/NativeNavigationPage.ux](../../Tests/ManualTests/ManualTestingApp/NativeNavigation/NativeNavigationPage.ux),
which CI builds. It covers bar rules, toolbar items and menus, every modal style, drag and expand,
embedded layout and stack depth.
