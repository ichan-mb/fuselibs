using Uno;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;

using Fuse;
using Fuse.Controls;
using Fuse.Controls.Native;
using Fuse.Controls.Native.Android;

namespace Fuse.Controls.Native.Android
{
	extern(!Android) class PlatformNativeView
	{
		[UXConstructor]
		public PlatformNativeView([UXParameter("Host")]PlatformView host) { }
	}

	/**
		Android-specific implementation that integrates Jetpack Compose views into Fuse applications.

		Acts as a bridge between Fuse's UI system and Jetpack Compose, handling view creation,
		data binding, and event communication. Uses ComposeContainer to host Compose views
		and manages view registration through the viewRegistration system.
	*/
	extern(Android) class PlatformNativeView : LeafView, IPlatformView
	{

		PlatformView _host;
		bool _loaded;

		[UXConstructor]
		public PlatformNativeView([UXParameter("Host")]PlatformView host) : base(Create())
		{
			_host = host;
			Source = _host.ViewName;
			if (_host.DataObject != null)
				Data = Json.Stringify(_host.DataObject);
			if (_host.DataArray != null)
				DataArray = Json.Stringify(_host.DataArray);
			DataFloat = _host.DataFloat;
			DataDouble = _host.DataDouble;
			DataInteger = _host.DataInteger;
			DataBool = _host.DataBool;
			DataString = _host.DataString;

			_host.PublishEnvironment(this);
		}

		public override void Dispose()
		{
			if (_loaded)
			{
				_host.OnUnloaded();
				_loaded = false;
			}

			DisposeContainer(Handle);
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
			JSON object data to pass to the Jetpack Compose view.
			Changes are automatically synchronized with the Compose view through ComposeContainer.
		*/
		public string Data
		{
			get { return _data; }
			set
			{
				if (value != _data)
				{
					_data = value;
					SetDataObject(Handle, value);
				}
			}
		}

		string _dataArray;
		/**
			JSON array data to pass to the Jetpack Compose view.
			Changes are automatically synchronized with the Compose view.
		*/
		public string DataArray
		{
			get { return _dataArray; }
			set
			{
				if (value != _dataArray)
				{
					_dataArray = value;
					SetDataArray(Handle, value);
				}
			}
		}

		float _dataFloat;
		/**
			Float data to pass to the Jetpack Compose view.
			Changes are automatically synchronized with the Compose view.
		*/
		public float DataFloat
		{
			get { return _dataFloat; }
			set
			{
				if (value != _dataFloat)
				{
					_dataFloat = value;
					SetDataFloat(Handle, value);
				}
			}
		}

		double _dataDouble;
		/**
			Double data to pass to the Jetpack Compose view.
			Changes are automatically synchronized with the Compose view.
		*/
		public double DataDouble
		{
			get { return _dataDouble; }
			set
			{
				if (value != _dataDouble)
				{
					_dataDouble = value;
					SetDataDouble(Handle, value);
				}
			}
		}

		int _dataInteger;
		/**
			Integer data to pass to the Jetpack Compose view.
			Changes are automatically synchronized with the Compose view.
		*/
		public int DataInteger
		{
			get { return _dataInteger; }
			set
			{
				if (value != _dataInteger)
				{
					_dataInteger = value;
					SetDataInteger(Handle, value);
				}
			}
		}

		bool _dataBool;
		/**
			Boolean data to pass to the Jetpack Compose view.
			Changes are automatically synchronized with the Compose view.
		*/
		public bool DataBool
		{
			get { return _dataBool; }
			set
			{
				if (value != _dataBool)
				{
					_dataBool = value;
					SetDataBool(Handle, value);
				}
			}
		}

		string _dataString;
		/**
			String data to pass to the Jetpack Compose view.
			Changes are automatically synchronized with the Compose view.
		*/
		public string DataString
		{
			get { return _dataString; }
			set
			{
				if (value != _dataString)
				{
					_dataString = value;
					SetDataString(Handle, value ?? "");
				}
			}
		}

		string _source;
		/**
			The name of the Jetpack Compose view to display.

			Should correspond to a view registered with the ComposeViewFactory.
			Changing the source will replace the current Compose view with the new one.
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
						SetSource(Handle, value,
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
					}
				}
			}
		}

		/**
			Sends a command with optional JSON arguments to the Compose view.
		*/
		public void Invoke(string command, string arguments)
		{
			InvokeCommand(Handle, command, arguments ?? "");
		}

		[Foreign(Language.Java)]
		static void InvokeCommand(Java.Object handle, string command, string arguments)
		@{
			com.fuse.android.kt.ComposeContainer composeView = (com.fuse.android.kt.ComposeContainer)handle;
			composeView.invoke(command, arguments);
		@}

		string _environment;
		/**
			JSON environment overrides (color scheme, layout direction) for the Compose view.
		*/
		public string Environment
		{
			get { return _environment; }
			set
			{
				if (value != _environment)
				{
					_environment = value;
					SetEnvironment(Handle, value ?? "{}");
				}
			}
		}

		[Foreign(Language.Java)]
		static void SetEnvironment(Java.Object handle, string json)
		@{
			com.fuse.android.kt.ComposeContainer composeView = (com.fuse.android.kt.ComposeContainer)handle;
			composeView.setEnvironment(json);
		@}

		[Foreign(Language.Java)]
		static void SetSource(Java.Object handle, string content,
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
			com.fuse.android.kt.ComposeContainer composeView = (com.fuse.android.kt.ComposeContainer)handle;
			composeView.showView(content,
				integer ->
				{
					intCallback.run(integer);
					return null;
				},
				aDouble ->
				{
					doubleCallback.run((aDouble));
					return null;
				},
				aFloat ->
				{
					floatCallback.run((aFloat));
					return null;
				},
				aBoolean ->
				{
					boolCallback.run(aBoolean);
					return null;
				},
				aString -> {
					stringCallback.run(aString);
					return null;
				},
				anObject -> {
					objectCallback.run(anObject);
					return null;
				},
				anArray -> {
					arrayCallback.run(anArray);
					return null;
				},
				(key, value) -> {
					callback.run(key, value);
					return null;
				},
				name -> {
					notFoundCallback.run(name);
					return null;
				},
				() -> {
					loadedCallback.run();
					return null;
				},
				() -> {
					appearedCallback.run();
					return null;
				},
				() -> {
					disappearedCallback.run();
					return null;
				}
			);
		@}

		[Foreign(Language.Java)]
		static void ClearSource(Java.Object handle)
		@{
			com.fuse.android.kt.ComposeContainer composeView = (com.fuse.android.kt.ComposeContainer)handle;
			composeView.clearView();
		@}

		[Foreign(Language.Java)]
		static void DisposeContainer(Java.Object handle)
		@{
			com.fuse.android.kt.ComposeContainer composeView = (com.fuse.android.kt.ComposeContainer)handle;
			composeView.dispose();
		@}

		/**
			Creates a ComposeContainer configured for hosting Jetpack Compose views.
			The container is configured for proper focus handling and layout behavior.
		*/
		[Foreign(Language.Java)]
		static Java.Object Create()
		@{
			com.fuse.android.kt.ComposeContainer composeContainer = new com.fuse.android.kt.ComposeContainer(com.fuse.Activity.getRootActivity());
			composeContainer.setFocusable(true);
			composeContainer.setFocusableInTouchMode(true);
			composeContainer.setLayoutParams(new android.widget.FrameLayout.LayoutParams(android.view.ViewGroup.LayoutParams.MATCH_PARENT, android.view.ViewGroup.LayoutParams.MATCH_PARENT));

			return composeContainer;
		@}

		[Foreign(Language.Java)]
		static void SetDataObject(Java.Object handle, string data)
		@{
			com.fuse.android.kt.ComposeContainer composeView = (com.fuse.android.kt.ComposeContainer)handle;
			composeView.setDataObject(data);
		@}

		[Foreign(Language.Java)]
		static void SetDataArray(Java.Object handle, string data)
		@{
			com.fuse.android.kt.ComposeContainer composeView = (com.fuse.android.kt.ComposeContainer)handle;
			composeView.setDataArray(data);
		@}

		[Foreign(Language.Java)]
		static void SetDataInteger(Java.Object handle, int data)
		@{
			com.fuse.android.kt.ComposeContainer composeView = (com.fuse.android.kt.ComposeContainer)handle;
			composeView.setDataInteger(data);
		@}

		[Foreign(Language.Java)]
		static void SetDataFloat(Java.Object handle, float data)
		@{
			com.fuse.android.kt.ComposeContainer composeView = (com.fuse.android.kt.ComposeContainer)handle;
			composeView.setDataFloat(data);
		@}

		[Foreign(Language.Java)]
		static void SetDataDouble(Java.Object handle, double data)
		@{
			com.fuse.android.kt.ComposeContainer composeView = (com.fuse.android.kt.ComposeContainer)handle;
			composeView.setDataDouble(data);
		@}

		[Foreign(Language.Java)]
		static void SetDataBool(Java.Object handle, bool data)
		@{
			com.fuse.android.kt.ComposeContainer composeView = (com.fuse.android.kt.ComposeContainer)handle;
			composeView.setDataBool(data);
		@}

		[Foreign(Language.Java)]
		static void SetDataString(Java.Object handle, string data)
		@{
			com.fuse.android.kt.ComposeContainer composeView = (com.fuse.android.kt.ComposeContainer)handle;
			composeView.setDataString(data);
		@}
	}
}
