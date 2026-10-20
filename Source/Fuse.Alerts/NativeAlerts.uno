using Uno;
using Uno.Collections;
using Uno.Threading;
using Uno.Diagnostics;
using Uno.UX;
using Fuse.Elements;
using Fuse.Scripting;

namespace Fuse.Alerts
{
	[UXGlobalModule]
	/**
		@scriptmodule FuseJS/Alerts

		@include Docs/Guide.md

		Offers native alert, confirm, prompt and action sheet dialogs on mobile platforms.
	*/
	public sealed partial class NativeAlerts : NativeModule
	{
		public NativeAlerts()
		{
			Resource.SetGlobalKey(this, "FuseJS/Alerts");
			AddMember(new NativePromise<bool, bool>("alert", Alert, null));
			AddMember(new NativePromise<object, object>("confirm", (FutureFactory2<object>)Confirm, null));
			AddMember(new NativePromise<string, string>("prompt", Prompt, null));
			AddMember(new NativePromise<int, int>("actionSheet", ActionSheet, null));
			AddMember(new NativeFunction("dismissAll", DismissAll));
		}

		/*
			Dialogs are shown one at a time. On iOS, presenting a second view
			controller while another one is being presented or dismissed is
			unreliable, and on Android it stacks dialogs on top of each other.
		*/
		static readonly Queue<Action> _pendingDialogs = new Queue<Action>();
		static bool _dialogVisible;

		static void EnqueueDialog(Action showDialog)
		{
			lock (_pendingDialogs)
			{
				_pendingDialogs.Enqueue(showDialog);
				if (_dialogVisible)
					return;
				_dialogVisible = true;
			}

			ShowNextDialog();
		}

		static void ShowNextDialog()
		{
			Action showDialog = null;
			lock (_pendingDialogs)
			{
				if (_pendingDialogs.Count == 0)
				{
					_dialogVisible = false;
					return;
				}
				showDialog = _pendingDialogs.Dequeue();
			}

			if (showDialog == null)
			{
				_dialogVisible = false;
				return;
			}

			try
			{
				showDialog();
			}
			catch (Exception e)
			{
				Uno.Diagnostics.Log.WriteLine(LogLevel.Error, "Fuse.Alerts: Failed to show dialog: " + e.Message);
				ShowNextDialog();
			}
		}

		static void CompleteDialog()
		{
			ShowNextDialog();
		}

		static object DismissAll(Context context, object[] args)
		{
			lock (_pendingDialogs)
			{
				_pendingDialogs.Clear();
				_dialogVisible = false;
			}

			if defined(Android || iOS)
				DismissAllNative();

			return null;
		}

		interface IDialogCallback
		{
			void Error(string message);
			void Dismissed();
		}

		static void ShowSafely(IDialogCallback callback, Action show)
		{
			try
			{
				if defined(Android || iOS)
					show();
				else
				{
					callback.Error("Dialogs are not supported on this platform.");
					callback.Dismissed();
				}
			}
			catch (Exception e)
			{
				callback.Error(e.Message);
				callback.Dismissed();
			}
		}

		internal sealed class DialogCallback : IDialogCallback
		{
			readonly Action _onPositive;
			readonly Action _onNegative;
			readonly Action<string> _onError;
			bool _settled;
			bool _completed;

			public DialogCallback(Action onPositive, Action onNegative, Action<string> onError)
			{
				_onPositive = onPositive;
				_onNegative = onNegative;
				_onError = onError;
			}

			public void Positive()
			{
				if (_settled)
					return;
				_settled = true;
				if (_onPositive != null)
					_onPositive();
			}

			public void Negative()
			{
				if (_settled)
					return;
				_settled = true;
				if (_onNegative != null)
					_onNegative();
			}

			public void Error(string message)
			{
				if (_settled)
					return;
				_settled = true;
				if (_onError != null)
					_onError(message);
			}

			public void Dismissed()
			{
				// If the dialog disappeared without an action (Back button,
				// outside tap, activity teardown), treat it as a cancellation.
				Negative();
				CompleteOnce();
			}

			void CompleteOnce()
			{
				if (_completed)
					return;
				_completed = true;
				CompleteDialog();
			}
		}

		sealed class PromiseDialogCallback
		{
			readonly Promise<bool> _promise;

