using Uno;
using Uno.IO;
using Uno.Testing;
using Uno.Collections;

using Fuse.Reactive;
using Fuse.Scripting;
using Fuse.Scripting.JavaScript.Test;
using FuseTest;

namespace Fuse.Scripting.Test
{
	public class NativeFunctionExceptionTestModule : NativeModule
	{
		public NativeFunctionExceptionTestModule()
		{
			Uno.UX.Resource.SetGlobalKey(this, "NativeFunctionExceptionTest");
			AddMember(new NativeFunction("throwIo", ThrowIo));
		}

		static object ThrowIo(Context c, object[] args)
		{
			throw new IOException("boom");
		}
	}

	public class ScriptingTest : TestBase
	{
		static int AsInt(object o)
		{
			return o is int ? (int)o : (int)(double)o;
		}

		static bool IsNumber(object o)
		{
			return o is int || o is double;
		}

		[Test]
		public void Primitives()
		{
			JSTest.RunTest(PrimitivesInner);
		}

		[Test]
		public void NativeFunctionExceptionsAreCatchable()
		{
			JSTest.RunTest(NativeFunctionExceptionsAreCatchableInner);
		}

		void NativeFunctionExceptionsAreCatchableInner(Fuse.Scripting.Context context)
		{
			new NativeFunctionExceptionTestModule();

			var result = context.Evaluate("NativeFunctionExceptions",
				"var caught = false;" +
				"try { NativeFunctionExceptionTest.throwIo(); }" +
				"catch (e) { caught = String(e).indexOf('boom') >= 0; }" +
				"caught");

			Assert.AreEqual(true, (bool)result);
		}

		void PrimitivesInner(Fuse.Scripting.Context context)
		{
			{
				var result = context.Evaluate("Primitive number", "12 + 13");
				Assert.IsTrue(result is int || result is double);
				Assert.AreEqual(25, AsInt(result));
			}
			{
				var result = context.Evaluate("Primitive double", "1.2 + 1.3");
				Assert.IsTrue(result is double);
				Assert.AreEqual(2.5, (double)result);
			}
			{
				var result = context.Evaluate("Primitive string", "\"abc 123\"");
				Assert.IsTrue(result is string);
				Assert.AreEqual("abc 123", (string)result);
			}
			{
				var result = context.Evaluate("Primitive bools", "true || false");
				Assert.IsTrue(result is bool);
				Assert.AreEqual(true, (bool)result);
			}
		}

		[Test]
		public void Objects()
		{
			JSTest.RunTest(ObjectsInner);
		}

		void ObjectsInner(Fuse.Scripting.Context context)
		{
			var obj = context.Evaluate("Objects", "({ a: \"abc åæø\", b: 123 })") as Scripting.Object;
			Assert.IsFalse(obj == null);
			Assert.IsTrue(obj["a"] is string);
			Assert.AreEqual("abc åæø", (string)obj["a"]);
			Assert.IsTrue(IsNumber(obj["b"]));
			{
				Assert.AreEqual(123, AsInt(obj["b"]));
			}
			obj["a"] = "xyz á, é, í, ó, ú, ü, ñ, ¿, ¡";
			Assert.AreEqual("xyz á, é, í, ó, ú, ü, ñ, ¿, ¡", (string)obj["a"]);
			obj["c"] = 123.4;
			Assert.AreEqual(123.4, (double)obj["c"]);
			var keys = obj.Keys;
			Assert.AreEqual(3, keys.Length);
			Assert.IsTrue(obj.ContainsKey("a"));
			Assert.IsTrue(obj.ContainsKey("b"));
			Assert.IsTrue(obj.ContainsKey("c"));
			Assert.IsFalse(obj.ContainsKey("d"));
			Assert.IsTrue(obj.Equals(obj));
			Assert.IsFalse(obj.Equals(context.Evaluate("Objects 2", "({ abc: \"abc\" })")));
			obj["f"] = context.Evaluate("Objects 3", "(function(x, y) { return x + y; })");
			var callResult = obj.CallMethod(context, "f", new object[] { 12, 13 });
			Assert.IsFalse(callResult == null);
			Assert.IsTrue(IsNumber(callResult));
			Assert.AreEqual(25, AsInt(callResult));
			Assert.IsTrue(
				(((Scripting.Object)context.Evaluate("Objects instanceof", "new Date()")))
				.InstanceOf(context, (Scripting.Function)context.Evaluate("Objects instanceof 2", "Date")));
			Assert.IsFalse(
				obj
				.InstanceOf(context,(Scripting.Function)context.Evaluate("Objects instanceof 3", "Date")));
		}

