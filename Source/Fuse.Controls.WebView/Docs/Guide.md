The WebView can be used to pull and display content from the web or even just from HTML from a string.

It hooks into some useful triggers for building a customized browsing experience, such as `PageBeginLoading`, `WhilePageLoading` and `PageLoaded`. Navigation triggers like `GoBack` and `GoForward` are complemented with WebView-specific ones, like `Reload`, `LoadUrl` and `LoadHtml`. It can also be used to feed a `ProgressAnimation`.

The WebView is a native Android and iOS element, and as such needs to be contained in a `NativeViewHost`.

Whilst you will naturally want to do most of your JS coding in Fuse the usual way, there are times you may want to evaluate JS in the WebView's context and the resulting data be fed back into Fuse. This is where the `EvaluateJS` comes in:

```xml
	<App>
		<JavaScript>
			module.exports = {
					onPageLoaded : function(res) {
						console.log("WebView arrived at "+ JSON.parse(res.json).url);
				}
			};
		</JavaScript>
		<DockPanel>
			<StatusBarBackground Dock="Top"/>

			<NativeViewHost>
				<WebView Dock="Fill" Url="https://www.google.com">
					<PageLoaded>
						<EvaluateJS Handler="{onPageLoaded}">
							var result = {
								url : document.location.href
							};
							return result;
						</EvaluateJS>
					</PageLoaded>
				</WebView>
			</NativeViewHost>

			<BottomBarBackground Dock="Bottom" />
		</DockPanel>
	</App>
```

## HTML

`<HTML/>` is a semantic utility node used to feed a `WebView` component or a `LoadHtml` action with raw HTML:

```xml
	<NativeViewHost>
		<WebView>
			<HTML>
				<![CDATA[
					<h1>Boom!</h1>
				]]>
			</HTML>
		</WebView>
	</NativeViewHost>

	<LoadHtml>
		<HTML>
			<![CDATA[
				<h1>Bang!</h1>
			]]>
		</HTML>
	</LoadHtml>
```

WebViews can also be fed raw HTML to display by wrapping an `HTML` node or via the `LoadHtml` trigger action:

```xml
	<LoadHtml TargetNode="myWebView" BaseUrl="http://my.domain" Source="{html}"/>
```

## Error handling

Use the `PageFailed` trigger to react when a page fails to load due to a navigation, HTTP or SSL error:

```xml
	<WebView Url="https://example.com">
		<PageFailed Handler="{onError}">
			<Change panel.Color="Red" />
		</PageFailed>
	</WebView>
```

The handler receives an object with `url`, `description`, `code`, `httpStatusCode` and `isMainFrame`.
The same information is available from the `WebView.PageError` event in Uno code.

SSL errors are reported and the navigation is cancelled. HTTP errors are reported for the main frame.

## External navigation

By default links are loaded inside the WebView. Use `ExternalNavigationPolicy` to control top-level navigations, and `NewWindowPolicy` to control what happens with `target="_blank"` and `window.open()`:

```xml
	<WebView
		Url="https://example.com"
		ExternalNavigationPolicy="OpenExternally"
		NewWindowPolicy="OpenInWebView" />
```

- `ExternalNavigationPolicy`: `Allow` (default), `OpenExternally` or `Block`.
- `NewWindowPolicy`: `OpenInWebView` (default), `OpenExternally` or `Block`.

The WebView's custom URI scheme handler (`URISchemeHandler`) is still checked before these policies, and `mailto:`, `sms:` and `tel:` URLs are opened by the system.

## JavaScript dialogs and file inputs

`window.alert()`, `window.confirm()` and `window.prompt()` show native dialogs on both Android and iOS.

Android supports file inputs using the native file picker. iOS supports file inputs using the document picker on iOS 14 and newer.

## Cookies and sessions

Use the session methods to inspect or reset the WebView's cookies and storage:

```js
webView.getCookies("https://example.com", function (cookieHeader) {
  console.log(cookieHeader); // "session=abc; theme=dark"
});

webView.setCookie("https://example.com", "session=abc; Path=/; Secure");
webView.clearCookies();
webView.clearCache();
webView.clearStorage();
webView.reloadIgnoringCache();
```

The same methods are available from Uno code on the `WebView` class.

## User agent and headers

Use `UserAgent` to replace the User-Agent header, or `UserAgentSuffix` to append to the default one:

```xml
	<WebView UserAgent="MyApp/1.0" />
	<WebView UserAgentSuffix="MyApp/1.0" />
```

From JavaScript:

```js
webView.setUserAgent("MyApp/1.0");

webView.goto("https://example.com", {
  Authorization: "Bearer token",
});

webView.post("https://example.com/login", "user=alice&password=secret");
```

`goto` supports additional request headers. `post` sends an `application/x-www-form-urlencoded` body.

## Downloads

The WebView raises `BeginDownload` when a file download starts and `FileDownloaded` when it completes. `FileDownloaded` provides the local file path.

On Android, files are saved to the app-specific Downloads directory, so no storage permission is required. On iOS, downloads are saved to `Documents/Downloads` and require iOS 14.5 or newer. You can share the downloaded file with `Fuse.Share`.