			public PromiseDialogCallback(Promise<bool> promise)
			{
				_promise = promise;
			}

			public void Positive()
			{
				_promise.Resolve(true);
			}

			public void Negative()
			{
				_promise.Resolve(false);
			}

			public void Error(string message)
			{
				_promise.Reject(new Exception(message));
			}
		}

		sealed class PromiseBoolObjectDialogCallback
		{
			readonly Promise<object> _promise;

			public PromiseBoolObjectDialogCallback(Promise<object> promise)
			{
				_promise = promise;
			}

			public void Positive()
			{
				_promise.Resolve(true);
			}

			public void Negative()
			{
				_promise.Resolve(false);
			}

			public void Error(string message)
			{
				_promise.Reject(new Exception(message));
			}
		}

		sealed class PromiseChoiceDialogCallback
		{
			readonly Promise<object> _promise;

			public PromiseChoiceDialogCallback(Promise<object> promise)
			{
				_promise = promise;
			}

			public void Positive()
			{
				_promise.Resolve(0);
			}

			public void Neutral()
			{
				_promise.Resolve(1);
			}

			public void Negative()
			{
				_promise.Resolve(2);
			}

			public void Dismissed()
			{
				_promise.Resolve(-1);
			}

			public void Error(string message)
			{
				_promise.Reject(new Exception(message));
			}
		}

		sealed class DialogRequest
		{
			readonly bool _confirm;
			readonly string _title;
			readonly string _message;
			readonly string _okButtonLabel;
			readonly string _cancelButtonLabel;
			readonly DialogCallback _callback;

			public DialogRequest(bool confirm, string title, string message, string okButtonLabel, string cancelButtonLabel, DialogCallback callback)
			{
				_confirm = confirm;
				_title = title;
				_message = message;
				_okButtonLabel = okButtonLabel;
				_cancelButtonLabel = cancelButtonLabel;
				_callback = callback;
			}

			public void Show()
			{
				ShowSafely(_callback, ShowNative);
			}

			void ShowNative()
			{
				if (_confirm)
				{
					if defined(Android)
						ConfirmNative(_title, _message, _okButtonLabel, _cancelButtonLabel, _callback.Positive, _callback.Negative, _callback.Error, _callback.Dismissed);
					if defined(iOS)
						ConfirmNative(_title, _message, _okButtonLabel, _cancelButtonLabel, _callback.Positive, _callback.Negative, _callback.Error, _callback.Dismissed);
				}
				else
				{
					if defined(Android)
						AlertNative(_title, _message, _okButtonLabel, _callback.Positive, _callback.Negative, _callback.Error, _callback.Dismissed);
					if defined(iOS)
						AlertNative(_title, _message, _okButtonLabel, _callback.Positive, _callback.Negative, _callback.Error, _callback.Dismissed);
				}
			}
		}

		sealed class ConfirmChoiceDialogCallback : IDialogCallback
		{
			readonly Action _onPositive;
			readonly Action _onNeutral;
			readonly Action _onNegative;
			readonly Action _onDismissed;
			readonly Action<string> _onError;
			bool _settled;
			bool _completed;

			public ConfirmChoiceDialogCallback(Action onPositive, Action onNeutral, Action onNegative, Action onDismissed, Action<string> onError)
			{
				_onPositive = onPositive;
				_onNeutral = onNeutral;
				_onNegative = onNegative;
				_onDismissed = onDismissed;
				_onError = onError;
			}

			void Settle(Action action)
			{
				if (_settled)
					return;
				_settled = true;
				if (action != null)
					action();
			}

			public void Positive()
			{
				Settle(_onPositive);
			}

			public void Neutral()
			{
				Settle(_onNeutral);
			}

			public void Negative()
			{
				Settle(_onNegative);
			}

			public void Error(string message)
			{
				if (_settled)
					return;
				_settled = true;
				if (_onError != null)
					_onError(message);
			}

			public void Dismissed()
			{
				Settle(_onDismissed);
				CompleteOnce();
			}

			void CompleteOnce()
			{
				if (_completed)
					return;
				_completed = true;
				CompleteDialog();
			}
		}