		[Test]
		public void NonStringKeys()
		{
			JSTest.RunTest(NonStringKeysInner);
		}

		void NonStringKeysInner(Fuse.Scripting.Context context)
		{
			var obj = context.Evaluate("NonStringKeys", "(function() { var o = {}; o[1] = 'a'; o[2] = 'b'; o[3] = 'c'; return o;})()") as Scripting.Object;
			var keys = obj.Keys;
			Assert.AreEqual(3, keys.Length);
			Assert.IsTrue(obj.ContainsKey("1"));
			Assert.IsTrue(obj.ContainsKey("2"));
			Assert.IsTrue(obj.ContainsKey("3"));
			Assert.AreEqual("a", obj["1"]);
			Assert.AreEqual("b", obj["2"]);
			Assert.AreEqual("c", obj["3"]);
		}

		[Test]
		public void Arrays()
		{
			JSTest.RunTest(ArraysInner);
		}

		void ArraysInner(Fuse.Scripting.Context context)
		{
			var arr = context.Evaluate("Arrays", "[\"abc\", 123]") as Scripting.Array;
			Assert.IsFalse(arr == null);
			Assert.AreEqual(2, arr.Length);
			Assert.IsTrue(arr.Equals(arr));
			Assert.IsFalse(arr.Equals((Scripting.Array)context.Evaluate("ArrayTests", "[1, 2, 3]")));
			Assert.AreEqual((string)arr[0], "abc");
			Assert.AreEqual(123, AsInt(arr[1]));
			arr[1] = "123";
			Assert.AreEqual((string)arr[1], "123");
		}

		[Test]
		public void Functions()
		{
			JSTest.RunTest(FunctionsInner);
		}

		void FunctionsInner(Fuse.Scripting.Context context)
		{
			var fun = context.Evaluate("FunctionTests", "(function(x, y) { return x * y; })") as Scripting.Function;
			Assert.IsFalse(fun == null);
			var callResult = fun.Call(context, new object[] { 11, 12 });
			Assert.IsFalse(callResult == null);
			Assert.AreEqual(132, AsInt(callResult));
			Assert.IsTrue(fun.Equals(fun));
			var str = context.Evaluate("Functions construct", "String") as Scripting.Function;
			Assert.IsFalse(str == null);
			Assert.IsFalse(fun.Equals(str));
			var obj = str.Construct(context, new object[] { "abc 123" });
			Assert.IsFalse(obj == null);
			var i = obj.CallMethod(context, "indexOf", new object[] { "1" });
			Assert.AreEqual(4, AsInt(i));
		}

		public object MyCallback(Scripting.Context context, object[] args)
		{
			if (args.Length == 2)
			{
				var x = AsInt(args[0]);
				var y = AsInt(args[1]);
				return x + y + 1000;
			}
			return null;
		}

		[Test]
		public void Callbacks()
		{
			JSTest.RunTest(CallbacksInner);
		}

		void CallbacksInner(Fuse.Scripting.Context context)
		{
			var f = context.Evaluate(
									 "Callbacks",
									 "(function(f) { return f(12, 13) + f(10, 20); })") as Scripting.Function;
			Assert.AreEqual(
							AsInt(f.Call(context, new object[] { new Scripting.Callback(MyCallback) })),
							12 + 13 + 1000 + 10 + 20 + 1000);
		}

