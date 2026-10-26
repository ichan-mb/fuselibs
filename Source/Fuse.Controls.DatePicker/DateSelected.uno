using Fuse.Triggers;

namespace Fuse.Controls
{
	/**
		Triggers when the user selects a date in the parent @DatePicker.

		Unlike the @DatePicker.ValueChanged event, this trigger only pulses when the user changes
		the date in the native picker. It does not pulse when `Value` is set programmatically.

		## Example

		```xml
			<DatePicker>
				<DateSelected Handler="{onDateSelected}">
					<!-- optional actions to perform when the user picks a date -->
				</DateSelected>
			</DatePicker>
		```

		The handler receives a `DateSelectedArgs` object containing `value` and `previousValue`.
	*/
	public class DateSelected : PulseTrigger<DateSelectedArgs>
	{
		DatePickerBase _datePicker;

		protected override void OnRooted()
		{
			base.OnRooted();

			_datePicker = GetNearestAncestorOfType<DatePickerBase>();
			if (_datePicker == null)
			{
				Fuse.Diagnostics.UserRootError("DatePicker", Parent, this);
				return;
			}

			_datePicker.DateSelected += OnDateSelected;
		}

		protected override void OnUnrooted()
		{
			if (_datePicker != null)
				_datePicker.DateSelected -= OnDateSelected;

			_datePicker = null;
			base.OnUnrooted();
		}

		void OnDateSelected(object sender, DateSelectedArgs args)
		{
			Pulse(args);
		}
	}
}
