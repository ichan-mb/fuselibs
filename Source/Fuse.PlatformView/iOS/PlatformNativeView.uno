using Uno;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;

using Fuse;
using Fuse.Controls;
using Fuse.Controls.Native;
using Fuse.Controls.Native.iOS;

namespace Fuse.Controls.Native.iOS
{
	extern(!iOS) class PlatformNativeView
	{
		[UXConstructor]
		public PlatformNativeView([UXParameter("Host")]PlatformView host) { }
	}

	/**
		iOS-specific implementation that integrates SwiftUI views into Fuse applications.

		Acts as a bridge between Fuse's UI system and SwiftUI, handling view creation,
		data binding, and event communication. Uses SwiftUIHostingContainer to host
		SwiftUI views and SwiftUIViewFactory to manage view registration and data
		synchronization.
	*/
	[ForeignInclude(Language.ObjC, "@(Project.Name)-Swift.h")]
	[Require("source.include", "UIKit/UIKit.h")]
	[Require("source.include", "iOS/SwiftUIHostingContainer.h")]
	extern(iOS) class PlatformNativeView : LeafView, IPlatformView
	{

		static int _instanceIdCounter;

		static int NextInstanceId()
		{
			_instanceIdCounter++;
			return _instanceIdCounter;
		}

		PlatformView _host;
		int _instanceId;
		bool _loaded;

		[UXConstructor]
		public PlatformNativeView([UXParameter("Host")]PlatformView host) : base(Create())
		{
			_host = host;
			_instanceId = NextInstanceId();

			// Data is assigned before the source so that the SwiftUI view is
			// created with the current values through PushAllData().
			DataFloat = _host.DataFloat;
			DataDouble = _host.DataDouble;
			DataInteger = _host.DataInteger;
			DataBool = _host.DataBool;
			DataString = _host.DataString;
			if (_host.DataObject != null)
				Data = Json.Stringify(_host.DataObject);
			if (_host.DataArray != null)
				DataArray = Json.Stringify(_host.DataArray);

			Source = _host.ViewName;
			_host.PublishEnvironment(this);
		}

		public override void Dispose()
		{
			if (_loaded)
			{
				_host.OnUnloaded();
				_loaded = false;
			}

			if (_instanceId != 0)
			{
				DisposeView(_instanceId);
				_instanceId = 0;
			}

			base.Dispose();
			_host = null;
		}

		void HandleLoaded()
		{
			_loaded = true;
			_host.OnLoaded();
		}

		string _data;
		/**
			JSON object data to pass to the SwiftUI view.
			Changes are automatically synchronized with the SwiftUI view through SwiftUIViewFactory.
		*/
		public string Data
		{
			get { return _data; }
			set
			{
				if (value != _data)
				{
					_data = value;
					SetData(Handle, _instanceId, value);
				}
			}
		}

		string _dataArray;
		/**
			JSON array data to pass to the SwiftUI view.
			Array changes are automatically synchronized with the SwiftUI view.
		*/
		public string DataArray
		{
			get { return _dataArray; }
			set
			{
				if (value != _dataArray)
				{
					_dataArray = value;
					SetDataArray(Handle, _instanceId, value);
				}
			}
		}

		float _dataFloat;
		/**
			Float data to pass to the SwiftUI view.
			Changes are automatically synchronized with the SwiftUI view.
		*/
		public float DataFloat
		{
			get { return _dataFloat; }
			set
			{
				if (value != _dataFloat)
				{
					_dataFloat = value;
					SetDataFloat(Handle, _instanceId, value);
				}
			}
		}

		double _dataDouble;
		/**
			Double data to pass to the SwiftUI view.
			Changes are automatically synchronized with the SwiftUI view.
		*/
		public double DataDouble
		{
			get { return _dataDouble; }
			set
			{
				if (value != _dataDouble)
				{
					_dataDouble = value;
					SetDataDouble(Handle, _instanceId, value);
				}
			}
		}

		int _dataInteger;
		/**
			Integer data to pass to the SwiftUI view.
			Changes are automatically synchronized with the SwiftUI view.
		*/
		public int DataInteger
		{
			get { return _dataInteger; }
			set
			{
				if (value != _dataInteger)
				{
					_dataInteger = value;
					SetDataInteger(Handle, _instanceId, value);
				}
			}
		}

		bool _dataBool;
		/**
			Boolean data to pass to the SwiftUI view.
			Changes are automatically synchronized with the SwiftUI view.
		*/
		public bool DataBool
		{
			get { return _dataBool; }
			set
			{
				if (value != _dataBool)
				{
					_dataBool = value;
					SetDataBool(Handle, _instanceId, value);
				}
			}
		}

		string _dataString;
		/**
			String data to pass to the SwiftUI view.
			Changes are automatically synchronized with the SwiftUI view.
		*/
		public string DataString
		{
			get { return _dataString; }
			set
			{
				if (value != _dataString)
				{
					_dataString = value;
					SetDataString(Handle, _instanceId, value ?? "");
				}
			}
		}

		string _source;
		/**
			The name of the SwiftUI view to display.

			Should correspond to a view registered with SwiftUIViewFactory.
			Changing the source will replace the current SwiftUI view with the new one
			and re-synchronize the current data values.
		*/
		public string Source
		{
			get { return _source; }
			set
			{
				if (value != _source)
				{
					_source = value;

					if (_loaded)
					{
						_host.OnUnloaded();
						_loaded = false;
					}

					if (string.IsNullOrEmpty(value))
					{
						ClearSource(Handle);
					}
					else
					{
						SetSource(Handle, _instanceId, value,
							_host.OnDataIntegerChanged,
							_host.OnDataDoubleChanged,
							_host.OnDataFloatChanged,
							_host.OnDataBoolChanged,
							_host.OnDataStringChanged,
							_host.OnDataObjectChanged,
							_host.OnDataArrayChanged,
							_host.TriggerEvent,
							_host.OnViewNotFound,
							HandleLoaded,
							_host.OnAppeared,
							_host.OnDisappeared);
						PushAllData();
					}
				}
			}
		}

		/**
			Pushes the current data values to the SwiftUI view. Used when the native view is
			(re)created, for example after changing ViewName.
		*/
		void PushAllData()
		{
			if (string.IsNullOrEmpty(_source))
				return;

			if (_data != null)
				SetData(Handle, _instanceId, _data);
			if (_dataArray != null)
				SetDataArray(Handle, _instanceId, _dataArray);

			SetDataFloat(Handle, _instanceId, _dataFloat);
			SetDataDouble(Handle, _instanceId, _dataDouble);
			SetDataInteger(Handle, _instanceId, _dataInteger);
			SetDataBool(Handle, _instanceId, _dataBool);
			SetDataString(Handle, _instanceId, _dataString ?? "");

			_host.ClearPendingData();
		}

		/**
			Sends a command with optional JSON arguments to the SwiftUI view.
		*/
		public void Invoke(string command, string arguments)
		{
			InvokeCommand(Handle, _instanceId, command, arguments ?? "");
		}

		[Foreign(Language.ObjC)]
		static void InvokeCommand(ObjC.Object handle, int instanceId, string command, string arguments)
		@{
			[SwiftUIViewFactory invokeWithId:instanceId command:command arguments:arguments];
		@}

		string _environment;
		/**
			JSON environment overrides (color scheme, layout direction) for the SwiftUI view.
		*/
		public string Environment
		{
			get { return _environment; }
			set
			{
				if (value != _environment)
				{
					_environment = value;
					SetEnvironment(Handle, _instanceId, value ?? "{}");
				}
			}
		}

		[Foreign(Language.ObjC)]
		static void SetEnvironment(ObjC.Object handle, int instanceId, string json)
		@{
			[SwiftUIViewFactory setEnvironmentWithId:instanceId json:json];
		@}

		[Foreign(Language.ObjC)]
		void SetSource(ObjC.Object handle, int instanceId, string viewName,
			Action<int> intCallback,
			Action<double> doubleCallback,
			Action<float> floatCallback,
			Action<bool> boolCallback,
			Action<string> stringCallback,
			Action<string> objectCallback,
			Action<string> arrayCallback,
			Action<string, string> callback,
			Action<string> notFoundCallback,
			Action loadedCallback,
			Action appearedCallback,
			Action disappearedCallback)
		@{
			SwiftUIHostingContainer* swiftUIHostingContainer = (SwiftUIHostingContainer*)handle;
			UIViewController* hostingController = [SwiftUIViewFactory makeSwiftUIViewWithId:instanceId name:viewName dataIntegerCallback:intCallback dataDoubleCallback:doubleCallback dataFloatCallback:floatCallback dataBoolCallback:boolCallback dataStringCallback:stringCallback dataObjectCallback:objectCallback dataArrayCallback:arrayCallback eventCallback:callback notFoundCallback:notFoundCallback loadedCallback:loadedCallback appearedCallback:appearedCallback disappearedCallback:disappearedCallback];
			swiftUIHostingContainer.hostingController = hostingController;
			[swiftUIHostingContainer setNeedsLayout];
		@}

		[Foreign(Language.ObjC)]
		static void ClearSource(ObjC.Object handle)
		@{
			SwiftUIHostingContainer* swiftUIHostingContainer = (SwiftUIHostingContainer*)handle;
			swiftUIHostingContainer.hostingController = nil;
		@}

		[Foreign(Language.ObjC)]
		static void DisposeView(int instanceId)
		@{
			[SwiftUIViewFactory disposeWithId:instanceId];
		@}

		[Foreign(Language.ObjC)]
		static void SetData(ObjC.Object handle, int instanceId, string data)
		@{
			[SwiftUIViewFactory setDataWithId:instanceId data:data isArray:NO];
		@}

		[Foreign(Language.ObjC)]
		static void SetDataArray(ObjC.Object handle, int instanceId, string data)
		@{
			[SwiftUIViewFactory setDataWithId:instanceId data:data isArray:YES];
		@}

		[Foreign(Language.ObjC)]
		static void SetDataFloat(ObjC.Object handle, int instanceId, float data)
		@{
			[SwiftUIViewFactory setDataWithId:instanceId dataFloat:data];
		@}

		[Foreign(Language.ObjC)]
		static void SetDataDouble(ObjC.Object handle, int instanceId, double data)
		@{
			[SwiftUIViewFactory setDataWithId:instanceId dataDouble:data];
		@}

		[Foreign(Language.ObjC)]
		static void SetDataInteger(ObjC.Object handle, int instanceId, int data)
		@{
			[SwiftUIViewFactory setDataWithId:instanceId dataInteger:data];
		@}

		[Foreign(Language.ObjC)]
		static void SetDataBool(ObjC.Object handle, int instanceId, bool data)
		@{
			[SwiftUIViewFactory setDataWithId:instanceId dataBool:data];
		@}

		[Foreign(Language.ObjC)]
		static void SetDataString(ObjC.Object handle, int instanceId, string data)
		@{
			[SwiftUIViewFactory setDataWithId:instanceId dataString:data];
		@}

		/**
			Creates a SwiftUIHostingContainer configured for hosting SwiftUI views.
			The container is configured for proper touch handling, layout, and clipping behavior.
		*/
		[Foreign(Language.ObjC)]
		static ObjC.Object Create()
		@{
			SwiftUIHostingContainer* container  = [[SwiftUIHostingContainer alloc] init];
			[container setMultipleTouchEnabled:true];
			[container setAutoresizesSubviews:false];
			[container setTranslatesAutoresizingMaskIntoConstraints:false];
			[container setClipsToBounds:true];
			return container;
		@}
	}
}
