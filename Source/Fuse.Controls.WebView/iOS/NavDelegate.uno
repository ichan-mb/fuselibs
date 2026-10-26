using Uno;
using Uno.UX;
using Uno.Platform;
using Uno.Collections;
using Fuse;
using Fuse.Elements;
using Fuse.Navigation;
using Uno.Compiler.ExportTargetInterop;
namespace Fuse.iOS.Controls
{
	[Require("source.include", "iOS/WVNavDelegate.h")]
	static public extern(iOS) class NavDelegate
	{
		[Foreign(Language.ObjC)]
		public static ObjC.Object Create(Action beginLoading, Action pageLoaded, Action urlChanged, Action<string> OnCustomURI, string[] schemes, Func<bool> hasURISchemeHandler)
		@{
			return [[WVNavDelegate alloc] initWithEventHandlers:beginLoading loaded:pageLoaded change:urlChanged uriHandler:OnCustomURI schemes:[schemes copyArray] hasURISchemeHandler:hasURISchemeHandler];
		@}

		[Foreign(Language.ObjC)]
		public static void Attach(ObjC.Object webViewHandle, ObjC.Object delegateHandle, Action progress, Action historyChanged, Action<string, string, int, int, bool> pageError, Action<string> beginDownload, Action<string, string> fileDownloaded, int externalNavigationPolicy)
		@{
			WVNavDelegate* navDelegate = (WVNavDelegate*)delegateHandle;
			navDelegate.onProgress = progress;
			navDelegate.onHistoryChanged = historyChanged;
			navDelegate.onPageError = pageError;
			navDelegate.onBeginDownload = beginDownload;
			navDelegate.onFileDownloaded = fileDownloaded;
			navDelegate.externalNavigationPolicy = (WVExternalNavigationPolicy)externalNavigationPolicy;
			[navDelegate attachToWebView:(WKWebView*)webViewHandle];
		@}

		[Foreign(Language.ObjC)]
		public static void SetExternalNavigationPolicy(ObjC.Object delegateHandle, int externalNavigationPolicy)
		@{
			((WVNavDelegate*)delegateHandle).externalNavigationPolicy = (WVExternalNavigationPolicy)externalNavigationPolicy;
		@}

		[Foreign(Language.ObjC)]
		public static void Detach(ObjC.Object delegateHandle)
		@{
			WVNavDelegate* navDelegate = (WVNavDelegate*)delegateHandle;
			navDelegate.onProgress = nil;
			navDelegate.onHistoryChanged = nil;
			navDelegate.onPageError = nil;
			navDelegate.onBeginDownload = nil;
			navDelegate.onFileDownloaded = nil;
			[navDelegate detachFromWebView];
		@}
	}
}
