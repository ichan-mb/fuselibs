using Uno;
using Uno.Collections;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;

using Fuse;
using Fuse.Resources;
using Fuse.Controls.Native;
using Fuse.Scripting;

namespace Fuse.Controls
{
	using Native.iOS;
	using Native.Android;

	/**
		Event arguments for PlatformView events, containing event name and value data
		that can be serialized for JavaScript consumption.
	*/
	public class PlatformViewArgs : EventArgs, IScriptEvent
	{
		readonly string _eventName;
		readonly string _eventValue;
		readonly object _eventData;

		/** The name of the event sent from the native view. */
		public string EventName { get { return _eventName; } }

		/** The raw string value sent from the native view. */
		public string EventValue { get { return _eventValue; } }

		/**
			The event value parsed as JSON, or `null` if the value is not valid JSON.
			Lets native views send structured payloads that JavaScript receives as objects.
		*/
		public object EventData { get { return _eventData; } }

		public PlatformViewArgs(string eventName, string value)
		{
			_eventName = eventName;
			_eventValue = value;
			_eventData = TryParse(value);
		}

		static object TryParse(string value)
		{
			if (string.IsNullOrEmpty(value))
				return null;

			try
			{
				return Json.Parse(value);
			}
			catch (Exception)
			{
				return null;
			}
		}

		void IScriptEvent.Serialize(IEventSerializer s)
		{
			Serialize(s);
		}

		virtual void Serialize(IEventSerializer s)
		{
			s.AddString("eventName", _eventName);
			s.AddString("eventValue", _eventValue);

			if (_eventData != null)
				s.AddObject("eventData", _eventData);
		}
	}

	public delegate void PlatformViewHandler(object sender, PlatformViewArgs args);

	/**
		Interface defining the contract for platform-specific native view implementations.
		Provides data binding capabilities for various data types.
	*/
	interface IPlatformView
	{
		string Source { set; }
		string Data { set; }
		string DataArray { set; }
		float DataFloat { set; }
		double DataDouble { set; }
		int DataInteger { set; }
		bool DataBool { set; }
		string DataString { set; }
		void Invoke(string command, string arguments);
		string Environment { set; }
	}

	/** Color scheme override for an embedded native view. */
	public enum PlatformViewColorScheme
	{
		Unspecified,
		Light,
		Dark
	}

	/** Layout direction override for an embedded native view. */
	public enum PlatformViewLayoutDirection
	{
		Unspecified,
		LeftToRight,
		RightToLeft
	}

	/** How data changes are delivered from Fuse to the native view. */
	public enum PlatformViewDataUpdateMode
	{
		/** Every change is pushed to the native view immediately. */
		Immediate,
		/** Changes are coalesced and pushed once per frame. */
		Batched
	}

	/**
		Enables embedding native platform-specific UI components within Fuse applications.

		PlatformView provides a bridge between Fuse and native UI frameworks:
		- SwiftUI views on iOS
		- Jetpack Compose views on Android

		Features two-way data binding, event handling, and supports multiple data types
		including primitives (string, bool, int, float) and complex types (objects, arrays)
		that are JSON-serialized for native consumption.

		## Example

		Basic usage with data binding:
		```xml
			<PlatformView ViewName="MyCustomView"
			              DataString="Hello from Fuse"
			              DataInteger="42"
			              EventHandler="{onNativeEvent}" />
		```

		With complex data:
		```xml
			<PlatformView ViewName="DataView" DataObject="{userProfile}" />
		```
	*/
	public abstract partial class PlatformViewBase : Panel
	{
		static PlatformViewBase()
		{
			ScriptClass.Register(typeof(PlatformViewBase),
				new ScriptMethod<PlatformViewBase>("invoke", InvokeScript),
				new ScriptMethod<PlatformViewBase>("setArgument", SetArgumentScript),
				new ScriptMethod<PlatformViewBase>("removeArgument", RemoveArgumentScript),
				new ScriptMethod<PlatformViewBase>("clearArguments", ClearArgumentsScript));
		}

