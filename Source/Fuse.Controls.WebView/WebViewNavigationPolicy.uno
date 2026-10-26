namespace Fuse.Controls
{
	/**
		Determines how a @WebView treats top-level navigations to URLs that are not
		handled inside the WebView itself.

		The default is @Allow, which keeps the current behavior of loading the URL
		in the WebView whenever possible.
	*/
	public enum ExternalNavigationPolicy
	{
		/**
			Load the URL in the WebView.
		*/
		Allow,

		/**
			Open the URL using the system browser or the app registered for the URL scheme.
		*/
		OpenExternally,

		/**
			Cancel the navigation.
		*/
		Block
	}

	/**
		Determines what a @WebView does when the page tries to open a new window,
		for example with `target="_blank"` or `window.open()`.

		The default is @OpenInWebView, which loads the new URL in the existing WebView.
	*/
	public enum NewWindowPolicy
	{
		/**
			Load the new URL in the existing WebView.
		*/
		OpenInWebView,

		/**
			Open the new URL using the system browser or the app registered for the URL scheme.
		*/
		OpenExternally,

		/**
			Ignore the request to open a new window.
		*/
		Block
	}

	internal interface IWebViewNavigationPolicyClient
	{
		void SetExternalNavigationPolicy(ExternalNavigationPolicy policy);
		void SetNewWindowPolicy(NewWindowPolicy policy);
	}
}
