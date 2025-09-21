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

		PlatformView _host;
		ObjC.Object _container;

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
			_container = null;
			_host = null;
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
					SetData(Handle, Source, value);
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
					SetDataArray(Handle, Source, value);
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
					SetDataFloat(Handle, Source, value);
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
					SetDataInteger(Handle, Source, value);
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
					SetDataBool(Handle, Source, value);
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
					SetDataString(Handle, Source, value);
				}
			}
		}

		string _source;
		/**
			The name of the SwiftUI view to display.

			Should correspond to a view registered with SwiftUIViewFactory.
			Changing the source will replace the current SwiftUI view with the new one.
		*/
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

		[Foreign(Language.ObjC)]
		void SetSource(ObjC.Object handle, string viewName,
			Action<int> intCallback,
			Action<float> floatCallback,
			Action<bool> boolCallback,
			Action<string> stringCallback,
			Action<string> objectCallback,
			Action<string> arrayCallback,
			Action<string, string> callback)
		@{
			SwiftUIHostingContainer* swiftUIHostingContainer = (SwiftUIHostingContainer*)handle;
			UIView *oldView = swiftUIHostingContainer.subviews.firstObject;
			if (oldView) {
				[oldView removeFromSuperview];
				oldView = nil;
			}
			UIViewController* hostingController = [SwiftUIViewFactory makeSwiftUIViewWithName:viewName dataIntegerCallback:intCallback dataFloatCallback:floatCallback dataBoolCallback:boolCallback dataStringCallback:stringCallback dataObjectCallback:objectCallback dataArrayCallback:arrayCallback eventCallback:callback];
			swiftUIHostingContainer.swiftUIView = hostingController.view;
			[swiftUIHostingContainer addSubview:hostingController.view];
			[swiftUIHostingContainer setNeedsLayout];
			@{PlatformNativeView:of(_this)._container:set(hostingController)};
		@}

		[Foreign(Language.ObjC)]
		static void SetData(ObjC.Object handle, string viewName, string data)
		@{
			[SwiftUIViewFactory setDataWithViewName:viewName data:data isArray:NO];
		@}

		[Foreign(Language.ObjC)]
		static void SetDataArray(ObjC.Object handle, string viewName, string data)
		@{
			[SwiftUIViewFactory setDataWithViewName:viewName data:data isArray:YES];
		@}

		[Foreign(Language.ObjC)]
		static void SetDataFloat(ObjC.Object handle, string viewName, float data)
		@{
			[SwiftUIViewFactory setDataWithViewName:viewName dataFloat:data];
		@}

		[Foreign(Language.ObjC)]
		static void SetDataInteger(ObjC.Object handle, string viewName, int data)
		@{
			[SwiftUIViewFactory setDataWithViewName:viewName dataInteger:data];
		@}

		[Foreign(Language.ObjC)]
		static void SetDataBool(ObjC.Object handle, string viewName, bool data)
		@{
			[SwiftUIViewFactory setDataWithViewName:viewName dataBool:data];
		@}

		[Foreign(Language.ObjC)]
		static void SetDataString(ObjC.Object handle, string viewName, string data)
		@{
			[SwiftUIViewFactory setDataWithViewName:viewName dataString:data];
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
