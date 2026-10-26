using Uno;
using Uno.UX;
using Uno.Collections;

using Fuse.Scripting;

namespace Fuse.Controls
{
	/** The native WebView for iOS & Android
		@scriptmodule FuseJS/Push

		@include Docs/Guide.md
	*/
	public partial class WebView
	{
		static WebView()
		{
			ScriptClass.Register(typeof(WebView),
				new ScriptMethod<WebView>("goto", setUrl),
				new ScriptMethod<WebView>("goBack", goBack),
				new ScriptMethod<WebView>("goForward", goForward),
				new ScriptMethod<WebView>("reload", reload),
				new ScriptMethod<WebView>("reloadIgnoringCache", reloadIgnoringCache),
				new ScriptMethod<WebView>("stop", stop),
				new ScriptMethod<WebView>("loadHtml", loadHtml),
				new ScriptMethod<WebView>("setBaseUrl", setBaseUrl),
				new ScriptMethod<WebView>("post", postUrl),
				new ScriptMethod<WebView>("setUserAgent", setUserAgent),
				new ScriptMethod<WebView>("getCookies", getCookies),
				new ScriptMethod<WebView>("setCookie", setCookie),
				new ScriptMethod<WebView>("clearCookies", clearCookies),
				new ScriptMethod<WebView>("clearCache", clearCache),
				new ScriptMethod<WebView>("clearStorage", clearStorage));
		}

		/**
			Loads an HTML document from the string provided.

			@scriptmethod loadHtml(html)
			@scriptmethod loadHtml(html, baseUrl)
			@param html The document to load into the WebView.
			@param baseUrl Specifies the base URL used to resolve relative locations in the @html parameter.
		*/
		static void loadHtml(WebView view, object[] args)
		{

			switch(args.Length)
			{
				case 1:
					view.LoadHtml(args[0] as string);
					return;
				case 2:
					view.LoadHtml(args[0] as string, args[1] as string);
					return;
				default:
					Fuse.Diagnostics.UserError("WebView.loadHtml takes either one url argument, or an url and a baseUrl argument", view);
					return;
			}

		}

		/**
			Go back to the previous page.

			@scriptmethod goBack()
		*/
		static void goBack(WebView view)
		{
			view.GoBack();
		}

		/**
			Go forward to the next page.

			@scriptmethod goForward()
		*/
		static void goForward(WebView view)
		{
			view.GoForward();
		}

		/**
			Reload the current page.

			@scriptmethod reload()
		*/
		static void reload(WebView view)
		{
			view.Reload();
		}


		/**
			Stop loading the page.

			@scriptmethod stop()
		*/
		static void stop(WebView view)
		{
			view.Stop();
		}

		/**
			Load a URL in the WebView.

			@scriptmethod goto(url)
			@scriptmethod goto(url, headers)
			@param url The location to load.
			@param headers An object of additional HTTP headers, for example `{ Authorization: "Bearer ..." }`.
		*/
		static void setUrl(WebView view, object[] args)
		{
			switch(args.Length)
			{
				case 1:
					view.Url = args[0] as string;
					return;
				case 2:
					var headers = args[1] as Fuse.Scripting.Object;
					if (headers == null)
					{
						view.Url = args[0] as string;
						return;
					}

					var names = new List<string>();
					var values = new List<string>();
					foreach (var key in headers.Keys)
					{
						names.Add(key);
						values.Add(headers[key] as string ?? "");
					}

					view.LoadUrl(args[0] as string, names.ToArray(), values.ToArray());
					return;
				default:
					Fuse.Diagnostics.UserError( "WebView.goto requires a url, and optionally a headers object", view);
					return;
			}
		}

		/**
			Perform a POST navigation with an `application/x-www-form-urlencoded` body.

			@scriptmethod post(url, body)
			@param url The location to post to.
			@param body The request body.
		*/
		static void postUrl(WebView view, object[] args)
		{
			if (args.Length != 2)
			{
				Fuse.Diagnostics.UserError( "WebView.post requires a url and a body", view);
				return;
			}

			view.PostUrl(args[0] as string, args[1] as string);
		}

		/**
			Overrides the User-Agent header.

			@scriptmethod setUserAgent(userAgent)
			@scriptmethod setUserAgent(userAgent, suffix)
			@param userAgent The full User-Agent string. Pass an empty string to restore the default.
			@param suffix A string appended to the default User-Agent. Ignored when `userAgent` is non-empty.
		*/
		static void setUserAgent(WebView view, object[] args)
		{
			switch(args.Length)
			{
				case 1:
					view.UserAgent = args[0] as string;
					return;
				case 2:
					view.UserAgent = args[0] as string;
					view.UserAgentSuffix = args[1] as string;
					return;
				default:
					Fuse.Diagnostics.UserError( "WebView.setUserAgent requires a user agent string, and optionally a suffix", view);
					return;
			}
		}

		/**
			Retrieve the cookie header string for a URL.

			@scriptmethod getCookies(url, callback)
			@param url The URL whose cookies should be retrieved.
			@param callback A function called with the cookie header string, for example `"session=abc; theme=dark"`.
		*/
		static object getCookies(Context context, WebView view, object[] args)
		{
			if (args.Length < 1 || !(args[0] is string))
			{
				Fuse.Diagnostics.UserError( "WebView.getCookies requires a url and a callback", view);
				return null;
			}

			var callback = args.Length > 1 ? args[1] as Fuse.Scripting.Function : null;
			var url = (string)args[0];

			// The native WebView/cookie APIs must be touched on the UI thread.
			Fuse.UpdateManager.PostAction(() =>
			{
				view.GetCookies(url, cookieHeader =>
				{
					context.Invoke(c =>
					{
						if (callback != null)
							callback.Call(c, cookieHeader ?? "");
					});
				});
			});

			return null;
		}

		/**
			Set a cookie for a URL.

			@scriptmethod setCookie(url, cookie)
			@param url The URL the cookie applies to.
			@param cookie A cookie in `Set-Cookie` format, for example `"session=abc; Path=/; Secure"`.
		*/
		static void setCookie(WebView view, object[] args)
		{
			if (args.Length != 2)
			{
				Fuse.Diagnostics.UserError( "WebView.setCookie requires a url and a cookie", view);
				return;
			}

			view.SetCookie(args[0] as string, args[1] as string);
		}

		/**
			Remove all cookies.

			@scriptmethod clearCookies()
		*/
		static void clearCookies(WebView view)
		{
			view.ClearCookies();
		}

		/**
			Clear the WebView cache.

			@scriptmethod clearCache()
		*/
		static void clearCache(WebView view)
		{
			view.ClearCache();
		}

		/**
			Clear local storage, session storage and related web storage.

			@scriptmethod clearStorage()
		*/
		static void clearStorage(WebView view)
		{
			view.ClearStorage();
		}

		/**
			Reload the current page while ignoring cached responses.

			@scriptmethod reloadIgnoringCache()
		*/
		static void reloadIgnoringCache(WebView view)
		{
			view.ReloadIgnoringCache();
		}

		/**
			Sets the base url used to resolve relative requests on a page (loaded via @loadHtml)

			@scriptmethod setBaseUrl(baseUrl)
			@param baseUrl The base URL used to resolve relative locations.
		*/
		static void setBaseUrl(WebView view, object[] args)
		{
			switch(args.Length)
			{
				case 1:
					view.BaseUrl = args[0] as string;
					return;
				default:
					Fuse.Diagnostics.UserError( "WebView.setBaseUrl requires 1 string argument", view );
					return;
			}
		}
	}
}
