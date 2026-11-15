package com.fuse.controls.cameraview;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.media.MediaScannerConnection;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.UUID;

/**
 * Storage helpers for captured photos and videos.
 *
 * Captures are written to the app specific external files directory. This
 * directory works without storage permissions on every supported Android
 * version and is not cleared by the system like the cache directory.
 *
 * Copying to the user visible gallery is done through MediaStore on API 29+
 * and through the public media directories on older versions.
 */
public final class CameraStorage {
    private static final String GALLERY_FOLDER = "FuseCamera";

    private CameraStorage() {}

    private static Context context() {
        return com.fuse.Activity.getRootActivity();
    }

    private static File ensureDir(File dir) {
        if (dir == null)
            throw new IllegalStateException("Media directory is not available");

        if (!dir.exists() && !dir.mkdirs() && !dir.exists())
            throw new IllegalStateException("Failed to create media directory: " + dir);

        return dir;
    }

    private static File appMediaDir(String type) {
        Context context = context();
        File dir = context.getExternalFilesDir(type);
        if (dir == null)
            dir = new File(context.getFilesDir(), type);
        return ensureDir(dir);
    }

    public static String createImageFilePath(String extension) {
        File dir = appMediaDir(Environment.DIRECTORY_PICTURES);
        String ext = (extension == null || extension.isEmpty()) ? "jpg" : extension;
        return new File(dir, "IMG_" + UUID.randomUUID().toString() + "." + ext).getAbsolutePath();
    }

    public static String createVideoFilePath() {
        File dir = appMediaDir(Environment.DIRECTORY_MOVIES);
        return new File(dir, "VID_" + UUID.randomUUID().toString() + ".mp4").getAbsolutePath();
    }

    public static boolean saveImageToGallery(String filePath) {
        return saveToGallery(
            filePath,
            android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            Environment.DIRECTORY_PICTURES,
            "image/jpeg");
    }

    public static boolean saveImageBytesToGallery(byte[] data) {
        if (data == null)
            return false;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContentResolver resolver = context().getContentResolver();
            ContentValues values = new ContentValues();
            values.put("display_name", "IMG_" + UUID.randomUUID().toString() + ".jpg");
            values.put("mime_type", "image/jpeg");
            values.put("relative_path", Environment.DIRECTORY_PICTURES + File.separator + GALLERY_FOLDER);
            values.put("is_pending", 1);

            Uri uri = resolver.insert(android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
            if (uri == null)
                return false;

            try (OutputStream out = resolver.openOutputStream(uri)) {
                if (out == null) {
                    resolver.delete(uri, null, null);
                    return false;
                }
                out.write(data);
            } catch (IOException e) {
                resolver.delete(uri, null, null);
                return false;
            }

            values.clear();
            values.put("is_pending", 0);
            resolver.update(uri, values, null, null);
            return true;
        }

        try {
            File publicDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES);
            if (publicDir == null)
                return false;

            File galleryDir = ensureDir(new File(publicDir, GALLERY_FOLDER));
            File destination = new File(galleryDir, "IMG_" + UUID.randomUUID().toString() + ".jpg");

            try (OutputStream out = new FileOutputStream(destination)) {
                out.write(data);
            }

            MediaScannerConnection.scanFile(
                context(),
                new String[] { destination.getAbsolutePath() },
                null,
                null);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    public static boolean saveVideoToGallery(String filePath) {
        return saveToGallery(
            filePath,
            android.provider.MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
            Environment.DIRECTORY_MOVIES,
            "video/mp4");
    }

    private static boolean saveToGallery(String filePath, Uri collection, String relativePath, String mimeType) {
        if (filePath == null)
            return false;

        File source = new File(filePath);
        if (!source.exists())
            return false;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContentResolver resolver = context().getContentResolver();
            ContentValues values = new ContentValues();
            values.put("display_name", source.getName());
            values.put("mime_type", mimeType);
            values.put("relative_path", relativePath + File.separator + GALLERY_FOLDER);
            values.put("is_pending", 1);

            Uri uri = resolver.insert(collection, values);
            if (uri == null)
                return false;

            try (InputStream in = new FileInputStream(source);
                 OutputStream out = resolver.openOutputStream(uri)) {
                if (out == null) {
                    resolver.delete(uri, null, null);
                    return false;
                }
                copy(in, out);
            } catch (IOException e) {
                resolver.delete(uri, null, null);
                return false;
            }

            values.clear();
            values.put("is_pending", 0);
            resolver.update(uri, values, null, null);
            return true;
        }

        try {
            File publicDir = Environment.getExternalStoragePublicDirectory(relativePath);
            if (publicDir == null)
                return false;

            File galleryDir = ensureDir(new File(publicDir, GALLERY_FOLDER));
            File destination = new File(galleryDir, source.getName());

            try (InputStream in = new FileInputStream(source);
                 OutputStream out = new FileOutputStream(destination)) {
                copy(in, out);
            } catch (IOException e) {
                return false;
            }

            MediaScannerConnection.scanFile(
                context(),
                new String[] { destination.getAbsolutePath() },
                null,
                null);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    private static void copy(InputStream in, OutputStream out) throws IOException {
        byte[] buffer = new byte[8192];
        int read;
        while ((read = in.read(buffer)) != -1)
            out.write(buffer, 0, read);
        out.flush();
    }
}
