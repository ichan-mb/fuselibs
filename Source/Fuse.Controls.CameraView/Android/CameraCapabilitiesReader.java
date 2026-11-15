package com.fuse.controls.cameraview;

import android.graphics.ImageFormat;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraMetadata;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.util.Range;
import android.util.Rational;
import android.util.Size;

import androidx.camera.core.Camera;
import androidx.camera.core.ExposureState;
import androidx.camera.core.ZoomState;

/**
 * Reads camera capabilities and current state without owning the camera.
 */
final class CameraCapabilitiesReader {
    private CameraCapabilitiesReader() {
    }

    // ---------------------------------------------------------------------
    // Photo sizes
    // ---------------------------------------------------------------------

    static Size[] pictureSizes(CameraCharacteristics characteristics) {
        StreamConfigurationMap map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
        return map == null ? null : map.getOutputSizes(ImageFormat.JPEG);
    }

    static int[] pictureSizesFlat(CameraCharacteristics characteristics) {
        Size[] sizes = pictureSizes(characteristics);
        if (sizes == null)
            return new int[0];

        int[] result = new int[sizes.length * 2];
        for (int i = 0; i < sizes.length; i++) {
            result[i * 2] = sizes[i].getWidth();
            result[i * 2 + 1] = sizes[i].getHeight();
        }
        return result;
    }

    // ---------------------------------------------------------------------
    // Zoom and torch
    // ---------------------------------------------------------------------

    static boolean isZoomSupported(Camera camera, CameraCharacteristics characteristics) {
        if (camera != null) {
            ZoomState state = camera.getCameraInfo().getZoomState().getValue();
            if (state != null)
                return state.getMaxZoomRatio() > state.getMinZoomRatio();
        }

        Float max = characteristics.get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM);
        return max != null && max > 1.0f;
    }

    static float minZoom(Camera camera) {
        if (camera != null) {
            ZoomState state = camera.getCameraInfo().getZoomState().getValue();
            if (state != null)
                return state.getMinZoomRatio();
        }

        return 1.0f;
    }

    static float maxZoom(Camera camera, CameraCharacteristics characteristics) {
        if (camera != null) {
            ZoomState state = camera.getCameraInfo().getZoomState().getValue();
            if (state != null)
                return state.getMaxZoomRatio();
        }

        Float max = characteristics.get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM);
        return max == null ? 1.0f : max;
    }

    static boolean isTorchSupported(Camera camera, CameraCharacteristics characteristics) {
        if (camera != null)
            return camera.getCameraInfo().hasFlashUnit();

        Boolean flash = characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE);
        return flash != null && flash;
    }

    // ---------------------------------------------------------------------
    // Exposure compensation
    // ---------------------------------------------------------------------

    static ExposureState exposureState(Camera camera) {
        return camera == null ? null : camera.getCameraInfo().getExposureState();
    }

    static float minExposureCompensation(Camera camera) {
        ExposureState exposure = exposureState(camera);
        if (exposure == null || !exposure.isExposureCompensationSupported())
            return 0.0f;

        Range<Integer> range = exposure.getExposureCompensationRange();
        Rational step = exposure.getExposureCompensationStep();
        return range == null || step == null ? 0.0f : range.getLower() * step.floatValue();
    }

    static float maxExposureCompensation(Camera camera) {
        ExposureState exposure = exposureState(camera);
        if (exposure == null || !exposure.isExposureCompensationSupported())
            return 0.0f;

        Range<Integer> range = exposure.getExposureCompensationRange();
        Rational step = exposure.getExposureCompensationStep();
        return range == null || step == null ? 0.0f : range.getUpper() * step.floatValue();
    }

    static float exposureCompensationStep(Camera camera) {
        ExposureState exposure = exposureState(camera);
        if (exposure == null || !exposure.isExposureCompensationSupported())
            return 0.0f;

        Rational step = exposure.getExposureCompensationStep();
        return step == null ? 0.0f : step.floatValue();
    }

    static float exposureCompensationNow(Camera camera) {
        ExposureState exposure = exposureState(camera);
        if (exposure == null || !exposure.isExposureCompensationSupported())
            return 0.0f;

        Rational step = exposure.getExposureCompensationStep();
        return step == null ? 0.0f : exposure.getExposureCompensationIndex() * step.floatValue();
    }

    // ---------------------------------------------------------------------
    // Manual exposure
    // ---------------------------------------------------------------------

    static Range<Integer> isoRange(CameraCharacteristics characteristics) {
        return characteristics.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE);
    }

    static Range<Long> exposureTimeRange(CameraCharacteristics characteristics) {
        return characteristics.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE);
    }

    static boolean isAeOffSupported(CameraCharacteristics characteristics) {
        int[] modes = characteristics.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_MODES);
        if (modes == null)
            return false;

        for (int mode : modes) {
            if (mode == CameraMetadata.CONTROL_AE_MODE_OFF)
                return true;
        }
        return false;
    }

    static boolean isManualExposureSupported(CameraCharacteristics characteristics) {
        return isoRange(characteristics) != null
            && exposureTimeRange(characteristics) != null
            && isAeOffSupported(characteristics);
    }

    static float minIso(CameraCharacteristics characteristics) {
        Range<Integer> range = isoRange(characteristics);
        return range == null ? 0.0f : range.getLower();
    }

    static float maxIso(CameraCharacteristics characteristics) {
        Range<Integer> range = isoRange(characteristics);
        return range == null ? 0.0f : range.getUpper();
    }

    static float minShutterSeconds(CameraCharacteristics characteristics) {
        Range<Long> range = exposureTimeRange(characteristics);
        return range == null ? 0.0f : range.getLower() / 1000000000.0f;
    }

    static float maxShutterSeconds(CameraCharacteristics characteristics) {
        Range<Long> range = exposureTimeRange(characteristics);
        return range == null ? 0.0f : range.getUpper() / 1000000000.0f;
    }
}