		class ContextObjectFactory
		{
			public ContextObjectFactory() {}

			public object Callback(Scripting.Context context, object[] args)
			{
				if (args.Length == 2)
				{
					var x = AsInt(args[0]);
					var y = AsInt(args[1]);
					var result = context.NewObject();
					result["x"] = x;
					result["y"] = y;
					return result;
				}
				return null;
			}
		}

		internal class ContextClosure<T1, TRes>
		{
			Scripting.Context _context;
			Func<Scripting.Context, T1, TRes> _f;
			T1 _arg;
			public ContextClosure(Scripting.Context context, Func<Scripting.Context, T1, TRes> f, T1 arg)
			{
				_context = context;
				_f = f;
				_arg = arg;
			}
			public void Run()
			{
				_f(_context, _arg);
			}
		}

		internal class ContextClosure2<T1, T2, TRes>
		{
			Func<Scripting.Context, T1, T2, TRes> _f;
			Scripting.Context _context;
			T1 _arg1;
			T2 _arg2;
			public ContextClosure2(Scripting.Context context, Func<Scripting.Context, T1, T2, TRes> f, T1 arg1, T2 arg2)
			{
				_context = context;
				_f = f;
				_arg1 = arg1;
				_arg2 = arg2;
			}
			public void Run()
			{
				_f(_context, _arg1, _arg2);
			}
		}

		[Test]
		public void CallbackAsConstructor()
		{
			JSTest.RunTest(CallbackAsConstructorInner);
		}

		void CallbackAsConstructorInner(Fuse.Scripting.Context context)
		{
			var f = context.Evaluate(
									 "CallbackAsConstructor",
									 "(function(f) { return new f(12, 13); })") as Scripting.Function;
			var res = f.Construct(context, new object[] { new Scripting.Callback(new ContextObjectFactory().Callback) });
			Assert.IsTrue(res is Scripting.Object);
			Assert.IsTrue(res.ContainsKey("x"));
			Assert.IsTrue(res.ContainsKey("y"));
			Assert.AreEqual(12, AsInt(res["x"]));
			Assert.AreEqual(13, AsInt(res["y"]));
		}

		internal class Closure<T1, TRes>
		{
			Func<T1, TRes> _f;
			T1 _arg;
			public Closure(Func<T1, TRes> f, T1 arg)
			{
				_f = f;
				_arg = arg;
			}
			public void Run()
			{
				_f(_arg);
			}
		}

		internal class Closure2<T1, T2, TRes>
		{
			Func<T1, T2, TRes> _f;
			T1 _arg1;
			T2 _arg2;
			public Closure2(Func<T1, T2, TRes> f, T1 arg1, T2 arg2)
			{
				_f = f;
				_arg1 = arg1;
				_arg2 = arg2;
			}
			public void Run()
			{
				_f(_arg1, _arg2);
			}
		}

		internal class Setter
		{
			Scripting.Object _obj;
			string _str;
			object _arg;
			public Setter(Scripting.Object obj, string str, object arg)
			{
				_obj = obj;
				_str = str;
				_arg = arg;
			}
			public void Run()
			{
				_obj[_str] = _arg;
			}
		}

		internal class Getter
		{
			Scripting.Object _obj;
			string _str;
			public Getter(Scripting.Object obj, string str)
			{
				_obj = obj;
				_str = str;
			}
			void Test(object o)
			{

			}
			public void Run()
			{
				Test(_obj[_str]);
			}
		}

		[Test]
		public void Errors()
		{
			JSTest.RunTest(ErrorsInner);
		}

