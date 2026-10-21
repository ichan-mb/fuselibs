package com.fuse.launcher.email;

import android.app.Activity;
import android.content.ClipData;
import android.content.Intent;
import android.net.Uri;
import java.util.ArrayList;

/**
 * Builds the Android intent used to compose an email.
 *
 * ACTION_SENDTO is used for plain messages because it only matches email
 * applications. Attachments and HTML require ACTION_SEND / ACTION_SEND_MULTIPLE,
 * which is restricted to email targets with the message/rfc822 MIME type.
 */
final class EmailIntentBuilder
{
    private EmailIntentBuilder() { }

    static Intent create(Activity activity, String mailtoUri,
                         String[] to, String[] cc, String[] bcc,
                         String subject, String body, String htmlBody,
                         String[] attachments)
    {
        boolean hasAttachments = attachments != null && attachments.length > 0;
        boolean hasHtml = htmlBody != null && htmlBody.length() > 0;
        Intent target;

        if (hasAttachments || hasHtml)
        {
            target = new Intent(hasAttachments && attachments.length > 1
                ? Intent.ACTION_SEND_MULTIPLE
                : Intent.ACTION_SEND);
            target.setType("message/rfc822");
            applyExtras(target, to, cc, bcc, subject, body, htmlBody);

            if (hasAttachments)
                applyAttachments(activity, target, attachments);
        }
        else
        {
            target = new Intent(Intent.ACTION_SENDTO, Uri.parse(mailtoUri));
            applyExtras(target, to, cc, bcc, subject, body, htmlBody);
        }

        return target;
    }

    private static void applyExtras(Intent target,
                                    String[] to, String[] cc, String[] bcc,
                                    String subject, String body, String htmlBody)
    {
        if (to != null && to.length > 0)
            target.putExtra(Intent.EXTRA_EMAIL, to);
        if (cc != null && cc.length > 0)
            target.putExtra(Intent.EXTRA_CC, cc);
        if (bcc != null && bcc.length > 0)
            target.putExtra(Intent.EXTRA_BCC, bcc);
        if (subject != null && subject.length() > 0)
            target.putExtra(Intent.EXTRA_SUBJECT, subject);
        if (body != null && body.length() > 0)
            target.putExtra(Intent.EXTRA_TEXT, body);
        if (htmlBody != null && htmlBody.length() > 0)
            target.putExtra(Intent.EXTRA_HTML_TEXT, htmlBody);
    }

    private static void applyAttachments(Activity activity, Intent target, String[] attachments)
    {
        EmailFileStager stager = new EmailFileStager(activity);
        ArrayList<Uri> uris = new ArrayList<Uri>();

        for (String path : attachments)
            uris.add(stager.toUri(path));

        if (uris.size() == 1)
        {
            target.putExtra(Intent.EXTRA_STREAM, uris.get(0));
        }
        else
        {
            target.putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris);
        }

        ClipData clipData = ClipData.newUri(
            activity.getContentResolver(), "email attachments", uris.get(0));

        for (int i = 1; i < uris.size(); i++)
            clipData.addItem(new ClipData.Item(uris.get(i)));

        target.setClipData(clipData);
        target.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
    }
}