		sealed class ConfirmChoiceDialogRequest
		{
			readonly string _title;
			readonly string _message;
			readonly string _okButtonLabel;
			readonly string _neutralButtonLabel;
			readonly string _cancelButtonLabel;
			readonly bool _destructive;
			readonly bool _cancelable;
			readonly ConfirmChoiceDialogCallback _callback;

			public ConfirmChoiceDialogRequest(string title, string message, string okButtonLabel, string neutralButtonLabel, string cancelButtonLabel, bool destructive, bool cancelable, ConfirmChoiceDialogCallback callback)
			{
				_title = title;
				_message = message;
				_okButtonLabel = okButtonLabel;
				_neutralButtonLabel = neutralButtonLabel;
				_cancelButtonLabel = cancelButtonLabel;
				_destructive = destructive;
				_cancelable = cancelable;
				_callback = callback;
			}

			public void Show()
			{
				ShowSafely(_callback, ShowNative);
			}

			void ShowNative()
			{
				if defined(Android)
					ConfirmChoiceNative(_title, _message, _okButtonLabel, _neutralButtonLabel, _cancelButtonLabel, _destructive, _cancelable, _callback.Positive, _callback.Neutral, _callback.Negative, _callback.Error, _callback.Dismissed);
				if defined(iOS)
					ConfirmChoiceNative(_title, _message, _okButtonLabel, _neutralButtonLabel, _cancelButtonLabel, _destructive, _cancelable, _callback.Positive, _callback.Neutral, _callback.Negative, _callback.Error, _callback.Dismissed);
			}
		}

		sealed class PromptDialogCallback : IDialogCallback
		{
			readonly Action<string> _onPositive;
			readonly Action _onNegative;
			readonly Action<string> _onError;
			bool _settled;
			bool _completed;

			public PromptDialogCallback(Action<string> onPositive, Action onNegative, Action<string> onError)
			{
				_onPositive = onPositive;
				_onNegative = onNegative;
				_onError = onError;
			}

			public void Positive(string text)
			{
				if (_settled)
					return;
				_settled = true;
				if (_onPositive != null)
					_onPositive(text);
			}

			public void Negative()
			{
				if (_settled)
					return;
				_settled = true;
				if (_onNegative != null)
					_onNegative();
			}

			public void Error(string message)
			{
				if (_settled)
					return;
				_settled = true;
				if (_onError != null)
					_onError(message);
			}

			public void Dismissed()
			{
				Negative();
				CompleteOnce();
			}

			void CompleteOnce()
			{
				if (_completed)
					return;
				_completed = true;
				CompleteDialog();
			}
		}

		sealed class PromiseStringDialogCallback
		{
			readonly Promise<string> _promise;

			public PromiseStringDialogCallback(Promise<string> promise)
			{
				_promise = promise;
			}

			public void Positive(string text)
			{
				_promise.Resolve(text);
			}

			public void Negative()
			{
				_promise.Resolve(null);
			}

			public void Error(string message)
			{
				_promise.Reject(new Exception(message));
			}
		}

		sealed class PromptDialogRequest
		{
			readonly string _title;
			readonly string _message;
			readonly string _placeholder;
			readonly string _value;
			readonly string _okButtonLabel;
			readonly string _cancelButtonLabel;
			readonly bool _secure;
			readonly string _keyboardType;
			readonly int _minChars;
			readonly PromptDialogCallback _callback;

			public PromptDialogRequest(string title, string message, string placeholder, string value, string okButtonLabel, string cancelButtonLabel, bool secure, string keyboardType, int minChars, PromptDialogCallback callback)
			{
				_title = title;
				_message = message;
				_placeholder = placeholder;
				_value = value;
				_okButtonLabel = okButtonLabel;
				_cancelButtonLabel = cancelButtonLabel;
				_secure = secure;
				_keyboardType = keyboardType;
				_minChars = minChars;
				_callback = callback;
			}

			public void Show()
			{
				ShowSafely(_callback, ShowNative);
			}

			void ShowNative()
			{
				if defined(Android)
					PromptNative(_title, _message, _placeholder, _value, _okButtonLabel, _cancelButtonLabel, _secure, _keyboardType, _minChars, _callback.Positive, _callback.Negative, _callback.Error, _callback.Dismissed);
				if defined(iOS)
					PromptNative(_title, _message, _placeholder, _value, _okButtonLabel, _cancelButtonLabel, _secure, _keyboardType, _minChars, _callback.Positive, _callback.Negative, _callback.Error, _callback.Dismissed);
			}
		}

