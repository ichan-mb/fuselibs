using Uno;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;

using Fuse.Controls;

namespace Fuse.Controls.Native.iOS
{
	extern(!iOS) class DatePickerView
	{
		[UXConstructor]
		public DatePickerView([UXParameter("Host")]DatePicker host) { }
	}

	[Require("source.include", "UIKit/UIKit.h")]
	extern(iOS) class DatePickerView : LeafView, IDatePickerView
	{
		DatePicker _host;
		IDisposable _valueChangedEvent;
		bool _suppressValueChanged;

		string _locale = "";
		string _calendar = "";
		int _firstDayOfWeek;
		float4 _tintColor = float4(0);

		[UXConstructor]
		public DatePickerView([UXParameter("Host")]DatePicker host) : base(Create())
		{
			_host = host;

			_locale = _host.Locale;
			_calendar = _host.Calendar;
			_firstDayOfWeek = _host.FirstDayOfWeek;
			_tintColor = _host.TintColor;

			if (_host.HasMinValue)
				MinValue = _host.MinValue;
			if (_host.HasMaxValue)
				MaxValue = _host.MaxValue;
			Value = _host.Value;
			Style = _host.Style;

			ApplyLocaleAndCalendar();
			ApplyTint();

			_valueChangedEvent = UIControlEvent.AddValueChangedCallback(Handle, OnValueChanged);
		}

		public override void Dispose()
		{
			base.Dispose();
			if (_valueChangedEvent != null)
				_valueChangedEvent.Dispose();
			_valueChangedEvent = null;
			_host = null;
		}

		void OnValueChanged(ObjC.Object sender, ObjC.Object args)
		{
			if (_suppressValueChanged || _host == null)
				return;

			_host.OnNativeViewValueChanged(Value, true);
		}

		public DatePickerStyle Style
		{
			get
			{
				var style = GetDatePickerStyle(Handle);
				switch (style)
				{
					case 0:
						return DatePickerStyle.Default;
					case 1:
						return DatePickerStyle.Compact;
					case 2:
						return DatePickerStyle.Inline;
					case 3:
						return DatePickerStyle.Wheels;
					default:
						return DatePickerStyle.Default;
				}
			}
			set
			{
				SetDatePickerStyle(Handle, value);

				// Some iOS versions reset the selected date when the preferred style changes,
				// so re-apply the value from the host after changing the style.
				if (_host != null)
					Value = _host.Value;
			}
		}

		public string DateFormat
		{
			set
			{
				// iOS renders the compact label itself; this property is Android-only.
			}
		}

		public string Locale
		{
			set
			{
				value = value ?? "";
				if (value == _locale)
					return;

				_locale = value;
				ApplyLocaleAndCalendar();
			}
		}

		public string Calendar
		{
			set
			{
				value = value ?? "";
				if (value == _calendar)
					return;

				_calendar = value;
				ApplyLocaleAndCalendar();
			}
		}

		public int FirstDayOfWeek
		{
			set
			{
				if (value == _firstDayOfWeek)
					return;

				_firstDayOfWeek = value;
				ApplyLocaleAndCalendar();
			}
		}

		public float4 TintColor
		{
			set
			{
				_tintColor = value;
				ApplyTint();
			}
		}

		public DateTime Value
		{
			get { return DateTimeConverterHelpers.ConvertNSDateToDateTime(DateTimeConverterHelpers.ReconstructUtcDate(GetDate(Handle))); }
			set
			{
				var wasSuppressed = _suppressValueChanged;
				_suppressValueChanged = true;
				SetDate(Handle, DateTimeConverterHelpers.ReconstructUtcDate(DateTimeConverterHelpers.ConvertDateTimeToNSDate(value)));
				_suppressValueChanged = wasSuppressed;
			}
		}

		public DateTime MinValue
		{
			set { SetMinValue(Handle, DateTimeConverterHelpers.ReconstructUtcDate(DateTimeConverterHelpers.ConvertDateTimeToNSDate(value))); }
		}

		public DateTime MaxValue
		{
			set { SetMaxValue(Handle, DateTimeConverterHelpers.ReconstructUtcDate(DateTimeConverterHelpers.ConvertDateTimeToNSDate(value))); }
		}

		void ApplyLocaleAndCalendar()
		{
			if (_host == null)
				return;

			var wasSuppressed = _suppressValueChanged;
			_suppressValueChanged = true;
			SetLocaleAndCalendar(Handle, _locale, _calendar, _firstDayOfWeek);
			Value = _host.Value;
			_suppressValueChanged = wasSuppressed;
		}

		void ApplyTint()
		{
			if (_host == null)
				return;

			SetTintColor(Handle, _tintColor.X, _tintColor.Y, _tintColor.Z, _tintColor.W);
		}

		public void OnRooted()
		{
		}

		public void OnUnrooted()
		{
		}

		[Foreign(Language.ObjC)]
		static ObjC.Object Create()
		@{
			UIDatePicker *dp = [[UIDatePicker alloc] init];

			[dp setDatePickerMode:UIDatePickerModeDate];

			// Make sure the date picker interprets date values in UTC
			[dp setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

			return dp;
		@}

		[Foreign(Language.ObjC)]
		void SetLocaleAndCalendar(ObjC.Object datePickerHandle, string localeId, string calendarId, int firstDayOfWeek)
		@{
			UIDatePicker* dp = (UIDatePicker*)datePickerHandle;

			if (localeId == nil || [localeId length] == 0)
				[dp setLocale:nil];
			else
				[dp setLocale:[NSLocale localeWithLocaleIdentifier:localeId]];

			NSCalendar* calendar = nil;
			if (calendarId != nil && [calendarId length] > 0)
			{
				@try
				{
					calendar = [[NSCalendar alloc] initWithCalendarIdentifier:calendarId];
				}
				@catch (NSException* e)
				{
					calendar = nil;
				}
			}

			if (calendar == nil)
				calendar = [dp calendar];

			if (calendar == nil && firstDayOfWeek >= 1 && firstDayOfWeek <= 7)
				calendar = [NSCalendar currentCalendar];

			if (calendar != nil)
			{
				if (firstDayOfWeek >= 1 && firstDayOfWeek <= 7)
				{
					calendar = (NSCalendar*)[calendar copy];
					[calendar setFirstWeekday:(NSInteger)firstDayOfWeek];
				}
				[dp setCalendar:calendar];
			}
		@}

		[Foreign(Language.ObjC)]
		void SetTintColor(ObjC.Object datePickerHandle, float r, float g, float b, float a)
		@{
			UIDatePicker* dp = (UIDatePicker*)datePickerHandle;
			if (a <= 0)
				[dp setTintColor:nil];
			else
				[dp setTintColor:[UIColor colorWithRed:r green:g blue:b alpha:a]];
		@}

		[Foreign(Language.ObjC)]
		void SetDate(ObjC.Object datePickerHandle, ObjC.Object date)
		@{
			UIDatePicker *dp = (UIDatePicker *)datePickerHandle;

			[dp setDate:date animated:false];
		@}

		[Foreign(Language.ObjC)]
		ObjC.Object GetDate(ObjC.Object datePickerHandle)
		@{
			UIDatePicker *dp = (UIDatePicker *)datePickerHandle;

			return [dp date];
		@}

		[Foreign(Language.ObjC)]
		void SetMinValue(ObjC.Object datePickerHandle, ObjC.Object date)
		@{
			UIDatePicker *dp = (UIDatePicker *)datePickerHandle;

			[dp setMinimumDate:date];
		@}

		[Foreign(Language.ObjC)]
		void SetMaxValue(ObjC.Object datePickerHandle, ObjC.Object date)
		@{
			UIDatePicker *dp = (UIDatePicker *)datePickerHandle;

			[dp setMaximumDate:date];
		@}

		[Foreign(Language.ObjC)]
		int GetDatePickerStyle(ObjC.Object datePickerHandle)
		@{
			#if defined(__IPHONE_13_4) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_4
			if (@available(iOS 13.4, *))
			{
				UIDatePicker *dp = (UIDatePicker *)datePickerHandle;
				UIDatePickerStyle style = dp.datePickerStyle;
				switch(style)
				{
					case UIDatePickerStyleAutomatic:
						return 0;
					case UIDatePickerStyleCompact:
						return 1;
					case UIDatePickerStyleInline:
						return 2;
					case UIDatePickerStyleWheels:
						return 3;
				}
			}
			#endif
			return 0;
		@}

		[Foreign(Language.ObjC)]
		void SetDatePickerStyle(ObjC.Object datePickerHandle, int style)
		@{
			#if defined(__IPHONE_13_4) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_4
			if (@available(iOS 13.4, *))
			{
				UIDatePicker *dp = (UIDatePicker *)datePickerHandle;
				UIDatePickerStyle datePickerStyle = UIDatePickerStyleAutomatic;
				switch (style)
				{
					case 0:
						datePickerStyle = UIDatePickerStyleAutomatic;
						break;
					case 1:
						datePickerStyle = UIDatePickerStyleCompact;
						break;
					case 2:
						datePickerStyle = UIDatePickerStyleInline;
						break;
					case 3:
						datePickerStyle = UIDatePickerStyleWheels;
						break;
				}
				[dp setPreferredDatePickerStyle:datePickerStyle];
			}
			#endif
		@}

	}

}
