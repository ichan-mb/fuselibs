using Uno;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;
using Uno.Collections;

namespace Fuse.Audio
{
	[Require("source.include", "Apple/AudioPlayerHelper.h")]
	[Set("fileExtension", "mm")]
	internal extern(iOS) static class AudioPlayerImpl
	{
		static ObjC.Object _currentPlayer;
		static double _duration = 0.0;
		static FileSource _currentFile;

		public static bool LoadAudio(FileSource fileSource, out double duration)
		{
			duration = 0.0;

			try
			{
				ReleaseCurrentPlayer();
				_currentFile = fileSource;

				var bundleFileSource = fileSource as BundleFileSource;
				if (bundleFileSource != null)
				{
					var path = "data/" + bundleFileSource.BundleFile.BundlePath;
					duration = LoadAudioFromBundle(path);
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

		[Foreign(Language.ObjC)]
		static double LoadAudioFromBundle(string path)
		@{
			@try {
				NSURL* url = [NSURL fileURLWithPath:[[NSBundle bundleForClass:[StrongUnoObject class]] pathForResource:path ofType:nil]];
				NSError* error = nil;

				AVAudioPlayer* player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
				if (error || !player) {
					return 0.0;
				}

				[player prepareToPlay];
				@{SetCurrentPlayer(ObjC.Object):call(player)};

				return [player duration];
			}
			@catch (NSException* exception) {
				return 0.0;
			}
		@}

		[Foreign(Language.ObjC)]
		static double LoadAudioFromByteArray(byte[] data)
		@{
			@try {
				NSData* audioData = [NSData dataWithBytes:data.unoArray->Ptr() length:data.unoArray->Length()];
				NSError* error = nil;

				AVAudioPlayer* player = [[AVAudioPlayer alloc] initWithData:audioData error:&error];
				if (error || !player) {
					return 0.0;
				}

				[player prepareToPlay];
				@{SetCurrentPlayer(ObjC.Object):call(player)};

				return [player duration];
			}
			@catch (NSException* exception) {
				return 0.0;
			}
		@}

		static void SetCurrentPlayer(ObjC.Object player)
		{
			_currentPlayer = player;
		}

		public static bool Resume()
		{
			if (_currentPlayer == null)
				return false;

			return ResumeImpl();
		}

		[Foreign(Language.ObjC)]
		static bool ResumeImpl()
		@{
			@try {
				AVAudioPlayer* player = (AVAudioPlayer*)@{_currentPlayer:get()};
				if (player) {
					return [player play];
				}
				return false;
			}
			@catch (NSException* exception) {
				return false;
			}
		@}

		public static bool Pause()
		{
			if (_currentPlayer == null)
				return false;

			return PauseImpl();
		}

		[Foreign(Language.ObjC)]
		static bool PauseImpl()
		@{
			@try {
				AVAudioPlayer* player = (AVAudioPlayer*)@{_currentPlayer:get()};
				if (player && [player isPlaying]) {
					[player pause];
					return true;
				}
				return false;
			}
			@catch (NSException* exception) {
				return false;
			}
		@}

		public static void Stop()
		{
			if (_currentPlayer == null)
				return;

			StopImpl();
		}

		[Foreign(Language.ObjC)]
		static void StopImpl()
		@{
			@try {
				AVAudioPlayer* player = (AVAudioPlayer*)@{_currentPlayer:get()};
				if (player) {
					[player stop];
					[player setCurrentTime:0.0];
					[player prepareToPlay];
				}
			}
			@catch (NSException* exception) {
				// Ignore errors during stop
			}
		@}

		public static void SetVolume(float volume)
		{
			if (_currentPlayer == null)
				return;

			SetVolumeImpl(volume);
		}

		[Foreign(Language.ObjC)]
		static void SetVolumeImpl(float volume)
		@{
			@try {
				AVAudioPlayer* player = (AVAudioPlayer*)@{_currentPlayer:get()};
				if (player) {
					[player setVolume:volume];
				}
			}
			@catch (NSException* exception) {
				// Ignore errors
			}
		@}

		public static void SetProgress(double progress)
		{
			if (_currentPlayer == null || _duration <= 0)
				return;

			var position = progress * _duration;
			SetPositionImpl(position);
		}

		public static void SetPosition(double positionInSeconds)
		{
			if (_currentPlayer == null)
				return;

			SetPositionImpl(positionInSeconds);
		}

		[Foreign(Language.ObjC)]
		static void SetPositionImpl(double positionInSeconds)
		@{
			@try {
				AVAudioPlayer* player = (AVAudioPlayer*)@{_currentPlayer:get()};
				if (player) {
					[player setCurrentTime:positionInSeconds];
				}
			}
			@catch (NSException* exception) {
				// Ignore errors
			}
		@}

		public static double GetCurrentPosition()
		{
			if (_currentPlayer == null)
				return -1.0;

			return GetCurrentPositionImpl();
		}

		[Foreign(Language.ObjC)]
		static double GetCurrentPositionImpl()
		@{
			@try {
				AVAudioPlayer* player = (AVAudioPlayer*)@{_currentPlayer:get()};
				if (player) {
					return [player currentTime];
				}
				return -1.0;
			}
			@catch (NSException* exception) {
				return -1.0;
			}
		@}

		public static bool IsPlaying()
		{
			if (_currentPlayer == null)
				return false;

			return IsPlayingImpl();
		}

		[Foreign(Language.ObjC)]
		static bool IsPlayingImpl()
		@{
			@try {
				AVAudioPlayer* player = (AVAudioPlayer*)@{_currentPlayer:get()};
				if (player) {
					return [player isPlaying];
				}
				return false;
			}
			@catch (NSException* exception) {
				return false;
			}
		@}

		static void ReleaseCurrentPlayer()
		{
			if (_currentPlayer == null)
				return;

			ReleaseCurrentPlayerImpl();
			_currentPlayer = null;
			_duration = 0.0;
		}

		[Foreign(Language.ObjC)]
		static void ReleaseCurrentPlayerImpl()
		@{
			@try {
				AVAudioPlayer* player = (AVAudioPlayer*)@{_currentPlayer:get()};
				if (player) {
					[player stop];
					// ARC will handle deallocation
				}
			}
			@catch (NSException* exception) {
				// Ignore errors during release
			}
		@}
	}
}