		static void SetArgumentScript(PlatformViewBase view, object[] args)
		{
			if (args.Length < 1 || !(args[0] is string))
			{
				Fuse.Diagnostics.UserError("PlatformView.setArgument requires a key. Usage: setArgument(key, value)", view);
				return;
			}

			view.SetArgument((string)args[0], args.Length > 1 ? args[1] : null);
		}

		static void RemoveArgumentScript(PlatformViewBase view, object[] args)
		{
			if (args.Length < 1 || !(args[0] is string))
			{
				Fuse.Diagnostics.UserError("PlatformView.removeArgument requires a key. Usage: removeArgument(key)", view);
				return;
			}

			view.RemoveArgument((string)args[0]);
		}

		static void ClearArgumentsScript(PlatformViewBase view)
		{
			view.ClearArguments();
		}

		static void InvokeScript(PlatformViewBase view, object[] args)
		{
			var command = args.Length > 0 ? args[0] as string : null;
			if (string.IsNullOrEmpty(command))
			{
				Fuse.Diagnostics.UserError("PlatformView.invoke must be called with a command name. Usage: invoke(command, arguments)", view);
				return;
			}

			if (args.Length > 1)
				view.Invoke(command, args[1]);
			else
				view.Invoke(command);
		}

		/**
			Sends a command to the native view, without any arguments.
		*/
		public void Invoke(string command)
		{
			InvokeCommand(command, null);
		}

		/**
			Sends a command to the native view. `arguments` is serialized to JSON before being
			handed to the native view, so it can be any JSON-serializable value.

			Native views receive the command through `PlatformViewData.onCommand` on iOS
			and `PlatformViewData.onCommand` on Android.
		*/
		public void Invoke(string command, object arguments)
		{
			if (string.IsNullOrEmpty(command))
			{
				Fuse.Diagnostics.UserError("PlatformView.Invoke requires a non-empty command name.", this);
				return;
			}

			string json = null;
			if (arguments != null)
			{
				try
				{
					json = Json.Stringify(arguments);
				}
				catch (Exception e)
				{
					Fuse.Diagnostics.UserError("PlatformView could not serialize arguments for command '" + command + "': " + e.Message, this);
					return;
				}
			}

			InvokeCommand(command, json);
		}

		void InvokeCommand(string command, string jsonArguments)
		{
			var pnv = PlatformNativeView;
			if (pnv != null)
				pnv.Invoke(command, jsonArguments ?? "");
		}

		static Selector _dataUpdateModeName = "DataUpdateMode";

		PlatformViewDataUpdateMode _dataUpdateMode = PlatformViewDataUpdateMode.Immediate;
		/**
			Controls how data changes are delivered to the native view.

			`Immediate` pushes every change right away. `Batched` coalesces changes and pushes the
			latest values once per frame, which is useful for high-frequency updates.
		*/
		[UXOriginSetter("SetDataUpdateMode")]
		public PlatformViewDataUpdateMode DataUpdateMode
		{
			get { return _dataUpdateMode; }
			set { SetDataUpdateMode(value, this); }
		}

		public void SetDataUpdateMode(PlatformViewDataUpdateMode value, IPropertyListener origin)
		{
			if (value != _dataUpdateMode)
			{
				_dataUpdateMode = value;
				OnPropertyChanged(_dataUpdateModeName, origin);
			}

			if (_dataUpdateMode == PlatformViewDataUpdateMode.Immediate)
				FlushData();
		}

		bool _dataFlushScheduled;
		bool _stringDirty, _boolDirty, _integerDirty, _floatDirty, _doubleDirty, _objectDirty, _arrayDirty;

		void RequestDataPush()
		{
			if (_dataUpdateMode == PlatformViewDataUpdateMode.Batched)
			{
				if (_dataFlushScheduled)
					return;

				_dataFlushScheduled = true;
				UpdateManager.PerformNextFrame(FlushData);
			}
			else
			{
				FlushData();
			}
		}

