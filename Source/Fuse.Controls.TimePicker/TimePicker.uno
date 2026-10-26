using Uno;
using Uno.UX;

using Fuse.Scripting;

namespace Fuse.Controls
{
	interface ITimePickerView
	{
		DateTime Value { set; }
		bool Is24HourView { set; }
		TimePickerStyle Style { set; }
		string Locale { set; }
		float4 TintColor { set; }

		void OnRooted();
		void OnUnrooted();
	}

	/** Available TimePicker style */
	public enum TimePickerStyle
	{
		Default,
		Compact,
		Inline,
		/** Only available on iOS */
		Wheels
	}

	/** Arguments for the @TimePicker.ValueChanged event. */
	public class TimePickerValueChangedArgs : ValueChangedArgs<DateTime>, IScriptEvent
	{
		public TimePickerValueChangedArgs(DateTime value) : base(value) { }

		void IScriptEvent.Serialize(IEventSerializer s)
		{
			s.AddObject("value", Value);
		}
	}

	/** Arguments for the @TimePicker.TimeSelected event. */
	public class TimeSelectedArgs : EventArgs, IScriptEvent
	{
		/** The newly selected time. */
		public DateTime Value { get; private set; }

		/** The previously selected time. */
		public DateTime PreviousValue { get; private set; }

		public TimeSelectedArgs(DateTime value, DateTime previousValue)
		{
			Value = value;
			PreviousValue = previousValue;
		}

		void IScriptEvent.Serialize(IEventSerializer s)
		{
			s.AddObject("value", Value);
			s.AddObject("previousValue", PreviousValue);
		}
	}

	public abstract partial class TimePickerBase : Panel
	{
		const long TicksPerDay = 864000000000L;
		const long TicksPerMinute = 600000000L;
		const long UnixEpochTicks = 621355968000000000L;

		static DateTime NormalizeTimeOfDay(DateTime value)
		{
			var timeTicks = value.Ticks % TicksPerDay;
			timeTicks -= timeTicks % TicksPerMinute;
			return new DateTime(UnixEpochTicks + timeTicks, DateTimeKind.Utc);
		}

		static Selector _styleName = "Style";

		TimePickerStyle _style = TimePickerStyle.Default;
		[UXOriginSetter("SetStyle")]
		/** TimePicker style */
		public TimePickerStyle Style
		{
			get { return _style; }
			set { SetStyle(value, this); }
		}

		public void SetStyle(TimePickerStyle value, IPropertyListener origin)
		{
			if (value != _style)
			{
				_style = value;
				OnStyleValueChanged(origin);
				InvalidateLayout();
			}

			var tpv = TimePickerView;
			if (tpv != null)
				tpv.Style = value;
		}

		internal void OnStyleValueChanged(IPropertyListener origin)
		{
			OnPropertyChanged(_styleName, origin);
		}

		static Selector _valueName = "Value";

		DateTime _value = NormalizeTimeOfDay(DateTime.UtcNow);
		[UXOriginSetter("SetValue")]
		/**
			Gets or sets the current time value selected by the `TimePicker`. The date component is normalized to 1 January 1970 UTC, and seconds and milliseconds are truncated.
		*/
		public DateTime Value
		{
			get { return _value; }
			set { SetValue(value, this); }
		}

		public void SetValue(DateTime value, IPropertyListener origin)
		{
			value = NormalizeTimeOfDay(value);
			UpdateValue(value, origin);

			var tpv = TimePickerView;
			if (tpv != null)
				tpv.Value = _value;
		}

		void UpdateValue(DateTime value, IPropertyListener origin)
		{
			if (value != _value)
			{
				_value = value;
				OnValueChanged(origin);

				if (ValueChanged != null)
					ValueChanged(this, new TimePickerValueChangedArgs(value));
			}
		}

		/**
			Raised whenever `Value` changes, including programmatic changes.
		*/
		public event ValueChangedHandler<DateTime> ValueChanged;

