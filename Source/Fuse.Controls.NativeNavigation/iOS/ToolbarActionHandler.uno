using Uno;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Controls.iOS
{
	[ForeignInclude(Language.ObjC, "iOS/ToolbarActionHandler.h")]
	extern(iOS) internal static class ToolbarActionHandler
	{
		[Foreign(Language.ObjC)]
		public static ObjC.Object Create(Action<int> onToolbarItemClicked, Action<int> onMenuItemClicked)
		@{
			FuseToolbarActionHandler* handler = [[FuseToolbarActionHandler alloc]
				initWithCallbacks:onToolbarItemClicked
				  menuItemClicked:onMenuItemClicked];
			return handler;
		@}

		[Foreign(Language.ObjC)]
		public static void Destroy(ObjC.Object handle)
		@{
			FuseToolbarActionHandler* handler = (FuseToolbarActionHandler*)handle;
			handler.onToolbarItemClicked = nil;
			handler.onMenuItemClicked = nil;
		@}
	}
}
