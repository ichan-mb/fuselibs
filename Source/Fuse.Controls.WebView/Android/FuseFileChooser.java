package com.fuse.webview;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.util.Log;
import android.view.MotionEvent;
import android.view.View;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebView;
import androidx.appcompat.app.AppCompatActivity;

import com.vansuita.pickimage.bean.PickResult;
import com.vansuita.pickimage.bundle.PickSetup;
import com.vansuita.pickimage.dialog.PickImageDialog;
import com.vansuita.pickimage.listeners.IPickCancel;
import com.vansuita.pickimage.listeners.IPickResult;

public class FuseFileChooser
{
	static final int REQUEST_CODE = 51426;

	AppCompatActivity _activity;
	ValueCallback<Uri[]> _callback;

	public FuseFileChooser(AppCompatActivity activity)
	{
		_activity = activity;
	}

	public boolean show(WebView webView, ValueCallback<Uri[]> callback, WebChromeClient.FileChooserParams params)
	{
		onReceiveValue(null);

		_callback = callback;

		final boolean allowMultiple = params.getMode() == WebChromeClient.FileChooserParams.MODE_OPEN_MULTIPLE;

		if (!allowMultiple) {
			PickImageDialog dialog = PickImageDialog
				.build(new PickSetup().setVideo(false))
				.setOnPickResult(new IPickResult() {
					@Override
					public void onPickResult(PickResult result) {
						onReceiveValue(new Uri[] { result.getUri() });
					}
				})
				.setOnPickCancel(new IPickCancel() {
					@Override
					public void onCancelClick() {
						onReceiveValue(null);
					}
				});

			// Some cancellation paths (tapping outside, back button) do not call
			// onCancelClick. Clear the callback on the next WebView touch so another
			// picker can be opened afterwards.
			webView.setOnTouchListener(new View.OnTouchListener() {
				@Override
				public boolean onTouch(View view, MotionEvent event) {
					onReceiveValue(null);
					return false;
				}
			});

			dialog.show(_activity.getSupportFragmentManager());
			return true;
		}

		Intent intent = new Intent(Intent.ACTION_GET_CONTENT);
		intent.addCategory(Intent.CATEGORY_OPENABLE);
		intent.setType("*/*");
		intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);

		com.fuse.Activity.ResultListener listener = new com.fuse.Activity.ResultListener() {
			@Override
			public boolean onResult(int requestCode, int resultCode, Intent intent) {
				if (requestCode != REQUEST_CODE)
					return true;

				if (resultCode == Activity.RESULT_OK && intent != null)
					onReceiveValue(readUris(intent));
				else
					onReceiveValue(null);

				com.fuse.Activity.unsubscribeFromResults(this);
				return true;
			}
		};

		com.fuse.Activity.subscribeToResults(listener);
		_activity.startActivityForResult(Intent.createChooser(intent, "Choose File"), REQUEST_CODE);
		return true;
	}

	private static Uri[] readUris(Intent intent)
	{
		try {
			if (intent.getDataString() != null)
				return new Uri[] { Uri.parse(intent.getDataString()) };

			if (intent.getClipData() != null) {
				final int count = intent.getClipData().getItemCount();
				Uri[] uris = new Uri[count];
				for (int i = 0; i < count; i++)
					uris[i] = intent.getClipData().getItemAt(i).getUri();
				return uris;
			}
		} catch (Exception e) {
			Log.e("FuseFileChooser", e.toString());
		}

		return null;
	}

	private void onReceiveValue(Uri[] value)
	{
		if (_callback == null)
			return;

		_callback.onReceiveValue(value);
		_callback = null;
	}

	public void dispose()
	{
		onReceiveValue(null);
		_activity = null;
	}
}