		sealed class ActionSheetDialogCallback : IDialogCallback
		{
			readonly Action<int> _onSelect;
			readonly Action _onCancel;
			readonly Action<string> _onError;
			bool _settled;
			bool _completed;

			public ActionSheetDialogCallback(Action<int> onSelect, Action onCancel, Action<string> onError)
			{
				_onSelect = onSelect;
				_onCancel = onCancel;
				_onError = onError;
			}

			public void Selected(int index)
			{
				if (_settled)
					return;
				_settled = true;
				if (_onSelect != null)
					_onSelect(index);
			}

			public void Cancelled()
			{
				if (_settled)
					return;
				_settled = true;
				if (_onCancel != null)
					_onCancel();
			}

			public void Error(string message)
			{
				if (_settled)
					return;
				_settled = true;
				if (_onError != null)
					_onError(message);
			}

			public void Dismissed()
			{
				Cancelled();
				CompleteOnce();
			}

			void CompleteOnce()
			{
				if (_completed)
					return;
				_completed = true;
				CompleteDialog();
			}
		}

		sealed class PromiseIntDialogCallback
		{
			readonly Promise<int> _promise;

			public PromiseIntDialogCallback(Promise<int> promise)
			{
				_promise = promise;
			}

			public void Selected(int index)
			{
				_promise.Resolve(index);
			}

			public void Cancelled()
			{
				_promise.Resolve(-1);
			}

			public void Error(string message)
			{
				_promise.Reject(new Exception(message));
			}
		}

		sealed class ActionSheetDialogRequest
		{
			readonly string _title;
			readonly string _message;
			readonly string[] _items;
			readonly bool[] _destructive;
			readonly bool[] _enabled;
			readonly string _cancelButtonLabel;
			readonly bool _hasOrigin;
			readonly float _originX;
			readonly float _originY;
			readonly ActionSheetDialogCallback _callback;

			public ActionSheetDialogRequest(string title, string message, string[] items, bool[] destructive, bool[] enabled, string cancelButtonLabel, bool hasOrigin, float originX, float originY, ActionSheetDialogCallback callback)
			{
				_title = title;
				_message = message;
				_items = items;
				_destructive = destructive;
				_enabled = enabled;
				_cancelButtonLabel = cancelButtonLabel;
				_hasOrigin = hasOrigin;
				_originX = originX;
				_originY = originY;
				_callback = callback;
			}

			public void Show()
			{
				ShowSafely(_callback, ShowNative);
			}

			void ShowNative()
			{
				if defined(Android)
					ActionSheetNative(_title, _message, _items, _destructive, _enabled, _cancelButtonLabel, _callback.Selected, _callback.Cancelled, _callback.Error, _callback.Dismissed);
				if defined(iOS)
					ActionSheetNative(_title, _message, _items, _destructive, _enabled, _cancelButtonLabel, _hasOrigin, _originX, _originY, _callback.Selected, _callback.Cancelled, _callback.Error, _callback.Dismissed);
			}
		}

		static T GetOrDefault<T>(object[] args, int index, T defaultValue)
		{
			return index < args.Length ?  (T)args[index] : defaultValue;
		}

		/**
			@scriptmethod alert(title, description, okbuttonlabel)

			Displays an alert box with a single button.

			@param title (string) The dialog box title. Defaults to "Alert!".
			@param description (string) The long form description of the alert. Blank by default.
			@param okbuttonlabel (string) The OK button label text. Defaults to "OK".

			@return (Promise) A boolean promise that resolves to `true` if the OK button was pressed and `false` if the dialog was dismissed.
		*/
		static Future<bool> Alert(Context context, object[] args)
		{
			return AlertInternal(
				GetOrDefault(args, 0, "Alert!"),
				GetOrDefault(args, 1, ""),
				ResolveLabel(GetOrDefault<string>(args, 2, null), false));
		}