		void ErrorsInner(Fuse.Scripting.Context context)
		{
			Assert.Throws<ScriptException>(new Closure2<string, string, object>(context.Evaluate, "Errors", "new ...").Run);
			Assert.Throws<ScriptException>(new Closure2<string, string, object>(context.Evaluate, "Errors", "obj.someMethod()").Run);
			Assert.Throws<ScriptException>(new Closure2<string, string, object>(context.Evaluate, "Errors", "throw \"Hello\";").Run);

			var obj = context.Evaluate("Errors", "({})") as Scripting.Object;

			Assert.Throws(new Closure<string, bool>(obj.ContainsKey, null).Run);
			Assert.Throws(new Getter(obj, null).Run);
			Assert.Throws(new Setter(obj, null, "a").Run);
			Assert.DoesNotThrowAny(new Setter(obj, "a", null).Run);
			Assert.Throws(new ContextClosure2<string, object[], object>(context, obj.CallMethod, null, new object[] { }).Run);
			Assert.Throws(new Closure2<string, string, object>(context.Evaluate, "Errors", null).Run);

			var throwingFun = (Scripting.Function)context.Evaluate("Errors", "(function() { throw \"Error\"; })");
			Assert.Throws<ScriptException>(new ContextClosure<object[], object>(context, throwingFun.Call, new object[0]).Run);
		}

		[Test]
		[Ignore("https://github.com/fuse-open/fuselibs/issues/679", "Android && USE_V8")]
		public void ExceptionMessageIsMarshalledToJavaScript()
		{
			JSTest.RunTest(ExceptionMessageIsMarshalledToJavaScriptInner);
		}

		void ExceptionMessageIsMarshalledToJavaScriptInner(Fuse.Scripting.Context context)
		{
			var f = context.Evaluate("ExceptionObjectLooksGoodWhenCatchedInJavaScript", "(function(f) { try { f(); } catch(ex) { return ex.toString(); } })") as Scripting.Function;
			var message = (string)f.Call(context, new object[] { new Scripting.Callback(ScriptingErrorThrowingCallback) });
			Assert.IsTrue(message.Contains("baaaaaaaah"));
		}

		readonly string[] _unicodeStrings = new string[]
		{
			"",
			"abc",
			"The quick brown fox jumps over the lazy dog",
			"ç, é, õ",
			"åååååååååååååææææææææøøøøøøøøøøøøø ç, é, õ aaaaaaaaaaaabbbbbbbbbbc ccccccc",
			"eeeeææææææææææaaaaaaaaa",
			"صِفْ Amiri3 صِفْ خَلْقَ Amiri2 صِفْ خَلْقَ خَوْدٍ Amiri1 صِفْ خَلْقَ خَوْدٍ صِفْ",
			"𐐷𐐷𐐷𐐷",
			"𐐷𐐷𐐷𐐷abc𤭢𤭢𤭢𤭢a𐐷𐐷𐐷𐐷abc𤭢𤭢𤭢𤭢a𐐷𐐷𐐷𐐷abc𤭢𤭢𤭢𤭢a𐐷𐐷𐐷𐐷abc𤭢𤭢𤭢𤭢a",
			"Emoji 😃  are such fun!",
			"देवनागरीदेवनागरीदेवनागरीदेवनागरीदेवनागरीदेवनागरीदेवनागरीदेवनागरीदेवनागरी",
			" א ב ג ד ה ו ז ח ט י\n כ ך ל מ ם נ ן ס ע פ\n ף צ ץ ק ר ש ת  •  ﭏ",
			"Testing «ταБЬℓσ»: 1<2 & 4+1>3, now 20% off!",
			"٩(-̮̮̃-̃)۶ ٩(●̮̮̃•̃)۶ ٩(͡๏̯͡๏)۶ ٩(-̮̮̃•̃).",
			"Quizdeltagerne spiste jordbær med fløde, mens cirkusklovnen Wolther spillede på xylofon.",
			"Falsches Üben von Xylophonmusik quält jeden größeren Zwerg",
			"Γαζέες καὶ μυρτιὲς δὲν θὰ βρῶ πιὰ στὸ χρυσαφὶ ξέφωτο",
			"Ξεσκεπάζω τὴν ψυχοφθόρα βδελυγμία",
			"El pingüino Wenceslao hizo kilómetros bajo exhaustiva lluvia y frío, añoraba a su querido cachorro.",
			"Le cœur déçu mais l'âme plutôt naïve, Louÿs rêva de crapaüter en canoë au delà des îles, près du mälström où brûlent les novæ.",
			"D'fhuascail Íosa, Úrmhac na hÓighe Beannaithe, pór Éava agus Ádhaimh",
			"Árvíztűrő tükörfúrógép",
			"Kæmi ný öxi hér ykist þjófum nú bæði víl og ádrepa",
			"Sævör grét áðan því úlpan var ónýt",
			"いろはにほへとちりぬるを\n わかよたれそつねならむ\n うゐのおくやまけふこえて\n あさきゆめみしゑひもせす\n",
			"イロハニホヘト チリヌルヲ ワカヨタレソ ツネナラム\n ウヰノオクヤマ ケフコエテ アサキユメミシ ヱヒモセスン",
			"? דג סקרן שט בים מאוכזב ולפתע מצא לו חברה איך הקליטה",
			"Pchnąć w tę łódź jeża lub ośm skrzyń fig",
			"В чащах юга жил бы цитрус? Да, но фальшивый экземпляр!",
			"Съешь же ещё этих мягких французских булок да выпей чаю",
			"๏ เป็นมนุษย์สุดประเสริฐเลิศคุณค่า  กว่าบรรดาฝูงสัตว์เดรัจฉาน",
			"Pijamalı hasta, yağız şoföre çabucak güvendi.",
		};

