package com.fuse.webview;

import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.net.Uri;
import android.os.Message;
import android.util.Log;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.JsPromptResult;
import android.webkit.JsResult;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.EditText;
import android.widget.FrameLayout;

import androidx.appcompat.app.AppCompatActivity;

import com.foreign.Uno.Action_int;

public class FuseWebChromeClient extends WebChromeClient
{
	int _originalOrientation;
	FullscreenHolder _fullscreenContainer;
	CustomViewCallback _customViewCallback;
	View _customView;
	AppCompatActivity _activity;
	Action_int _handler;
	int _newWindowPolicy;
	final FuseFileChooser _fileChooser;

	public FuseWebChromeClient(Action_int handler, int newWindowPolicy)
	{
		super();
		_activity = com.fuse.Activity.getRootActivity();
		_handler = handler;
		_newWindowPolicy = newWindowPolicy;
		_fileChooser = new FuseFileChooser(_activity);
	}

	public void setNewWindowPolicy(int policy)
	{
		_newWindowPolicy = policy;
	}

	public void dispose()
	{
		if (_customView != null)
		{
			try {
				onHideCustomView();
			} catch (Exception e) {
				Log.e("FuseWebChromeClient", "Failed to hide custom view: " + e.toString());
			}
		}

		_fileChooser.dispose();

		_handler = null;
		_activity = null;
	}

	@Override
	public boolean onCreateWindow(WebView view, boolean isDialog, boolean isUserGesture, Message resultMsg)
	{
		if (_newWindowPolicy == WebViewNavigationPolicy.NEW_WINDOW_BLOCK)
			return false;

		final WebView mainView = view;
		final WebView popupView = new WebView(view.getContext());
		popupView.getSettings().setJavaScriptEnabled(true);
		popupView.setWebViewClient(new WebViewClient() {
			@Override
			public boolean shouldOverrideUrlLoading(WebView popup, String url)
			{
				if (_newWindowPolicy == WebViewNavigationPolicy.NEW_WINDOW_OPEN_EXTERNALLY)
				{
					if (!WebViewIntents.openExternally(url))
						mainView.loadUrl(url);
				}
				else if (_newWindowPolicy == WebViewNavigationPolicy.NEW_WINDOW_OPEN_IN_WEBVIEW)
				{
					mainView.loadUrl(url);
				}

				// Destroy the temporary WebView after the current callback returns.
				final WebView popupToDestroy = popup;
				popup.post(new Runnable() {
					@Override
					public void run() {
						popupToDestroy.stopLoading();
						popupToDestroy.destroy();
					}
				});

				return true;
			}
		});

		WebView.WebViewTransport transport = (WebView.WebViewTransport) resultMsg.obj;
		transport.setWebView(popupView);
		resultMsg.sendToTarget();
		return true;
	}

	@Override
	public void onProgressChanged(WebView view, int progress)
	{
		super.onProgressChanged(view, progress);
		if (_handler != null)
			_handler.run(progress);
	}

	@Override
	public boolean onShowFileChooser(WebView webView, ValueCallback<Uri[]> filePathCallback, WebChromeClient.FileChooserParams fileChooserParams) {
		return _fileChooser.show(webView, filePathCallback, fileChooserParams);
	}

	private AlertDialog.Builder createDialogBuilder(String message)
	{
		AlertDialog.Builder builder = new AlertDialog.Builder(_activity);
		builder.setMessage(message != null ? message : "");
		return builder;
	}

	private void showDialog(AlertDialog.Builder builder)
	{
		AlertDialog dialog = builder.create();
		dialog.setCanceledOnTouchOutside(false);
		dialog.show();
	}

	@Override
	public boolean onJsAlert(WebView view, String url, String message, final JsResult result) {
		if (_activity == null) {
			result.cancel();
			return true;
		}

		AlertDialog.Builder builder = createDialogBuilder(message);
		builder.setPositiveButton(android.R.string.ok, new DialogInterface.OnClickListener() {
			@Override
			public void onClick(DialogInterface dialog, int which) {
				result.confirm();
			}
		});
		builder.setOnCancelListener(new DialogInterface.OnCancelListener() {
			@Override
			public void onCancel(DialogInterface dialog) {
				result.confirm();
			}
		});

		showDialog(builder);
		return true;
	}

