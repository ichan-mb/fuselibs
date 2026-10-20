package com.fuse.share;

import android.content.Context;
import android.net.Uri;
import androidx.core.content.FileProvider;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.UUID;

/**
 * Stages files in a dedicated cache/share directory so the FileProvider only
 * exposes that directory, and turns them into shareable content URIs.
 */
final class ShareFileStager
{
    private static final long MAX_AGE_MS = 24L * 60L * 60L * 1000L;

    private ShareFileStager() { }

    static File ensureDirectory(Context context)
    {
        File shareDir = new File(context.getCacheDir(), "share");

        if (!shareDir.exists() && !shareDir.mkdirs())
            throw new IllegalStateException("Could not create the share cache directory.");

        cleanup(shareDir);
        return shareDir;
    }

    static Uri toShareUri(Context context, String path, File shareDir)
    {
        Uri parsed = Uri.parse(path);
        String scheme = parsed.getScheme();

        if (scheme != null && scheme.equalsIgnoreCase("content"))
            return parsed;

        String filePath = path;
        if (scheme != null && scheme.equalsIgnoreCase("file"))
            filePath = parsed.getPath();

        File source = new File(filePath);
        if (!source.exists() || !source.isFile())
            throw new IllegalArgumentException("The file does not exist: " + path);

        File sharedFile = isInside(source, shareDir) ? source : copyToDirectory(source, shareDir);

        return FileProvider.getUriForFile(
            context,
            context.getPackageName() + ".share_file_provider",
            sharedFile);
    }

    private static boolean isInside(File file, File directory)
    {
        try
        {
            String filePath = file.getCanonicalPath();
            String directoryPath = directory.getCanonicalPath();

            return filePath.equals(directoryPath) ||
                filePath.startsWith(directoryPath + File.separator);
        }
        catch (IOException e)
        {
            return false;
        }
    }

    private static File copyToDirectory(File source, File shareDir)
    {
        String name = source.getName();
        int dot = name.lastIndexOf('.');
        String extension = dot > 0 ? name.substring(dot) : "";

        File destination = new File(
            shareDir,
            "share-" + UUID.randomUUID().toString() + extension);

        FileInputStream input = null;
        FileOutputStream output = null;

        try
        {
            input = new FileInputStream(source);
            output = new FileOutputStream(destination);

            byte[] buffer = new byte[16 * 1024];
            int read;
            while ((read = input.read(buffer)) != -1)
                output.write(buffer, 0, read);

            return destination;
        }
        catch (IOException e)
        {
            destination.delete();
            throw new IllegalStateException("Could not prepare the file for sharing: " + source.getPath(), e);
        }
        finally
        {
            if (input != null)
            {
                try { input.close(); } catch (IOException e) { }
            }

            if (output != null)
            {
                try { output.close(); } catch (IOException e) { }
            }
        }
    }

    private static void cleanup(File shareDir)
    {
        File[] files = shareDir.listFiles();
        if (files == null)
            return;

        long cutoff = System.currentTimeMillis() - MAX_AGE_MS;

        for (File file : files)
        {
            if (file.isFile() && file.lastModified() < cutoff)
                file.delete();
        }
    }
}