		[Test]
		public void Unicode1()
		{
			JSTest.RunTest(Unicode1Inner);
		}

		void Unicode1Inner(Fuse.Scripting.Context context)
		{
			foreach (var str in _unicodeStrings)
			{
				var res = context.Evaluate("Unicode", "\"" + str.Replace("\n", "\\n") + "\"") as string;
				Assert.AreEqual(str, res);
			}
		}

		[Test]
		public void Unicode2()
		{
			JSTest.RunTest(Unicode2Inner);
		}

		void Unicode2Inner(Fuse.Scripting.Context context)
		{
			var id = context.Evaluate("Unicode2", "(function(x) { return x; })") as Scripting.Function;
			foreach (var str in _unicodeStrings)
			{
				var res = id.Call(context, str) as string;
				Assert.AreEqual(str, res);
			}
		}

		[Test]
		public void StringHomomorphism()
		{
			JSTest.RunTest(StringHomomorphismInner);
		}

		void StringHomomorphismInner(Fuse.Scripting.Context context)
		{
			var f = context.Evaluate("StringHomomorphism", "(function(x, y) { return x + y; })") as Scripting.Function;
			foreach (var x in _unicodeStrings)
				foreach (var y in _unicodeStrings)
				{
					var res = f.Call(context, x, y) as string;
					Assert.AreEqual(x + y, res);
				}
		}

		object ScriptingErrorThrowingCallback(Scripting.Context context, object[] xs)
		{
			throw new Scripting.Error("baaaaaaaah");
		}

		[Test]
		[Ignore("https://github.com/fuse-open/fuselibs/issues/679", "Android && USE_V8")]
		public void CallbackExceptions()
		{
			JSTest.RunTest(CallbackExceptionsInner);
		}

		void CallbackExceptionsInner(Fuse.Scripting.Context context)
		{
			var f = context.Evaluate("CallbackException", "(function(f) { f(); })") as Scripting.Function;
			Assert.Throws(new ContextClosure<object[], object>(context, f.Call, new object[] { new Scripting.Callback(ScriptingErrorThrowingCallback) }).Run);
		}

