package com.fuse.webview;

/**
 * Integer values shared with Fuse.Controls.ExternalNavigationPolicy and
 * Fuse.Controls.NewWindowPolicy. Keep these in sync with the Uno enums.
 */
public final class WebViewNavigationPolicy
{
	public static final int EXTERNAL_ALLOW = 0;
	public static final int EXTERNAL_OPEN_EXTERNALLY = 1;
	public static final int EXTERNAL_BLOCK = 2;

	public static final int NEW_WINDOW_OPEN_IN_WEBVIEW = 0;
	public static final int NEW_WINDOW_OPEN_EXTERNALLY = 1;
	public static final int NEW_WINDOW_BLOCK = 2;

	private WebViewNavigationPolicy() {}
}
