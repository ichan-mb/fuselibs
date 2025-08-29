using Uno;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Controls.iOS
{
	[ForeignInclude(Language.ObjC, "iOS/NativeNavigationDelegate.h")]
	extern(iOS) internal static class NativeNavigationDelegate
	{
		[Foreign(Language.ObjC)]
		public static ObjC.Object Create(Action<string> onViewWillAppear, Action<string> onViewDidAppear, Action<string> onViewWillDisappear, Action<string> onViewDidDisappear)
		@{
			FuseNavigationDelegate* delegate = [[FuseNavigationDelegate alloc]
				initWithCallbacks:onViewWillAppear
					   didAppear:onViewDidAppear
				   willDisappear:onViewWillDisappear
					didDisappear:onViewDidDisappear];
			return delegate;
		@}

		[Foreign(Language.ObjC)]
		public static void Destroy(ObjC.Object delegateHandle)
		@{
			// ARC will handle cleanup automatically
		@}

		[Foreign(Language.ObjC)]
		public static void SetAsDelegate(ObjC.Object navigationController, ObjC.Object delegateHandle)
		@{
			UINavigationController* navController = (UINavigationController*)navigationController;
			FuseNavigationDelegate* delegate = (FuseNavigationDelegate*)delegateHandle;
			navController.delegate = delegate;
		@}
	}
}