		[Test]
		[Ignore("https://github.com/fuse-open/fuselibs/issues/679", "Android && USE_V8")]
		public void CatchingCallbackExceptions()
		{
			JSTest.RunTest(CatchingCallbackExceptionsInner);
		}

		void CatchingCallbackExceptionsInner(Fuse.Scripting.Context context)
		{
			var f = context.Evaluate("CatchingCallbackExceptions", "(function(f) { try { f(); } catch (e) { } })") as Scripting.Function;
			Assert.DoesNotThrowAny(new ContextClosure<object[], object>(context, f.Call, new object[] { new Scripting.Callback(ScriptingErrorThrowingCallback) }).Run);
		}

		object ExceptionThrowingCallback(Scripting.Context context, object[] xs)
		{
			throw new Exception("baaaaaaaaaaaaaaaah");
		}

		[Test]
		[Ignore("https://github.com/fuse-open/fuselibs/issues/679", "Android && USE_V8")]
		public void CatchingUnoExceptions()
		{
			JSTest.RunTest(CatchingUnoExceptionsInner);
		}

		void CatchingUnoExceptionsInner(Fuse.Scripting.Context context)
		{
			var f = context.Evaluate("CatchingUnoExceptions", "(function(f) { try { f(); } catch (e) { } })") as Scripting.Function;
			Assert.Throws(new ContextClosure<object[], object>(context, f.Call, new object[] { new Scripting.Callback(ExceptionThrowingCallback) }).Run);
		}

		class SomeObject
		{
			public string SomeField;
			public SomeObject(string someField)
			{
				SomeField = someField;
			}
		}

		[Test]
		public void External()
		{
			JSTest.RunTest(ExternalInner);
		}

		void ExternalInner(Fuse.Scripting.Context context)
		{
			var someObject = new SomeObject("theField");
			{
				var f = context.Evaluate("External", "(function(x) { return x; })") as Scripting.Function;
				var res = f.Call(context, new object[] { new External(someObject) });
				Assert.IsTrue(res is Scripting.External);
				var ext = res as Scripting.External;
				var o = ext.Object;
				Assert.IsTrue(o is SomeObject);
				var so = o as SomeObject;
				Assert.AreEqual(so, someObject);
				Assert.AreEqual(so.SomeField, "theField");
			}
			{
				var o = context.Evaluate("External 2", "new Object()") as Scripting.Object;
				Assert.IsTrue(o != null);
				o["test"] = new External(someObject);
				Assert.IsTrue(o["test"] is Scripting.External);
				Assert.AreEqual(someObject, (o["test"] as Scripting.External).Object);
			}
		}

		[Test]
		public void ExternalSameObject()
		{
			JSTest.RunTest(ExternalSameObjectInner);
		}

		void ExternalSameObjectInner(Fuse.Scripting.Context context)
		{
			var someObject = new SomeObject("theField");
			{
				var o = context.Evaluate("ExternalSomeObject", "new Object()") as Scripting.Object;
				Assert.IsTrue(o != null);
				var ext = new External(someObject);
				for (int i = 0; i < 100; ++i)
				{
					if defined(CPlusPlus) extern "uAutoReleasePool autoReleasePool";
					var index = "test" + i;
					o[index] = ext;
					Assert.IsTrue(o[index] is Scripting.External);
					Assert.AreEqual(someObject, (o[index] as Scripting.External).Object);
					Memory1(context);
				}
			}
		}

		void Memory1(Context context)
		{
			for (int i = 0; i < 100; ++i)
			{
				var fun = context.Evaluate("Memory", "(function(x, y) { return x * y; })") as Scripting.Function;
				Assert.IsFalse(fun == null);
			}
		}

		[Test]
		public void Memory()
		{
			JSTest.RunTest(MemoryInner);
		}

		void MemoryInner(Fuse.Scripting.Context context)
		{
			for (int i = 0; i < 100; ++i)
			{
				if defined(CPlusPlus) extern "uAutoReleasePool autoReleasePool";
				Memory1(context);
			}
		}

