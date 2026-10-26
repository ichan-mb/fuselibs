package com.fuse.webview;

import android.content.Intent;
import android.net.Uri;

final class WebViewIntents
{
	private WebViewIntents() {}

	static boolean openExternally(String url)
	{
		try {
			Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
			intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
			com.fuse.Activity.getRootActivity().startActivity(intent);
			return true;
		} catch (Exception e) {
			return false;
		}
	}
}
