package com.fuse.mediapicker;

import android.Manifest;
import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.hardware.camera2.CameraCharacteristics;
import android.net.Uri;
import android.os.Build;
import android.provider.MediaStore;
import androidx.core.app.ActivityCompat;
import androidx.core.content.FileProvider;
import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.json.JSONArray;

import com.foreign.Uno.Action_String;

enum CameraDevice {
	REAR,

	FRONT
}

public class MediaPickerImpl {

	static final int REQUEST_CODE_CHOOSE_IMAGE_FROM_GALLERY = 2342;
	static final int REQUEST_CODE_TAKE_IMAGE_WITH_CAMERA = 2343;
	static final int REQUEST_CAMERA_IMAGE_PERMISSION = 2345;
	static final int REQUEST_CODE_CHOOSE_MULTI_IMAGE_FROM_GALLERY = 2346;
	static final int REQUEST_CODE_CHOOSE_VIDEO_FROM_GALLERY = 2352;
	static final int REQUEST_CODE_TAKE_VIDEO_WITH_CAMERA = 2353;
	static final int REQUEST_CODE_CHOOSE_MULTI_VIDEO_FROM_GALLERY = 2354;
	static final int REQUEST_CAMERA_VIDEO_PERMISSION = 2355;

	// Avoid a hard dependency on a specific compile SDK for the Android photo picker.
	private static final String ACTION_PICK_IMAGES = "android.provider.action.PICK_IMAGES";
	private static final String EXTRA_PICK_IMAGES_MAX = "android.provider.extra.PICK_IMAGES_MAX";

	private final ImageResizer imageResizer;
	private final PermissionManager permissionManager;
	private final FileUriResolver fileUriResolver;
	private final FileUtils fileUtils;
	private CameraDevice cameraDevice;
	final String fileProviderName;
	final File externalFilesDirectory;

	interface PermissionManager {
		boolean isPermissionGranted(String permissionName);

		void askForPermission(String permissionName, int requestCode);

		boolean needRequestCameraPermission();
	}

	interface FileUriResolver {
		Uri resolveFileProviderUriForFile(String fileProviderName, File imageFile);
	}

	private String pendingCameraMediaPath;
	private Action_String result;
	private Action_String reject;
	private Map<String, Object> arguments;
	private static MediaPickerImpl instance;

	public static MediaPickerImpl getInstance() {
		if (instance != null)
			return instance;

		final File cacheDirectory = com.fuse.Activity.getRootActivity().getCacheDir();
		final ExifDataCopier exifDataCopier = new ExifDataCopier();
		final ImageResizer imageResizer = new ImageResizer(cacheDirectory, exifDataCopier);
		instance = new MediaPickerImpl(cacheDirectory, imageResizer);
		return instance;
	}

	private MediaPickerImpl(
			final File externalFilesDirectory,
			final ImageResizer imageResizer) {
		this(
				externalFilesDirectory,
				imageResizer,
				new PermissionManager() {
					@Override
					public boolean isPermissionGranted(String permissionName) {
						return ActivityCompat.checkSelfPermission(com.fuse.Activity.getRootActivity(), permissionName)
								== PackageManager.PERMISSION_GRANTED;
					}

					@Override
					public void askForPermission(String permissionName, int requestCode) {
						ActivityCompat.requestPermissions(com.fuse.Activity.getRootActivity(), new String[] {permissionName}, requestCode);
					}

					@Override
					public boolean needRequestCameraPermission() {
						return MediaPickerUtils.needRequestCameraPermission(com.fuse.Activity.getRootActivity());
					}
				},
				new FileUriResolver() {
					@Override
					public Uri resolveFileProviderUriForFile(String fileProviderName, File file) {
						return FileProvider.getUriForFile(com.fuse.Activity.getRootActivity(), fileProviderName, file);
					}
				},
				new FileUtils());
	}

