using Uno;
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
		string _eventName;
		object _eventValue;

		public PlatformViewArgs(string eventName, object value)
		{
			_eventName = eventName;
			_eventValue = value;
		}
		void IScriptEvent.Serialize(IEventSerializer s)
		{
			Serialize(s);
		}

		virtual void Serialize(IEventSerializer s)
		{
			s.AddString("eventName", _eventName);
			s.AddObject("eventValue", _eventValue);
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
		int DataInteger { set; }
		bool DataBool { set; }
		string DataString { set; }
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
			var pnv = PlatformNativeView;
			if (pnv != null && origin != null)
			{
				pnv.DataString = data;
			}
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
			var pnv = PlatformNativeView;
			if (pnv != null && origin != null)
			{
				pnv.DataBool = data;
			}
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
			var pnv = PlatformNativeView;
			if (pnv != null && origin != null)
			{
				pnv.DataInteger = data;
			}
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
			var pnv = PlatformNativeView;
			if (pnv != null && origin != null)
			{
				pnv.DataFloat = data;
			}
		}

		void UpdateDataFloat(float data, IPropertyListener origin)
		{
			if (data != _dataFloat)
			{
				_dataFloat = data;
				OnPropertyChanged(_dataFloatName, origin);
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
			var pnv = PlatformNativeView;
			if (pnv != null && origin != null)
			{
				pnv.Data = Json.Stringify(data);
			}
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
			var pnv = PlatformNativeView;
			if (pnv != null && origin != null)
				pnv.DataArray = Json.Stringify(data);
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
				pnv.Source = viewName;
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

		internal void TriggerEvent(string eventName, string value)
		{
			if (EventHandler != null)
			{
				EventHandler(this, new PlatformViewArgs(eventName, value));
			}
		}

		internal void OnDataIntegerChanged(int newValue)
		{
			SetDataInteger(newValue, null);
		}

		internal void OnDataFloatChanged(float newValue)
		{
			SetDataFloat(newValue, null);
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
			SetDataObject(Json.Parse(newValue), null);
		}

		internal void OnDataArrayChanged(string newValue)
		{
			SetDataArray(Json.Parse(newValue), null);
		}

		IPlatformView PlatformNativeView
		{
			get { return (IPlatformView)NativeView; }
		}
	}

}
