using Uno;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;

using Fuse.Controls;

namespace Fuse.Controls.Native.iOS
{
	extern(!iOS) class TimePickerView
	{
		[UXConstructor]
		public TimePickerView([UXParameter("Host")]TimePicker host) { }
	}

	[Require("source.include", "UIKit/UIKit.h")]
	extern(iOS) class TimePickerView : LeafView, ITimePickerView
	{
		TimePicker _host;
		IDisposable _valueChangedEvent;
		bool _suppressValueChanged;

		string _locale = "";
		float4 _tintColor = float4(0);

		[UXConstructor]
		public TimePickerView([UXParameter("Host")]TimePicker host) : base(Create())
		{
			_host = host;

			_locale = _host.Locale;
			_tintColor = _host.TintColor;

			Value = _host.Value;
			Style = _host.Style;

			ApplyLocale();
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

		public TimePickerStyle Style
		{
			get
			{
				var style = GetTimePickerStyle(Handle);
				switch (style)
				{
					case 0:
						return TimePickerStyle.Default;
					case 1:
						return TimePickerStyle.Compact;
					case 2:
						return TimePickerStyle.Inline;
					case 3:
						return TimePickerStyle.Wheels;
					default:
						return TimePickerStyle.Default;
				}
			}
			set
			{
				SetTimePickerStyle(Handle, value);

				// Some iOS versions reset the selected time when the preferred style changes,
				// so re-apply the value from the host after changing the style.
				if (_host != null)
					Value = _host.Value;
			}
		}

		// Dummy property: UIDatePicker does not expose an explicit 12/24-hour API.
		// Use Locale to select a locale with the preferred time format.
		public bool Is24HourView
		{
			set
			{
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
				ApplyLocale();
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
			get { return DateTimeConverterHelpers.ConvertNSDateToDateTime(DateTimeConverterHelpers.ReconstructUtcTime(GetTime(Handle))); }
			set
			{
				var wasSuppressed = _suppressValueChanged;
				_suppressValueChanged = true;
				SetTime(Handle, DateTimeConverterHelpers.ReconstructUtcTime(DateTimeConverterHelpers.ConvertDateTimeToNSDate(value)));
				_suppressValueChanged = wasSuppressed;
			}
		}

		void ApplyLocale()
		{
			if (_host == null)
				return;

			var wasSuppressed = _suppressValueChanged;
			_suppressValueChanged = true;
			SetLocale(Handle, _locale);
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

			[dp setDatePickerMode:UIDatePickerModeTime];

			// Make sure the time picker interprets date values in UTC
			[dp setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

			return dp;
		@}

		[Foreign(Language.ObjC)]
		void SetLocale(ObjC.Object timePickerHandle, string localeId)
		@{
			UIDatePicker* dp = (UIDatePicker*)timePickerHandle;

			if (localeId == nil || [localeId length] == 0)
				[dp setLocale:nil];
			else
				[dp setLocale:[NSLocale localeWithLocaleIdentifier:localeId]];
		@}

		[Foreign(Language.ObjC)]
		void SetTintColor(ObjC.Object timePickerHandle, float r, float g, float b, float a)
		@{
			UIDatePicker* dp = (UIDatePicker*)timePickerHandle;
			if (a <= 0)
				[dp setTintColor:nil];
			else
				[dp setTintColor:[UIColor colorWithRed:r green:g blue:b alpha:a]];
		@}

		[Foreign(Language.ObjC)]
		void SetTime(ObjC.Object datePickerHandle, ObjC.Object time)
		@{
			UIDatePicker *dp = (UIDatePicker *)datePickerHandle;

			[dp setDate:time animated:false];
		@}

		[Foreign(Language.ObjC)]
		ObjC.Object GetTime(ObjC.Object datePickerHandle)
		@{
			UIDatePicker *dp = (UIDatePicker *)datePickerHandle;

			return [dp date];
		@}

		[Foreign(Language.ObjC)]
		int GetTimePickerStyle(ObjC.Object timePickerHandle)
		@{
			#if defined(__IPHONE_13_4) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_4
			if (@available(iOS 13.4, *))
			{
				UIDatePicker *dp = (UIDatePicker *)timePickerHandle;
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
		void SetTimePickerStyle(ObjC.Object timePickerHandle, int style)
		@{
			#if defined(__IPHONE_13_4) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_4
			if (@available(iOS 13.4, *))
			{
				UIDatePicker *dp = (UIDatePicker *)timePickerHandle;
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