	@Override
	public boolean onJsConfirm(WebView view, String url, String message, final JsResult result) {
		if (_activity == null) {
			result.cancel();
			return true;
		}

		AlertDialog.Builder builder = createDialogBuilder(message);
		builder.setPositiveButton(android.R.string.ok, new DialogInterface.OnClickListener() {
			@Override
			public void onClick(DialogInterface dialog, int which) {
				result.confirm();
			}
		});
		builder.setNegativeButton(android.R.string.cancel, new DialogInterface.OnClickListener() {
			@Override
			public void onClick(DialogInterface dialog, int which) {
				result.cancel();
			}
		});
		builder.setOnCancelListener(new DialogInterface.OnCancelListener() {
			@Override
			public void onCancel(DialogInterface dialog) {
				result.cancel();
			}
		});

		showDialog(builder);
		return true;
	}

	@Override
	public boolean onJsPrompt(WebView view, String url, String message, String defaultValue, final JsPromptResult result) {
		if (_activity == null) {
			result.cancel();
			return true;
		}

		final EditText input = new EditText(_activity);
		input.setSingleLine();
		input.setText(defaultValue != null ? defaultValue : "");

		AlertDialog.Builder builder = createDialogBuilder(message);
		builder.setView(input);
		builder.setPositiveButton(android.R.string.ok, new DialogInterface.OnClickListener() {
			@Override
			public void onClick(DialogInterface dialog, int which) {
				result.confirm(input.getText().toString());
			}
		});
		builder.setNegativeButton(android.R.string.cancel, new DialogInterface.OnClickListener() {
			@Override
			public void onClick(DialogInterface dialog, int which) {
				result.cancel();
			}
		});
		builder.setOnCancelListener(new DialogInterface.OnCancelListener() {
			@Override
			public void onCancel(DialogInterface dialog) {
				result.cancel();
			}
		});

		showDialog(builder);
		return true;
	}

	@Override
	public void onShowCustomView(View view, CustomViewCallback callback) {
		if (_customView != null) {
			callback.onCustomViewHidden();
			return;
		}

		_originalOrientation = _activity.getRequestedOrientation();

		FrameLayout decor = (FrameLayout) _activity.getWindow().getDecorView();

		_fullscreenContainer = new FullscreenHolder(_activity);
		_fullscreenContainer.addView(view, ViewGroup.LayoutParams.MATCH_PARENT);
		decor.addView(_fullscreenContainer, ViewGroup.LayoutParams.MATCH_PARENT);
		_customView = view;
		setFullscreen(true);
		_customViewCallback = callback;
		_activity.setRequestedOrientation(_originalOrientation);
		super.onShowCustomView(view, callback);
	}

	@Override
	public void onHideCustomView() {
		if (_customView == null) {
			return;
		}

		setFullscreen(false);

		FrameLayout decor = (FrameLayout) _activity.getWindow().getDecorView();
		decor.removeView(_fullscreenContainer);
		_fullscreenContainer = null;
		_customView = null;
		_customViewCallback.onCustomViewHidden();

		_activity.setRequestedOrientation(_originalOrientation);
	}

	private void setFullscreen(boolean enabled) {

		Window win = _activity.getWindow();
		WindowManager.LayoutParams winParams = win.getAttributes();
		final int bits = WindowManager.LayoutParams.FLAG_FULLSCREEN;
		if (enabled) {
			winParams.flags |= bits;
		} else {
			winParams.flags &= ~bits;
			if (_customView != null) {
				_customView.setSystemUiVisibility(View.SYSTEM_UI_FLAG_VISIBLE);
			}
		}
		win.setAttributes(winParams);
	}

	static class FullscreenHolder extends FrameLayout {

		public FullscreenHolder(Context ctx) {
			super(ctx);
			setBackgroundColor(ctx.getResources().getColor(android.R.color.black));
		}

		@Override
		public boolean onTouchEvent(MotionEvent evt) {
			return true;
		}
	}
}
