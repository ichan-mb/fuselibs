package com.fuse.controls.cameraview;

import androidx.annotation.NonNull;

import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.OnSuccessListener;
import com.google.android.gms.tasks.Task;
import com.google.mlkit.vision.barcode.BarcodeScanner;
import com.google.mlkit.vision.barcode.BarcodeScannerOptions;
import com.google.mlkit.vision.barcode.BarcodeScanning;
import com.google.mlkit.vision.barcode.common.Barcode;
import com.google.mlkit.vision.common.InputImage;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Barcode and QR code scanning on top of the frame pipeline.
 *
 * A scan is either one shot, which reports the first code and stops, or
 * continuous, which reports every code once while it stays in view.
 */
final class BarcodeConsumer implements FramePipeline.Consumer {

    private final FrameAnalysis.Host _host;
    private final FramePipeline _pipeline;

    private BarcodeScanner _scanner;
    private final AtomicBoolean _busy = new AtomicBoolean(false);
    private boolean _active;
    private boolean _continuous;
    private String _lastValue;
    private CameraXSession.BarcodeCallback _callback;

    BarcodeConsumer(FrameAnalysis.Host host, FramePipeline pipeline) {
        _host = host;
        _pipeline = pipeline;
    }

    /** Returns null on success, or a message describing why scanning cannot start. */
    String start(boolean continuous, String[] formats, CameraXSession.BarcodeCallback callback) {
        if (!_busy.compareAndSet(false, true))
            return "A barcode scan is already in progress";

        int[] mlKitFormats = toMlKitFormats(formats);
        if (formats != null && formats.length > 0 && mlKitFormats.length == 0) {
            _busy.set(false);
            return "Unsupported barcode format";
        }

        _callback = callback;
        _continuous = continuous;
        _active = true;
        _lastValue = null;

        try {
            BarcodeScannerOptions.Builder options = new BarcodeScannerOptions.Builder();
            if (mlKitFormats.length > 0) {
                options.setBarcodeFormats(mlKitFormats[0],
                                          Arrays.copyOfRange(mlKitFormats, 1, mlKitFormats.length));
            }
            _scanner = BarcodeScanning.getClient(options.build());
        } catch (Throwable t) {
            finish();
            return "Could not start barcode scanning: " + FramePipeline.messageOf(t);
        }

        String error = _pipeline.attach(this);
        if (error != null) {
            finish();
            return error;
        }

        return null;
    }

    boolean stop() {
        boolean wasActive = _active;
        if (!wasActive)
            return false;

        // A one shot scan is waiting for a result, so it has to be told that it
        // will never get one.
        final CameraXSession.BarcodeCallback pending = _continuous ? null : _callback;
        finish();

        if (pending != null)
            pending.onError("Barcode scanning was stopped");

        return true;
    }

    boolean isActive() {
        return _active;
    }

    void dispose() {
        final CameraXSession.BarcodeCallback pending = _callback;
        finish();

        if (pending != null) {
            _host.mainHandler().post(new Runnable() {
                @Override
                public void run() {
                    pending.onError("Camera has been disposed");
                }
            });
        }
    }

    @Override
    public void onFrame(FrameLease lease) {
        BarcodeScanner scanner = _active ? _scanner : null;
        if (scanner == null)
            return;

        InputImage input = lease.inputImage();
        if (input == null)
            return;

        // ML Kit keeps working after this callback returns, so hold the frame
        // open until the task completes.
        lease.retain();

        Task<List<Barcode>> task;
        try {
            task = scanner.process(input);
        } catch (Throwable t) {
            lease.release();

            if (!_continuous)
                failScan(FramePipeline.messageOf(t));
            return;
        }

        task.addOnSuccessListener(new OnSuccessListener<List<Barcode>>() {
            @Override
            public void onSuccess(List<Barcode> barcodes) {
                if (barcodes != null)
                    deliver(barcodes);
            }
        }).addOnFailureListener(new OnFailureListener() {
            @Override
            public void onFailure(@NonNull Exception e) {
                // Decoding a single frame can fail for a number of transient
                // reasons. Continuous scanning simply waits for the next frame
                // instead of aborting.
                if (!_continuous)
                    failScan(FramePipeline.messageOf(e));
            }
        }).addOnCompleteListener(new OnCompleteListener<List<Barcode>>() {
            @Override
            public void onComplete(@NonNull Task<List<Barcode>> task) {
                lease.release();
            }
        });
    }

    // ---------------------------------------------------------------------
    // Result delivery
    // ---------------------------------------------------------------------

    private void finish() {
        if (!_active)
            return;

        _active = false;
        _continuous = false;
        _callback = null;
        _lastValue = null;
        _busy.set(false);

        closeScanner();
        _pipeline.detach(this);
    }

