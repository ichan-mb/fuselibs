package com.fuse.sensorkit;

/**
 * Common interface implemented by every native sensor handle.
 *
 * AbstractSensor covers SensorManager backed sensors, while BatterySensor and
 * ConnectionStateSensor are backed by broadcasts/callbacks. The Uno side only needs this
 * interface to start, stop and query any of them.
 */
public interface SensorHandle {

    void start(int intervalMs) throws Exception;

    void stop();

    boolean isSensing();
}