		[Test]
		public void Memory2()
		{
			JSTest.RunTest(Memory2Inner);
		}

		void Memory2Inner(Fuse.Scripting.Context context)
		{
			var fun = context.Evaluate("Memory2", "(function(x, y) { var arr = new Array(1000); arr[100] = x; arr[200] = y; return arr[0]; })") as Scripting.Function;
			Assert.IsFalse(fun == null);
			// This should trigger GC after a while, and tests that the finalizers don't crash.
			for (int i = 0; i < 10000; ++i)
			{
				fun.Call(context, new Scripting.Callback(MyCallback), new Scripting.External(new Uno.Object()));
			}
		}

		[Test]
		public void ArrayBufferSupport()
		{
			JSTest.RunTest(ArrayBufferSupportInner);

		}

		void ArrayBufferSupportInner(Fuse.Scripting.Context context)
		{
			Assert.IsTrue((bool)context.Evaluate("ArrayBufferSupport", "typeof(ArrayBuffer) !== 'undefined'"));
			Assert.IsTrue((bool)context.Evaluate("ArrayBufferSupport", "typeof(Int8Array) !== 'undefined'"));
			Assert.IsTrue((bool)context.Evaluate("ArrayBufferSupport", "typeof(Int16Array) !== 'undefined'"));
			Assert.IsTrue((bool)context.Evaluate("ArrayBufferSupport", "typeof(Int32Array) !== 'undefined'"));
			Assert.IsTrue((bool)context.Evaluate("ArrayBufferSupport", "typeof(Uint8Array) !== 'undefined'"));
			Assert.IsTrue((bool)context.Evaluate("ArrayBufferSupport", "typeof(Uint16Array) !== 'undefined'"));
			Assert.IsTrue((bool)context.Evaluate("ArrayBufferSupport", "typeof(Uint32Array) !== 'undefined'"));
			Assert.IsTrue((bool)context.Evaluate("ArrayBufferSupport", "typeof(Uint8ClampedArray) !== 'undefined'"));
			Assert.IsTrue((bool)context.Evaluate("ArrayBufferSupport", "typeof(Float32Array) !== 'undefined'"));
			Assert.IsTrue((bool)context.Evaluate("ArrayBufferSupport", "typeof(Float64Array) !== 'undefined'"));
			Assert.IsTrue((bool)context.Evaluate("ArrayBufferSupport", "typeof(DataView) !== 'undefined'"));

			var int8 = context.Evaluate(
										"ArrayBufferSupport",
										"(function() { var int8 = new Int8Array(100); int8[99] = 42; return int8; })().buffer") as byte[];
			Assert.IsTrue(int8 is byte[]);

			var getLastItem = context.Evaluate(
											   "ArrayBufferSupport",
											   "(function(x) { var z = new Int8Array(x, 0, x.byteLength); return z[99]; })") as Scripting.Function;
			Assert.AreEqual(42, AsInt(getLastItem.Call(context, int8)));
		}

		[Test]
		public void Buffers()
		{
			JSTest.RunTest(BuffersInner);
		}

