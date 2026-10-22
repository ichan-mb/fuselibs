package com.fuse.sensorkit;

public class SensorData
{
    protected final SensorType moduleType;
    protected final float[] data;
    protected double elapsed;

    public SensorData(SensorType moduleType, float[] data) {
        this.moduleType = moduleType;
        this.data = data;
    }

    public SensorType getSensorType() {
        return moduleType;
    }

    public float[] getData() {
        return this.data;
    }

    /**
     * Seconds on the device's monotonic clock (the value of SensorEvent.timestamp).
     * Set by AbstractSensor when the event arrives.
     */
    public double getElapsed() {
        return this.elapsed;
    }

    public void setElapsed(double elapsed) {
        this.elapsed = elapsed;
    }
}
