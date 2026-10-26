# Fuse.Controls.WebView

Native WebView for Android and iOS in Fuse.

`WebView` embeds the platform WebView (`android.webkit.WebView` on Android and
`WKWebView` on iOS) and exposes it as a Fuse panel. Because it is a native view,
it must be hosted in a `NativeViewHost`.

## Quick start

```xml
<App>
    <JavaScript>
        module.exports = {
            onTitle: function(result) {
                console.log("Title: " + JSON.parse(result.json));
            },
            onError: function(args) {
                console.log("Failed: " + args.description);
            }
        };
    </JavaScript>

    <NativeViewHost>
        <WebView Url="https://example.com">
            <PageLoaded>
                <EvaluateJS JavaScript="return document.title;" Handler="{onTitle}" />
            </PageLoaded>
            <PageFailed Handler="{onError}" />
        </WebView>
    </NativeViewHost>
</App>
```

## Loading content

```xml
<!-- Load a URL -->
<WebView Url="https://example.com" />

<!-- Load HTML with a base URL for relative resources -->
<WebView BaseUrl="https://example.com/">
    <HTML>
        <![CDATA[
            <h1>Hello</h1>
        ]]>
    </HTML>
</WebView>

<!-- Load a bundled HTML file -->
<WebView File="assets/index.html" />
```

`LoadHtml`, `LoadUrl` and `File` are also available from Uno code and the
`LoadHtml` / `LoadUrl` trigger actions.

## Navigation and progress

```xml
<WebView Url="https://example.com">
    <PageBeginLoading>
        <Change loading.Opacity="1" />
    </PageBeginLoading>
    <WhilePageLoading>
        <Change loading.Opacity="1" />
    </WhilePageLoading>
    <PageLoaded Handler="{onLoaded}" />
    <PageFailed Handler="{onError}" />
</WebView>
```

Available members include:

- `Url`, `Source`, `BaseUrl`, `File`, `DocumentTitle`
- `LoadUrl`, `LoadHtml`, `Reload`, `Stop`, `ReloadIgnoringCache`
- `GoBack`, `GoForward`, `CanGoBack`, `CanGoForward`
- `Progress`, `ProgressChanged`, `HistoryChanged`
- `PageLoaded`, `BeginLoading`, `UrlChanged`, `PageError`

### Error reporting

`PageFailed` fires for navigation, HTTP and SSL errors. The handler receives:

| Field | Description |
|---|---|
| `url` | URL that failed |
| `description` | Human-readable error |
| `code` | Platform error code (`0` for HTTP errors) |
| `httpStatusCode` | HTTP status code, or `0` |
| `isMainFrame` | Whether the error is for the main frame |

SSL errors are reported and cancelled. HTTP errors are reported for the main
frame while the response is still displayed.

## JavaScript

### EvaluateJS action

```xml
<PageLoaded>
    <EvaluateJS Handler="{onResult}">
        var data = { url: document.location.href };
        return data;
    </EvaluateJS>
</PageLoaded>
```

The handler receives a `json` string. See `Docs/Guide.md` for details.

### JavaScript API

| Method | Description |
|---|---|
| `goto(url)` | Load a URL |
| `goto(url, headers)` | Load a URL with custom HTTP headers |
| `goBack()` / `goForward()` | Navigate history |
| `reload()` | Reload the page |
| `reloadIgnoringCache()` | Reload and ignore cached responses |
| `stop()` | Stop loading |
| `loadHtml(html[, baseUrl])` | Load HTML |
| `setBaseUrl(baseUrl)` | Set the base URL for loaded HTML |
| `post(url, body)` | POST an `application/x-www-form-urlencoded` body |
| `setUserAgent(ua[, suffix])` | Override or extend the User-Agent |
| `getCookies(url, callback)` | Read cookies for a URL |
| `setCookie(url, cookie)` | Set a cookie |
| `clearCookies()` | Remove all cookies |
| `clearCache()` | Clear the WebView cache |
| `clearStorage()` | Clear local/session storage and related data |

`getCookies` uses a callback because it is exposed through `ScriptClass`:

