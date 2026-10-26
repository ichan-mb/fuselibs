using Uno;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;

using Fuse;
using Fuse.Controls;

namespace Fuse.Controls.Native.Android
{
	extern(!Android) class DatePickerView
	{
		[UXConstructor]
		public DatePickerView([UXParameter("Host")]DatePicker host) { }
	}

	extern(Android) class DatePickerView : LeafView, IDatePickerView
	{
		DatePicker _host;
		Java.Object _datePicker;
		Java.Object _dateLabel;
		Java.Object _dialog;

		bool _suppressValueChanged;
		bool _hasMinValue;
		bool _hasMaxValue;
		DateTime _minValue;
		DateTime _maxValue;

		DatePickerStyle _style = DatePickerStyle.Default;
		string _locale = "";
		string _dateFormat = "";
		int _firstDayOfWeek;
		float4 _tintColor = float4(0);

		[UXConstructor]
		public DatePickerView([UXParameter("Host")]DatePicker host) : base(Create())
		{
			_host = host;

			_style = _host.Style;
			_locale = _host.Locale;
			_dateFormat = _host.DateFormat;
			_firstDayOfWeek = _host.FirstDayOfWeek;
			_tintColor = _host.TintColor;

			if (_host.HasMinValue)
			{
				_hasMinValue = true;
				_minValue = _host.MinValue;
			}
			if (_host.HasMaxValue)
			{
				_hasMaxValue = true;
				_maxValue = _host.MaxValue;
			}

			RecreateNativeControl();
		}

		public override void Dispose()
		{
			DismissDialog();
			base.Dispose();
			_host = null;
		}

		public DatePickerStyle Style
		{
			get { return _style; }
			set
			{
				if (value == _style && _datePicker != null)
					return;

				_style = value;
				RecreateNativeControl();
			}
		}

		public string DateFormat
		{
			set
			{
				value = value ?? "";
				if (value == _dateFormat)
					return;

				_dateFormat = value;
				UpdateLabel();
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
				if (_datePicker != null)
					RecreateNativeControl();
			}
		}

		public string Calendar
		{
			set
			{
				// Android does not expose a calendar-system property on DatePicker;
				// the calendar system follows the locale.
			}
		}

		public int FirstDayOfWeek
		{
			set
			{
				_firstDayOfWeek = value;
				if (_datePicker != null)
					ApplyFirstDayOfWeek(_datePicker, value);
			}
		}

		public float4 TintColor
		{
			set
			{
				_tintColor = value;
				if (_datePicker != null)
					ApplyTint(_datePicker, _dateLabel, value.X, value.Y, value.Z, value.W);
			}
		}

		public DateTime Value
		{
			get
			{
				if (_datePicker == null)
					return default(DateTime);

				var msSince1970InUtc = GetDateInMsSince1970InUtc(_datePicker);
				return DateTimeConverterHelpers.ConvertMsSince1970InUtcToDateTime(msSince1970InUtc);
			}
			set
			{
				if (_datePicker == null)
					return;

				var wasSuppressed = _suppressValueChanged;
				_suppressValueChanged = true;
				SetDate(_datePicker, _dateLabel, DateTimeConverterHelpers.ConvertDateTimeToMsSince1970InUtc(value), _dateFormat);
				_suppressValueChanged = wasSuppressed;
			}
		}

		public DateTime MinValue
		{
			set
			{
				_minValue = value;
				_hasMinValue = true;

				if (_datePicker == null)
					return;

				var wasSuppressed = _suppressValueChanged;
				_suppressValueChanged = true;
				SetMinValue(_datePicker, DateTimeConverterHelpers.ConvertDateTimeToMsSince1970InUtc(value));
				_suppressValueChanged = wasSuppressed;
			}
		}

		public DateTime MaxValue
		{
			set
			{
				_maxValue = value;
				_hasMaxValue = true;

				if (_datePicker == null)
					return;

				var wasSuppressed = _suppressValueChanged;
				_suppressValueChanged = true;
				SetMaxValue(_datePicker, DateTimeConverterHelpers.ConvertDateTimeToMsSince1970InUtc(value));
				_suppressValueChanged = wasSuppressed;
			}
		}

		void RecreateNativeControl()
		{
			DismissDialog();

			var wasSuppressed = _suppressValueChanged;
			_suppressValueChanged = true;
			SetStyle(Handle, (int)_style, _locale);
			ApplyNativeState();
			_suppressValueChanged = wasSuppressed;
		}

		void ApplyNativeState()
		{
			if (_datePicker == null || _host == null)
				return;

			if (_hasMinValue)
				SetMinValue(_datePicker, DateTimeConverterHelpers.ConvertDateTimeToMsSince1970InUtc(_minValue));
			if (_hasMaxValue)
				SetMaxValue(_datePicker, DateTimeConverterHelpers.ConvertDateTimeToMsSince1970InUtc(_maxValue));

			SetDate(_datePicker, _dateLabel, DateTimeConverterHelpers.ConvertDateTimeToMsSince1970InUtc(_host.Value), _dateFormat);
			ApplyFirstDayOfWeek(_datePicker, _firstDayOfWeek);
			ApplyTint(_datePicker, _dateLabel, _tintColor.X, _tintColor.Y, _tintColor.Z, _tintColor.W);
		}

		void UpdateLabel()
		{
			if (_datePicker == null || _dateLabel == null)
				return;

			var wasSuppressed = _suppressValueChanged;
			_suppressValueChanged = true;
			SetDate(_datePicker, _dateLabel, DateTimeConverterHelpers.ConvertDateTimeToMsSince1970InUtc(Value), _dateFormat);
			_suppressValueChanged = wasSuppressed;
		}

		void OnDateChanged()
		{
			if (_suppressValueChanged || _datePicker == null || _host == null)
				return;

			var value = Value;

			var wasSuppressed = _suppressValueChanged;
			_suppressValueChanged = true;
			SetDate(_datePicker, _dateLabel, DateTimeConverterHelpers.ConvertDateTimeToMsSince1970InUtc(value), _dateFormat);
			_suppressValueChanged = wasSuppressed;

			_host.OnNativeViewValueChanged(value, true);
		}

		void OnDialogCancelled()
		{
			if (_datePicker == null || _host == null)
				return;

			// The dialog's internal DatePicker is modified while the user scrolls, so restore
			// it to the host value when the dialog is cancelled.
			var wasSuppressed = _suppressValueChanged;
			_suppressValueChanged = true;
			SetDate(_datePicker, _dateLabel, DateTimeConverterHelpers.ConvertDateTimeToMsSince1970InUtc(_host.Value), _dateFormat);
			_suppressValueChanged = wasSuppressed;
		}

		// Some Android versions scroll the calendar to a bogus month after layout changes.
		// Rewriting the current value after layout settles forces it to scroll back to the
		// selected date.
		internal protected override void OnSizeChanged()
		{
			if (_datePicker == null || _dialog != null)
				return;

			UpdateManager.PerformNextFrame(Writeback, UpdateStage.Primary, 2);
		}

		void Writeback()
		{
			if (_datePicker == null || _dialog != null)
				return;

			var v = DateTimeConverterHelpers.ConvertDateTimeToMsSince1970InUtc(Value);

			var wasSuppressed = _suppressValueChanged;
			_suppressValueChanged = true;
			SetDate(_datePicker, _dateLabel, v - 1, _dateFormat); // Write temp value, as the picker won't scroll unless the value actually changes
			SetDate(_datePicker, _dateLabel, v, _dateFormat);
			_suppressValueChanged = wasSuppressed;
		}

		public void OnRooted()
		{
		}

		public void OnUnrooted()
		{
			DismissDialog();
			_datePicker = null;
			_dateLabel = null;
		}

		void DismissDialog()
		{
			if (_dialog == null)
				return;

			DismissDialogNative(_dialog);
			_dialog = null;
		}

		[Foreign(Language.Java)]
		static Java.Object Create()
		@{
			return com.fuse.android.widget.FusePickerUtils.createFrameLayout();
		@}

		[Foreign(Language.Java)]
		void SetStyle(Java.Object handle, int style, string locale)
		@{
			android.widget.FrameLayout frameLayout = (android.widget.FrameLayout)handle;
			frameLayout.removeAllViews();
			@{DatePickerView:of(_this)._dialog:set(null)};

			android.content.Context context = com.fuse.android.widget.FusePickerUtils.createContext(
				com.fuse.Activity.getRootActivity(), locale);

			if (style == 1) { // compact
				final android.app.DatePickerDialog pickerDialog = com.fuse.android.widget.FuseDatePicker.createDatePickerDialog(
					context,
					new android.app.DatePickerDialog.OnDateSetListener() {
						@Override
						public void onDateSet(android.widget.DatePicker view, int year, int monthOfYear, int dayOfMonth) {
							@{DatePickerView:of(_this).OnDateChanged():call()};
						}
					},
					1970, 0, 1, locale);
				pickerDialog.setOnCancelListener(new android.content.DialogInterface.OnCancelListener() {
					@Override
					public void onCancel(android.content.DialogInterface dialog) {
						@{DatePickerView:of(_this).OnDialogCancelled():call()};
					}
				});

				android.widget.TextView textview = com.fuse.android.widget.FusePickerUtils.createCompactLabel(context);
				textview.setOnClickListener(new android.view.View.OnClickListener() {
					@Override
					public void onClick(android.view.View v) {
						pickerDialog.show();
					}
				});
				frameLayout.addView(textview);
				@{DatePickerView:of(_this)._datePicker:set(pickerDialog.getDatePicker())};
				@{DatePickerView:of(_this)._dateLabel:set(textview)};
				@{DatePickerView:of(_this)._dialog:set(pickerDialog)};
			} else {
				android.widget.DatePicker datePicker = com.fuse.android.widget.FuseDatePicker.createDatePicker(context, locale);
				datePicker.setLayoutParams(new android.widget.FrameLayout.LayoutParams(android.view.ViewGroup.LayoutParams.MATCH_PARENT, android.view.ViewGroup.LayoutParams.MATCH_PARENT));
				@{DatePickerView:of(_this)._datePicker:set(datePicker)};
				@{DatePickerView:of(_this)._dateLabel:set(null)};
				datePicker.init(1970, 0, 1, new android.widget.DatePicker.OnDateChangedListener() {
					@Override
					public void onDateChanged(android.widget.DatePicker view, int year, int monthOfYear, int dayOfMonth) {
						@{DatePickerView:of(_this).OnDateChanged():call()};
					}
				});

				if (style == 2) { // inline: show the calendar
					datePicker.setCalendarViewShown(true);
					datePicker.setSpinnersShown(false);
				} else if (style == 3) { // wheels: show the spinners
					datePicker.setCalendarViewShown(false);
					datePicker.setSpinnersShown(true);
				}

				frameLayout.addView(datePicker);
			}
		@}

		[Foreign(Language.Java)]
		static void DismissDialogNative(Java.Object dialog)
		@{
			com.fuse.android.widget.FusePickerUtils.dismissDialog(dialog);
		@}

		[Foreign(Language.Java)]
		void SetDate(Java.Object datePickerHandle, Java.Object dateLabelHandle, long msSince1970InUtc, string dateFormat)
		@{
			java.util.Calendar cal = java.util.Calendar.getInstance(java.util.TimeZone.getTimeZone("UTC"), java.util.Locale.getDefault());
			cal.setTimeInMillis(msSince1970InUtc);

			int y = cal.get(java.util.Calendar.YEAR);
			int m = cal.get(java.util.Calendar.MONTH);
			int d = cal.get(java.util.Calendar.DAY_OF_MONTH);

			android.widget.DatePicker datePicker = (android.widget.DatePicker)datePickerHandle;
			datePicker.updateDate(y, m, d);
			android.widget.TextView textview = (android.widget.TextView)dateLabelHandle;
			if (textview != null) {
				textview.setText(com.fuse.android.widget.FusePickerUtils.formatDate(
					textview.getContext(), msSince1970InUtc, dateFormat));
			}
		@}

		[Foreign(Language.Java)]
		void ApplyFirstDayOfWeek(Java.Object datePickerHandle, int firstDayOfWeek)
		@{
			com.fuse.android.widget.FuseDatePicker.applyFirstDayOfWeek(
				(android.widget.DatePicker)datePickerHandle, firstDayOfWeek);
		@}

		[Foreign(Language.Java)]
		void ApplyTint(Java.Object datePickerHandle, Java.Object dateLabelHandle, float r, float g, float b, float a)
		@{
			com.fuse.android.widget.FuseDatePicker.applyTint(
				(android.widget.DatePicker)datePickerHandle,
				(android.widget.TextView)dateLabelHandle,
				r, g, b, a);
		@}

		[Foreign(Language.Java)]
		long GetDateInMsSince1970InUtc(Java.Object datePickerHandle)
		@{
			android.widget.DatePicker datePicker = (android.widget.DatePicker)datePickerHandle;

			java.util.Calendar cal = java.util.Calendar.getInstance(
				java.util.TimeZone.getTimeZone("UTC"), java.util.Locale.getDefault());
			cal.clear();
			cal.set(datePicker.getYear(), datePicker.getMonth(), datePicker.getDayOfMonth(), 0, 0, 0);

			return cal.getTimeInMillis();
		@}

		[Foreign(Language.Java)]
		void SetMinValue(Java.Object datePickerHandle, long msSince1970InUtc)
		@{
			android.widget.DatePicker datePicker = (android.widget.DatePicker)datePickerHandle;
			datePicker.setMinDate(com.fuse.android.widget.FusePickerUtils.toDefaultTimezoneTicks(msSince1970InUtc));
		@}

		[Foreign(Language.Java)]
		void SetMaxValue(Java.Object datePickerHandle, long msSince1970InUtc)
		@{
			android.widget.DatePicker datePicker = (android.widget.DatePicker)datePickerHandle;
			datePicker.setMaxDate(com.fuse.android.widget.FusePickerUtils.toDefaultTimezoneTicks(msSince1970InUtc));
		@}
	}
}