		/**
			@scriptmethod confirm(title, description, okbuttonlabel, cancelbuttonlabel)
			@scriptmethod confirm(options)

			Displays an ok/cancel dialog. When called with an options object it can
			also show a third, neutral button.

			The positional form resolves to a boolean: `true` for OK and `false`
			for Cancel, Back or an outside tap.

			The options form resolves to an index: `0` for OK, `1` for neutral,
			`2` for Cancel and `-1` when dismissed without a button.

			@param title (string) The dialog box title. Defaults to "Confirm".
			@param description (string) The long form description of the alert. Blank by default.
			@param okbuttonlabel (string) The OK button label text. Defaults to "OK".
			@param cancelbuttonlabel (string) The Cancel button label text. Defaults to "Cancel".
			@param options.title (string) The dialog box title. Defaults to "Confirm".
			@param options.message (string) The long form description. Blank by default.
			@param options.okLabel (string) The OK button label. Defaults to "OK".
			@param options.neutralLabel (string) Optional neutral button label.
			@param options.cancelLabel (string) The Cancel button label. Defaults to "Cancel".
			@param options.destructive (bool) Whether the OK button uses destructive styling. Defaults to false.
			@param options.cancelable (bool) Whether Android allows dismissing with Back or an outside tap. Defaults to true.

			@return (Promise) A boolean for the positional form, or a number for the options form.
		*/
		static Future<object> Confirm(Context context, object[] args)
		{
			if (args.Length > 0 && args[0] is Fuse.Scripting.Object)
			{
				var options = (Fuse.Scripting.Object)args[0];
				return ConfirmChoiceInternal(
					GetString(options, "title", "Confirm"),
					GetString(options, "message", ""),
					ResolveLabel(GetString(options, "okLabel", null), false),
					GetString(options, "neutralLabel", null),
					ResolveLabel(GetString(options, "cancelLabel", null), true),
					GetBool(options, "destructive", false),
					GetBool(options, "cancelable", true));
			}

			return ConfirmInternal(
				GetOrDefault(args, 0, "Confirm"),
				GetOrDefault(args, 1, ""),
				ResolveLabel(GetOrDefault<string>(args, 2, null), false),
				ResolveLabel(GetOrDefault<string>(args, 3, null), true));
		}

		/**
			@scriptmethod prompt(options)

			Displays a native text input dialog.

			@param options (object) Dialog options.
			@param options.title (string) The dialog title. Defaults to "Prompt".
			@param options.message (string) The longer description. Blank by default.
			@param options.placeholder (string) Placeholder text for the input field.
			@param options.value (string) Initial input value.
			@param options.okLabel (string) The OK button label. Defaults to "OK".
			@param options.cancelLabel (string) The cancel button label. Defaults to "Cancel".
			@param options.secure (bool) Whether to hide the input text. Defaults to false.
			@param options.keyboardType (string) One of "text", "email", "number", "phone" or "url". Defaults to "text".
			@param options.required (bool) Whether the input must be non-empty before OK is enabled. Defaults to false.
			@param options.minLength (int) Minimum input length before OK is enabled. Defaults to 0.

			@return (Promise) A promise that resolves to the entered text, or `null` if the dialog was canceled or dismissed.
		*/
		static Future<string> Prompt(Context context, object[] args)
		{
			var options = args.Length > 0 ? args[0] as Fuse.Scripting.Object : null;
			var minLength = GetInt(options, "minLength", 0);
			if (GetBool(options, "required", false) && minLength < 1)
				minLength = 1;

			return PromptInternal(
				GetString(options, "title", "Prompt"),
				GetString(options, "message", ""),
				GetString(options, "placeholder", ""),
				GetString(options, "value", ""),
				ResolveLabel(GetString(options, "okLabel", null), false),
				ResolveLabel(GetString(options, "cancelLabel", null), true),
				GetBool(options, "secure", false),
				GetString(options, "keyboardType", "text"),
				minLength);
		}

