package com.fuse.launcher.email;

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
public final class EmailLauncherHelper
{
    private EmailLauncherHelper() { }

    /**
     * Returns true when an email application is registered for mailto: or for
     * an email sharing intent.
     */
    public static boolean isAvailable(Activity activity)
    {
        if (activity == null)
            return false;

        try
        {
            Intent mailto = new Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:"));
            if (activity.getPackageManager().resolveActivity(mailto, 0) != null)
                return true;

            Intent send = new Intent(Intent.ACTION_SEND);
            send.setType("message/rfc822");
            return activity.getPackageManager().resolveActivity(send, 0) != null;
        }
        catch (Exception e)
        {
            return false;
        }
    }

    public static void launch(final Activity activity,
                              final String mailtoUri,
                              final String[] to,
                              final String[] cc,
                              final String[] bcc,
                              final String subject,
                              final String body,
                              final String htmlBody,
                              final String[] attachments,
                              final String chooserTitle,
                              final String packageName,
                              final Action onOpened,
                              final Action_String onError)
    {
        if (activity == null)
        {
            onError.run("No active Android activity to launch the email app.");
            return;
        }

        Runnable task = new Runnable()
        {
            @Override
            public void run()
            {
                launchOnUiThread(activity, mailtoUri, to, cc, bcc, subject, body,
                    htmlBody, attachments, chooserTitle, packageName, onOpened, onError);
            }
        };

        if (Looper.myLooper() == Looper.getMainLooper())
            task.run();
        else
            activity.runOnUiThread(task);
    }

    private static void launchOnUiThread(Activity activity, String mailtoUri,
                                         String[] to, String[] cc, String[] bcc,
                                         String subject, String body, String htmlBody,
                                         String[] attachments, String chooserTitle,
                                         String packageName,
                                         Action onOpened, Action_String onError)
    {
        if (activity.isFinishing() || activity.isDestroyed())
        {
            onError.run("No active Android activity to launch the email app.");
            return;
        }

        try
        {
            Intent target = EmailIntentBuilder.create(activity, mailtoUri, to, cc, bcc,
                subject, body, htmlBody, attachments);

            try
            {
                startTarget(activity, target, chooserTitle, packageName);
            }
            catch (ActivityNotFoundException e)
            {
                				if (packageName == null || packageName.length() == 0)
                					throw e;

                				// The requested package is not installed. Fall back to the
                				// regular chooser so the user can still send the message.
                				target.setPackage(null);
                				startTarget(activity, target, chooserTitle, null);
            }

            onOpened.run();
        }
        catch (ActivityNotFoundException e)
        {
            onError.run("No app is available to compose email.");
        }
        catch (Exception e)
        {
            onError.run(e.getMessage() != null
                ? e.getMessage()
                : "Could not launch the email app.");
        }
    }

    private static void startTarget(Activity activity, Intent target,
                                    String chooserTitle, String packageName)
    {
        if (packageName != null && packageName.length() > 0)
        {
            target.setPackage(packageName);
            activity.startActivity(target);
            return;
        }

        if (Intent.ACTION_SENDTO.equals(target.getAction()))
        {
            activity.startActivity(target);
            return;
        }

        CharSequence title = chooserTitle != null && chooserTitle.length() > 0
            ? chooserTitle
            : null;

        activity.startActivity(Intent.createChooser(target, title));
    }
}
