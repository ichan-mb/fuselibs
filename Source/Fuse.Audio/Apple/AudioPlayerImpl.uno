using Uno;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Audio
{
	/** Native playback objects for one AudioPlayer instance (iOS) */
	internal extern(iOS) class AudioPlayerHandle
	{
		/** AVAudioPlayer for bundled/byte-array sources, AVPlayer for streams */
		public ObjC.Object Player;

		/** Whether Player is an AVPlayer */
		public bool IsStreaming;
	}

	[Require("source.include", "Apple/AudioHelper.h")]
	[Require("source.include", "Apple/AudioPlayerCallbacks.h")]
	[Set("fileExtension", "mm")]
	internal extern(iOS) static class AudioPlayerImpl
	{
		static bool _sessionActive;
		static ObjC.Object _interruptionObserver;
		static ObjC.Object _routeObserver;
		static bool _samplingWarningShown;

		/**
			Creates a native player for the given source.

			Local sources use AVAudioPlayer; `url` uses AVPlayer so streaming and HLS work.
			Returns the handle, or null when the source could not be opened (in which case
			the error has already been reported through `AudioPlayer.OnNativeError`).

			`duration` is the known duration, or 0 for streams whose length is not known yet.
		*/
		public static object LoadAudio(FileSource fileSource, string url, int callbackId, int generation, out double duration)
		{
			duration = -1.0;

			try
			{
				// Url takes precedence over File
				if (!string.IsNullOrEmpty(url))
				{
					var streamHandle = new AudioPlayerHandle();
					streamHandle.IsStreaming = true;
					streamHandle.Player = LoadFromUrl(url);

					if (streamHandle.Player == null)
					{
						AudioPlayer.OnNativeError(callbackId, generation, "Failed to open audio url");
						return null;
					}

					ObserveStreamEnd(streamHandle.Player, callbackId, generation);
					duration = GetStreamDuration(streamHandle.Player);
					return streamHandle;
				}

				if (fileSource == null)
				{
					AudioPlayer.OnNativeError(callbackId, generation, "No audio file or url specified");
					return null;
				}

				ObjC.Object player;

				var bundleFileSource = fileSource as BundleFileSource;
				if (bundleFileSource != null)
					player = LoadFromBundle("data/" + bundleFileSource.BundleFile.BundlePath);
				else
					player = LoadFromBytes(fileSource.ReadAllBytes());

				if (player == null)
				{
					AudioPlayer.OnNativeError(callbackId, generation, "Failed to load audio file");
					return null;
				}

				// Callbacks must be installed before playback can start
				InstallCallbacks(player, callbackId, generation);

				var handle = new AudioPlayerHandle();
				handle.Player = player;
				duration = GetDurationImpl(player, false);
				return handle;
			}
			catch (Exception e)
			{
				AudioPlayer.OnNativeError(callbackId, generation, "Failed to load audio: " + e.Message);
				return null;
			}
		}

		[Foreign(Language.ObjC)]
		static ObjC.Object LoadFromBundle(string path)
		@{
			@try {
				NSURL* url = [NSURL fileURLWithPath:[[NSBundle bundleForClass:[StrongUnoObject class]] pathForResource:path ofType:nil]];
				NSError* error = nil;

				AVAudioPlayer* player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
				if (error || !player)
					return nil;

				[player prepareToPlay];
				return player;
			}
			@catch (NSException* exception) {
				return nil;
			}
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object LoadFromBytes(byte[] data)
		@{
			@try {
				NSData* audioData = [NSData dataWithBytes:data.unoArray->Ptr() length:data.unoArray->Length()];
				NSError* error = nil;

				AVAudioPlayer* player = [[AVAudioPlayer alloc] initWithData:audioData error:&error];
				if (error || !player)
					return nil;

				[player prepareToPlay];
				return player;
			}
			@catch (NSException* exception) {
				return nil;
			}
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object LoadFromUrl(string url)
		@{
			@try {
				NSURL* nsUrl = [NSURL URLWithString:url];
				if (nsUrl == nil)
					return nil;

				AVPlayerItem* item = [AVPlayerItem playerItemWithURL:nsUrl];
				// Time domain keeps speech/music natural when the rate changes
				item.audioTimePitchAlgorithm = AVAudioTimePitchAlgorithmTimeDomain;

				AVPlayer* player = [[AVPlayer alloc] initWithPlayerItem:item];
				player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
				return player;
			}
			@catch (NSException* exception) {
				return nil;
			}
		@}

		static void InstallCallbacks(ObjC.Object player, int callbackId, int generation)
		{
			InstallCallbacksImpl(player,
				() => NativeCompleted(callbackId, generation),
				message => NativeError(callbackId, generation, message));
		}

		[Foreign(Language.ObjC)]
		static void InstallCallbacksImpl(ObjC.Object handle, Action onCompleted, Action<string> onError)
		@{
			UnoAudioPlayerInstallCallbacks((AVAudioPlayer*)handle, onCompleted, onError);
		@}

		static void ObserveStreamEnd(ObjC.Object player, int callbackId, int generation)
		{
			ObserveStreamEndImpl(player,
				() => NativeCompleted(callbackId, generation),
				message => NativeError(callbackId, generation, message));
		}

		[Foreign(Language.ObjC)]
		static void ObserveStreamEndImpl(ObjC.Object handle, Action onCompleted, Action<string> onError)
		@{
			UnoAudioPlayerObserveStream((AVPlayer*)handle, onCompleted, onError);
		@}

		static void NativeCompleted(int callbackId, int generation)
		{
			AudioPlayer.OnNativeCompleted(callbackId, generation);
		}

		static void NativeError(int callbackId, int generation, string message)
		{
			Fuse.Diagnostics.UserError("iOS audio: " + message, null);
			AudioPlayer.OnNativeError(callbackId, generation, message);
		}

		// ---- Playback ----

		public static bool Resume(object handle, double rate)
		{
			var h = handle as AudioPlayerHandle;
			if (h == null || h.Player == null)
				return false;

			return ResumeImpl(h.Player, h.IsStreaming, (float)rate);
		}

		[Foreign(Language.ObjC)]
		static bool ResumeImpl(ObjC.Object playerHandle, bool streaming, float rate)
		@{
			@try {
				if (streaming) {
					AVPlayer* player = (AVPlayer*)playerHandle;
					[player play];
					if (rate != 1.0f)
						[player setRate:rate];
					return true;
				}

				AVAudioPlayer* player = (AVAudioPlayer*)playerHandle;
				player.enableRate = YES;
				player.rate = rate;
				return [player play];
			}
			@catch (NSException* exception) {
				return false;
			}
		@}

		public static bool Pause(object handle)
		{
			var h = handle as AudioPlayerHandle;
			if (h == null || h.Player == null)
				return false;

			return PauseImpl(h.Player, h.IsStreaming);
		}

		[Foreign(Language.ObjC)]
		static bool PauseImpl(ObjC.Object playerHandle, bool streaming)
		@{
			@try {
				if (streaming) {
					AVPlayer* player = (AVPlayer*)playerHandle;
					if (player.rate != 0.0f) {
						[player pause];
						return true;
					}
					return false;
				}

				AVAudioPlayer* player = (AVAudioPlayer*)playerHandle;
				if ([player isPlaying]) {
					[player pause];
					return true;
				}
				return false;
			}
			@catch (NSException* exception) {
				return false;
			}
		@}

		public static void Stop(object handle)
		{
			var h = handle as AudioPlayerHandle;
			if (h == null || h.Player == null)
				return;

			StopImpl(h.Player, h.IsStreaming);
		}

		[Foreign(Language.ObjC)]
		static void StopImpl(ObjC.Object playerHandle, bool streaming)
		@{
			@try {
				if (streaming) {
					AVPlayer* player = (AVPlayer*)playerHandle;
					[player pause];
					[player seekToTime:kCMTimeZero];
					return;
				}

				AVAudioPlayer* player = (AVAudioPlayer*)playerHandle;
				// Pause (rather than stop) so the player stays ready to start again
				if ([player isPlaying])
					[player pause];
				[player setCurrentTime:0.0];
			}
			@catch (NSException* exception) {
				// Ignore errors during stop
			}
		@}

		public static void SetVolume(object handle, float volume, float balance)
		{
			var h = handle as AudioPlayerHandle;
			if (h == null || h.Player == null)
				return;

			SetVolumeImpl(h.Player, h.IsStreaming, volume, balance);
		}

		[Foreign(Language.ObjC)]
		static void SetVolumeImpl(ObjC.Object playerHandle, bool streaming, float volume, float balance)
		@{
			@try {
				if (streaming) {
					// AVPlayer has no pan control; balance is ignored while streaming
					[(AVPlayer*)playerHandle setVolume:volume];
					return;
				}

				AVAudioPlayer* player = (AVAudioPlayer*)playerHandle;
				[player setVolume:volume];
				[player setPan:balance];
			}
			@catch (NSException* exception) {
				// Ignore errors
			}
		@}

		public static void SetRate(object handle, double rate)
		{
			var h = handle as AudioPlayerHandle;
			if (h == null || h.Player == null)
				return;

			SetRateImpl(h.Player, h.IsStreaming, (float)rate);
		}

		[Foreign(Language.ObjC)]
		static void SetRateImpl(ObjC.Object playerHandle, bool streaming, float rate)
		@{
			@try {
				if (streaming) {
					AVPlayer* player = (AVPlayer*)playerHandle;
					// Setting a non-zero rate also starts playback, so only apply
					// the rate when the stream is already playing.
					if (player.rate != 0.0f)
						[player setRate:rate];
					return;
				}

				[(AVAudioPlayer*)playerHandle setRate:rate];
			}
			@catch (NSException* exception) {
				// Ignore errors
			}
		@}

		public static void SetLoop(object handle, bool loop)
		{
			var h = handle as AudioPlayerHandle;
			if (h == null || h.Player == null)
				return;

			SetLoopImpl(h.Player, h.IsStreaming, loop);
		}

		[Foreign(Language.ObjC)]
		static void SetLoopImpl(ObjC.Object playerHandle, bool streaming, bool loop)
		@{
			@try {
				if (streaming) {
					// Streams restart through the completion path, so only the end
					// behaviour needs to be configured here.
					[(AVPlayer*)playerHandle setActionAtItemEnd:
						loop ? AVPlayerActionAtItemEndNone : AVPlayerActionAtItemEndPause];
					return;
				}

				// Gapless looping for local files
				[(AVAudioPlayer*)playerHandle setNumberOfLoops:(loop ? -1 : 0)];
			}
			@catch (NSException* exception) {
				// Ignore errors
			}
		@}

		public static void SetPosition(object handle, double positionInSeconds)
		{
			var h = handle as AudioPlayerHandle;
			if (h == null || h.Player == null)
				return;

			SetPositionImpl(h.Player, h.IsStreaming, positionInSeconds);
		}

		[Foreign(Language.ObjC)]
		static void SetPositionImpl(ObjC.Object playerHandle, bool streaming, double positionInSeconds)
		@{
			@try {
				if (streaming) {
					[(AVPlayer*)playerHandle seekToTime:CMTimeMakeWithSeconds(positionInSeconds, 600)];
					return;
				}

				[(AVAudioPlayer*)playerHandle setCurrentTime:positionInSeconds];
			}
			@catch (NSException* exception) {
				// Ignore errors
			}
		@}

		public static double GetCurrentPosition(object handle)
		{
			var h = handle as AudioPlayerHandle;
			if (h == null || h.Player == null)
				return -1.0;

			return GetCurrentPositionImpl(h.Player, h.IsStreaming);
		}

		[Foreign(Language.ObjC)]
		static double GetCurrentPositionImpl(ObjC.Object playerHandle, bool streaming)
		@{
			@try {
				if (streaming) {
					double seconds = CMTimeGetSeconds([(AVPlayer*)playerHandle currentTime]);
					return isfinite(seconds) ? seconds : 0.0;
				}

				return [(AVAudioPlayer*)playerHandle currentTime];
			}
			@catch (NSException* exception) {
				return -1.0;
			}
		@}

		public static double GetDuration(object handle)
		{
			var h = handle as AudioPlayerHandle;
			if (h == null || h.Player == null)
				return -1.0;

			return GetDurationImpl(h.Player, h.IsStreaming);
		}

		[Foreign(Language.ObjC)]
		static double GetDurationImpl(ObjC.Object playerHandle, bool streaming)
		@{
			@try {
				if (streaming) {
					AVPlayer* player = (AVPlayer*)playerHandle;
					AVPlayerItem* item = player.currentItem;
					if (item == nil)
						return -1.0;

					CMTime duration = item.duration;
					if (CMTIME_IS_INDEFINITE(duration) || CMTIME_IS_INVALID(duration))
						return 0.0;

					double seconds = CMTimeGetSeconds(duration);
					return isfinite(seconds) ? seconds : 0.0;
				}

				return [(AVAudioPlayer*)playerHandle duration];
			}
			@catch (NSException* exception) {
				return -1.0;
			}
		@}

		static double GetStreamDuration(ObjC.Object player)
		{
			return GetDurationImpl(player, true);
		}

		public static double GetBuffered(object handle, int callbackId)
		{
			var h = handle as AudioPlayerHandle;
			if (h == null || h.Player == null)
				return -1.0;

			return GetBufferedImpl(h.Player, h.IsStreaming);
		}

		[Foreign(Language.ObjC)]
		static double GetBufferedImpl(ObjC.Object playerHandle, bool streaming)
		@{
			@try {
				if (!streaming) {
					// Local files are fully available
					return [(AVAudioPlayer*)playerHandle duration];
				}

				AVPlayer* player = (AVPlayer*)playerHandle;
				AVPlayerItem* item = player.currentItem;
				if (item == nil)
					return -1.0;

				NSArray* ranges = item.loadedTimeRanges;
				if (ranges == nil || [ranges count] == 0)
					return -1.0;

				CMTimeRange range = [[ranges lastObject] CMTimeRangeValue];
				double end = CMTimeGetSeconds(range.start) + CMTimeGetSeconds(range.duration);
				return isfinite(end) ? end : -1.0;
			}
			@catch (NSException* exception) {
				return -1.0;
			}
		@}

		public static bool IsBuffering(object handle, int callbackId)
		{
			var h = handle as AudioPlayerHandle;
			if (h == null || h.Player == null)
				return false;

			if (!h.IsStreaming)
				return false;

			return IsBufferingImpl(h.Player);
		}

		[Foreign(Language.ObjC)]
		static bool IsBufferingImpl(ObjC.Object playerHandle)
		@{
			@try {
				AVPlayerItem* item = [(AVPlayer*)playerHandle currentItem];
				if (item == nil)
					return false;

				return !item.isPlaybackLikelyToKeepUp;
			}
			@catch (NSException* exception) {
				return false;
			}
		@}

		public static string GetError(object handle)
		{
			var h = handle as AudioPlayerHandle;
			if (h == null || h.Player == null || !h.IsStreaming)
				return "";

			return GetStreamErrorImpl(h.Player);
		}

		[Foreign(Language.ObjC)]
		static string GetStreamErrorImpl(ObjC.Object playerHandle)
		@{
			@try {
				AVPlayerItem* item = [(AVPlayer*)playerHandle currentItem];
				if (item == nil || item.error == nil)
					return @"";

				return item.error.localizedDescription;
			}
			@catch (NSException* exception) {
				return @"";
			}
		@}

		public static void Release(object handle, int callbackId)
		{
			var h = handle as AudioPlayerHandle;
			if (h == null || h.Player == null)
				return;

			ReleaseImpl(h.Player, h.IsStreaming);
		}

		[Foreign(Language.ObjC)]
		static void ReleaseImpl(ObjC.Object playerHandle, bool streaming)
		@{
			@try {
				if (streaming) {
					AVPlayer* player = (AVPlayer*)playerHandle;
					UnoAudioPlayerRemoveObservers(player);
					[player pause];
					return;
				}

				AVAudioPlayer* player = (AVAudioPlayer*)playerHandle;
				player.delegate = nil;
				[player stop];
				// ARC releases the player (and its associated delegate) when the
				// Uno handle is dropped
			}
			@catch (NSException* exception) {
				// Ignore errors during release
			}
		@}

		// ---- Audio session ----

		public static void ActivateAudioSession()
		{
			if (_sessionActive)
				return;

			_sessionActive = ActivateSessionImpl();
			if (_sessionActive)
				RegisterSessionObservers();
		}

		public static void DeactivateAudioSession()
		{
			if (!_sessionActive)
				return;

			_sessionActive = false;
			UnregisterSessionObservers();
			DeactivateSessionImpl();
		}

		[Foreign(Language.ObjC)]
		static bool ActivateSessionImpl()
		@{
			@try {
				AVAudioSession* session = [AVAudioSession sharedInstance];
				NSError* error = nil;

				// Playback category: keeps playing when the ringer switch is off
				if (![session setCategory:AVAudioSessionCategoryPlayback error:&error])
					return false;

				if (![session setActive:YES error:&error])
					return false;

				return true;
			}
			@catch (NSException* exception) {
				return false;
			}
		@}

		[Foreign(Language.ObjC)]
		static void DeactivateSessionImpl()
		@{
			@try {
				NSError* error = nil;
				[[AVAudioSession sharedInstance] setActive:NO
					withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
					error:&error];
			}
			@catch (NSException* exception) {
				// Ignore errors while deactivating
			}
		@}

		static void SetSessionObservers(ObjC.Object interruptionObserver, ObjC.Object routeObserver)
		{
			_interruptionObserver = interruptionObserver;
			_routeObserver = routeObserver;
		}

		static void NativeInterruptionBegan()
		{
			AudioPlayer.OnNativeInterruptionBegan();
		}

		static void NativeInterruptionEnded(bool shouldResume)
		{
			AudioPlayer.OnNativeInterruptionEnded(shouldResume);
		}

		static void NativeRouteChanged()
		{
			AudioPlayer.OnNativeRouteChanged();
		}

		[Foreign(Language.ObjC)]
		static void RegisterSessionObservers()
		@{
			NSNotificationCenter* center = [NSNotificationCenter defaultCenter];

			id interruptionObserver = [center addObserverForName:AVAudioSessionInterruptionNotification
			                                              object:nil
			                                               queue:[NSOperationQueue mainQueue]
			                                          usingBlock:^(NSNotification* note) {
				NSUInteger type = [[note.userInfo objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
				if (type == AVAudioSessionInterruptionTypeBegan) {
					@{NativeInterruptionBegan():call()};
				} else {
					NSUInteger options = [[note.userInfo objectForKey:AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
					@{NativeInterruptionEnded(bool):call((options & AVAudioSessionInterruptionOptionShouldResume) != 0)};
				}
			}];

			id routeObserver = [center addObserverForName:AVAudioSessionRouteChangeNotification
			                                       object:nil
			                                        queue:[NSOperationQueue mainQueue]
			                                   usingBlock:^(NSNotification* note) {
				NSUInteger reason = [[note.userInfo objectForKey:AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
				if (reason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
					// Headphones were unplugged or a Bluetooth output disconnected
					@{NativeRouteChanged():call()};
				}
			}];

			@{SetSessionObservers(ObjC.Object,ObjC.Object):call(interruptionObserver, routeObserver)};
		@}

		[Foreign(Language.ObjC)]
		static void UnregisterSessionObservers()
		@{
			NSNotificationCenter* center = [NSNotificationCenter defaultCenter];

			id interruptionObserver = (id)@{_interruptionObserver:get()};
			if (interruptionObserver != nil)
				[center removeObserver:interruptionObserver];

			id routeObserver = (id)@{_routeObserver:get()};
			if (routeObserver != nil)
				[center removeObserver:routeObserver];

			@{SetSessionObservers(ObjC.Object,ObjC.Object):call(nil, nil)};
		@}

		// ---- Audio sampling ----
		// AVAudioPlayer/AVPlayer do not expose decoded output, so per-sample capture
		// requires moving playback to AVAudioEngine. Until then, sampling is reported
		// as unsupported instead of silently delivering nothing.

		public static void StartAudioSampling(object handle, int callbackId, int sampleRate, int channelCount,
		                                      int format, int bufferSize, int updateIntervalMs)
		{
			if (_samplingWarningShown)
				return;

			_samplingWarningShown = true;
			Fuse.Diagnostics.UserWarning("Audio sampling is not supported on iOS yet", null);
		}

		public static void StopAudioSampling(object handle, int callbackId)
		{
		}
	}
}