		/**
			@scriptmethod actionSheet(options)

			Displays a native list of choices.

			@param options (object) Dialog options.
			@param options.title (string) The dialog title.
			@param options.message (string) The longer description. Blank by default.
			@param options.items (array) An array of strings, or objects with `label`, optional `destructive` and optional `enabled` properties.
			@param options.cancelLabel (string) The cancel button label. Defaults to "Cancel".
			@param options.destructiveIndex (int) Optional index to treat as destructive. Defaults to -1.
			@param options.origin (Element) Optional iPad popover anchor, usually a UX element.

			@return (Promise) A promise that resolves to the selected item index, or -1 if the dialog was canceled or dismissed.
		*/
		static Future<int> ActionSheet(Context context, object[] args)
		{
			var options = args.Length > 0 ? args[0] as Fuse.Scripting.Object : null;

			int destructiveIndex = GetInt(options, "destructiveIndex", -1);
			bool[] destructive;
			bool[] enabled;
			var items = GetActionSheetItems(options, out destructive, out enabled);
			if (items == null || items.Length == 0)
				throw new Exception("actionSheet requires a non-empty 'items' array.");

			if (destructiveIndex >= 0 && destructiveIndex < destructive.Length)
				destructive[destructiveIndex] = true;

			float2 origin;
			var hasOrigin = TryGetPosition(options != null && options.ContainsKey("origin") ? options["origin"] : null, out origin);

			return ActionSheetInternal(
				GetString(options, "title", ""),
				GetString(options, "message", ""),
				items,
				destructive,
				enabled,
				ResolveLabel(GetString(options, "cancelLabel", null), true),
				hasOrigin,
				origin.X,
				origin.Y);
		}

		static string GetString(Fuse.Scripting.Object obj, string key, string defaultValue)
		{
			if (obj == null || !obj.ContainsKey(key))
				return defaultValue;
			var value = obj[key];
			if (value == null)
				return defaultValue;
			var str = value as string;
			return str != null ? str : value.ToString();
		}

		static bool GetBool(Fuse.Scripting.Object obj, string key, bool defaultValue)
		{
			if (obj == null || !obj.ContainsKey(key))
				return defaultValue;
			return Fuse.Marshal.ToBool(obj[key]);
		}

		static int GetInt(Fuse.Scripting.Object obj, string key, int defaultValue)
		{
			if (obj == null || !obj.ContainsKey(key))
				return defaultValue;
			return Fuse.Marshal.ToInt(obj[key]);
		}

		internal static string ResolveLabel(string label, bool cancel)
		{
			if (label != null && label.Length > 0)
				return label;

			if defined(Android || iOS)
				return cancel ? DefaultCancelLabel() : DefaultOkLabel();

			return cancel ? "Cancel" : "OK";
		}

		static string[] GetActionSheetItems(Fuse.Scripting.Object options, out bool[] destructive, out bool[] enabled)
		{
			destructive = null;
			enabled = null;
			if (options == null || !options.ContainsKey("items"))
				return null;

			var array = options["items"] as Fuse.Scripting.Array;
			if (array == null)
				return null;

			var items = new string[array.Length];
			destructive = new bool[array.Length];
			enabled = new bool[array.Length];
			for (int i = 0; i < array.Length; i++)
			{
				var value = array[i];
				var item = value as Fuse.Scripting.Object;
				enabled[i] = true;

				if (item != null)
				{
					items[i] = GetString(item, "label", "");
					destructive[i] = GetBool(item, "destructive", false);
					enabled[i] = GetBool(item, "enabled", true);
				}
				else
				{
					var label = value as string;
					items[i] = label != null ? label : (value != null ? value.ToString() : "");
				}
			}
			return items;
		}

		static bool TryGetPosition(object arg, out float2 position)
		{
			position = float2(0);
			var obj = arg as Fuse.Scripting.Object;
			if (obj == null || !obj.ContainsKey("external_object"))
				return false;

			var external = obj["external_object"] as Fuse.Scripting.External;
			if (external == null)
				return false;

			var element = external.Object as Element;
			if (element == null)
				return false;

			position = element.ActualPosition + element.ActualSize * 0.5f;
			return true;
		}


		/* MOBILE AND DESKTOP */

		static Future<object> ConfirmInternal(String title, String message, String okButtonLabel, String cancelButtonLabel)
		{
			var promise = new Promise<object>();
			if defined(Android || iOS)
			{
				var callback = new PromiseBoolObjectDialogCallback(promise);
				ShowConfirm(title, message, okButtonLabel, cancelButtonLabel, callback.Positive, callback.Negative, callback.Error);
			}
			else
			{
				promise.Resolve(true);
			}
			return promise;
		}

