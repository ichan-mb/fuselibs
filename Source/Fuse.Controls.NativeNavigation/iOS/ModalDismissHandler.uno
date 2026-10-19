using Uno;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Controls.iOS
{
	[ForeignInclude(Language.ObjC, "iOS/ModalDismissHandler.h")]
	extern(iOS) internal static class ModalDismissHandler
	{
		[Foreign(Language.ObjC)]
		public static ObjC.Object Create(Action onDismissed)
		@{
			FuseModalDismissHandler* handler = [[FuseModalDismissHandler alloc] initWithCallback:onDismissed];
			return handler;
		@}

		/**
			Clears the callback. The handler must outlive the modal because the presentation controller
			holds its delegate weakly.
		*/
		[Foreign(Language.ObjC)]
		public static void Destroy(ObjC.Object handle)
		@{
			FuseModalDismissHandler* handler = (FuseModalDismissHandler*)handle;
			handler.onDismissed = nil;
		@}
	}
}
