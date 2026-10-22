using Uno;
using Uno.Collections;

namespace Fuse.Scripting
{
	public delegate object NativeCallback(Context c, object[] args);

	public sealed class NativeFunction: NativeMember
	{
		NativeCallback _nativeCallback;

		protected override object CreateObject(Context context)
		{
			return (Callback)(new NativeFunctionClosure(_nativeCallback, context).Callback);
		}

		public NativeFunction(string name, NativeCallback callback): base(name)
		{
			_nativeCallback = callback;
		}

		class NativeFunctionClosure
		{
			NativeCallback _callback;
			Context _context;

			public NativeFunctionClosure(NativeCallback callback, Context context)
			{
				_context = context;
				_callback = callback;
			}

			public object Callback(Context context, object[] args)
			{
				try
				{
					return _callback(_context, args);
				}
				catch (Exception e)
				{
					// Only Scripting.Error is converted to a catchable JavaScript error by
					// the script backends. Wrap other native exceptions so user code can
					// catch them instead of them being reported as unhandled.
					if (e is Error)
						throw;

					throw new Error(e.Message, e);
				}
			}
		}
	}
}
