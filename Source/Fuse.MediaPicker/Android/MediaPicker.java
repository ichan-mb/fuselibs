package com.fuse.mediapicker;

import java.util.Map;
import com.foreign.Uno.Action_String;

public class MediaPicker {

	private static final int CAMERA_DEVICE_FRONT = 1;

	private static final int SOURCE_CAMERA = 0;
	private static final int SOURCE_GALLERY = 1;

	private final MediaPickerImpl mediaPickerImpl;

	public MediaPicker() {
		this.mediaPickerImpl = MediaPickerImpl.getInstance();
	}

	private boolean begin(Map<String, Object> arguments, Action_String result, Action_String reject) {
		if (mediaPickerImpl.isPicking()) {
			reject.run("Another media picker request is already in progress.");
			return false;
		}
		setupCamera(arguments);
		mediaPickerImpl.setArguments(arguments);
		mediaPickerImpl.setResult(result);
		mediaPickerImpl.setReject(reject);
		return true;
	}

	private void setupCamera(Map<String, Object> arguments) {
		int device = getInt(arguments, "cameraDevice", 0);
		mediaPickerImpl.setCameraDevice(
				device == CAMERA_DEVICE_FRONT ? CameraDevice.FRONT : CameraDevice.REAR);
	}

	private int getSource(Map<String, Object> arguments) {
		return getInt(arguments, "source", SOURCE_GALLERY);
	}

	public void pickImage(Map<String, Object> arguments, Action_String result, Action_String reject) {
		if (!begin(arguments, result, reject))
			return;

		int imageSource = getSource(arguments);
		switch (imageSource) {
			case SOURCE_GALLERY:
				int maxImages = getInt(arguments, "maxImages", 1);
				if (maxImages == 1)
					mediaPickerImpl.launchPickImageFromGalleryIntent();
				else
					mediaPickerImpl.launchMultiPickImageFromGalleryIntent(maxImages);
				break;
			case SOURCE_CAMERA:
				mediaPickerImpl.takeImageWithCamera();
				break;
			default:
				mediaPickerImpl.finishWithError("Invalid image source: " + imageSource);
				break;
		}
	}

	public void pickVideo(Map<String, Object> arguments, Action_String result, Action_String reject) {
		if (!begin(arguments, result, reject))
			return;

		int videoSource = getSource(arguments);
		switch (videoSource) {
			case SOURCE_GALLERY:
				mediaPickerImpl.launchPickVideoFromGalleryIntent();
				break;
			case SOURCE_CAMERA:
				mediaPickerImpl.takeVideoWithCamera();
				break;
			default:
				mediaPickerImpl.finishWithError("Invalid video source: " + videoSource);
				break;
		}
	}

	/** Picks one or more videos from the gallery; multi-video capture is not supported. */
	public void pickVideos(Map<String, Object> arguments, Action_String result, Action_String reject) {
		if (!begin(arguments, result, reject))
			return;

		int maxVideos = getInt(arguments, "maxVideos", 1);
		if (maxVideos == 1)
			mediaPickerImpl.launchPickVideoFromGalleryIntent();
		else
			mediaPickerImpl.launchMultiPickVideoFromGalleryIntent(maxVideos);
	}

	private static int getInt(Map<String, Object> arguments, String key, int fallback) {
		Object value = (arguments != null) ? arguments.get(key) : null;
		return (value instanceof Number) ? ((Number)value).intValue() : fallback;
	}
}
