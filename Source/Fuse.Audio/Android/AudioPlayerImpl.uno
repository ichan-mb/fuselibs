using Uno;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;
using Uno.Collections;

namespace Fuse.Audio
{
	[Require("gradle.dependency", "androidx.media:media:1.6.0")]
	[Require("source.include", "android/media/MediaPlayer.h")]
	[Require("source.include", "java/io/IOException.h")]
	[ForeignInclude(Language.Java,
		"android.media.MediaPlayer",
		"android.content.res.AssetFileDescriptor",
		"java.io.IOException",
		"android.os.Handler",
		"android.os.Looper",
		"com.uno.UnoBackedByteBuffer")]
	internal extern(Android) static class AudioPlayerImpl
	{
		static Java.Object _currentPlayer;
		static double _duration = 0.0;
		static bool _isPrepared = false;
		static FileSource _currentFile;

		public static bool LoadAudio(FileSource fileSource, out double duration)
		{
			duration = 0.0;

			try
			{
				ReleaseCurrentPlayer();
				_currentFile = fileSource;
				_isPrepared = false;

				var bundleFileSource = fileSource as BundleFileSource;
				if (bundleFileSource != null)
				{
					duration = LoadAudioFromBundle(AndroidDeviceInterop.OpenAssetFileDescriptor(bundleFileSource));
				}
				else
				{
					duration = LoadAudioFromByteArray(fileSource.ReadAllBytes());
				}

				_duration = duration;
				return duration > 0;
			}
			catch (Exception e)
			{
				Fuse.Diagnostics.UserError("Failed to load audio: " + e.Message, null);
				return false;
			}
		}

		[Foreign(Language.Java)]
		static double LoadAudioFromBundle(Java.Object fd)
		@{
			try {
				android.media.MediaPlayer player = new android.media.MediaPlayer();

				final AssetFileDescriptor afd = (AssetFileDescriptor)fd;
				player.setDataSource(afd.getFileDescriptor(), afd.getStartOffset(), afd.getLength());
				afd.close();

				player.prepareAsync();
				player.setOnPreparedListener(new android.media.MediaPlayer.OnPreparedListener() {
					public void onPrepared(android.media.MediaPlayer mp) {
						@{SetPrepared():call()};
					}
				});

				player.setOnCompletionListener(new android.media.MediaPlayer.OnCompletionListener() {
					public void onCompletion(android.media.MediaPlayer mp) {
						@{OnPlaybackCompleted():call()};
					}
				});

				player.setOnErrorListener(new android.media.MediaPlayer.OnErrorListener() {
					public boolean onError(android.media.MediaPlayer mp, int what, int extra) {
						@{OnPlaybackError(string):call("MediaPlayer error: " + what + ", " + extra)};
						return true;
					}
				});

				@{SetCurrentPlayer(Java.Object):call(player)};

				// Wait a bit for preparation (this is not ideal but necessary for synchronous API)
				Thread.sleep(100);

				if (player.getDuration() > 0) {
					return player.getDuration() / 1000.0;
				}
				return 0.0;
			} catch (Exception e) {
				return 0.0;
			}
		@}

		[Foreign(Language.Java)]
		static double LoadAudioFromByteArray(byte[] data)
		@{
			try {
				android.media.MediaPlayer player = new android.media.MediaPlayer();

				// Create temporary file for byte array data
				java.io.File tempFile = java.io.File.createTempFile("audio", ".tmp", @(Activity.Package).getActivity().getCacheDir());
				java.io.FileOutputStream fos = new java.io.FileOutputStream(tempFile);
				fos.write(data.copyArray());
				fos.close();

				player.setDataSource(tempFile.getAbsolutePath());
				player.prepareAsync();

				player.setOnPreparedListener(new android.media.MediaPlayer.OnPreparedListener() {
					public void onPrepared(android.media.MediaPlayer mp) {
						@{SetPrepared():call()};
					}
				});

				player.setOnCompletionListener(new android.media.MediaPlayer.OnCompletionListener() {
					public void onCompletion(android.media.MediaPlayer mp) {
						@{OnPlaybackCompleted():call()};
					}
				});

				player.setOnErrorListener(new android.media.MediaPlayer.OnErrorListener() {
					public boolean onError(android.media.MediaPlayer mp, int what, int extra) {
						@{OnPlaybackError(string):call("MediaPlayer error: " + what + ", " + extra)};
						return true;
					}
				});

				@{SetCurrentPlayer(Java.Object):call(player)};

				// Wait a bit for preparation
				Thread.sleep(100);

				if (player.getDuration() > 0) {
					tempFile.delete(); // Clean up temp file
					return player.getDuration() / 1000.0;
				}

				tempFile.delete(); // Clean up temp file
				return 0.0;
			} catch (Exception e) {
				return 0.0;
			}
		@}

		static void SetCurrentPlayer(Java.Object player)
		{
			_currentPlayer = player;
		}

		static void SetPrepared()
		{
			_isPrepared = true;
		}

		static void OnPlaybackCompleted()
		{
			// This will be handled by the progress tracking in AudioPlayer
		}

		static void OnPlaybackError(string error)
		{
			Fuse.Diagnostics.UserError("Android MediaPlayer error: " + error, null);
		}

		public static bool Resume()
		{
			if (_currentPlayer == null || !_isPrepared)
				return false;

			return ResumeImpl();
		}

		[Foreign(Language.Java)]
		static bool ResumeImpl()
		@{
			try {
				android.media.MediaPlayer player = (android.media.MediaPlayer)@{_currentPlayer:get()};
				if (player != null) {
					player.start();
					return true;
				}
				return false;
			} catch (Exception e) {
				return false;
			}
		@}

		public static bool Pause()
		{
			if (_currentPlayer == null)
				return false;

			return PauseImpl();
		}

		[Foreign(Language.Java)]
		static bool PauseImpl()
		@{
			try {
				android.media.MediaPlayer player = (android.media.MediaPlayer)@{_currentPlayer:get()};
				if (player != null && player.isPlaying()) {
					player.pause();
					return true;
				}
				return false;
			} catch (Exception e) {
				return false;
			}
		@}

		public static void Stop()
		{
			if (_currentPlayer == null)
				return;

			StopImpl();
		}

		[Foreign(Language.Java)]
		static void StopImpl()
		@{
			try {
				android.media.MediaPlayer player = (android.media.MediaPlayer)@{_currentPlayer:get()};
				if (player != null) {
					if (player.isPlaying()) {
						player.stop();
					}
					player.seekTo(0);
					player.prepareAsync();
				}
			} catch (Exception e) {
				// Ignore errors during stop
			}
		@}

		public static void SetVolume(float volume)
		{
			if (_currentPlayer == null)
				return;

			SetVolumeImpl(volume);
		}

		[Foreign(Language.Java)]
		static void SetVolumeImpl(float volume)
		@{
			try {
				android.media.MediaPlayer player = (android.media.MediaPlayer)@{_currentPlayer:get()};
				if (player != null) {
					player.setVolume(volume, volume);
				}
			} catch (Exception e) {
				// Ignore errors
			}
		@}

		public static void SetProgress(double progress)
		{
			if (_currentPlayer == null || _duration <= 0)
				return;

			var position = progress * _duration * 1000.0; // Convert to milliseconds
			SetPositionImpl((int)position);
		}

		public static void SetPosition(double positionInSeconds)
		{
			if (_currentPlayer == null)
				return;

			var position = positionInSeconds * 1000.0; // Convert to milliseconds
			SetPositionImpl((int)position);
		}

		[Foreign(Language.Java)]
		static void SetPositionImpl(int positionMs)
		@{
			try {
				android.media.MediaPlayer player = (android.media.MediaPlayer)@{_currentPlayer:get()};
				if (player != null) {
					player.seekTo(positionMs);
				}
			} catch (Exception e) {
				// Ignore errors
			}
		@}

		public static double GetCurrentPosition()
		{
			if (_currentPlayer == null)
				return -1.0;

			return GetCurrentPositionImpl() / 1000.0; // Convert from milliseconds to seconds
		}

		[Foreign(Language.Java)]
		static int GetCurrentPositionImpl()
		@{
			try {
				android.media.MediaPlayer player = (android.media.MediaPlayer)@{_currentPlayer:get()};
				if (player != null) {
					return player.getCurrentPosition();
				}
				return -1;
			} catch (Exception e) {
				return -1;
			}
		@}

		public static bool IsPlaying()
		{
			if (_currentPlayer == null)
				return false;

			return IsPlayingImpl();
		}

		[Foreign(Language.Java)]
		static bool IsPlayingImpl()
		@{
			try {
				android.media.MediaPlayer player = (android.media.MediaPlayer)@{_currentPlayer:get()};
				if (player != null) {
					return player.isPlaying();
				}
				return false;
			} catch (Exception e) {
				return false;
			}
		@}

		static void ReleaseCurrentPlayer()
		{
			if (_currentPlayer == null)
				return;

			ReleaseCurrentPlayerImpl();
			_currentPlayer = null;
			_isPrepared = false;
			_duration = 0.0;
		}

		[Foreign(Language.Java)]
		static void ReleaseCurrentPlayerImpl()
		@{
			try {
				android.media.MediaPlayer player = (android.media.MediaPlayer)@{_currentPlayer:get()};
				if (player != null) {
					player.release();
				}
			} catch (Exception e) {
				// Ignore errors during release
			}
		@}
	}
}
