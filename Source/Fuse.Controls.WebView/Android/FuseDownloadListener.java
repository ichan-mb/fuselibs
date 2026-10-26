package com.fuse.webview;

import android.app.DownloadManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.Uri;
import android.os.Environment;
import android.webkit.CookieManager;
import android.webkit.DownloadListener;
import android.webkit.URLUtil;
import com.foreign.Uno.Action_String_String;
import com.foreign.Uno.Action_String;
import java.io.File;
import java.io.UnsupportedEncodingException;
import java.net.URLDecoder;
import java.util.HashMap;
import java.util.Map;

public class FuseDownloadListener implements DownloadListener
{
	Action_String _beginDownload;
	Action_String_String _fileDownloaded;
	BroadcastReceiver _receiver;
	Context _context;
	DownloadManager _downloadManager;
	Map<Long, String[]> _pending = new HashMap<Long, String[]>();

	public FuseDownloadListener(Action_String beginDownload, Action_String_String fileDownloaded)
	{
		_beginDownload = beginDownload;
		_fileDownloaded = fileDownloaded;
		_context = com.fuse.Activity.getRootActivity().getApplicationContext();
		_downloadManager = (DownloadManager) _context.getSystemService(Context.DOWNLOAD_SERVICE);

		_receiver = new BroadcastReceiver() {
			@Override
			public void onReceive(Context context, Intent intent) {
				long id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1);
				String[] info = _pending.remove(id);
				if (info == null || _fileDownloaded == null)
					return;

				String url = info[0];
				String path = info[1];

				if (_downloadManager != null)
				{
					android.database.Cursor cursor = _downloadManager.query(
						new DownloadManager.Query().setFilterById(id));
					if (cursor != null)
					{
						try {
							if (!cursor.moveToFirst())
								return;

							int status = cursor.getInt(cursor.getColumnIndex(DownloadManager.COLUMN_STATUS));
							if (status != DownloadManager.STATUS_SUCCESSFUL)
								return;

							String localUri = cursor.getString(cursor.getColumnIndex(DownloadManager.COLUMN_LOCAL_URI));
							if (localUri != null && localUri.startsWith("file://"))
							{
								String localPath = Uri.parse(localUri).getPath();
								if (localPath != null)
									path = localPath;
							}
						} finally {
							cursor.close();
						}
					}
				}

				_fileDownloaded.run(url, path);
			}
		};
		_context.registerReceiver(_receiver, new IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE));
	}

	@Override
	public void onDownloadStart(final String url, String userAgent, String contentDisposition, String mimeType, long contentLength) {
		DownloadManager.Request request = new DownloadManager.Request(Uri.parse(url));
		if (contentDisposition != null) {
			try {
				contentDisposition = URLDecoder.decode(contentDisposition, "UTF-8");
			} catch (UnsupportedEncodingException e) {
				e.printStackTrace();
			}
		}

		request.setMimeType(mimeType);

		final String filename = makeUniqueFilename(URLUtil.guessFileName(url, contentDisposition, mimeType));

		String cookies = CookieManager.getInstance().getCookie(url);
		if (cookies != null)
			request.addRequestHeader("cookie", cookies);
		if (userAgent != null)
			request.addRequestHeader("User-Agent", userAgent);
		request.setDescription("Downloading file...");
		request.setTitle(filename);
		request.allowScanningByMediaScanner();
		request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
		try {
			request.setDestinationInExternalFilesDir(_context, Environment.DIRECTORY_DOWNLOADS, filename);
		} catch (Exception e) {
			return;
		}

		DownloadManager dm = _downloadManager != null
			? _downloadManager
			: (DownloadManager) _context.getSystemService(Context.DOWNLOAD_SERVICE);
		if (dm == null)
			return;

		long id;
		try {
			id = dm.enqueue(request);
		} catch (Exception e) {
			return;
		}

		File dir = _context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS);
		String path = dir != null ? new File(dir, filename).getAbsolutePath() : filename;
		_pending.put(id, new String[] { url, path });

		if (_beginDownload != null)
			_beginDownload.run(url);
	}

	private String makeUniqueFilename(String filename)
	{
		File dir = _context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS);
		if (dir == null || filename == null)
			return filename;

		File candidate = new File(dir, filename);
		if (!candidate.exists())
			return filename;

		String base = filename;
		String extension = "";
		int dot = filename.lastIndexOf('.');
		if (dot > 0) {
			base = filename.substring(0, dot);
			extension = filename.substring(dot);
		}

		int i = 1;
		do {
			filename = base + " (" + i + ")" + extension;
			candidate = new File(dir, filename);
			i++;
		} while (candidate.exists());

		return filename;
	}

	public void dispose() {
		if (_receiver != null && _context != null) {
			try {
				_context.unregisterReceiver(_receiver);
			} catch (IllegalArgumentException e) {
				// Already unregistered.
			}
			_receiver = null;
		}
		_pending.clear();
		_beginDownload = null;
		_fileDownloaded = null;
		_downloadManager = null;
	}
}
