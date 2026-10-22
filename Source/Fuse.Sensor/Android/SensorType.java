package com.fuse.sensorkit;

/**
 * Sensor types, with explicit codes.
 *
 * The code is the value of the Fuse.Sensor.SensorType enum and is part of the public JavaScript
 * API. Explicit codes keep the two enums decoupled: entries can be reordered here without
 * changing the values applications see.
 */
public enum SensorType {
    ACCELEROMETER(0),
    GYROSCOPE(1),
    MAGNETOMETER(2),
    GRAVITY(3),
    USER_ACCELERATION(4),
    ROTATION(5),
    STEP_COUNTER(6),
    PRESSURE(7),
    BATTERY(8),
    CONNECTION_STATE(9);

    public final int code;

    SensorType(int code) {
        this.code = code;
    }

    public static SensorType fromCode(int code) {
        for (SensorType type : values()) {
            if (type.code == code)
                return type;
        }
        return null;
    }
}
