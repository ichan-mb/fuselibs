package com.fuse.launcher.interapp;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;
import android.os.Looper;
import android.provider.Settings;
import com.foreign.Uno.Action;
import com.foreign.Uno.Action_String;

/**
 * Entry point used by the Uno foreign layer.
 *
 * Availability checks are subject to Android 11 package visibility. Apps that
 * query custom schemes or packages must declare them in the manifest:
 *
 *   <queries>
 *     <intent>
 *       <action android:name="android.intent.action.VIEW" />
 *       <data android:scheme="myapp" />
 *     </intent>
 *     <package android:name="com.example.app" />
 *   </queries>
 *
 * The `Android.Queries.Schemes` and `Android.Queries.Packages` project
 * properties emit this block for library and application projects.
 */
public final class InterAppLauncherHelper
{
    private InterAppLauncherHelper() { }

    /**
     * Returns true when an application is registered for the given URI.
     */
    public static boolean isUriAvailable(Activity activity, String uri)
    {
        if (activity == null || uri == null || uri.length() == 0)
            return false;

        try
        {
            Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(uri));
            return intent.resolveActivity(activity.getPackageManager()) != null;
        }
        catch (Exception e)
        {
            return false;
        }
    }

    /**
     * Returns true when the package has a launchable activity and is visible
     * to this application.
     */
    public static boolean isAppAvailable(Activity activity, String applicationId)
    {
        if (activity == null || applicationId == null || applicationId.length() == 0)
            return false;

        try
        {
            return activity.getPackageManager().getLaunchIntentForPackage(applicationId) != null;
        }
        catch (Exception e)
        {
            return false;
        }
    }

    /**
     * Opens a URI with ACTION_VIEW.
     *
     * When packageName is set and that package does not handle the URI, the
     * launch is retried without the package restriction so the default
     * application can handle it.
     */
    public static void launchUri(final Activity activity,
                                 final String uri,
                                 final String packageName,
                                 final String className,
                                 final String mimeType,
                                 final String[] flags,
                                 final String[] extras,
                                 final Action onOpened,
                                 final Action_String onError)
    {
        if (activity == null)
        {
            onError.run("No active Android activity to launch the app.");
            return;
        }

        runOnUiThread(activity, new Runnable()
        {
            @Override
            public void run()
            {
                launchUriOnUiThread(activity, uri, packageName, className, mimeType,
                    flags, extras, onOpened, onError);
            }
        });
    }

    /**
     * Launches the main activity of an installed package.
     */
    public static void launchApp(final Activity activity,
                                 final String applicationId,
                                 final String[] flags,
                                 final String[] extras,
                                 final Action onOpened,
                                 final Action_String onError)
    {
        if (activity == null)
        {
            onError.run("No active Android activity to launch the app.");
            return;
        }

        runOnUiThread(activity, new Runnable()
        {
            @Override
            public void run()
            {
                launchAppOnUiThread(activity, applicationId, flags, extras,
                    onOpened, onError);
            }
        });
    }

    /**
     * Opens the system settings page for this application.
     */
    public static void openSettings(final Activity activity,
                                    final Action onOpened,
                                    final Action_String onError)
    {
        if (activity == null)
        {
            onError.run("No active Android activity to open settings.");
            return;
        }

        runOnUiThread(activity, new Runnable()
        {
            @Override
            public void run()
            {
                if (activity.isFinishing() || activity.isDestroyed())
                {
                    onError.run("No active Android activity to open settings.");
                    return;
                }

                try
                {
                    Intent intent = new Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:" + activity.getPackageName()));

                    activity.startActivity(intent);
                    onOpened.run();
                }
                catch (Exception e)
                {
                    onError.run(errorMessage(e, "Could not open app settings."));
                }
            }
        });
    }

    private static void launchUriOnUiThread(Activity activity, String uri,
                                            String packageName, String className,
                                            String mimeType, String[] flags,
                                            String[] extras,
                                            Action onOpened, Action_String onError)
    {
        if (activity.isFinishing() || activity.isDestroyed())
        {
            onError.run("No active Android activity to launch the app.");
            return;
        }

        if (uri == null || uri.length() == 0)
        {
            onError.run("A URI is required.");
            return;
        }

        boolean hasPackage = packageName != null && packageName.length() > 0;
        Intent target;

        if (mimeType != null && mimeType.length() > 0)
        {
            target = new Intent(Intent.ACTION_VIEW);
            target.setDataAndType(Uri.parse(uri), mimeType);
        }
        else
        {
            target = new Intent(Intent.ACTION_VIEW, Uri.parse(uri));
        }

        if (hasPackage)
        {
            if (className != null && className.length() > 0)
                target.setClassName(packageName, className);
            else
                target.setPackage(packageName);
        }

        applyFlags(target, flags);
        applyExtras(target, extras);

        try
        {
            activity.startActivity(target);
            onOpened.run();
        }
        catch (ActivityNotFoundException e)
        {
            if (hasPackage)
            {
                // The requested package is not installed or does not handle
                // the URI. Fall back to the default application.
                target.setPackage(null);
                target.setComponent(null);

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

            onError.run("No app is available to handle this request.");
        }
        catch (Exception e)
        {
            onError.run(errorMessage(e, "Could not launch the app."));
        }
    }

    private static void launchAppOnUiThread(Activity activity, String applicationId,
                                            String[] flags, String[] extras,
                                            Action onOpened, Action_String onError)
    {
        if (activity.isFinishing() || activity.isDestroyed())
        {
            onError.run("No active Android activity to launch the app.");
            return;
        }

        if (applicationId == null || applicationId.length() == 0)
        {
            onError.run("An application id is required.");
            return;
        }

        try
        {
            Intent target = activity.getPackageManager().getLaunchIntentForPackage(applicationId);
            if (target == null)
            {
                onError.run("No app is installed for " + applicationId + ".");
                return;
            }

            applyFlags(target, flags);
            applyExtras(target, extras);

            activity.startActivity(target);
            onOpened.run();
        }
        catch (ActivityNotFoundException e)
        {
            onError.run("No app is installed for " + applicationId + ".");
        }
        catch (Exception e)
        {
            onError.run(errorMessage(e, "Could not launch " + applicationId + "."));
        }
    }

    private static void applyFlags(Intent intent, String[] flags)
    {
        if (flags == null)
            return;

        for (int i = 0; i < flags.length; i++)
        {
            int value = flagValue(flags[i]);
            if (value != 0)
                intent.addFlags(value);
        }
    }

    private static int flagValue(String flag)
    {
        if (flag == null)
            return 0;

        switch (flag)
        {
            case "newTask": return Intent.FLAG_ACTIVITY_NEW_TASK;
            case "clearTop": return Intent.FLAG_ACTIVITY_CLEAR_TOP;
            case "singleTop": return Intent.FLAG_ACTIVITY_SINGLE_TOP;
            case "clearTask": return Intent.FLAG_ACTIVITY_CLEAR_TASK;
            case "noHistory": return Intent.FLAG_ACTIVITY_NO_HISTORY;
            case "excludeFromRecents": return Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS;
            case "reorderToFront": return Intent.FLAG_ACTIVITY_REORDER_TO_FRONT;
            case "launchAdjacent": return Intent.FLAG_ACTIVITY_LAUNCH_ADJACENT;
            case "multipleTask": return Intent.FLAG_ACTIVITY_MULTIPLE_TASK;
            case "noAnimation": return Intent.FLAG_ACTIVITY_NO_ANIMATION;
            case "retainInRecents": return Intent.FLAG_ACTIVITY_RETAIN_IN_RECENTS;
            case "newDocument": return Intent.FLAG_ACTIVITY_NEW_DOCUMENT;
            case "taskOnHome": return Intent.FLAG_ACTIVITY_TASK_ON_HOME;
            case "resetTaskIfNeeded": return Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED;
            case "noUserAction": return Intent.FLAG_ACTIVITY_NO_USER_ACTION;
            default: return 0;
        }
    }

    private static void applyExtras(Intent intent, String[] extras)
    {
        if (extras == null)
            return;

        for (int i = 0; i + 1 < extras.length; i += 2)
            intent.putExtra(extras[i], extras[i + 1]);
    }

    private static String errorMessage(Exception e, String fallback)
    {
        return e.getMessage() != null ? e.getMessage() : fallback;
    }

    private static void runOnUiThread(Activity activity, Runnable task)
    {
        if (Looper.myLooper() == Looper.getMainLooper())
            task.run();
        else
            activity.runOnUiThread(task);
    }
}