		internal void ClearPendingData()
		{
			_stringDirty = false;
			_boolDirty = false;
			_integerDirty = false;
			_floatDirty = false;
			_doubleDirty = false;
			_objectDirty = false;
			_arrayDirty = false;
		}

		void FlushData()
		{
			_dataFlushScheduled = false;

			var pnv = PlatformNativeView;
			if (pnv == null)
			{
				ClearPendingData();
				return;
			}

			if (_stringDirty)
			{
				pnv.DataString = _dataString ?? "";
				_stringDirty = false;
			}

			if (_boolDirty)
			{
				pnv.DataBool = _dataBool;
				_boolDirty = false;
			}

			if (_integerDirty)
			{
				pnv.DataInteger = _dataInteger;
				_integerDirty = false;
			}

			if (_floatDirty)
			{
				pnv.DataFloat = _dataFloat;
				_floatDirty = false;
			}

			if (_doubleDirty)
			{
				pnv.DataDouble = _dataDouble;
				_doubleDirty = false;
			}

			if (_objectDirty)
			{
				try
				{
					pnv.Data = _dataObject != null ? Json.Stringify(_dataObject) : "{}";
				}
				catch (Exception e)
				{
					Fuse.Diagnostics.UserError("PlatformView could not serialize DataObject: " + e.Message, this);
				}
				_objectDirty = false;
			}

			if (_arrayDirty)
			{
				try
				{
					pnv.DataArray = _dataArray != null ? Json.Stringify(_dataArray) : "[]";
				}
				catch (Exception e)
				{
					Fuse.Diagnostics.UserError("PlatformView could not serialize DataArray: " + e.Message, this);
				}
				_arrayDirty = false;
			}
		}

		Dictionary<string, object> _arguments;

		/**
			Sets a named argument on the native view.

			Arguments are delivered as a single JSON object (the same channel as `DataObject`),
			so this is a convenience over assigning `DataObject` yourself. Avoid mixing
			`SetArgument` with a bound `DataObject` on the same view.
		*/
		public void SetArgument(string key, object value)
		{
			if (string.IsNullOrEmpty(key))
			{
				Fuse.Diagnostics.UserError("PlatformView.SetArgument requires a non-empty key.", this);
				return;
			}

			var next = new Dictionary<string, object>();
			if (_arguments != null)
			{
				foreach (var k in _arguments.Keys)
					next[k] = _arguments[k];
			}

			next[key] = value;
			_arguments = next;
			SetDataObject(_arguments, this);
		}

		/** Removes a named argument previously set with `SetArgument`. */
		public void RemoveArgument(string key)
		{
			if (_arguments == null || string.IsNullOrEmpty(key) || !_arguments.ContainsKey(key))
				return;

			var next = new Dictionary<string, object>();
			foreach (var k in _arguments.Keys)
			{
				if (k != key)
					next[k] = _arguments[k];
			}

			_arguments = next;
			SetDataObject(_arguments, this);
		}

		/** Removes all arguments previously set with `SetArgument`. */
		public void ClearArguments()
		{
			if (_arguments == null)
				return;

			_arguments = new Dictionary<string, object>();
			SetDataObject(_arguments, this);
		}

		static Selector _colorSchemeName = "ColorScheme";

		PlatformViewColorScheme _colorScheme;
		/**
			Overrides the color scheme used by the native view. `Unspecified` inherits the system setting.
		*/
		[UXOriginSetter("SetColorScheme")]
		public PlatformViewColorScheme ColorScheme
		{
			get { return _colorScheme; }
			set { SetColorScheme(value, this); }
		}

		public void SetColorScheme(PlatformViewColorScheme value, IPropertyListener origin)
		{
			if (value != _colorScheme)
			{
				_colorScheme = value;
				OnPropertyChanged(_colorSchemeName, origin);
			}

			PushEnvironment();
		}

		static Selector _layoutDirectionName = "LayoutDirection";

		PlatformViewLayoutDirection _layoutDirection;
		/**
			Overrides the layout direction used by the native view. `Unspecified` inherits the system setting.
		*/
		[UXOriginSetter("SetLayoutDirection")]
		public PlatformViewLayoutDirection LayoutDirection
		{
			get { return _layoutDirection; }
			set { SetLayoutDirection(value, this); }
		}

