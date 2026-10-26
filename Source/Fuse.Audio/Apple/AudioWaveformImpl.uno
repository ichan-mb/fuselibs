using Uno;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Audio
{
	[Require("source.include", "Apple/AudioWaveform.h")]
	[Set("fileExtension", "mm")]
	internal extern(iOS) static class AudioWaveformImpl
	{
		/** Decodes the file at `path` and fills `output` with normalized peak values */
		public static bool ExtractFromPath(string path, float[] output)
		{
			return ExtractFromPathImpl(path, output);
		}

		[Foreign(Language.ObjC)]
		static bool ExtractFromPathImpl(string path, float[] output)
		@{
			@try {
				NSURL* url = [path hasPrefix:@"file://"]
					? [NSURL URLWithString:path]
					: [NSURL fileURLWithPath:path];

				return UnoAudioWaveformExtract(url, output.unoArray);
			}
			@catch (NSException* exception) {
				return false;
			}
		@}

		/** Decodes a bundled file, or one backed by memory, into `output` */
		public static bool ExtractFromFile(FileSource file, float[] output)
		{
			var bundleFile = file as BundleFileSource;
			if (bundleFile != null)
				return ExtractFromBundle("data/" + bundleFile.BundleFile.BundlePath, output);

			return ExtractFromBytes(file.ReadAllBytes(), ExtensionOf(file.Name), output);
		}

		[Foreign(Language.ObjC)]
		static bool ExtractFromBundle(string path, float[] output)
		@{
			@try {
				NSString* fullPath = [[NSBundle bundleForClass:[StrongUnoObject class]] pathForResource:path ofType:nil];
				if (fullPath == nil)
					return false;

				return UnoAudioWaveformExtract([NSURL fileURLWithPath:fullPath], output.unoArray);
			}
			@catch (NSException* exception) {
				return false;
			}
		@}

		[Foreign(Language.ObjC)]
		static bool ExtractFromBytes(byte[] data, string extension, float[] output)
		@{
			@try {
				NSData* bytes = [NSData dataWithBytes:data.unoArray->Ptr() length:data.unoArray->Length()];

				NSString* name = [[NSUUID UUID] UUIDString];
				NSString* fileName = (extension != nil && [extension length] > 0)
					? [name stringByAppendingString:extension]
					: name;
				NSString* tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];

				if (![bytes writeToFile:tempPath atomically:YES])
					return false;

				@try {
					return UnoAudioWaveformExtract([NSURL fileURLWithPath:tempPath], output.unoArray);
				}
				@finally {
					[[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];
				}
			}
			@catch (NSException* exception) {
				return false;
			}
		@}

		/** Returns the extension of a file name, including the dot, or an empty string */
		static string ExtensionOf(string name)
		{
			if (string.IsNullOrEmpty(name))
				return "";

			var dot = -1;
			for (int i = name.Length - 1; i >= 0; i--)
			{
				var c = name[i];
				if (c == '.')
				{
					dot = i;
					break;
				}

				if (c == '/' || c == '\\')
					break;
			}

			if (dot < 0 || dot == name.Length - 1)
				return "";

			return name.Substring(dot);
		}
	}
}
