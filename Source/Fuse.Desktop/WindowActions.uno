using Uno;
using Fuse;

namespace Fuse.Triggers.Actions
{
	/** Opens (or brings to front) a declared @Window. The desktop preview renders
		all windows inline, so this does nothing. */
	extern(!MOBILE) public class WindowOpen : TriggerAction
	{
		/** The window to open. */
		public Window Target { get; set; }

		protected override void Perform(Node target) { }
	}

	/** Closes a declared @Window. The desktop preview renders all windows
		inline, so this does nothing. */
	extern(!MOBILE) public class WindowClose : TriggerAction
	{
		/** The window to close. */
		public Window Target { get; set; }

		protected override void Perform(Node target) { }
	}
}