	private MediaPickerImpl(final File externalFilesDirectory, final ImageResizer imageResizer, final PermissionManager permissionManager, final FileUriResolver fileUriResolver, final FileUtils fileUtils) {
		this.externalFilesDirectory = externalFilesDirectory;
		this.imageResizer = imageResizer;
		this.fileProviderName = com.fuse.Activity.getRootActivity().getPackageName() + ".media_picker_file_provider";
		this.permissionManager = permissionManager;
		this.fileUriResolver = fileUriResolver;
		this.fileUtils = fileUtils;
		com.fuse.Activity.ResultListener l = new com.fuse.Activity.ResultListener() {
			@Override
			public boolean onResult(int requestCode, int resultCode, android.content.Intent data) {
				return MediaPickerImpl.this.onActivityResult(requestCode, resultCode, data);
			}
		};
		com.fuse.Activity.subscribeToResults(l);
	}

	boolean isPicking() {
		return result != null;
	}

	void setCameraDevice(CameraDevice device) {
		cameraDevice = device;
	}

	void setArguments(Map<String, Object> arguments) {
		this.arguments = arguments;
	}

	void setResult(Action_String result) {
		this.result = result;
	}

	void setReject(Action_String reject) {
		this.reject = reject;
	}


	public void launchPickVideoFromGalleryIntent() {
		launchGalleryIntent("video/*", false, 1, REQUEST_CODE_CHOOSE_VIDEO_FROM_GALLERY);
	}

	public void launchMultiPickVideoFromGalleryIntent(int maxVideos) {
		launchGalleryIntent("video/*", true, maxVideos, REQUEST_CODE_CHOOSE_MULTI_VIDEO_FROM_GALLERY);
	}

	public void takeVideoWithCamera() {
		if (needRequestCameraPermission()
				&& !permissionManager.isPermissionGranted(Manifest.permission.CAMERA)) {
			permissionManager.askForPermission(
					Manifest.permission.CAMERA, REQUEST_CAMERA_VIDEO_PERMISSION);
			return;
		}

		launchTakeVideoWithCameraIntent();
	}

	private void launchTakeVideoWithCameraIntent() {
		Intent intent = new Intent(MediaStore.ACTION_VIDEO_CAPTURE);
		if (arguments != null && arguments.get("maxDuration") != null) {
			int maxSeconds = ((Number)arguments.get("maxDuration")).intValue();
			if (maxSeconds > 0)
				intent.putExtra(MediaStore.EXTRA_DURATION_LIMIT, maxSeconds);
		}
		if (cameraDevice == CameraDevice.FRONT) {
			useFrontCamera(intent);
		}

		File videoFile;
		try {
			videoFile = createTemporaryWritableVideoFile();
		} catch (RuntimeException e) {
			finishWithError("Could not create a temporary file for the video.");
			return;
		}

		pendingCameraMediaPath = videoFile.getAbsolutePath();
		Uri videoUri = fileUriResolver.resolveFileProviderUriForFile(fileProviderName, videoFile);
		intent.putExtra(MediaStore.EXTRA_OUTPUT, videoUri);
		grantUriPermissions(intent, videoUri);

		try {
			com.fuse.Activity.getRootActivity().startActivityForResult(intent, REQUEST_CODE_TAKE_VIDEO_WITH_CAMERA);
		} catch (ActivityNotFoundException e) {
			deletePendingCameraMedia();
			finishWithError("No cameras available for recording video.");
		} catch (Exception e) {
			deletePendingCameraMedia();
			finishWithError("Could not open the camera: " + e.getMessage());
		}
	}

	public void launchPickImageFromGalleryIntent() {
		launchGalleryIntent("image/*", false, 1, REQUEST_CODE_CHOOSE_IMAGE_FROM_GALLERY);
	}

	public void launchMultiPickImageFromGalleryIntent(int maxImages) {
		launchGalleryIntent("image/*", true, maxImages, REQUEST_CODE_CHOOSE_MULTI_IMAGE_FROM_GALLERY);
	}

	private void launchGalleryIntent(String mimeType, boolean allowMultiple, int maxCount, int requestCode) {
		Intent intent;
		if (Build.VERSION.SDK_INT >= 33) {
			intent = new Intent(ACTION_PICK_IMAGES);
			intent.setType(mimeType);
			if (allowMultiple)
				intent.putExtra(EXTRA_PICK_IMAGES_MAX, maxCount > 0 ? maxCount : Integer.MAX_VALUE);
		} else {
			intent = new Intent(Intent.ACTION_GET_CONTENT);
			intent.addCategory(Intent.CATEGORY_OPENABLE);
			intent.setType(mimeType);
			if (allowMultiple)
				intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
		}

		try {
			com.fuse.Activity.getRootActivity().startActivityForResult(intent, requestCode);
		} catch (ActivityNotFoundException e) {
			finishWithError("No media picker available for this media type.");
		} catch (Exception e) {
			finishWithError("Could not open the media picker: " + e.getMessage());
		}
	}

