package com.fuse.sensorkit;

import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.BroadcastReceiver;
import com.foreign.Uno.Action_Object;

public class BatterySensor implements SensorHandle {

    private final Action_Object onDataChanged;
    private boolean isSensing = false;

    // Last reported state, used to drop broadcasts that do not change anything.
    private int mLastLevelSensed = Integer.MAX_VALUE;
    private int mLastPluggedSensed = Integer.MAX_VALUE;
    private int mLastStatusSensed = Integer.MAX_VALUE;
    private int mLastHealthSensed = Integer.MAX_VALUE;

    private final BroadcastReceiver mBroadcastReceiver;
    private boolean mRegistered = false;

    public BatterySensor(Action_Object onDataChanged) {
        this.onDataChanged = onDataChanged;
        mBroadcastReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                int level = intent.getIntExtra("level", -1);
                int scale = intent.getIntExtra("scale", -1);
                int plugged = intent.getIntExtra("plugged", -1);
                int status = intent.getIntExtra("status", 0);
                int health = intent.getIntExtra("health", 0);

                BatteryData data = new BatteryData(level, scale, plugged, status, health);
                if (BatterySensor.this.onDataChanged != null && shouldPostData(data))
                    BatterySensor.this.onDataChanged.run(data);
            }
        };
    }

    public void start(int intervalMs) {
        if (this.isSensing)
            return;

        // Mark as sensing before registering, since ACTION_BATTERY_CHANGED is a sticky broadcast
        // that is delivered synchronously from registerReceiver().
        this.isSensing = true;

        try {
            IntentFilter filter = new IntentFilter(Intent.ACTION_BATTERY_CHANGED);
            com.fuse.Activity.getRootActivity().registerReceiver(mBroadcastReceiver, filter);
            mRegistered = true;
        } catch (Exception e) {
            this.isSensing = false;
            mRegistered = false;
        }
    }

    public void stop() {
        if (!this.isSensing)
            return;

        if (mRegistered) {
            try {
                com.fuse.Activity.getRootActivity().unregisterReceiver(mBroadcastReceiver);
            } catch (IllegalArgumentException e) {
                // Already unregistered.
            }
            mRegistered = false;
        }

        this.isSensing = false;

        // Clear last sensed values, so the current state is reported again on the next start.
        mLastLevelSensed = Integer.MAX_VALUE;
        mLastPluggedSensed = Integer.MAX_VALUE;
        mLastStatusSensed = Integer.MAX_VALUE;
        mLastHealthSensed = Integer.MAX_VALUE;
    }

    public boolean isSensing() {
        return isSensing;
    }

    private boolean shouldPostData(BatteryData data) {
        int level = data.getLevel();
        int plugged = data.getPlugged();
        int status = data.getBatteryStatus();
        int health = data.getBatteryHealth();

        // Only report when a value that is exposed actually changed. Temperature and voltage are
        // not read, and the scale is implicitly covered by the level.
        boolean shouldPost = (mLastLevelSensed != level ||
                              mLastPluggedSensed != plugged ||
                              mLastStatusSensed != status ||
                              mLastHealthSensed != health);

        if (shouldPost) {
            this.mLastLevelSensed = level;
            this.mLastPluggedSensed = plugged;
            this.mLastStatusSensed = status;
            this.mLastHealthSensed = health;
        }

        return shouldPost;
    }

}