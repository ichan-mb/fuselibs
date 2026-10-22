package com.fuse.sensorkit;

import android.content.Context;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import com.foreign.Uno.Action_Object;

public abstract class AbstractSensor implements SensorHandle {

    private final SensorManager mSensorManager;
    private final Sensor mSensor;
    private final SensorEventListener mSensorEventListener;
    private boolean isSensing = false;
    private Action_Object onDataChanged;

    public AbstractSensor(final SensorType sensorType, Action_Object onDataChanged) {
        this.onDataChanged = onDataChanged;
        mSensorManager = (SensorManager) com.fuse.Activity.getRootActivity().getSystemService(Context.SENSOR_SERVICE);
        mSensor = mSensorManager != null ? mSensorManager.getDefaultSensor(getSensorType(sensorType)) : null;

        mSensorEventListener = new SensorEventListener() {

            @Override
            public void onAccuracyChanged(Sensor sensor, int accuracy) {
                // Accuracy changes are not exposed by this module.
            }

            @Override
            public void onSensorChanged(SensorEvent event) {
                SensorData data = buildData(event);

                // SensorEvent.timestamp is nanoseconds on the monotonic clock (since boot).
                data.setElapsed(event.timestamp / 1e9);

                if (AbstractSensor.this.onDataChanged != null)
                    AbstractSensor.this.onDataChanged.run(data);
            }
        };
    }

    public void start(int intervalMs) throws Exception {
        if (this.isSensing)
            return;

        if (mSensorManager == null || mSensor == null)
            throw new Exception(getSensorName() + " sensor is not available.");

        int samplingPeriodUs = intervalMs > 0 ? intervalMs * 1000 : SensorManager.SENSOR_DELAY_NORMAL;
        boolean status = mSensorManager.registerListener(mSensorEventListener, mSensor, samplingPeriodUs);
        if (!status)
            throw new Exception(getSensorName() + " sensor is not available.");

        // Only report as sensing once the sensor actually started, so isSensing() never lies.
        this.isSensing = true;
    }

    public void stop() {
        if (!this.isSensing)
            return;

        if (mSensorManager != null)
            mSensorManager.unregisterListener(mSensorEventListener);

        this.isSensing = false;
    }

    protected abstract SensorData buildData(SensorEvent event);

    protected abstract String getSensorName();

    /** Whether the device has hardware for the given sensor type. */
    public static boolean isAvailable(SensorType sensorType) {
        if (sensorType == null)
            return false;

        // These are not backed by SensorManager and are always available.
        if (sensorType == SensorType.BATTERY || sensorType == SensorType.CONNECTION_STATE)
            return true;

        SensorManager manager = (SensorManager) com.fuse.Activity.getRootActivity().getSystemService(Context.SENSOR_SERVICE);
        return manager != null && manager.getDefaultSensor(getSensorType(sensorType)) != null;
    }

    public boolean isSensing() {
        return isSensing;
    }

    private static int getSensorType(SensorType sensorType) {

        switch (sensorType) {

            case ACCELEROMETER:
                return Sensor.TYPE_ACCELEROMETER;

            case GRAVITY:
                return Sensor.TYPE_GRAVITY;

            case GYROSCOPE:
                return Sensor.TYPE_GYROSCOPE;

            case USER_ACCELERATION:
                return Sensor.TYPE_LINEAR_ACCELERATION;

            case ROTATION:
                return Sensor.TYPE_ROTATION_VECTOR;

            case MAGNETOMETER:
                return Sensor.TYPE_MAGNETIC_FIELD;

            case STEP_COUNTER:
                return Sensor.TYPE_STEP_COUNTER;

            case PRESSURE:
                return Sensor.TYPE_PRESSURE;
        }
        return 0;
    }
}