		public void SetLayoutDirection(PlatformViewLayoutDirection value, IPropertyListener origin)
		{
			if (value != _layoutDirection)
			{
				_layoutDirection = value;
				OnPropertyChanged(_layoutDirectionName, origin);
			}

			PushEnvironment();
		}

		static Selector _accessibilityLabelName = "AccessibilityLabel";

		string _accessibilityLabel;
		/**
			Accessibility label announced for the native view.
		*/
		[UXOriginSetter("SetAccessibilityLabel")]
		public string AccessibilityLabel
		{
			get { return _accessibilityLabel; }
			set { SetAccessibilityLabel(value, this); }
		}

		public void SetAccessibilityLabel(string value, IPropertyListener origin)
		{
			if (value != _accessibilityLabel)
			{
				_accessibilityLabel = value;
				OnPropertyChanged(_accessibilityLabelName, origin);
			}

			PushEnvironment();
		}

		static Selector _accessibilityHintName = "AccessibilityHint";

		string _accessibilityHint;
		/**
			Accessibility hint announced for the native view.
		*/
		[UXOriginSetter("SetAccessibilityHint")]
		public string AccessibilityHint
		{
			get { return _accessibilityHint; }
			set { SetAccessibilityHint(value, this); }
		}

		public void SetAccessibilityHint(string value, IPropertyListener origin)
		{
			if (value != _accessibilityHint)
			{
				_accessibilityHint = value;
				OnPropertyChanged(_accessibilityHintName, origin);
			}

			PushEnvironment();
		}

		internal string BuildEnvironment()
		{
			var env = new Dictionary<string, object>();

			if (_colorScheme == PlatformViewColorScheme.Light)
				env["colorScheme"] = "light";
			else if (_colorScheme == PlatformViewColorScheme.Dark)
				env["colorScheme"] = "dark";

			if (_layoutDirection == PlatformViewLayoutDirection.LeftToRight)
				env["layoutDirection"] = "ltr";
			else if (_layoutDirection == PlatformViewLayoutDirection.RightToLeft)
				env["layoutDirection"] = "rtl";

			if (!string.IsNullOrEmpty(_accessibilityLabel))
				env["accessibilityLabel"] = _accessibilityLabel;

			if (!string.IsNullOrEmpty(_accessibilityHint))
				env["accessibilityHint"] = _accessibilityHint;

			return Json.Stringify(env);
		}

		internal void PublishEnvironment(IPlatformView view)
		{
			if (view != null)
				view.Environment = BuildEnvironment();
		}

		void PushEnvironment()
		{
			var pnv = PlatformNativeView;
			if (pnv != null)
				pnv.Environment = BuildEnvironment();
		}

		static Selector _dataStringName = "DataString";

		string _dataString;
		/**
			String value to pass to the native view.
			Changes are automatically synchronized with the native view.
		*/
		[UXOriginSetter("SetDataString")]
		public string DataString
		{
			get { return _dataString; }
			set { SetDataString(value, this); }
		}

		public void SetDataString(string data, IPropertyListener origin)
		{
			UpdateDataString(data, origin);
			if (origin == null)
				return;

			_stringDirty = true;
			RequestDataPush();
		}

		void UpdateDataString(string data, IPropertyListener origin)
		{
			if (data != _dataString)
			{
				_dataString = data;
				OnPropertyChanged(_dataStringName, origin);
			}
		}

		static Selector _dataBoolName = "DataBool";

		bool _dataBool;
		/**
			Boolean value to pass to the native view.
			Changes are automatically synchronized with the native view.
		*/
		[UXOriginSetter("SetDataBool")]
		public bool DataBool
		{
			get { return _dataBool; }
			set { SetDataBool(value, this); }
		}

		public void SetDataBool(bool data, IPropertyListener origin)
		{
			UpdateDataBool(data, origin);
			if (origin == null)
				return;

			_boolDirty = true;
			RequestDataPush();
		}

