using Uno;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;

using Fuse;
using Fuse.Controls;

namespace Fuse.Controls.Native.Android
{
	extern(!Android) class TimePickerView
	{
		[UXConstructor]
		public TimePickerView([UXParameter("Host")]TimePicker host) { }
	}

	extern(Android) class TimePickerView : LeafView, ITimePickerView
	{
		TimePicker _host;
		Java.Object _timePicker;
		Java.Object _timeLabel;
		Java.Object _dialog;

		bool _dialogOpen;
		bool _suppressValueChanged;
		bool _is24HourView;
		string _locale = "";
		float4 _tintColor = float4(0);

		[UXConstructor]
		public TimePickerView([UXParameter("Host")]TimePicker host) : base(Create())
		{
			_host = host;
			_is24HourView = _host.Is24HourView;
			_locale = _host.Locale;
			_tintColor = _host.TintColor;

			RecreateNativeControl();
			UpdatePollValueCache();
		}

		public override void Dispose()
		{
			DismissDialog();
			base.Dispose();
			_host = null;
		}

		TimePickerStyle _style = TimePickerStyle.Default;
		public TimePickerStyle Style
		{
			get { return _style; }
			set
			{
				if (value == _style && _timePicker != null)
					return;

				_style = value;
				RecreateNativeControl();
			}
		}

		public bool Is24HourView
		{
			set
			{
				_is24HourView = value;

				if (_timePicker == null)
					return;

				SetIs24HourView(_timePicker, value);
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
				if (_timePicker != null)
					RecreateNativeControl();
			}
		}

		public float4 TintColor
		{
			set
			{
				_tintColor = value;
				if (_timeLabel != null)
					ApplyTint(_timeLabel, value.X, value.Y, value.Z, value.W);
			}
		}

		public DateTime Value
		{
			get
			{
				if (_timePicker == null)
					return default(DateTime);

				var msSince1970InUtc = GetTimeInMsSince1970InUtc(_timePicker);
				return DateTimeConverterHelpers.ConvertMsSince1970InUtcToDateTime(msSince1970InUtc);
			}
			set
			{
				if (_timePicker == null)
					return;

				var wasSuppressed = _suppressValueChanged;
				_suppressValueChanged = true;
				SetTime(_timePicker, _timeLabel, DateTimeConverterHelpers.ConvertDateTimeToMsSince1970InUtc(value), _is24HourView);
				_suppressValueChanged = wasSuppressed;
				UpdatePollValueCache();
			}
		}

		DateTime _pollValueCache;

		void RecreateNativeControl()
		{
			DismissDialog();

			var wasSuppressed = _suppressValueChanged;
			_suppressValueChanged = true;
			SetStyle(Handle, (int)_style, _locale, _is24HourView);
			ApplyNativeState();
			_suppressValueChanged = wasSuppressed;

			UpdatePollValueCache();
		}

		void ApplyNativeState()
		{
			if (_timePicker == null || _host == null)
				return;

			SetIs24HourView(_timePicker, _is24HourView);
			SetTime(_timePicker, _timeLabel, DateTimeConverterHelpers.ConvertDateTimeToMsSince1970InUtc(_host.Value), _is24HourView);
			ApplyTint(_timeLabel, _tintColor.X, _tintColor.Y, _tintColor.Z, _tintColor.W);
		}

		void UpdateLabel()
		{
			if (_timePicker == null || _timeLabel == null)
				return;

			var wasSuppressed = _suppressValueChanged;
			_suppressValueChanged = true;
			SetTime(_timePicker, _timeLabel, DateTimeConverterHelpers.ConvertDateTimeToMsSince1970InUtc(Value), _is24HourView);
			_suppressValueChanged = wasSuppressed;
		}

		void UpdatePollValueCache()
		{
			_pollValueCache = Value;
		}

		// onTimeChanged is unreliable in clock mode, so poll instead. Programmatic writes
		// update the cache, so any difference observed here was caused by the user.
		void PollViewValue()
		{
			if (_dialogOpen || _timePicker == null || _host == null)
				return;

			var value = Value;
			if (value == _pollValueCache)
				return;

			// The native control already shows the new time; only the compact label needs
			// to be updated here.
			if (_timeLabel != null)
			{
				var wasSuppressed = _suppressValueChanged;
				_suppressValueChanged = true;
				SetTime(_timePicker, _timeLabel, DateTimeConverterHelpers.ConvertDateTimeToMsSince1970InUtc(value), _is24HourView);
				_suppressValueChanged = wasSuppressed;
			}

			_pollValueCache = value;
			_host.OnNativeViewValueChanged(value, true);
		}

		void OnDialogOpening()
		{
			_dialogOpen = true;
		}

		void OnDialogTimeSet()
		{
			if (_timePicker == null || _host == null)
				return;

			var value = Value;

			var wasSuppressed = _suppressValueChanged;
			_suppressValueChanged = true;
			SetTime(_timePicker, _timeLabel, DateTimeConverterHelpers.ConvertDateTimeToMsSince1970InUtc(value), _is24HourView);
			_suppressValueChanged = wasSuppressed;

			_pollValueCache = value;
			_dialogOpen = false;
			_host.OnNativeViewValueChanged(value, true);
		}

		void OnDialogCancelled()
		{
			if (_timePicker == null || _host == null)
				return;

			var wasSuppressed = _suppressValueChanged;
			_suppressValueChanged = true;
			SetTime(_timePicker, _timeLabel, DateTimeConverterHelpers.ConvertDateTimeToMsSince1970InUtc(_host.Value), _is24HourView);
			_suppressValueChanged = wasSuppressed;

			_pollValueCache = _host.Value;
			_dialogOpen = false;
		}

		void OnDialogDismissed()
		{
			_dialogOpen = false;
			if (_timePicker != null)
				UpdatePollValueCache();
		}

		public void OnRooted()
		{
			UpdateManager.AddAction(PollViewValue);
		}

		public void OnUnrooted()
		{
			UpdateManager.RemoveAction(PollViewValue);
			DismissDialog();
			_timePicker = null;
			_timeLabel = null;
		}

		void DismissDialog()
		{
			_dialogOpen = false;

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
		void SetStyle(Java.Object handle, int style, string locale, bool is24HourView)
		@{
			android.widget.FrameLayout frameLayout = (android.widget.FrameLayout)handle;
			frameLayout.removeAllViews();
			@{TimePickerView:of(_this)._dialog:set(null)};

			android.content.Context context = com.fuse.android.widget.FusePickerUtils.createContext(
				com.fuse.Activity.getRootActivity(), locale);

			if (style == 1) { // compact
				final com.fuse.android.widget.FuseTimePickerDialog pickerDialog = new com.fuse.android.widget.FuseTimePickerDialog(
					context,
					new android.app.TimePickerDialog.OnTimeSetListener() {
						@Override
						public void onTimeSet(android.widget.TimePicker view, int hourOfDay, int minute) {
							@{TimePickerView:of(_this).OnDialogTimeSet():call()};
						}
					},
					0, 0, is24HourView);
				pickerDialog.setOnCancelListener(new android.content.DialogInterface.OnCancelListener() {
					@Override
					public void onCancel(android.content.DialogInterface dialog) {
						@{TimePickerView:of(_this).OnDialogCancelled():call()};
					}
				});
				pickerDialog.setOnDismissListener(new android.content.DialogInterface.OnDismissListener() {
					@Override
					public void onDismiss(android.content.DialogInterface dialog) {
						@{TimePickerView:of(_this).OnDialogDismissed():call()};
					}
				});

				android.widget.TextView textview = com.fuse.android.widget.FusePickerUtils.createCompactLabel(context);
				textview.setOnClickListener(new android.view.View.OnClickListener() {
					@Override
					public void onClick(android.view.View v) {
						@{TimePickerView:of(_this).OnDialogOpening():call()};
						pickerDialog.show();
					}
				});
				frameLayout.addView(textview);
				@{TimePickerView:of(_this)._timePicker:set(pickerDialog.getTimePicker())};
				@{TimePickerView:of(_this)._timeLabel:set(textview)};
				@{TimePickerView:of(_this)._dialog:set(pickerDialog)};
			} else {
				android.widget.TimePicker timePicker = new android.widget.TimePicker(context);
				@{TimePickerView:of(_this)._timePicker:set(timePicker)};
				@{TimePickerView:of(_this)._timeLabel:set(null)};
				frameLayout.addView(timePicker);
			}
		@}

		[Foreign(Language.Java)]
		static void DismissDialogNative(Java.Object dialog)
		@{
			com.fuse.android.widget.FusePickerUtils.dismissDialog(dialog);
		@}

		[Foreign(Language.Java)]
		void SetTime(Java.Object timePickerHandle, Java.Object timeLabelHandle, long msSince1970InUtc, bool is24HourView)
		@{
			java.util.Calendar cal = java.util.Calendar.getInstance(
				java.util.TimeZone.getTimeZone("UTC"), java.util.Locale.getDefault());
			cal.setTimeInMillis(msSince1970InUtc);

			int hour = cal.get(java.util.Calendar.HOUR_OF_DAY);
			int minute = cal.get(java.util.Calendar.MINUTE);

			android.widget.TimePicker timePicker = (android.widget.TimePicker)timePickerHandle;
			if (android.os.Build.VERSION.SDK_INT >= 23) {
				timePicker.setHour(hour);
				timePicker.setMinute(minute);
			} else {
				timePicker.setCurrentHour(hour);
				timePicker.setCurrentMinute(minute);
			}

			android.widget.TextView textview = (android.widget.TextView)timeLabelHandle;
			if (textview != null) {
				textview.setText(com.fuse.android.widget.FusePickerUtils.formatTime(
					textview.getContext(), msSince1970InUtc, is24HourView));
			}
		@}

		[Foreign(Language.Java)]
		void SetIs24HourView(Java.Object timePickerHandle, bool value)
		@{
			((android.widget.TimePicker)timePickerHandle).setIs24HourView(value);
		@}

		[Foreign(Language.Java)]
		void ApplyTint(Java.Object timeLabelHandle, float r, float g, float b, float a)
		@{
			com.fuse.android.widget.FusePickerUtils.applyLabelColor(
				(android.widget.TextView)timeLabelHandle, r, g, b, a);
		@}

		[Foreign(Language.Java)]
		long GetTimeInMsSince1970InUtc(Java.Object timePickerHandle)
		@{
			android.widget.TimePicker timePicker = (android.widget.TimePicker)timePickerHandle;

			int hour, minute;

			if (android.os.Build.VERSION.SDK_INT >= 23) {
				hour = timePicker.getHour();
				minute = timePicker.getMinute();
			} else {
				hour = timePicker.getCurrentHour();
				minute = timePicker.getCurrentMinute();
			}

			// Remove date offsets so we only express the time in UTC
			java.util.Calendar cal = java.util.Calendar.getInstance(
				java.util.TimeZone.getTimeZone("UTC"), java.util.Locale.getDefault());
			cal.clear();
			cal.set(1970, 0, 1, hour, minute, 0); // Android month starts at 0
			cal.set(java.util.Calendar.MILLISECOND, 0);

			return cal.getTimeInMillis();
		@}
	}
}
