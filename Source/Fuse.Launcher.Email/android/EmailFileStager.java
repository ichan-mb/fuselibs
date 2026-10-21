package com.fuse.launcher.email;

import android.content.Context;
import android.net.Uri;
import androidx.core.content.FileProvider;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.UUID;

/**
 * Stages attachment files in a dedicated cache/email directory so the
 * FileProvider only exposes that directory, and turns them into URIs that the
 * receiving email app can read.
 */
final class EmailFileStager
{
    private static final long MAX_AGE_MS = 24L * 60L * 60L * 1000L;

    private final Context _context;
    private final File _directory;

    EmailFileStager(Context context)
    {
        _context = context;
        _directory = ensureDirectory(context);
    }

    Uri toUri(String path)
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

        File staged = isInside(source, _directory) ? source : copyToDirectory(source);

        return FileProvider.getUriForFile(
            _context,
            _context.getPackageName() + ".email_file_provider",
            staged);
    }

    private static File ensureDirectory(Context context)
    {
        File directory = new File(context.getCacheDir(), "email");

        if (!directory.exists() && !directory.mkdirs())
            throw new IllegalStateException("Could not create the email cache directory.");

        cleanup(directory);
        return directory;
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

    private File copyToDirectory(File source)
    {
        String name = source.getName();
        int dot = name.lastIndexOf('.');
        String extension = dot > 0 ? name.substring(dot) : "";

        File destination = new File(
            _directory,
            "email-" + UUID.randomUUID().toString() + extension);

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
            throw new IllegalStateException(
                "Could not prepare the file for email: " + source.getPath(), e);
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

    private static void cleanup(File directory)
    {
        File[] files = directory.listFiles();
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
