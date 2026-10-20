package com.fuse.share;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.res.Configuration;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import com.foreign.Uno.Action;
import com.foreign.Uno.Action_String;

/**
 * Presents the chooser and reports the selected target or cancellation back to
 * the waiting promise. All work happens on the main thread.
 */
final class ShareSession
{
    private final Activity _activity;
    private final String _chooserTitle;
    private final int _requestCode;
    private final Action_String _onChosen;
    private final Action _onCancelled;
    private final Action_String _onError;
    private final String _action;

    private BroadcastReceiver _receiver;
    private com.fuse.Activity.ResultListener _listener;
    private com.fuse.Activity.ActivityListener _lifecycleListener;
    private boolean _settled;

    ShareSession(Activity activity, String chooserTitle, int requestCode,
                 Action_String onChosen, Action onCancelled, Action_String onError)
    {
        _activity = activity;
        _chooserTitle = chooserTitle;
        _requestCode = requestCode;
        _onChosen = onChosen;
        _onCancelled = onCancelled;
        _onError = onError;
        _action = activity.getPackageName() + ".fuse.share.result." + _requestCode;
    }

    void start(final Intent target)
    {
        try
        {
            if (_activity == null || _activity.isFinishing() || _activity.isDestroyed())
            {
                fail("No active Android activity to show the share dialog.");
                return;
            }

            _receiver = new BroadcastReceiver()
            {
                @Override
                public void onReceive(Context context, Intent intent)
                {
                    finish(true, chosenTarget(intent));
                }
            };

            IntentFilter filter = new IntentFilter(_action);
            if (Build.VERSION.SDK_INT >= 33)
                _activity.registerReceiver(_receiver, filter, Context.RECEIVER_NOT_EXPORTED);
            else
                _activity.registerReceiver(_receiver, filter);

            subscribeToLifecycle();

            Intent chooser = createChooser(target);

            _listener = new com.fuse.Activity.ResultListener()
            {
                @Override
                public boolean onResult(int requestCode, final int resultCode, Intent data)
                {
                    if (requestCode != _requestCode)
                        return false;

                    // The chooser can return before the selection broadcast is delivered.
                    new Handler(Looper.getMainLooper()).postDelayed(new Runnable()
                    {
                        @Override
                        public void run()
                        {
                            if (_settled)
                                return;

                            if (resultCode == Activity.RESULT_OK)
                                finish(true, null);
                            else
                                finish(false, null);
                        }
                    }, 1000);

                    return true;
                }
            };

            com.fuse.Activity.subscribeToResults(_listener);
            _activity.startActivityForResult(chooser, _requestCode);
        }
        catch (android.content.ActivityNotFoundException e)
        {
            fail("No app is available to handle this share.");
        }
        catch (Exception e)
        {
            fail(e.getMessage() != null ? e.getMessage() : "Could not open the share dialog.");
        }
    }

    private void subscribeToLifecycle()
    {
        _lifecycleListener = new com.fuse.Activity.ActivityListener()
        {
            @Override public void onPause() { }
            @Override public void onResume() { }
            @Override public void onStart() { }
            @Override public void onStop() { }
            @Override public void onWindowFocusChanged(boolean hasFocus) { }
            @Override public void onConfigurationChanged(Configuration config) { }

            @Override
            public void onDestroy()
            {
                // Activity iterates its listener list while dispatching, so
                // unsubscribe on the next main-loop turn.
                new Handler(Looper.getMainLooper()).post(new Runnable()
                {
                    @Override
                    public void run()
                    {
                        finish(false, null);
                    }
                });
            }
        };
        com.fuse.Activity.SubscribeToLifecycleChange(_lifecycleListener);
    }

    private static String chosenTarget(Intent intent)
    {
        Intent chosen = (Intent)intent.getParcelableExtra(Intent.EXTRA_INTENT);
        if (chosen == null || chosen.getComponent() == null)
            return null;

        return chosen.getComponent().flattenToShortString();
    }

    private Intent createChooser(Intent target)
    {
        CharSequence title = _chooserTitle != null && _chooserTitle.length() > 0 ? _chooserTitle : null;

        if (Build.VERSION.SDK_INT >= 22)
        {
            int flags = PendingIntent.FLAG_UPDATE_CURRENT;
            if (Build.VERSION.SDK_INT >= 31)
                flags |= PendingIntent.FLAG_MUTABLE;

            PendingIntent pending = PendingIntent.getBroadcast(
                _activity,
                _requestCode,
                new Intent(_action).setPackage(_activity.getPackageName()),
                flags);

            return Intent.createChooser(target, title, pending.getIntentSender());
        }

        return Intent.createChooser(target, title);
    }

    private synchronized void finish(boolean completed, String activityType)
    {
        if (_settled)
            return;

        _settled = true;
        cleanup();

        if (completed)
            _onChosen.run(activityType != null ? activityType : "");
        else
            _onCancelled.run();
    }

    private synchronized void fail(String message)
    {
        if (_settled)
            return;

        _settled = true;
        cleanup();
        _onError.run(message);
    }

    private void cleanup()
    {
        if (_receiver != null)
        {
            try
            {
                _activity.unregisterReceiver(_receiver);
            }
            catch (Exception e) { }
            _receiver = null;
        }

        if (_listener != null)
        {
            com.fuse.Activity.unsubscribeFromResults(_listener);
            _listener = null;
        }

        if (_lifecycleListener != null)
        {
            com.fuse.Activity.UnsubscribeFromLifecycleChange(_lifecycleListener);
            _lifecycleListener = null;
        }
    }
}
