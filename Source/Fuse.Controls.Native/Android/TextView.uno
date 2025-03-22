
using Uno;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Controls.Native.Android
{
	extern(!Android) public class TextView { }
	extern(Android) public class TextView : LeafView, ITextView
	{
		public TextView(Java.Object handle) : base(handle) { }

		public TextView() : this(Create()) { }

		public string Value
		{
			set { SetText(Handle, value); }
		}

		public int MaxLength
		{
			set
			{
				// TODO: fix the value == 0 crap
				SetMaxLength(Handle, (value == 0) ? int.MaxValue : value);
			}
		}

		int ITextView.MaxLines
		{
			set
			{
				if (value > 0) SetMaxLines(Handle, value);
			}
		}

		public TextWrapping TextWrapping
		{
			set { SetTextWrapping(Handle, value == Fuse.Controls.TextWrapping.Wrap); }
		}

		public float LineSpacing
		{
			set { SetLineSpacing(Handle, value); }
		}

		public float FontSize
		{
			set { SetFontSize(Handle, value); }
		}

		public Font Font
		{
			set
			{
				var typeface = (value != Fuse.Font.PlatformDefault)
					? TypefaceCache.GetTypeface(value)
					: Typeface.Default;
				SetFont(Handle, typeface.Handle);
			}
		}

		public TextAlignment TextAlignment
		{
			set
			{
				switch (value)
				{
					case Fuse.Controls.TextAlignment.Left: SetTextAlignment(Handle, 0x00000003); break;
					case Fuse.Controls.TextAlignment.Center: SetTextAlignment(Handle, 0x00000001); break;
					case Fuse.Controls.TextAlignment.Right: SetTextAlignment(Handle, 0x00000005); break;
				}
			}
		}

		public float4 TextColor
		{
			set { SetTextColor(Handle, (int)Color.ToArgb(value)); }
		}

		public bool SizeToFit
		{
			set { SetSizeToFit(Handle, value); }
		}

		TextTruncation ITextView.TextTruncation
		{
			set
			{
				if (value == TextTruncation.Standard)
					SetTextTruncation(Handle);
			}
		}

		[Foreign(Language.Java)]
		static Java.Object Create()
		@{
			return new android.widget.TextView(com.fuse.Activity.getRootActivity());
		@}

		[Foreign(Language.Java)]
		static void SetText(Java.Object handle, string text)
		@{
			((android.widget.TextView)handle).setText(text);
			if (handle instanceof android.widget.EditText) {
				((android.widget.EditText)handle).setSelection(text.length());
			}
		@}

		[Foreign(Language.Java)]
		static void SetSizeToFit(Java.Object handle, bool value)
		@{
			android.widget.TextView tv = (android.widget.TextView)handle;
			if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O)
			{
				if (value) {
					tv.setAutoSizeTextTypeUniformWithConfiguration(5, 112, 2, android.util.TypedValue.COMPLEX_UNIT_SP);
				} else {
					tv.setAutoSizeTextTypeWithDefaults(android.widget.TextView.AUTO_SIZE_TEXT_TYPE_NONE);
				}
				tv.requestLayout();
			}
		@}

		[Foreign(Language.Java)]
		static void SetTextWrapping(Java.Object handle, bool wrap)
		@{
			android.widget.TextView tv = (android.widget.TextView)handle;
			tv.setHorizontallyScrolling( (wrap) ? false : true );
			tv.setSingleLine( (wrap) ? false : true );
			tv.requestLayout();
		@}

		[Foreign(Language.Java)]
		static void SetTextTruncation(Java.Object handle)
		@{
			android.widget.TextView tv = (android.widget.TextView)handle;
			tv.setEllipsize(android.text.TextUtils.TruncateAt.END);
			tv.setHorizontallyScrolling(false);
			tv.setSingleLine();
			tv.requestLayout();
		@}

		[Foreign(Language.Java)]
		static void SetLineSpacing(Java.Object handle, float spacing)
		@{
			android.widget.TextView tv = (android.widget.TextView)handle;
			tv.setLineSpacing(spacing, 1.0f);
			tv.requestLayout();
		@}

		[Foreign(Language.Java)]
		static void SetMaxLines(Java.Object handle, int line)
		@{
			android.widget.TextView tv = (android.widget.TextView)handle;
			tv.setEllipsize(android.text.TextUtils.TruncateAt.END);
			tv.setHorizontallyScrolling(false);
			tv.setMaxLines(line);
			tv.requestLayout();
		@}

		[Foreign(Language.Java)]
		static void SetFontSize(Java.Object handle, float size)
		@{
			android.widget.TextView tv = ((android.widget.TextView)handle);
			tv.setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, size);
			tv.requestLayout();
		@}

		[Foreign(Language.Java)]
		static void SetFont(Java.Object handle, Java.Object fontHandle)
		@{
			((android.widget.TextView)handle).setTypeface(((android.graphics.Typeface)fontHandle));
		@}

		[Foreign(Language.Java)]
		static void SetTextAlignment(Java.Object handle, int alignment)
		@{
			((android.widget.TextView)handle).setTextAlignment(android.view.View.TEXT_ALIGNMENT_GRAVITY);
			((android.widget.TextView)handle).setGravity(alignment);
		@}

		[Foreign(Language.Java)]
		static void SetTextColor(Java.Object handle, int color)
		@{
			((android.widget.TextView)handle).setTextColor(color);
		@}

		[Foreign(Language.Java)]
		static void SetMaxLength(Java.Object handle, int maxLength)
		@{
			android.widget.TextView t = (android.widget.TextView)handle;
			android.text.InputFilter[] filters = new android.text.InputFilter[1];
			filters[0] = new android.text.InputFilter.LengthFilter(maxLength);
			t.setFilters(filters);
		@}

	}
}
