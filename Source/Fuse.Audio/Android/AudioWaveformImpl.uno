using Uno;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;
using Fuse.Android.Bindings;

namespace Fuse.Audio
{
	[ForeignInclude(Language.Java,
		"android.media.MediaExtractor",
		"android.media.MediaCodec",
		"android.media.MediaFormat",
		"android.content.res.AssetFileDescriptor",
		"android.content.Context",
		"java.io.File",
		"java.io.FileOutputStream",
		"java.nio.ByteBuffer",
		"java.nio.ByteOrder")]
	internal extern(Android) static class AudioWaveformImpl
	{
		/** Decodes the file at `path` and fills `output` with normalized peak values */
		public static bool ExtractFromPath(string path, float[] output)
		{
			return ExtractFromPathImpl(NormalizePath(path), output.Length, output);
		}

		/** Decodes a bundled file, or one backed by a stream, into `output` */
		public static bool ExtractFromFile(FileSource file, float[] output)
		{
			var bundleFile = file as BundleFileSource;
			if (bundleFile != null)
				return ExtractFromBundle(AndroidDeviceInterop.OpenAssetFileDescriptor(bundleFile), output.Length, output);

			return ExtractFromBytes(file.ReadAllBytes(), output.Length, output);
		}

		static string NormalizePath(string path)
		{
			// MediaExtractor takes a filesystem path, not a file URL
			if (path != null && path.StartsWith("file://"))
				return path.Substring(7);

			return path;
		}

		[Foreign(Language.Java)]
		static bool ExtractFromPathImpl(string path, int bars, float[] output)
		@{
			MediaExtractor extractor = new MediaExtractor();
			try {
				extractor.setDataSource(path);
				return Decode(extractor, bars, output);
			} catch (Exception e) {
				return false;
			} finally {
				try { extractor.release(); } catch (Exception e) { }
			}
		@}

		[Foreign(Language.Java)]
		static bool ExtractFromBundle(Java.Object afdHandle, int bars, float[] output)
		@{
			AssetFileDescriptor afd = (AssetFileDescriptor)afdHandle;
			MediaExtractor extractor = new MediaExtractor();
			try {
				extractor.setDataSource(afd.getFileDescriptor(), afd.getStartOffset(), afd.getLength());
				afd.close();
				return Decode(extractor, bars, output);
			} catch (Exception e) {
				return false;
			} finally {
				try { extractor.release(); } catch (Exception e) { }
			}
		@}

		[Foreign(Language.Java)]
		static bool ExtractFromBytes(byte[] data, int bars, float[] output)
		@{
			java.io.File tempFile = null;
			try {
				tempFile = java.io.File.createTempFile("waveform", ".tmp",
					com.fuse.Activity.getRootActivity().getCacheDir());

				java.io.FileOutputStream fos = new java.io.FileOutputStream(tempFile);
				fos.write(data.copyArray());
				fos.close();

				MediaExtractor extractor = new MediaExtractor();
				try {
					extractor.setDataSource(tempFile.getAbsolutePath());
					return Decode(extractor, bars, output);
				} finally {
					try { extractor.release(); } catch (Exception e) { }
				}
			} catch (Exception e) {
				return false;
			} finally {
				if (tempFile != null)
					tempFile.delete();
			}
		@}

		/**
			Decodes the selected audio track and keeps the peak amplitude per bar.

			The bucket for each decoded buffer comes from its presentation time, so the
			result does not depend on how the decoder chunks the output.
		*/
		[Foreign(Language.Java)]
		static bool Decode(Java.Object extractorHandle, int bars, float[] output)
		@{
			MediaExtractor extractor = (MediaExtractor)extractorHandle;

			int trackIndex = -1;
			MediaFormat format = null;
			for (int i = 0; i < extractor.getTrackCount(); i++) {
				MediaFormat candidate = extractor.getTrackFormat(i);
				String mime = candidate.getString(MediaFormat.KEY_MIME);
				if (mime != null && mime.startsWith("audio/")) {
					trackIndex = i;
					format = candidate;
					break;
				}
			}

			if (trackIndex < 0 || format == null)
				return false;

			if (!format.containsKey(MediaFormat.KEY_DURATION))
				return false;

			long durationUs = format.getLong(MediaFormat.KEY_DURATION);
			if (durationUs <= 0)
				return false;

			String mime = format.getString(MediaFormat.KEY_MIME);
			extractor.selectTrack(trackIndex);

			MediaCodec codec = null;
			try {
				codec = MediaCodec.createDecoderByType(mime);
				codec.configure(format, null, null, 0);
				codec.start();

				int channels = format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)
					? format.getInteger(MediaFormat.KEY_CHANNEL_COUNT) : 1;
				boolean floatPcm = false;

				MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
				boolean inputDone = false;
				boolean outputDone = false;
				int guard = 0;

				while (!outputDone && guard++ < 200000) {
					if (!inputDone) {
						int inIndex = codec.dequeueInputBuffer(10000);
						if (inIndex >= 0) {
							ByteBuffer inBuffer = codec.getInputBuffer(inIndex);
							int sampleSize = extractor.readSampleData(inBuffer, 0);
							if (sampleSize < 0) {
								codec.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM);
								inputDone = true;
							} else {
								long pts = extractor.getSampleTime();
								codec.queueInputBuffer(inIndex, 0, sampleSize, pts, 0);
								extractor.advance();
							}
						}
					}

					int outIndex = codec.dequeueOutputBuffer(info, 10000);
					if (outIndex >= 0) {
						if (info.size > 0) {
							ByteBuffer outBuffer = codec.getOutputBuffer(outIndex);
							outBuffer.order(ByteOrder.LITTLE_ENDIAN);
							outBuffer.position(info.offset);
							outBuffer.limit(info.offset + info.size);

							int bucket = (int)((info.presentationTimeUs * (long)bars) / durationUs);
							if (bucket < 0) bucket = 0;
							if (bucket >= bars) bucket = bars - 1;

							float peak = 0.0f;
							if (floatPcm) {
								int count = info.size / 4;
								int samples = count - (count % channels);
								for (int i = 0; i < samples; i++) {
									float value = Math.abs(outBuffer.getFloat());
									if (value > peak) peak = value;
								}
							} else {
								int count = info.size / 2;
								int samples = count - (count % channels);
								for (int i = 0; i < samples; i++) {
									float value = Math.abs(outBuffer.getShort()) / 32768.0f;
									if (value > peak) peak = value;
								}
							}

							if (peak > 1.0f) peak = 1.0f;
							if (peak > output.get(bucket))
								output.set(bucket, peak);
						}

						codec.releaseOutputBuffer(outIndex, false);
						if ((info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0)
							outputDone = true;
					} else if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
						MediaFormat outFormat = codec.getOutputFormat();
						if (outFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT))
							channels = outFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT);

						if (android.os.Build.VERSION.SDK_INT >= 24
							&& outFormat.containsKey(MediaFormat.KEY_PCM_ENCODING))
							floatPcm = outFormat.getInteger(MediaFormat.KEY_PCM_ENCODING)
								== android.media.AudioFormat.ENCODING_PCM_FLOAT;
					}
				}

				return true;
			} catch (Exception e) {
				return false;
			} finally {
				if (codec != null) {
					try { codec.stop(); } catch (Exception e) { }
					try { codec.release(); } catch (Exception e) { }
				}
			}
		@}
	}
}