		void OnValueChanged(IPropertyListener origin)
		{
			OnPropertyChanged(_valueName, origin);
		}

		internal void OnNativeViewValueChanged(DateTime newValue, bool isUserInitiated)
		{
			newValue = NormalizeTimeOfDay(newValue);
			var previousValue = _value;
			UpdateValue(newValue, this);

			if (isUserInitiated && newValue != previousValue)
				OnTimeSelected(newValue, previousValue);
		}

		/**
			Raised when the user selects a time in the native picker. Does not fire for programmatic changes to `Value`.
		*/
		public event EventHandler<TimeSelectedArgs> TimeSelected;

		void OnTimeSelected(DateTime value, DateTime previousValue)
		{
			if (TimeSelected != null)
				TimeSelected(this, new TimeSelectedArgs(value, previousValue));
		}

		static Selector _is24HourViewName = "Is24HourView";

		bool _is24HourView;
		[UXOriginSetter("SetIs24HourView")]
		/**
			Used to toggle 24-hour or am/pm view. Default is false (am/pm).

			Currently only implemented for Android. On iOS, use @TimePicker.Locale to select a locale whose preferred time format matches the desired mode, as `UIDatePicker` does not expose an explicit 12/24-hour API.
		*/
		public bool Is24HourView
		{
			get { return _is24HourView; }
			set { SetIs24HourView(value, this); }
		}

		public void SetIs24HourView(bool value, IPropertyListener origin)
		{
			if (value != _is24HourView)
			{
				_is24HourView = value;
				OnIs24HourViewChanged(origin);
				InvalidateLayout();
			}

			var tpv = TimePickerView;
			if (tpv != null)
				tpv.Is24HourView = value;
		}

		void OnIs24HourViewChanged(IPropertyListener origin)
		{
			OnPropertyChanged(_is24HourViewName, origin);
		}

		static Selector _localeName = "Locale";

		string _locale = "";
		[UXOriginSetter("SetLocale")]
		/**
			Gets or sets the BCP-47 locale identifier used by the native picker, for example `en-US` or `fr-FR`. An empty string uses the device locale. On iOS this also determines whether the picker uses a 12-hour or 24-hour clock.

			@default ""
		*/
		public string Locale
		{
			get { return _locale; }
			set { SetLocale(value, this); }
		}

		public void SetLocale(string value, IPropertyListener origin)
		{
			value = value ?? "";
			if (value != _locale)
			{
				_locale = value;
				OnPropertyChanged(_localeName, origin);
				InvalidateLayout();
			}

			var tpv = TimePickerView;
			if (tpv != null)
				tpv.Locale = value;
		}

		static Selector _tintColorName = "TintColor";

		float4 _tintColor = float4(0);
		[UXOriginSetter("SetTintColor")]
		/**
			Gets or sets the accent color used by the native picker. On iOS this maps to `UIDatePicker.tintColor`. On Android it is applied on a best-effort basis to the compact label. A fully transparent color uses the platform default.

			@default float4(0) (platform default)
		*/
		public float4 TintColor
		{
			get { return _tintColor; }
			set { SetTintColor(value, this); }
		}

		public void SetTintColor(float4 value, IPropertyListener origin)
		{
			if (value != _tintColor)
			{
				_tintColor = value;
				OnPropertyChanged(_tintColorName, origin);
			}

			var tpv = TimePickerView;
			if (tpv != null)
				tpv.TintColor = value;
		}

		ITimePickerView TimePickerView
		{
			get { return (ITimePickerView)NativeView; }
		}

		protected override void OnRooted()
		{
			base.OnRooted();

			var tpv = TimePickerView;
			if (tpv != null)
				tpv.OnRooted();
		}

		protected override void OnUnrooted()
		{
			var tpv = TimePickerView;
			if (tpv != null)
				tpv.OnUnrooted();

			base.OnUnrooted();
		}
	}
}