	public void takeImageWithCamera() {
		if (needRequestCameraPermission()
				&& !permissionManager.isPermissionGranted(Manifest.permission.CAMERA)) {
			permissionManager.askForPermission(
					Manifest.permission.CAMERA, REQUEST_CAMERA_IMAGE_PERMISSION);
			return;
		}
		launchTakeImageWithCameraIntent();
	}

	private boolean needRequestCameraPermission() {
		return permissionManager.needRequestCameraPermission();
	}

	private void launchTakeImageWithCameraIntent() {
		Intent intent = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
		if (cameraDevice == CameraDevice.FRONT) {
			useFrontCamera(intent);
		}

		File imageFile;
		try {
			imageFile = createTemporaryWritableImageFile();
		} catch (RuntimeException e) {
			finishWithError("Could not create a temporary file for the image.");
			return;
		}

		pendingCameraMediaPath = imageFile.getAbsolutePath();
		Uri imageUri = fileUriResolver.resolveFileProviderUriForFile(fileProviderName, imageFile);
		intent.putExtra(MediaStore.EXTRA_OUTPUT, imageUri);
		grantUriPermissions(intent, imageUri);

		try {
			com.fuse.Activity.getRootActivity().startActivityForResult(intent, REQUEST_CODE_TAKE_IMAGE_WITH_CAMERA);
		} catch (ActivityNotFoundException e) {
			deletePendingCameraMedia();
			finishWithError("No cameras available for taking pictures.");
		} catch (Exception e) {
			deletePendingCameraMedia();
			finishWithError("Could not open the camera: " + e.getMessage());
		}
	}

	private File createTemporaryWritableImageFile() {
		return createTemporaryWritableFile(".jpg");
	}

	private File createTemporaryWritableVideoFile() {
		return createTemporaryWritableFile(".mp4");
	}

	private File createTemporaryWritableFile(String suffix) {
		String filename = UUID.randomUUID().toString();
		File image;

		try {
			externalFilesDirectory.mkdirs();
			image = File.createTempFile(filename, suffix, externalFilesDirectory);
		} catch (IOException e) {
			throw new RuntimeException(e);
		}

		return image;
	}

	private void grantUriPermissions(Intent intent, Uri imageUri) {
		PackageManager packageManager = com.fuse.Activity.getRootActivity().getPackageManager();
		List<ResolveInfo> compatibleActivities = packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY);

		for (ResolveInfo info : compatibleActivities) {
			com.fuse.Activity.getRootActivity().grantUriPermission(
					info.activityInfo.packageName,
					imageUri,
					Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
		}
	}

	public static boolean onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
		boolean permissionGranted = grantResults != null && grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED;