    private void closeScanner() {
        if (_scanner == null)
            return;

        try {
            _scanner.close();
        } catch (Throwable ignored) {
        }

        _scanner = null;
    }

    private void deliver(List<Barcode> barcodes) {
        if (!_active)
            return;

        for (Barcode barcode : barcodes) {
            String value = rawValueOf(barcode);
            if (value != null && value.length() > 0) {
                deliverCode(value, formatNameOf(barcode.getFormat()));
                return;
            }
        }
    }

    private void deliverCode(final String value, final String format) {
        if (!_active)
            return;

        if (!_continuous) {
            resolveScan(value, format);
            return;
        }

        // Only report a code once so a static barcode does not flood the
        // callback on every analysed frame.
        if (value.equals(_lastValue))
            return;

        _lastValue = value;
        if (_callback != null)
            _callback.onResult(value, format);
    }

    private void resolveScan(final String value, final String format) {
        _host.mainHandler().post(new Runnable() {
            @Override
            public void run() {
                CameraXSession.BarcodeCallback callback = _callback;
                finish();

                if (callback != null)
                    callback.onResult(value, format);
            }
        });
    }

    private void failScan(final String message) {
        _host.mainHandler().post(new Runnable() {
            @Override
            public void run() {
                CameraXSession.BarcodeCallback callback = _callback;
                finish();

                if (callback != null)
                    callback.onError(message);
            }
        });
    }

    // ---------------------------------------------------------------------
    // Barcode values and formats
    // ---------------------------------------------------------------------

    static String rawValueOf(Barcode barcode) {
        String value = barcode.getRawValue();
        if (value == null)
            value = barcode.getDisplayValue();
        if (value == null && barcode.getUrl() != null)
            value = barcode.getUrl().getUrl();
        return value;
    }

    static String formatNameOf(int format) {
        switch (format) {
        case Barcode.FORMAT_CODE_128:
            return "CODE_128";
        case Barcode.FORMAT_CODE_39:
            return "CODE_39";
        case Barcode.FORMAT_CODE_93:
            return "CODE_93";
        case Barcode.FORMAT_CODABAR:
            return "CODABAR";
        case Barcode.FORMAT_DATA_MATRIX:
            return "DATA_MATRIX";
        case Barcode.FORMAT_EAN_13:
            return "EAN_13";
        case Barcode.FORMAT_EAN_8:
            return "EAN_8";
        case Barcode.FORMAT_ITF:
            return "ITF";
        case Barcode.FORMAT_QR_CODE:
            return "QR_CODE";
        case Barcode.FORMAT_UPC_A:
            return "UPC_A";
        case Barcode.FORMAT_UPC_E:
            return "UPC_E";
        case Barcode.FORMAT_PDF417:
            return "PDF417";
        case Barcode.FORMAT_AZTEC:
            return "AZTEC";
        default:
            return "UNKNOWN";
        }
    }

    static int[] toMlKitFormats(String[] formats) {
        if (formats == null || formats.length == 0)
            return new int[0];

        List<Integer> result = new ArrayList<>();
        for (String format : formats) {
            int value = mlKitFormatOf(format);
            if (value != 0 && !result.contains(value))
                result.add(value);
        }

        int[] converted = new int[result.size()];
        for (int i = 0; i < converted.length; i++)
            converted[i] = result.get(i);
        return converted;
    }

    static int mlKitFormatOf(String format) {
        if (format == null)
            return 0;

        String name = format.trim().toUpperCase(Locale.US);
        if ("QR_CODE".equals(name))
            return Barcode.FORMAT_QR_CODE;
        if ("EAN_13".equals(name))
            return Barcode.FORMAT_EAN_13;
        if ("EAN_8".equals(name))
            return Barcode.FORMAT_EAN_8;
        if ("UPC_A".equals(name))
            return Barcode.FORMAT_UPC_A;
        if ("UPC_E".equals(name))
            return Barcode.FORMAT_UPC_E;
        if ("CODE_128".equals(name))
            return Barcode.FORMAT_CODE_128;
        if ("CODE_39".equals(name))
            return Barcode.FORMAT_CODE_39;
        if ("CODE_93".equals(name))
            return Barcode.FORMAT_CODE_93;
        if ("ITF".equals(name) || "CODE_ITF".equals(name))
            return Barcode.FORMAT_ITF;
        if ("CODABAR".equals(name))
            return Barcode.FORMAT_CODABAR;
        if ("DATA_MATRIX".equals(name))
            return Barcode.FORMAT_DATA_MATRIX;
        if ("PDF417".equals(name))
            return Barcode.FORMAT_PDF417;
        if ("AZTEC".equals(name))
            return Barcode.FORMAT_AZTEC;
        return 0;
    }
}
