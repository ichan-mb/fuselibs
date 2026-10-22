package com.fuse.sensorkit;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkInfo;
import android.net.NetworkRequest;
import android.os.Build;
import com.foreign.Uno.Action_Object;

/**
 * Monitors network connectivity.
 *
 * Uses ConnectivityManager network callbacks instead of the CONNECTIVITY_CHANGE broadcast. The
 * broadcast no longer carries EXTRA_NETWORK_INFO on modern Android versions, and Android 7+
 * discourages broadcast-based connectivity monitoring.
 */
public class ConnectionStateSensor implements SensorHandle {

    private final Action_Object onDataChanged;
    private ConnectivityManager mConnectivityManager;
    private final ConnectivityManager.NetworkCallback mNetworkCallback;
    private boolean mRegistered = false;
    private boolean isSensing = false;

    // -1 = nothing reported yet, 0 = disconnected, 1 = connected
    private int mLastReportedState = -1;

    public ConnectionStateSensor(Action_Object onDataChanged) {
        this.onDataChanged = onDataChanged;
        mConnectivityManager = null;

        mNetworkCallback = new ConnectivityManager.NetworkCallback() {
            @Override
            public void onAvailable(Network network) {
                postConnectionState(true);
            }

            @Override
            public void onLost(Network network) {
                // Another network may already have taken over, so re-evaluate instead of
                // unconditionally reporting "disconnected".
                postConnectionState(isConnected());
            }

            @Override
            public void onCapabilitiesChanged(Network network, NetworkCapabilities networkCapabilities) {
                postConnectionState(networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET));
            }
        };
    }

    public void start(int intervalMs) {
        if (this.isSensing)
            return;

        // Resolved lazily so that constructing the sensor does not depend on the activity being
        // available yet.
        if (mConnectivityManager == null)
            mConnectivityManager = (ConnectivityManager) com.fuse.Activity.getRootActivity().getSystemService(Context.CONNECTIVITY_SERVICE);

        if (mConnectivityManager != null) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    mConnectivityManager.registerDefaultNetworkCallback(mNetworkCallback);
                } else {
                    NetworkRequest request = new NetworkRequest.Builder()
                            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                            .build();
                    mConnectivityManager.registerNetworkCallback(request, mNetworkCallback);
                }
                mRegistered = true;
            } catch (Exception e) {
                // Most likely a missing ACCESS_NETWORK_STATE permission. Keep the sensor usable
                // through the initial state reported below instead of crashing.
                mRegistered = false;
            }
        }

        this.isSensing = true;
        mLastReportedState = -1;

        // Report the current state immediately, so the app does not have to wait for a change.
        postConnectionState(isConnected());
    }

    public void stop() {
        if (!this.isSensing)
            return;

        if (mRegistered && mConnectivityManager != null) {
            try {
                mConnectivityManager.unregisterNetworkCallback(mNetworkCallback);
            } catch (IllegalArgumentException e) {
                // Already unregistered.
            }
            mRegistered = false;
        }

        this.isSensing = false;
        mLastReportedState = -1;
    }

    private boolean isConnected() {
        if (mConnectivityManager == null)
            return false;

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Network network = mConnectivityManager.getActiveNetwork();
                if (network == null)
                    return false;

                NetworkCapabilities capabilities = mConnectivityManager.getNetworkCapabilities(network);
                return capabilities != null
                        && capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET);
            }

            NetworkInfo networkInfo = mConnectivityManager.getActiveNetworkInfo();
            return networkInfo != null && networkInfo.isConnected();
        } catch (Exception e) {
            return false;
        }
    }

    private void postConnectionState(boolean connected) {
        int state = connected ? 1 : 0;
        if (!this.isSensing || state == mLastReportedState)
            return;

        mLastReportedState = state;

        if (this.onDataChanged != null)
            this.onDataChanged.run(new ConnectionStateData(connected, connected ? "connected" : "disconnected"));
    }

    public boolean isSensing() {
        return isSensing;
    }
}