		void UpdateDataBool(bool data, IPropertyListener origin)
		{
			if (data != _dataBool)
			{
				_dataBool = data;
				OnPropertyChanged(_dataBoolName, origin);
			}
		}

		static Selector _dataIntegerName = "DataInteger";

		int _dataInteger;
		/**
			Integer value to pass to the native view.
			Changes are automatically synchronized with the native view.
		*/
		[UXOriginSetter("SetDataInteger")]
		public int DataInteger
		{
			get { return _dataInteger; }
			set { SetDataInteger(value, this); }
		}

		public void SetDataInteger(int data, IPropertyListener origin)
		{
			UpdateDataInteger(data, origin);
			if (origin == null)
				return;

			_integerDirty = true;
			RequestDataPush();
		}

		void UpdateDataInteger(int data, IPropertyListener origin)
		{
			if (data != _dataInteger)
			{
				_dataInteger = data;
				OnPropertyChanged(_dataIntegerName, origin);
			}
		}

		static Selector _dataFloatName = "DataFloat";

		float _dataFloat;
		/**
			Float value to pass to the native view.
			Changes are automatically synchronized with the native view.
		*/
		[UXOriginSetter("SetDataFloat")]
		public float DataFloat
		{
			get { return _dataFloat; }
			set { SetDataFloat(value, this); }
		}

		public void SetDataFloat(float data, IPropertyListener origin)
		{
			UpdateDataFloat(data, origin);
			if (origin == null)
				return;

			_floatDirty = true;
			RequestDataPush();
		}

		void UpdateDataFloat(float data, IPropertyListener origin)
		{
			if (data != _dataFloat)
			{
				_dataFloat = data;
				OnPropertyChanged(_dataFloatName, origin);
			}
		}

		static Selector _dataDoubleName = "DataDouble";

		double _dataDouble;
		/**
			Double-precision value to pass to the native view.
			Changes are automatically synchronized with the native view.
		*/
		[UXOriginSetter("SetDataDouble")]
		public double DataDouble
		{
			get { return _dataDouble; }
			set { SetDataDouble(value, this); }
		}

		public void SetDataDouble(double data, IPropertyListener origin)
		{
			UpdateDataDouble(data, origin);
			if (origin == null)
				return;

			_doubleDirty = true;
			RequestDataPush();
		}

		void UpdateDataDouble(double data, IPropertyListener origin)
		{
			if (data != _dataDouble)
			{
				_dataDouble = data;
				OnPropertyChanged(_dataDoubleName, origin);
			}
		}

		static Selector _dataObjectName = "DataObject";

		object _dataObject;
		/**
			Object to pass to the native view.
			The object is automatically JSON-serialized before being sent to the native view.
		*/
		[UXOriginSetter("SetDataObject")]
		public object DataObject
		{
			get { return _dataObject; }
			set { SetDataObject(value, this); }
		}

		public void SetDataObject(object data, IPropertyListener origin)
		{
			UpdateDataObject(data, origin);
			if (origin == null)
				return;

			_objectDirty = true;
			RequestDataPush();
		}

		void UpdateDataObject(object data, IPropertyListener origin)
		{
			if (data != _dataObject)
			{
				_dataObject = data;
				OnPropertyChanged(_dataObjectName, origin);
			}
		}

		static Selector _dataArrayName = "DataArray";

		object _dataArray;
		/**
			Array/list to pass to the native view.
			The array is automatically JSON-serialized before being sent to the native view.
		*/
		[UXOriginSetter("SetDataArray")]
		public object DataArray
		{
			get { return _dataArray; }
			set { SetDataArray(value, this); }
		}

		public void SetDataArray(object data, IPropertyListener origin)
		{
			UpdateDataArray(data, origin);
			if (origin == null)
				return;

			_arrayDirty = true;
			RequestDataPush();
		}

		void UpdateDataArray(object data, IPropertyListener origin)
		{
			if (data != _dataArray)
			{
				_dataArray = data;
				OnPropertyChanged(_dataArrayName, origin);
			}
		}