```js
webView.getCookies("https://example.com", function(cookieHeader) {
    console.log(cookieHeader); // "session=abc; theme=dark"
});
```

## Cookies and sessions

```js
webView.setCookie("https://example.com", "session=abc; Path=/; Secure");
webView.clearCookies();
webView.clearCache();
webView.clearStorage();
webView.reloadIgnoringCache();
```

The same methods are available on the `WebView` class from Uno code through
the `IWebViewSession` interface.

## User agent and request headers

```xml
<WebView UserAgent="MyApp/1.0" />
<!-- or append to the default user agent -->
<WebView UserAgentSuffix="MyApp/1.0" />
```

```js
webView.setUserAgent("MyApp/1.0");

webView.goto("https://example.com", {
    "Authorization": "Bearer token"
});

webView.post("https://example.com/login", "user=alice&password=secret");
```

`goto` supports additional request headers. Android's `postUrl` accepts a body
but not custom headers.

## Navigation policies

```xml
<WebView
    Url="https://example.com"
    ExternalNavigationPolicy="OpenExternally"
    NewWindowPolicy="OpenInWebView" />
```

- `ExternalNavigationPolicy`: `Allow` (default), `OpenExternally`, `Block`
- `NewWindowPolicy`: `OpenInWebView` (default), `OpenExternally`, `Block`

Custom URI schemes declared in the project (`project.mobile.uriScheme`) are
reported through `URISchemeHandler` before these policies are applied.
`mailto:`, `sms:` and `tel:` URLs are opened by the system.

## Downloads

`BeginDownload` fires when a download starts. `FileDownloaded` fires on
success and provides the local file path.

- **Android:** files are saved to the app-specific `Downloads` directory
  (`getExternalFilesDir`). No storage permission is required.
- **iOS:** files are saved to `Documents/Downloads` using `WKDownload` and
  require iOS 14.5 or newer.

Use `Fuse.Share` or `Fuse.Launcher` to expose downloaded files to the user.

## Custom URI schemes

Set `mobile.uriScheme` in the project file and handle `URISchemeHandler`:

```xml
<WebView Url="https://example.com">
    <URISchemeHandler Handler="{onUriScheme}" />
</WebView>
```

The event provides the full URL that was intercepted.

## Platform notes

- `WebView` is a native view and must be inside a `NativeViewHost`.
- Android downloads use app-specific storage to avoid scoped-storage and
  runtime-permission issues.
- iOS downloads require iOS 14.5+. iOS file inputs (`<input type="file">`) use
  the document picker and require iOS 14+.
- Android `target="_blank"` / `window.open()` is implemented with a temporary
  WebView. Popups that write content without navigating to a URL are not
  captured.
- iOS applies `ExternalNavigationPolicy` to user-initiated link and form
  navigations. Android applies it to navigations routed through
  `shouldOverrideUrlLoading`; programmatic `LoadUrl` calls are not intercepted.
- `ClearCache()` on iOS also clears the shared `NSURLCache`.
- Android `ClearStorage()` clears WebView DOM storage for the application.

## Uno API

The main contracts are:

- `IWebView` — navigation, loading and JavaScript evaluation
- `IWebViewError` — adds `PageError`
- `IWebViewSession` — cookies, cache and storage
- `IWebView` implementations can be supplied through `WebView.WebViewClient`

## Package layout

```
Android/    Android WebView, chrome client, downloads, file picker, JS bridge
iOS/        WKWebView control, delegates, downloads, shared ObjC helpers
Docs/       Package guide and examples
```

## Development

Run the library checks from the repository root:

```sh
uno doctor Source/Fuse.Controls.WebView/Fuse.Controls.WebView.unoproj
```

A native build is required to exercise platform behavior:

```sh
uno build android Tests/ManualTests/ManualTestingApp/ManualTestingApp.unoproj
uno build ios     Tests/ManualTests/ManualTestingApp/ManualTestingApp.unoproj
```

The manual test suite includes `Tests/ManualTests/ManualTestingApp/Singles/WebViewPage.ux`.

## License

Part of the Fuse Open fuselibs project. See the repository `LICENSE.txt`.
