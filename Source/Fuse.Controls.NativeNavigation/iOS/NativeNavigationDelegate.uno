using Uno;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Controls.iOS
{
	[ForeignInclude(Language.ObjC, "iOS/NativeNavigationDelegate.h")]
	extern(iOS) internal static class NativeNavigationDelegate
	{
		[Foreign(Language.ObjC)]
		public static ObjC.Object Create(Action<string> onWillShowViewController, Action<string> onDidShowViewController)
		@{
			FuseNavigationDelegate* delegate = [[FuseNavigationDelegate alloc]
				initWithCallbacks:onWillShowViewController
						didShow:onDidShowViewController];
			return delegate;
		@}

		[Foreign(Language.ObjC)]
		public static void Destroy(ObjC.Object delegateHandle)
		@{
			// Leave the delegate installed: removing it would stop transition reporting (and swipe-back).
			// ARC handles cleanup.
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