		static Selector _viewNameSelector = "ViewName";

		string _viewName;
		/**
			The name/identifier of the native view to display.

			This should correspond to a view registered with the platform-specific view factory:
			- iOS: SwiftUI view registered with SwiftUIViewFactory
			- Android: Jetpack Compose view registered with ComposeViewFactory
		*/
		[UXOriginSetter("SetViewName")]
		public string ViewName
		{
			get { return _viewName; }
			set { SetViewName(value, this); }
		}

		public void SetViewName(string viewName, IPropertyListener origin)
		{
			UpdateViewName(viewName, origin);
			var pnv = PlatformNativeView;
			if (pnv != null)
			{
				pnv.Source = viewName;
				pnv.Environment = BuildEnvironment();
			}
		}

		void UpdateViewName(string viewName, IPropertyListener origin)
		{
			if (viewName != _viewName)
			{
				_viewName = viewName;
				OnPropertyChanged(_viewNameSelector, origin);
			}
		}

		/**
			Event triggered when the native view sends events back to Fuse.
			Subscribe to this event to handle custom events from native views.
		*/
		public event PlatformViewHandler EventHandler;

		/**
			Raised when the native view has been created and is ready to receive data and commands.
		*/
		public event EventHandler Loaded;

		/**
			Raised when the native view is disposed.
		*/
		public event EventHandler Unloaded;

		/**
			Raised when the native view becomes visible on screen.
		*/
		public event EventHandler Appeared;

		/**
			Raised when the native view is no longer visible on screen.
		*/
		public event EventHandler Disappeared;

		internal void TriggerEvent(string eventName, string value)
		{
			if (EventHandler != null)
			{
				EventHandler(this, new PlatformViewArgs(eventName, value));
			}
		}

		internal void OnLoaded()
		{
			if (Loaded != null)
				Loaded(this, EventArgs.Empty);
		}

		internal void OnUnloaded()
		{
			if (Unloaded != null)
				Unloaded(this, EventArgs.Empty);
		}

		internal void OnAppeared()
		{
			if (Appeared != null)
				Appeared(this, EventArgs.Empty);
		}

		internal void OnDisappeared()
		{
			if (Disappeared != null)
				Disappeared(this, EventArgs.Empty);
		}

		/**
			Called when no native view is registered under the current `ViewName`.
			Reports a user-facing diagnostic instead of failing silently.
		*/
		internal void OnViewNotFound(string viewName)
		{
			if (string.IsNullOrEmpty(viewName))
				return;

			Fuse.Diagnostics.UserError("No native view is registered for ViewName '" + viewName +
				"'. Register it with the platform-specific view registry before creating the PlatformView.", this);
		}

		internal void OnDataIntegerChanged(int newValue)
		{
			SetDataInteger(newValue, null);
		}

		internal void OnDataFloatChanged(float newValue)
		{
			SetDataFloat(newValue, null);
		}

		internal void OnDataDoubleChanged(double newValue)
		{
			SetDataDouble(newValue, null);
		}

		internal void OnDataBoolChanged(bool newValue)
		{
			SetDataBool(newValue, null);
		}

		internal void OnDataStringChanged(string newValue)
		{
			SetDataString(newValue, null);
		}

		internal void OnDataObjectChanged(string newValue)
		{
			object parsed = null;
			try
			{
				parsed = Json.Parse(newValue);
			}
			catch (Exception e)
			{
				Fuse.Diagnostics.UserError("PlatformView could not parse DataObject received from the native view: " + e.Message, this);
				return;
			}

			SetDataObject(parsed, null);
		}

		internal void OnDataArrayChanged(string newValue)
		{
			object parsed = null;
			try
			{
				parsed = Json.Parse(newValue);
			}
			catch (Exception e)
			{
				Fuse.Diagnostics.UserError("PlatformView could not parse DataArray received from the native view: " + e.Message, this);
				return;
			}

			SetDataArray(parsed, null);
		}

		IPlatformView PlatformNativeView
		{
			get { return (IPlatformView)NativeView; }
		}
	}

}