		static Future<object> ConfirmChoiceInternal(String title, String message, String okButtonLabel, String neutralButtonLabel, String cancelButtonLabel, bool destructive, bool cancelable)
		{
			var promise = new Promise<object>();
			if defined(Android || iOS)
			{
				var callback = new PromiseChoiceDialogCallback(promise);
				ShowConfirmChoice(title, message, okButtonLabel, neutralButtonLabel, cancelButtonLabel, destructive, cancelable, callback.Positive, callback.Neutral, callback.Negative, callback.Dismissed, callback.Error);
			}
			else
			{
				promise.Resolve(-1);
			}
			return promise;
		}

		static Future<bool> AlertInternal(String title, String message, String okButtonLabel)
		{
			var promise = new Promise<bool>();
			if defined(Android || iOS)
			{
				var callback = new PromiseDialogCallback(promise);
				ShowAlert(title, message, okButtonLabel, callback.Positive, callback.Negative, callback.Error);
			}
			else
			{
				promise.Resolve(true);
			}
			return promise;
		}

		static Future<string> PromptInternal(String title, String message, String placeholder, String value, String okButtonLabel, String cancelButtonLabel, bool secure, String keyboardType, int minChars)
		{
			var promise = new Promise<string>();
			if defined(Android || iOS)
			{
				var callback = new PromiseStringDialogCallback(promise);
				ShowPrompt(title, message, placeholder, value, okButtonLabel, cancelButtonLabel, secure, keyboardType, minChars, callback.Positive, callback.Negative, callback.Error);
			}
			else
			{
				promise.Resolve(null);
			}
			return promise;
		}

		static Future<int> ActionSheetInternal(String title, String message, String[] items, bool[] destructive, bool[] enabled, String cancelButtonLabel, bool hasOrigin, float originX, float originY)
		{
			var promise = new Promise<int>();
			if defined(Android || iOS)
			{
				var callback = new PromiseIntDialogCallback(promise);
				ShowActionSheet(title, message, items, destructive, enabled, cancelButtonLabel, hasOrigin, originX, originY, callback.Selected, callback.Cancelled, callback.Error);
			}
			else
			{
				promise.Resolve(-1);
			}
			return promise;
		}

		internal static void ShowConfirm(String title, String message, String okButtonLabel, String cancelButtonLabel, Action onOK, Action onCancel, Action<string> onError)
		{
			var callback = new DialogCallback(onOK, onCancel, onError);
			var request = new DialogRequest(true, title, message, okButtonLabel, cancelButtonLabel, callback);
			EnqueueDialog(request.Show);
		}

		internal static void ShowAlert(String title, String message, String okButtonLabel, Action onOK, Action onCancel, Action<string> onError)
		{
			var callback = new DialogCallback(onOK, onCancel, onError);
			var request = new DialogRequest(false, title, message, okButtonLabel, null, callback);
			EnqueueDialog(request.Show);
		}

		internal static void ShowConfirmChoice(String title, String message, String okButtonLabel, String neutralButtonLabel, String cancelButtonLabel, bool destructive, bool cancelable, Action onOK, Action onNeutral, Action onCancel, Action onDismissed, Action<string> onError)
		{
			var callback = new ConfirmChoiceDialogCallback(onOK, onNeutral, onCancel, onDismissed, onError);
			var request = new ConfirmChoiceDialogRequest(title, message, okButtonLabel, neutralButtonLabel, cancelButtonLabel, destructive, cancelable, callback);
			EnqueueDialog(request.Show);
		}

		internal static void ShowPrompt(String title, String message, String placeholder, String value, String okButtonLabel, String cancelButtonLabel, bool secure, String keyboardType, int minChars, Action<string> onOK, Action onCancel, Action<string> onError)
		{
			var callback = new PromptDialogCallback(onOK, onCancel, onError);
			var request = new PromptDialogRequest(title, message, placeholder, value, okButtonLabel, cancelButtonLabel, secure, keyboardType, minChars, callback);
			EnqueueDialog(request.Show);
		}

		internal static void ShowActionSheet(String title, String message, String[] items, bool[] destructive, bool[] enabled, String cancelButtonLabel, bool hasOrigin, float originX, float originY, Action<int> onSelect, Action onCancel, Action<string> onError)
		{
			var callback = new ActionSheetDialogCallback(onSelect, onCancel, onError);
			var request = new ActionSheetDialogRequest(title, message, items, destructive, enabled, cancelButtonLabel, hasOrigin, originX, originY, callback);
			EnqueueDialog(request.Show);
		}
	}
}
