package com.fuse.share;

import android.app.Activity;
import android.content.Intent;
import android.os.Handler;
import android.os.Looper;
import com.foreign.Uno.Action;
import com.foreign.Uno.Action_String;

/**
 * Entry point used by the Uno foreign layer.
 *
 * Intent building and file staging happen on a worker thread; the chooser and
 * activity lifecycle work happen on the main thread.
 */
public final class AndroidShareHelper
{
    private AndroidShareHelper() { }

    public static void share(final Activity activity,
                             final String text, final String url, final String[] files,
                             final String mimeType, final String subject, final String chooserTitle,
                             final int requestCode,
                             final Action_String onChosen, final Action onCancelled, final Action_String onError)
    {
        new Thread(new Runnable()
        {
            @Override
            public void run()
            {
                prepareAndShow(activity, text, url, files, mimeType, subject,
                    chooserTitle, requestCode, onChosen, onCancelled, onError);
            }
        }, "FuseSharePrepare").start();
    }

    private static void prepareAndShow(final Activity activity,
                                       String text, String url, String[] files,
                                       String mimeType, String subject, final String chooserTitle,
                                       final int requestCode,
                                       final Action_String onChosen, final Action onCancelled,
                                       final Action_String onError)
    {
        try
        {
            final Intent target = ShareIntentBuilder.create(activity, text, url, files, mimeType, subject);

            new Handler(Looper.getMainLooper()).post(new Runnable()
            {
                @Override
                public void run()
                {
                    new ShareSession(
                        activity, chooserTitle, requestCode,
                        onChosen, onCancelled, onError).start(target);
                }
            });
        }
        catch (Exception e)
        {
            onError.run(e.getMessage() != null ? e.getMessage() : "Could not prepare the share.");
        }
    }
}
