package com.fuse.share;

import android.app.Activity;
import android.content.ClipData;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.webkit.MimeTypeMap;
import java.io.File;
import java.util.ArrayList;

/** Builds the Android ACTION_SEND / ACTION_SEND_MULTIPLE intent. */
final class ShareIntentBuilder
{
    private ShareIntentBuilder() { }

    static Intent create(Activity activity, String text, String url, String[] files,
                         String mimeType, String subject)
    {
        Intent target = new Intent();
        ArrayList<Uri> uris = new ArrayList<Uri>();
        String resolvedMimeType = mimeType;

        if (files != null && files.length > 0)
        {
            File shareDir = ShareFileStager.ensureDirectory(activity);

            for (String path : files)
                uris.add(ShareFileStager.toShareUri(activity, path, shareDir));

            if (resolvedMimeType == null || resolvedMimeType.length() == 0)
                resolvedMimeType = guessCommonMimeType(activity, files);

            setStreamAction(target, uris);
            addReadPermission(target, activity, uris);
        }
        else
        {
            target.setAction(Intent.ACTION_SEND);
        }

        applyText(target, text, url);
        applySubject(target, subject);

        if (resolvedMimeType == null || resolvedMimeType.length() == 0)
            resolvedMimeType = uris.isEmpty() ? "text/plain" : "application/octet-stream";

        target.setType(resolvedMimeType);
        return target;
    }

    private static void setStreamAction(Intent target, ArrayList<Uri> uris)
    {
        if (uris.size() == 1)
        {
            target.setAction(Intent.ACTION_SEND);
            target.putExtra(Intent.EXTRA_STREAM, uris.get(0));
        }
        else
        {
            target.setAction(Intent.ACTION_SEND_MULTIPLE);
            target.putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris);
        }
    }

    private static void addReadPermission(Intent target, Context context, ArrayList<Uri> uris)
    {
        ClipData clipData = ClipData.newUri(context.getContentResolver(), "shared files", uris.get(0));
        for (int i = 1; i < uris.size(); i++)
            clipData.addItem(new ClipData.Item(uris.get(i)));

        target.setClipData(clipData);
        target.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
    }

    private static void applyText(Intent target, String text, String url)
    {
        String extraText = text;

        if (extraText == null || extraText.length() == 0)
            extraText = url;
        else if (url != null && url.length() > 0)
            extraText = extraText + "\n" + url;

        if (extraText != null && extraText.length() > 0)
            target.putExtra(Intent.EXTRA_TEXT, extraText);
    }

    private static void applySubject(Intent target, String subject)
    {
        if (subject != null && subject.length() > 0)
            target.putExtra(Intent.EXTRA_SUBJECT, subject);
    }

    private static String guessCommonMimeType(Context context, String[] files)
    {
        String common = null;

        for (String path : files)
        {
            String mime = guessMimeType(context, path);

            if (common == null)
                common = mime;
            else if (!common.equals(mime))
                return "*/*";
        }

        return common != null ? common : "application/octet-stream";
    }

    private static String guessMimeType(Context context, String path)
    {
        Uri uri = Uri.parse(path);
        String scheme = uri.getScheme();

        if (scheme != null && scheme.equalsIgnoreCase("content"))
        {
            String mime = context.getContentResolver().getType(uri);
            if (mime != null)
                return mime;
        }

        int slash = path.lastIndexOf('/');
        int dot = path.lastIndexOf('.');

        if (dot > slash && dot < path.length() - 1)
        {
            String extension = path.substring(dot + 1).toLowerCase();
            String mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);
            if (mime != null)
                return mime;
        }

        return "application/octet-stream";
    }
}
