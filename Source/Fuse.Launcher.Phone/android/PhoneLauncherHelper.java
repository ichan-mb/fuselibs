package com.fuse.launcher.phone;

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
public final class PhoneLauncherHelper
{
    private PhoneLauncherHelper() { }

    /**
     * Returns true when the platform has an application registered for
     * DIAL intents.
     */
    public static boolean isCallAvailable(Activity activity)
    {
        if (activity == null)
            return false;

        try
        {
            Intent dial = new Intent(Intent.ACTION_DIAL, Uri.parse("tel:"));
            return activity.getPackageManager().resolveActivity(dial, 0) != null;
        }
        catch (Exception e)
        {
            return false;
        }
    }

    /**
     * Returns true when the platform has an application registered for
     * SMS compose intents.
     */
    public static boolean isSmsAvailable(Activity activity)
    {
        if (activity == null)
            return false;

        try
        {
            Intent sendto = new Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:"));
            return activity.getPackageManager().resolveActivity(sendto, 0) != null;
        }
        catch (Exception e)
        {
            return false;
        }
    }

    public static void launchCall(final Activity activity,
                                  final String uri,
                                  final boolean directCall,
                                  final String packageName,
                                  final Action onOpened,
                                  final Action_String onError)
    {
        if (activity == null)
        {
            onError.run("No active Android activity to launch the phone app.");
            return;
        }

        runOnUiThread(activity, new Runnable()
        {
            @Override
            public void run()
            {
                launchCallOnUiThread(activity, uri, directCall, packageName, onOpened, onError);
            }
        });
    }

    public static void launchSms(final Activity activity,
                                 final String uri,
                                 final String body,
                                 final String chooserTitle,
                                 final String packageName,
                                 final Action onOpened,
                                 final Action_String onError)
    {
        if (activity == null)
        {
            onError.run("No active Android activity to launch the messaging app.");
            return;
        }

        runOnUiThread(activity, new Runnable()
        {
            @Override
            public void run()
            {
                launchSmsOnUiThread(activity, uri, body, chooserTitle, packageName, onOpened, onError);
            }
        });
    }

    private static void launchCallOnUiThread(Activity activity, String uri,
                                             boolean directCall, String packageName,
                                             Action onOpened, Action_String onError)
    {
        if (activity.isFinishing() || activity.isDestroyed())
        {
            onError.run("No active Android activity to launch the phone app.");
            return;
        }

        boolean hasPackage = packageName != null && packageName.length() > 0;
        Intent target = new Intent(
            directCall ? Intent.ACTION_CALL : Intent.ACTION_DIAL,
            Uri.parse(uri));

        if (hasPackage)
            target.setPackage(packageName);

        try
        {
            activity.startActivity(target);
            onOpened.run();
        }
        catch (SecurityException e)
        {
            // The permission may have been revoked between the request and
            // the launch. Fall back to the dialer instead of failing silently.
            if (directCall && startDialer(activity, uri))
            {
                onOpened.run();
                return;
            }

            onError.run(directCall
                ? "Permission to place the call was denied."
                : "Could not launch the phone app.");
        }
        catch (ActivityNotFoundException e)
        {
            // The requested package is not installed or does not handle the
            // intent. Fall back to the default dialer.
            if (hasPackage)
            {
                target.setPackage(null);

                try
                {
                    activity.startActivity(target);
                    onOpened.run();
                    return;
                }
                catch (Exception ignored)
                {
                }
            }

            if (directCall && startDialer(activity, uri))
            {
                onOpened.run();
                return;
            }

            onError.run("No app is available to make phone calls.");
        }
        catch (Exception e)
        {
            onError.run(e.getMessage() != null
                ? e.getMessage()
                : "Could not launch the phone app.");
        }
    }

    private static void launchSmsOnUiThread(Activity activity, String uri, String body,
                                            String chooserTitle, String packageName,
                                            Action onOpened, Action_String onError)
    {
        if (activity.isFinishing() || activity.isDestroyed())
        {
            onError.run("No active Android activity to launch the messaging app.");
            return;
        }

        boolean hasPackage = packageName != null && packageName.length() > 0;
        Intent target = new Intent(Intent.ACTION_SENDTO, Uri.parse(uri));

        if (body != null)
        {
            // AOSP messaging apps read sms_body; some third-party clients
            // only look at EXTRA_TEXT.
            target.putExtra("sms_body", body);
            target.putExtra(Intent.EXTRA_TEXT, body);
        }

        if (hasPackage)
            target.setPackage(packageName);

        try
        {
            startSmsTarget(activity, target, chooserTitle, hasPackage);
            onOpened.run();
        }
        catch (ActivityNotFoundException e)
        {
            // The requested package is not installed. Fall back to the
            // default messaging application or chooser.
            if (hasPackage)
            {
                target.setPackage(null);

                try
                {
                    startSmsTarget(activity, target, chooserTitle, false);
                    onOpened.run();
                    return;
                }
                catch (Exception ignored)
                {
                }
            }

            onError.run("No app is available to send messages.");
        }
        catch (Exception e)
        {
            onError.run(e.getMessage() != null
                ? e.getMessage()
                : "Could not launch the messaging app.");
        }
    }

    private static void startSmsTarget(Activity activity, Intent target,
                                       String chooserTitle, boolean hasPackage)
    {
        if (hasPackage)
        {
            activity.startActivity(target);
            return;
        }

        if (chooserTitle != null && chooserTitle.length() > 0)
        {
            activity.startActivity(Intent.createChooser(target, chooserTitle));
            return;
        }

        activity.startActivity(target);
    }

    private static boolean startDialer(Activity activity, String uri)
    {
        try
        {
            activity.startActivity(new Intent(Intent.ACTION_DIAL, Uri.parse(uri)));
            return true;
        }
        catch (Exception e)
        {
            return false;
        }
    }

    private static void runOnUiThread(Activity activity, Runnable task)
    {
        if (Looper.myLooper() == Looper.getMainLooper())
            task.run();
        else
            activity.runOnUiThread(task);
    }
}