		switch (requestCode) {
			case REQUEST_CAMERA_IMAGE_PERMISSION:
				if (permissionGranted)
					MediaPickerImpl.getInstance().launchTakeImageWithCameraIntent();
				else
					MediaPickerImpl.getInstance().finishWithError("The user did not allow camera access.");
				return true;
			case REQUEST_CAMERA_VIDEO_PERMISSION:
				if (permissionGranted)
					MediaPickerImpl.getInstance().launchTakeVideoWithCameraIntent();
				else
					MediaPickerImpl.getInstance().finishWithError("The user did not allow camera access.");
				return true;
			default:
				return false;
		}
	}

	public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
		switch (requestCode) {
			case REQUEST_CODE_CHOOSE_IMAGE_FROM_GALLERY:
				handleChooseImageResult(resultCode, data);
				break;
			case REQUEST_CODE_CHOOSE_MULTI_IMAGE_FROM_GALLERY:
				handleChooseMultiImageResult(resultCode, data);
				break;
			case REQUEST_CODE_TAKE_IMAGE_WITH_CAMERA:
				handleCaptureImageResult(resultCode, data);
				break;
			case REQUEST_CODE_CHOOSE_VIDEO_FROM_GALLERY:
				handleChooseVideoResult(resultCode, data);
				break;
			case REQUEST_CODE_CHOOSE_MULTI_VIDEO_FROM_GALLERY:
				handleChooseMultiVideoResult(resultCode, data);
				break;
			case REQUEST_CODE_TAKE_VIDEO_WITH_CAMERA:
				handleCaptureVideoResult(resultCode, data);
				break;
			default:
				return false;
		}

		return true;
	}

	private void handleChooseImageResult(int resultCode, Intent data) {
		if (resultCode != Activity.RESULT_OK) {
			finishWithError("User cancelled picking an image.");
			return;
		}

		String path = getPathFromIntentData(data);
		if (path == null) {
			finishWithError("Could not read the selected image.");
			return;
		}
		handleImageResult(path, false);
	}

	private void handleChooseMultiImageResult(int resultCode, Intent intent) {
		if (resultCode != Activity.RESULT_OK) {
			finishWithError("User cancelled picking images.");
			return;
		}

		ArrayList<Uri> uris = getUrisFromIntent(intent);
		if (uris.isEmpty()) {
			finishWithError("Could not read the selected images.");
			return;
		}

		int maxImages = getIntArgument("maxImages", 0);
		if (maxImages > 0 && uris.size() > maxImages) {
			finishWithError("Maximum selected images is " + maxImages);
			return;
		}

		ArrayList<String> paths = new ArrayList<>();
		for (Uri uri : uris) {
			String path = fileUtils.getPathFromUri(com.fuse.Activity.getRootActivity(), uri);
			if (path != null)
				paths.add(path);
		}
		handleMultiImageResult(paths);
	}

	private void handleChooseVideoResult(int resultCode, Intent data) {
		if (resultCode != Activity.RESULT_OK) {
			finishWithError("User cancelled picking a video.");
			return;
		}

		String path = getPathFromIntentData(data);
		if (path == null) {
			finishWithError("Could not read the selected video.");
			return;
		}
		handleVideoResult(path);
	}

	private void handleChooseMultiVideoResult(int resultCode, Intent intent) {
		if (resultCode != Activity.RESULT_OK) {
			finishWithError("User cancelled picking videos.");
			return;
		}

		ArrayList<Uri> uris = getUrisFromIntent(intent);
		if (uris.isEmpty()) {
			finishWithError("Could not read the selected videos.");
			return;
		}

		int maxVideos = getIntArgument("maxVideos", 0);
		if (maxVideos > 0 && uris.size() > maxVideos) {
			finishWithError("Maximum selected videos is " + maxVideos);
			return;
		}

		ArrayList<String> paths = new ArrayList<>();
		for (Uri uri : uris) {
			String path = fileUtils.getPathFromUri(com.fuse.Activity.getRootActivity(), uri);
			if (path != null)
				paths.add(path);
		}
		handleMultiVideoResult(paths);
	}

	private void handleCaptureImageResult(int resultCode, Intent data) {
		if (resultCode != Activity.RESULT_OK) {
			deletePendingCameraMedia();
			finishWithError("User cancelled taking a picture.");
			return;
		}

		String path = getValidPendingMediaPath();
		if (path == null)
			path = getPathFromIntentData(data);
		if (path == null) {
			deletePendingCameraMedia();
			finishWithError("Could not read the captured image.");
			return;
		}

		handleImageResult(path, true);
	}

	private void handleCaptureVideoResult(int resultCode, Intent data) {
		if (resultCode != Activity.RESULT_OK) {
			deletePendingCameraMedia();
			finishWithError("User cancelled recording a video.");
			return;
		}

		String path = getValidPendingMediaPath();
		if (path == null)
			path = getPathFromIntentData(data);
		if (path == null) {
			deletePendingCameraMedia();
			finishWithError("Could not read the recorded video.");
			return;
		}

		handleVideoResult(path);
	}

	private String getValidPendingMediaPath() {
		if (pendingCameraMediaPath == null)
			return null;

		File file = new File(pendingCameraMediaPath);
		if (!file.exists() || file.length() == 0)
			return null;

		return pendingCameraMediaPath;
	}

	private String getPathFromIntentData(Intent data) {
		if (data == null || data.getData() == null)
			return null;
		return fileUtils.getPathFromUri(com.fuse.Activity.getRootActivity(), data.getData());
	}

	private ArrayList<Uri> getUrisFromIntent(Intent intent) {
		ArrayList<Uri> uris = new ArrayList<>();
		if (intent == null)
			return uris;

		ClipData clipData = intent.getClipData();
		if (clipData != null) {
			for (int i = 0; i < clipData.getItemCount(); i++) {
				Uri uri = clipData.getItemAt(i).getUri();
				if (uri != null)
					uris.add(uri);
			}
		} else if (intent.getData() != null) {
			uris.add(intent.getData());
		}

		return uris;
	}

	private void handleMultiImageResult(ArrayList<String> paths) {
		ArrayList<String> finalPaths = new ArrayList<>();
		for (String path : paths) {
			String finalImagePath = getResizedImagePath(path);
			if (finalImagePath != null)
				finalPaths.add(finalImagePath);
		}

		if (finalPaths.isEmpty()) {
			finishWithError("Could not process the selected images.");
			return;
		}

		finishWithListSuccess(finalPaths);
	}

	private void handleMultiVideoResult(ArrayList<String> paths) {
		if (paths == null || paths.isEmpty()) {
			finishWithError("Could not process the selected videos.");
			return;
		}

		finishWithListSuccess(paths);
	}

	private void handleImageResult(String path, boolean shouldDeleteOriginalIfScaled) {
		String finalImagePath = getResizedImagePath(path);
		if (finalImagePath == null) {
			finishWithError("Could not process the selected image.");
			return;
		}

		// Delete the original file if it was scaled.
		if (!finalImagePath.equals(path) && shouldDeleteOriginalIfScaled)
			new File(path).delete();

		ArrayList<String> paths = new ArrayList<>();
		paths.add(finalImagePath);
		finishWithListSuccess(paths);
	}

	private int getIntArgument(String key, int fallback) {
		if (arguments == null)
			return fallback;
		Object value = arguments.get(key);
		return (value instanceof Number) ? ((Number)value).intValue() : fallback;
	}

	private String getResizedImagePath(String path) {
		if (path == null || path.isEmpty())
			return null;

		if (arguments == null)
			return path;

		Double maxWidth = getDoubleArgument("maxWidth");
		Double maxHeight = getDoubleArgument("maxHeight");
		Integer imageQuality = getIntArgument("imageQuality", 100);

		try {
			return imageResizer.resizeImageIfNeeded(path, maxWidth, maxHeight, imageQuality);
		} catch (Exception e) {
			return null;
		}
	}

	private Double getDoubleArgument(String key) {
		Object value = arguments.get(key);
		return (value instanceof Number) ? ((Number)value).doubleValue() : null;
	}

	private void handleVideoResult(String path) {
		if (path == null || path.isEmpty()) {
			finishWithError("Could not process the selected video.");
			return;
		}
		finishWithSuccess(path);
	}

	private void finishWithSuccess(String path) {
		Action_String callback = this.result;
		clearCallbacks();
		if (callback != null)
			callback.run(path);
	}

	private void finishWithListSuccess(ArrayList<String> paths) {
		Action_String callback = this.result;
		clearCallbacks();
		if (callback == null)
			return;
		callback.run(new JSONArray(paths).toString());
	}

	void finishWithError(String errorMessage) {
		Action_String callback = this.reject;
		clearCallbacks();
		if (callback != null)
			callback.run(errorMessage);
	}

	private void clearCallbacks() {
		result = null;
		reject = null;
		arguments = null;
		pendingCameraMediaPath = null;
	}

	private void deletePendingCameraMedia() {
		if (pendingCameraMediaPath == null)
			return;

		File file = new File(pendingCameraMediaPath);
		if (file.exists())
			file.delete();
		pendingCameraMediaPath = null;
	}

	private void useFrontCamera(Intent intent) {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
			intent.putExtra("android.intent.extras.CAMERA_FACING", CameraCharacteristics.LENS_FACING_FRONT);
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				intent.putExtra("android.intent.extra.USE_FRONT_CAMERA", true);
			}
		} else {
			intent.putExtra("android.intent.extras.CAMERA_FACING", 1);
		}
	}
}
