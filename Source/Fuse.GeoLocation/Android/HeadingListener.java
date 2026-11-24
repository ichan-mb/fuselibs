package fuse.geolocation;

import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import com.foreign.Uno.Action_Object;

public class HeadingListener implements SensorEventListener
{
	private Action_Object _onHeadingChanged;

	public HeadingListener(Action_Object onHeadingChanged)
	{
		_onHeadingChanged = onHeadingChanged;
	}

	@Override
	public void onSensorChanged(SensorEvent event)
	{
		if (_onHeadingChanged != null)
			_onHeadingChanged.run(event);
	}

	@Override
	public void onAccuracyChanged(Sensor sensor, int accuracy)
	{
	}
}
