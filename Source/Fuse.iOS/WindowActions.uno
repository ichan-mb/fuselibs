using Uno;
using Fuse;
using Fuse.Platform;

namespace Fuse.Triggers.Actions
{
	/** Opens (or brings to front) a declared @Window.

		## Example
		```xml
			<Button Text="Open">
				<Clicked>
					<WindowOpen Target="secondWindow" />
				</Clicked>
			</Button>
		```
	*/
	extern(iOS && !LIBRARY) public class WindowOpen : TriggerAction
	{
		/** The window to open. */
		public Window Target { get; set; }

		protected override void Perform(Node target)
		{
			Fuse.Platform.Windows.OpenWindow(Target);
		}
	}

	/** Closes a declared @Window.

		## Example
		```xml
			<Button Text="Close">
				<Clicked>
					<WindowClose Target="secondWindow" />
				</Clicked>
			</Button>
		```
	*/
	extern(iOS && !LIBRARY) public class WindowClose : TriggerAction
	{
		/** The window to close. */
		public Window Target { get; set; }

		protected override void Perform(Node target)
		{
			Fuse.Platform.Windows.CloseWindow(Target);
		}
	}

	/** Library (preview/editor) builds on iOS: windows are not separate; the
		actions do nothing. */
	extern(iOS && LIBRARY) public class WindowOpen : TriggerAction
	{
		public Window Target { get; set; }
		protected override void Perform(Node target) { }
	}

	extern(iOS && LIBRARY) public class WindowClose : TriggerAction
	{
		public Window Target { get; set; }
		protected override void Perform(Node target) { }
	}
}