		void BuffersInner(Fuse.Scripting.Context context)
		{
				int len = 10;
				var buf = new byte[len];
				for (byte i = 0; i < len; ++i)
				{
					buf[i] = i;
				}

				{
					var instanceOfArrayBuffer = context.Evaluate(
						"Buffers",
						"(function(x) { return x instanceof ArrayBuffer; })") as Scripting.Function;
					Assert.IsTrue((bool)instanceOfArrayBuffer.Call(context, buf));
				}

				{
					var check1 = context.Evaluate(
						"Buffers 2",
						"(function(buf, len) { return buf.byteLength === len; })") as Scripting.Function;

					var check2 = context.Evaluate(
						"Buffers 2",
						"(function(buf, len) { var arr = new Uint8Array(buf); for (var i = 0; i < len; ++i) { if (arr[i] != i) return false; }; return true; })") as Scripting.Function;

					Assert.IsFalse(check1 == null);
					Assert.IsFalse(check2 == null);
					Assert.IsTrue((bool)check1.Call(context, buf, len));
					Assert.IsTrue((bool)check2.Call(context, buf, len));
				}

				{
					var createBuffer = context.Evaluate(
						"Buffers 3",
						"(function(len) { var res = new ArrayBuffer(len); var arr = new Uint8Array(res); for (var i = 0; i < len; ++i) arr[i] = i; return res; })") as Scripting.Function;
					var buf2 = createBuffer.Call(context, len);
					Assert.IsTrue(buf2 is byte[]);
					var buf3 = buf2 as byte[];
					Assert.AreEqual(len, buf3.Length);
					for (int i = 0; i < len; ++i)
					{
						Assert.AreEqual(buf[i], buf3[i]);
					}
				}

				{
					var identity = context.Evaluate(
						"Buffers 4",
						"(function(x) { return x; })") as Scripting.Function;
					var res = identity.Call(context, buf);
					Assert.IsTrue(res is byte[]);
					var buf2 = res as byte[];
					Assert.AreEqual(len, buf2.Length);
					for (int i = 0; i < len; ++i)
					{
						Assert.AreEqual(buf[i], buf2[i]);
					}
				}

				// We have to copy on iOS < 10
				if defined(!iOS && !(Android && USE_JAVASCRIPTCORE))
				{
					var identity = context.Evaluate(
						"Buffers 5",
						"(function(x) { return x; })") as Scripting.Function;
					Assert.AreEqual(identity.Call(context, buf), buf);
				}
			}

		[Test]
		public void StringObjects()
		{
			JSTest.RunTest(StringObjectsInner);
		}

		void StringObjectsInner(Fuse.Scripting.Context context)
		{
			var str1 = context.Evaluate("StringObjects", "\"abc 123\"") as string;
			var str2 = context.Evaluate("StringObjects", "new String(\"abc 123\")") as Scripting.Object;

			Assert.AreEqual(str1, "abc 123");
			Assert.IsTrue(str2 != null);
		}

		[Test]
		public void ArrayObjects()
		{
			JSTest.RunTest(ArrayObjectsInner);
		}

		void ArrayObjectsInner(Fuse.Scripting.Context context)
		{
			var arr1 = context.Evaluate("ArrayObjects", "['a', 'b', 'c', 1, 2, 3]") as Scripting.Array;
			var arr2 = context.Evaluate("ArrayObjects", "new Array('a', 'b', 'c', 1, 2, 3)") as Scripting.Array;

			Assert.AreEqual(arr1.Length, arr2.Length);
			for (int i = 0; i < arr1.Length; ++i)
			{
				Assert.AreEqual(arr1[i], arr2[i]);
			}
		}

		[Test]
		public void NumberObjects()
		{
			JSTest.RunTest(NumberObjectsInner);
		}

		void NumberObjectsInner(Fuse.Scripting.Context context)
		{
			var num1 = AsInt(context.Evaluate("NumberObjects", "123"));
			var num2 = context.Evaluate("NumberObjects", "new Number(123)") as Scripting.Object;

			Assert.AreEqual(123, num1);
			Assert.IsTrue(num2 != null);
		}

		[Test]
		public void BooleanObjects()
		{
			JSTest.RunTest(BooleanObjectsInner);
		}

		void BooleanObjectsInner(Fuse.Scripting.Context context)
		{
			var t1 = (bool)context.Evaluate("BooleanObjects", "true");
			var t2 = context.Evaluate("BooleanObjects", "new Boolean(true)") as Scripting.Object;
			Assert.AreEqual(true, t1);
			Assert.IsTrue(t2 != null);
		}
	}
}
