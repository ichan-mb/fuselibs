package fuse.geolocation;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class GeofenceReceiver extends BroadcastReceiver
{
	public static final String ACTION_GEOFENCE_TRANSITION = "fuse.geolocation.GEOFENCE_TRANSITION";
	public static final String EXTRA_ID = "id";

	public static com.foreign.Uno.Action_Object Callback;

	@Override
	public void onReceive(Context context, Intent intent)
	{
		if (intent == null || !ACTION_GEOFENCE_TRANSITION.equals(intent.getAction()))
			return;

		if (Callback != null)
			Callback.run(intent);
	}
}
