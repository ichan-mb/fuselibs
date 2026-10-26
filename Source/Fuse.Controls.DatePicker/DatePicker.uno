using Uno;
using Uno.UX;

using Fuse.Scripting;

namespace Fuse.Controls
{
	interface IDatePickerView
	{
		DateTime Value { set; }
		DateTime MinValue { set; }
		DateTime MaxValue { set; }
		DatePickerStyle Style { set; }
		string DateFormat { set; }
		string Locale { set; }
		string Calendar { set; }
		int FirstDayOfWeek { set; }
		float4 TintColor { set; }

		void OnRooted();
		void OnUnrooted();
	}

	/** Available DatePicker style */
	public enum DatePickerStyle
	{
		/** The platform default style. */
		Default,
		/** A compact date label that opens a picker when tapped. */
		Compact,
		/** An inline calendar style. On Android this selects the calendar view. */
		Inline,
		/** Wheel/spinner style. On Android this selects the spinner view where supported. */
		Wheels
	}

	/** Arguments for the @DatePicker.ValueChanged event. */
	public class DatePickerValueChangedArgs : ValueChangedArgs<DateTime>, IScriptEvent
	{
		public DatePickerValueChangedArgs(DateTime value) : base(value) { }

		void IScriptEvent.Serialize(IEventSerializer s)
		{
			s.AddObject("value", Value);
		}
	}

	/** Arguments for the @DatePicker.DateSelected event. */
	public class DateSelectedArgs : EventArgs, IScriptEvent
	{
		/** The newly selected date. */
		public DateTime Value { get; private set; }

		/** The previously selected date. */
		public DateTime PreviousValue { get; private set; }

		public DateSelectedArgs(DateTime value, DateTime previousValue)
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

	public abstract partial class DatePickerBase : Panel
	{
		const long TicksPerDay = 864000000000L;

		static DateTime TruncateToUtcDate(DateTime value)
		{
			var ticks = value.Ticks;
			return new DateTime(ticks - (ticks % TicksPerDay), DateTimeKind.Utc);
		}

		static Selector _styleName = "Style";

		DatePickerStyle _style = DatePickerStyle.Default;
		[UXOriginSetter("SetStyle")]
		/** DatePicker style */
		public DatePickerStyle Style
		{
			get { return _style; }
			set { SetStyle(value, this); }
		}

		public void SetStyle(DatePickerStyle value, IPropertyListener origin)
		{
			if (value != _style)
			{
				_style = value;
				OnStyleValueChanged(origin);
				InvalidateLayout();
			}

			var dpv = DatePickerView;
			if (dpv != null)
				dpv.Style = value;
		}

		internal void OnStyleValueChanged(IPropertyListener origin)
		{
			OnPropertyChanged(_styleName, origin);
		}

		static Selector _dateFormatName = "DateFormat";

		string _dateFormat = "";
		[UXOriginSetter("SetDateFormat")]
		/**
			Gets or sets the date format used by the compact label on Android. The value is a `java.text.SimpleDateFormat` pattern, for example `EEE, MMM d, yyyy`. Ignored on iOS, where the compact label is rendered by the system.

			@default "" (locale medium date format)
		*/
		public string DateFormat
		{
			get { return _dateFormat; }
			set { SetDateFormat(value, this); }
		}

		public void SetDateFormat(string value, IPropertyListener origin)
		{
			value = value ?? "";
			if (value != _dateFormat)
			{
				_dateFormat = value;
				OnPropertyChanged(_dateFormatName, origin);
				InvalidateLayout();
			}

			var dpv = DatePickerView;
			if (dpv != null)
				dpv.DateFormat = value;
		}

		static Selector _localeName = "Locale";

		string _locale = "";
		[UXOriginSetter("SetLocale")]
		/**
			Gets or sets the BCP-47 locale identifier used by the native picker, for example `en-US` or `fr-FR`. An empty string uses the device locale.

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

			var dpv = DatePickerView;
			if (dpv != null)
				dpv.Locale = value;
		}

		static Selector _calendarName = "Calendar";

		string _calendar = "";
		[UXOriginSetter("SetCalendar")]
		/**
			Gets or sets the calendar identifier used by the picker. On iOS this is an `NSCalendarIdentifier`, for example `gregorian`, `islamic`, `buddhist`, `japanese`, or `hebrew`. Ignored on Android, where the calendar system follows the locale.

			@default ""
		*/
		public string Calendar
		{
			get { return _calendar; }
			set { SetCalendar(value, this); }
		}

