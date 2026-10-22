package com.fuse.launcher.maps;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;
import android.os.Looper;
import com.foreign.Uno.Action;
import com.foreign.Uno.Action_String;

/**
 * Entry point used by the Uno foreign layer.
 */
public final class MapsLauncherHelper
{
    private MapsLauncherHelper() { }

    /**
     * Returns true when the platform has an application registered for
     * geo: intents.
     */
    public static boolean isAvailable(Activity activity)
    {
        if (activity == null)
            return false;

        try
        {
            Intent geo = new Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0"));
            return activity.getPackageManager().resolveActivity(geo, 0) != null;
        }
        catch (Exception e)
        {
            return false;
        }
    }

    public static void launch(final Activity activity,
                              final String uri,
                              final String webFallbackUri,
                              final String packageName,
                              final Action onOpened,
                              final Action_String onError)
    {
        if (activity == null)
        {
            onError.run("No active Android activity to launch the map app.");
            return;
        }

        Runnable task = new Runnable()
        {
            @Override
            public void run()
            {
                launchOnUiThread(activity, uri, webFallbackUri, packageName, onOpened, onError);
            }
        };

        if (Looper.myLooper() == Looper.getMainLooper())
            task.run();
        else
            activity.runOnUiThread(task);
    }

    private static void launchOnUiThread(Activity activity, String uri,
                                         String webFallbackUri, String packageName,
                                         Action onOpened, Action_String onError)
    {
        if (activity.isFinishing() || activity.isDestroyed())
        {
            onError.run("No active Android activity to launch the map app.");
            return;
        }

        try
        {
            Intent target = new Intent(Intent.ACTION_VIEW, Uri.parse(uri));

            if (packageName != null && packageName.length() > 0)
                target.setPackage(packageName);

            try
            {
                activity.startActivity(target);
            }
            catch (ActivityNotFoundException e)
            {
                if (packageName == null || packageName.length() == 0)
                    throw e;

                // The requested package is not installed. Fall back to the
                // default map application.
                target.setPackage(null);
                activity.startActivity(target);
            }

            onOpened.run();
        }
        catch (ActivityNotFoundException e)
        {
            if (openWebFallback(activity, webFallbackUri))
            {
                onOpened.run();
                return;
            }

            onError.run("No app is available to open maps.");
        }
        catch (Exception e)
        {
            onError.run(e.getMessage() != null
                ? e.getMessage()
                : "Could not launch the map app.");
        }
    }

    private static boolean openWebFallback(Activity activity, String webFallbackUri)
    {
        if (webFallbackUri == null || webFallbackUri.length() == 0)
            return false;

        try
        {
            activity.startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(webFallbackUri)));
            return true;
        }
        catch (Exception e)
        {
            return false;
        }
    }
}
