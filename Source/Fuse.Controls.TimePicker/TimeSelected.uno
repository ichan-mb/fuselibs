using Fuse.Triggers;

namespace Fuse.Controls
{
	/**
		Triggers when the user selects a time in the parent @TimePicker.

		Unlike the @TimePicker.ValueChanged event, this trigger only pulses when the user changes
		the time in the native picker. It does not pulse when `Value` is set programmatically.

		## Example

		```xml
			<TimePicker>
				<TimeSelected Handler="{onTimeSelected}">
					<!-- optional actions to perform when the user picks a time -->
				</TimeSelected>
			</TimePicker>
		```

		The handler receives a `TimeSelectedArgs` object containing `value` and `previousValue`.
	*/
	public class TimeSelected : PulseTrigger<TimeSelectedArgs>
	{
		TimePickerBase _timePicker;

		protected override void OnRooted()
		{
			base.OnRooted();

			_timePicker = GetNearestAncestorOfType<TimePickerBase>();
			if (_timePicker == null)
			{
				Fuse.Diagnostics.UserRootError("TimePicker", Parent, this);
				return;
			}

			_timePicker.TimeSelected += OnTimeSelected;
		}

		protected override void OnUnrooted()
		{
			if (_timePicker != null)
				_timePicker.TimeSelected -= OnTimeSelected;

			_timePicker = null;
			base.OnUnrooted();
		}

		void OnTimeSelected(object sender, TimeSelectedArgs args)
		{
			Pulse(args);
		}
	}
}