		public void SetCalendar(string value, IPropertyListener origin)
		{
			value = value ?? "";
			if (value != _calendar)
			{
				_calendar = value;
				OnPropertyChanged(_calendarName, origin);
				InvalidateLayout();
			}

			var dpv = DatePickerView;
			if (dpv != null)
				dpv.Calendar = value;
		}

		static Selector _firstDayOfWeekName = "FirstDayOfWeek";

		int _firstDayOfWeek;
		[UXOriginSetter("SetFirstDayOfWeek")]
		/**
			Gets or sets the first day of the week, using the `java.util.Calendar` numbering: 1 is Sunday, 2 is Monday, ... and 7 is Saturday. 0 uses the locale default.

			@default 0
		*/
		public int FirstDayOfWeek
		{
			get { return _firstDayOfWeek; }
			set { SetFirstDayOfWeek(value, this); }
		}

		public void SetFirstDayOfWeek(int value, IPropertyListener origin)
		{
			if (value < 0 || value > 7)
			{
				Fuse.Diagnostics.UserError("DatePicker.FirstDayOfWeek must be between 0 (locale default) and 7 (Saturday)", this);
				return;
			}

			if (value != _firstDayOfWeek)
			{
				_firstDayOfWeek = value;
				OnPropertyChanged(_firstDayOfWeekName, origin);
				InvalidateLayout();
			}

			var dpv = DatePickerView;
			if (dpv != null)
				dpv.FirstDayOfWeek = value;
		}

		static Selector _tintColorName = "TintColor";

		float4 _tintColor = float4(0);
		[UXOriginSetter("SetTintColor")]
		/**
			Gets or sets the accent color used by the native picker. On iOS this maps to `UIDatePicker.tintColor`. On Android it is applied on a best-effort basis to the compact label and calendar highlights. A fully transparent color uses the platform default.

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

			var dpv = DatePickerView;
			if (dpv != null)
				dpv.TintColor = value;
		}

		static Selector _valueName = "Value";

		DateTime _value = TruncateToUtcDate(DateTime.UtcNow);
		[UXOriginSetter("SetValue")]
		/**
			Gets or sets the current date value selected by the `DatePicker`. The value is normalized to midnight UTC, and clamped to the range specified by `MinValue` and `MaxValue` if these have been set.
		*/
		public DateTime Value
		{
			get { return _value; }
			set { SetValue(value, this); }
		}

		public void SetValue(DateTime value, IPropertyListener origin)
		{
			value = ClampToRange(TruncateToUtcDate(value));
			UpdateValue(value, origin);

			var dpv = DatePickerView;
			if (dpv != null)
				dpv.Value = _value;
		}

		void UpdateValue(DateTime value, IPropertyListener origin)
		{
			if (value != _value)
			{
				_value = value;
				OnValueChanged(origin);

				if (ValueChanged != null)
					ValueChanged(this, new DatePickerValueChangedArgs(value));
			}
		}

		/**
			Raised whenever `Value` changes, including programmatic changes.
		*/
		public event ValueChangedHandler<DateTime> ValueChanged;

		internal void OnValueChanged(IPropertyListener origin)
		{
			OnPropertyChanged(_valueName, origin);
		}

		internal void OnNativeViewValueChanged(DateTime newValue, bool isUserInitiated)
		{
			newValue = ClampToRange(TruncateToUtcDate(newValue));
			var previousValue = _value;
			UpdateValue(newValue, this);

			if (isUserInitiated && newValue != previousValue)
				OnDateSelected(newValue, previousValue);
		}

		/**
			Raised when the user selects a date in the native picker. Does not fire for programmatic changes to `Value`.
		*/
		public event EventHandler<DateSelectedArgs> DateSelected;

