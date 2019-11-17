using Uno;
using Uno.UX;

using Fuse.Scripting;

namespace Fuse.Controls
{
	public partial class TextInput
	{
		static TextInput()
		{
			ScriptClass.Register(typeof(TextInput), new ScriptMethod<TextInput>("moveCaret", MoveCaret));
		}

		/**
			Move Caret position of TextInput. You can set negative value to move caret position to the end.

			@scriptmethod moveCaret(position)
		*/
		static void MoveCaret(TextInput s, object[] args)
		{
			if (args.Length == 0)
			{
				Fuse.Diagnostics.UserError("moveCaret requires 1 arguments", s);
				return;
			}
			var pos = Marshal.ToInt(args[0]);
			s.MoveCaretTo(pos);
		}

		void MoveCaretTo(int position)
		{
			Editor.MoveCaret(position);
		}
	}

	public partial class TextView
	{
		static TextView()
		{
			ScriptClass.Register(typeof(TextView), new ScriptMethod<TextView>("moveCaret", MoveCaret));
		}

		/**
			Move Caret position of TextView. You can set negative value to move caret position to the end.

			@scriptmethod moveCaret(position)
		*/
		static void MoveCaret(TextView s, object[] args)
		{
			if (args.Length == 0)
			{
				Fuse.Diagnostics.UserError("moveCaret requires 1 arguments", s);
				return;
			}
			var pos = Marshal.ToInt(args[0]);
			s.MoveCaretTo(pos);
		}

		void MoveCaretTo(int position)
		{
			Editor.MoveCaret(position);
		}
	}
}
