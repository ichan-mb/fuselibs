package com.fuse.sensorkit;

import android.os.BatteryManager;

/**
 * Battery state, as read from the ACTION_BATTERY_CHANGED broadcast.
 *
 * Only the values Fuse.Sensor exposes or uses for change detection are kept; temperature and
 * voltage are not read at all.
 */
public class BatteryData {

    protected final int level;
    protected final int scale;
    protected final int plugged;
    protected final int status;
    protected final int health;

    public BatteryData(int level, int scale, int plugged, int status, int health) {
        this.level = level;
        this.scale = scale;
        this.plugged = plugged;
        this.status = status;
        this.health = health;
    }

    /** The level as a 0.0-1.0 ratio, or 0 when the scale is unknown. */
    public float getLevelRatio() {
        return level >= 0 && scale > 0 ? level / (float)scale : 0;
    }

    public int getLevel() {
        return this.level;
    }

    public int getPlugged() {
        return this.plugged;
    }

    public int getBatteryStatus() {
        return this.status;
    }

    public int getBatteryHealth() {
        return this.health;
    }

    /** Canonical, lower case status name. Part of the JavaScript API. */
    public String getBatteryStatusString() {
        switch (status) {
            case BatteryManager.BATTERY_STATUS_CHARGING:
                return "charging";

            case BatteryManager.BATTERY_STATUS_DISCHARGING:
                return "unplugged";

            case BatteryManager.BATTERY_STATUS_FULL:
                return "full";

            case BatteryManager.BATTERY_STATUS_NOT_CHARGING:
                return "not_charging";

            case BatteryManager.BATTERY_STATUS_UNKNOWN:
                return "unknown";

            default:
                return "unsupported";
        }
    }
}