		void OnDateSelected(DateTime value, DateTime previousValue)
		{
			if (DateSelected != null)
				DateSelected(this, new DateSelectedArgs(value, previousValue));
		}

		static Selector _minValueName = "MinValue";

		// Min/Max are optional. default(DateTime) is year 1, so track whether a bound was explicitly set.
		DateTime _minValue;
		bool _hasMinValue;
		[UXOriginSetter("SetMinValue")]
		/**
			Gets or sets the minimum date value that can be selected by the `DatePicker`. If not set, the `DatePicker` does not constrain the range in this direction. The value is normalized to midnight UTC. Must not be higher than `MaxValue` if it has been specified.
		*/
		public DateTime MinValue
		{
			get { return _minValue; }
			set { SetMinValue(value, this); }
		}

		internal bool HasMinValue
		{
			get { return _hasMinValue; }
		}

		public void SetMinValue(DateTime value, IPropertyListener origin)
		{
			value = TruncateToUtcDate(value);

			if (!_hasMinValue || value != _minValue)
			{
				_minValue = value;
				_hasMinValue = true;
				OnMinValueChanged(origin);
			}

			if (!IsRangeValid)
				Fuse.Diagnostics.UserError("DatePicker.MinValue can not be greater than MaxValue", this);
			else
				ApplyRange(origin);
		}

		internal void OnMinValueChanged(IPropertyListener origin)
		{
			OnPropertyChanged(_minValueName, origin);
		}

		static Selector _maxValueName = "MaxValue";

		DateTime _maxValue;
		bool _hasMaxValue;
		[UXOriginSetter("SetMaxValue")]
		/**
			Gets or sets the maximum date value that can be selected by the `DatePicker`. If not set, the `DatePicker` does not constrain the range in this direction. The value is normalized to midnight UTC. Must not be lower than `MinValue` if it has been specified.
		*/
		public DateTime MaxValue
		{
			get { return _maxValue; }
			set { SetMaxValue(value, this); }
		}

		internal bool HasMaxValue
		{
			get { return _hasMaxValue; }
		}

		public void SetMaxValue(DateTime value, IPropertyListener origin)
		{
			value = TruncateToUtcDate(value);

			if (!_hasMaxValue || value != _maxValue)
			{
				_maxValue = value;
				_hasMaxValue = true;
				OnMaxValueChanged(origin);
			}

			if (!IsRangeValid)
				Fuse.Diagnostics.UserError("DatePicker.MaxValue can not be less than MinValue", this);
			else
				ApplyRange(origin);
		}

		internal void OnMaxValueChanged(IPropertyListener origin)
		{
			OnPropertyChanged(_maxValueName, origin);
		}

		bool IsRangeValid
		{
			get { return !_hasMinValue || !_hasMaxValue || _minValue.Ticks <= _maxValue.Ticks; }
		}

		DateTime ClampToRange(DateTime value)
		{
			if (!IsRangeValid)
				return value;

			if (_hasMinValue && value.Ticks < _minValue.Ticks)
				value = _minValue;
			if (_hasMaxValue && value.Ticks > _maxValue.Ticks)
				value = _maxValue;

			return value;
		}

		void ApplyRange(IPropertyListener origin)
		{
			if (!IsRangeValid)
				return;

			var clamped = ClampToRange(_value);
			if (clamped != _value)
				UpdateValue(clamped, origin);

			var dpv = DatePickerView;
			if (dpv != null)
			{
				if (_hasMinValue)
					dpv.MinValue = _minValue;
				if (_hasMaxValue)
					dpv.MaxValue = _maxValue;

				dpv.Value = _value;
			}
		}

		IDatePickerView DatePickerView
		{
			get { return (IDatePickerView)NativeView; }
		}

		protected override void OnRooted()
		{
			base.OnRooted();

			var dpv = DatePickerView;
			if (dpv != null)
				dpv.OnRooted();
		}

		protected override void OnUnrooted()
		{
			var dpv = DatePickerView;
			if (dpv != null)
				dpv.OnUnrooted();

			base.OnUnrooted();
		}
	}
}
