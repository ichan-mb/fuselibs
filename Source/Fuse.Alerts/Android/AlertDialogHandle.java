package com.fuse.alerts;

import android.app.AlertDialog;

/**
 * Tracks the currently visible AlertDialog so the JS API can dismiss it.
 */
public final class AlertDialogHandle
{
	private static AlertDialog _current;

	private AlertDialogHandle()
	{
	}

	public static void setCurrent(AlertDialog dialog)
	{
		_current = dialog;
	}

	public static void clearCurrent()
	{
		_current = null;
	}

	public static void dismissCurrent()
	{
		AlertDialog dialog = _current;
		_current = null;
		if (dialog != null)
			dialog.dismiss();
	}
}
