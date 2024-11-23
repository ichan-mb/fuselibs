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

	[Require("gradle.dependency.implementation", "androidx.compose.ui:ui:1.7.5")]
	[Require("gradle.dependency.implementation", "androidx.compose.runtime:runtime-livedata:1.7.5")]
	[Require("gradle.dependency.implementation", "androidx.compose.foundation:foundation:1.7.5")]
	[Require("gradle.dependency.implementation", "androidx.compose.material3:material3:1.3.1")]
	[Require("gradle.android.end", "buildFeatures { compose true } ")]
	[Require("gradle.android.end", "composeOptions { kotlinCompilerExtensionVersion '1.5.1' } ")]
	extern(Android) class PlatformNativeView : LeafView, IPlatformView
	{

		PlatformView _host;

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
			DataInteger = _host.DataInteger;
			DataBool = _host.DataBool;
			DataString = _host.DataString;
		}

		public override void Dispose()
		{
			base.Dispose();
			_host = null;
		}

		string _data;
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

		int _dataInteger;
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
		public string DataString
		{
			get { return _dataString; }
			set
			{
				if (value != _dataString)
				{
					_dataString = value;
					SetDataString(Handle, value);
				}
			}
		}

		string _source;
		public string Source
		{
			get { return _source; }
			set
			{
				if (value != _source)
				{
					_source = value;
					SetSource(Handle, value, _host.OnDataIntegerChanged, _host.OnDataFloatChanged, _host.OnDataBoolChanged, _host.OnDataStringChanged, _host.OnDataObjectChanged, _host.OnDataArrayChanged, _host.TriggerEvent);
				}
			}
		}

		[Foreign(Language.Java)]
		static void SetSource(Java.Object handle, string content,
			Action<int> intCallback,
			Action<float> floatCallback,
			Action<bool> boolCallback,
			Action<string> stringCallback,
			Action<string> objectCallback,
			Action<string> arrayCallback,
			Action<string, string> callback)
		@{
			com.fuse.android.kt.ComposeContainer composeView = (com.fuse.android.kt.ComposeContainer)handle;
			composeView.showView(content,
				integer ->
				{
					intCallback.run(integer);
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
				}
			);
		@}

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