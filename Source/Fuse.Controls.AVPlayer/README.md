# Fuse.Controls.AVPlayer

Cross-platform media player for [Fuse](https://fuseopen.com) apps, exposed as the
`MediaPlayer` element.

Playback is handled by the platform's own media stack:

- **Android** — [AndroidX Media3](https://developer.android.com/media/media3) (`ExoPlayer`)
- **iOS** — `AVPlayer` / `AVPlayerViewController`

Both implementations share one API, one state machine and one set of Fuse triggers.

```ux
<MediaPlayer Url="https://example.com/video.mp4" StretchMode="Uniform" />
```

> This package targets **Android and iOS only**. On other targets (dotnet, native) the
> element renders a placeholder panel.

---

## Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Basic usage](#basic-usage)
- [Sources](#sources)
- [Playback properties](#playback-properties)
- [Presentation properties](#presentation-properties)
- [State and triggers](#state-and-triggers)
- [Actions](#actions)
- [Events](#events)
- [JavaScript API](#javascript-api)
- [Background playback and audio](#background-playback-and-audio)
- [Platform support](#platform-support)
- [Known limitations](#known-limitations)
- [Package layout](#package-layout)

---

## Requirements

- Fuselibs 3.0 or later.
- **Android**: `minSdkVersion` 21 or later. The Media3 libraries (1.4.1) are added to the
  app's Gradle dependencies by the package itself — no manual setup, but the app must
  build with `android.useAndroidX=true` (the Uno Android template does this by default).
- **iOS**: needs `AVPlayer.timeControlStatus` (iOS 10 or later) for accurate
  play/pause/buffering state.
- Picture-in-Picture on iOS requires the _Audio, AirPlay and Picture in Picture_
  background mode in the app project.

> **Note for apps using ExoPlayer 2.x directly**: this package depends on AndroidX Media3.
> Media3 and `com.google.android.exoplayer2` cannot coexist in one APK, so an app that
> references ExoPlayer 2.x must migrate as well.

## Installation

Add the package to the app's `.unoproj`:

```json
{
  "references": ["Fuse", "Fuse.Controls.AVPlayer"]
}
```

## Basic usage

```ux
<App>
	<ClientPanel>
		<MediaPlayer
			ux:Name="player"
			Url="https://example.com/video.mp4"
			AutoPlay="false"
			StretchMode="Uniform"
			Width="320"
			Height="240">

			<WhilePlaying>
				<Text Value="Playing" Alignment="Center" />
			</WhilePlaying>
			<WhilePaused>
				<Text Value="Paused" Alignment="Center" />
			</WhilePaused>
			<WhileLoading>
				<Text Value="Loading…" Alignment="Center" />
			</WhileLoading>
			<WhileFailed>
				<Text Value="{player.ErrorMessage}" Alignment="Center" />
			</WhileFailed>
		</MediaPlayer>

		<Grid Columns="1*,1*" Dock="Bottom">
			<Button Text="Play">
				<Clicked>
					<Play Target="player" />
				</Clicked>
			</Button>
			<Button Text="Pause">
				<Clicked>
					<Pause Target="player" />
				</Clicked>
			</Button>
		</Grid>
	</ClientPanel>
</App>
```

A seek bar can be bound directly, since `PlaybackPosition` is writable (dragging it
seeks) and both it and `Duration` raise property changes:

```ux
<Slider Minimum="0" Maximum="{player.Duration}" Value="{player.PlaybackPosition}" />
```

## Sources

Exactly one of `Url` or `File` should be set. Setting either one resets the position and
starts loading; the previous media is unloaded.

```ux
<!-- Streaming (progressive, HLS or DASH) -->
<MediaPlayer Url="https://example.com/stream.m3u8" />

<!-- Bundled asset: include the file in the .unoproj, e.g. "assets/video.mp4:Bundle" -->
<MediaPlayer File="assets/video.mp4" />

<!-- Local file, loaded from a FileSource -->
<MediaPlayer File="{ReadFile someFile}" />
```

`File` sources are copied into the app's `Videos` directory before playback on both
platforms.

## Playback properties

| Property           | Type                 | Default   | Description                                                 |
| ------------------ | -------------------- | --------- | ----------------------------------------------------------- |
| `Url`              | `string`             | `""`      | Streaming or remote URL (progressive, HLS, DASH on Android) |
| `File`             | `FileSource`         | `null`    | Bundled or local file                                       |
| `AutoPlay`         | `bool`               | `true`    | Start playing once the source is loaded                     |
| `IsLooping`        | `bool`               | `false`   | Restart at the end of the media                             |
| `Volume`           | `float`              | `1.0`     | Audio volume, `0.0`–`1.0`                                   |
| `Muted`            | `bool`               | `false`   | Mutes the output without changing `Volume`                  |
| `PlaybackRate`     | `float`              | `1.0`     | Speed multiplier, clamped to `0.25`–`4.0`                   |
| `StreamQuality`    | `MediaStreamQuality` | `Auto`    | Bitrate cap for adaptive streams                            |
| `PlaybackPosition` | `double`             | `0`       | Position in seconds; setting it seeks                       |
| `Progress`         | `double`             | `0`       | Position as a fraction of the duration; setting it seeks    |
| `Duration`         | `double`             | read-only | Media duration in seconds, `0` while unknown                |
| `State`            | `MediaPlayerState`   | read-only | Current playback state                                      |
| `IsPlaying`        | `bool`               | read-only | Whether playback is active                                  |
| `IsBuffering`      | `bool`               | read-only | Whether playback is waiting for data                        |
| `BufferProgress`   | `float`              | read-only | Buffered fraction of the media, `0`–`1`                     |
| `ErrorMessage`     | `string`             | read-only | Reason of the last failure, empty otherwise                 |

`MediaStreamQuality` is `Auto`, `SD` (~1.5 Mbit/s), `HD` (~4 Mbit/s) or `FullHD`
(~8 Mbit/s). It is a _cap_: the player still adapts to the available bandwidth below the
limit. It has no effect on progressive files (only HLS/DASH).

## Presentation properties

| Property       | Type          | Default   | Description                                                      |
| -------------- | ------------- | --------- | ---------------------------------------------------------------- |
| `StretchMode`  | `StretchMode` | `Uniform` | How the video is fitted: `Uniform`, `UniformToFill` or `Fill`    |
| `ShowControls` | `bool`        | `true`    | Native playback controls (ExoPlayer controller / AVKit controls) |
| `KeepScreenOn` | `bool`        | `false`   | Keep the display awake while playing                             |

`StretchMode` maps to `AspectRatioFrameLayout.RESIZE_MODE_*` on Android and
`AVPlayerViewController.videoGravity` on iOS.

## State and triggers

`State` is a `MediaPlayerState`: `Idle`, `Loading`, `Ready`, `Playing`, `Paused`, `Ended`
or `Failed`. The standard Fuse playback triggers are driven automatically:

| Trigger            | Active when                                   |
| ------------------ | --------------------------------------------- |
| `<WhilePlaying>`   | `Playing`                                     |
| `<WhilePaused>`    | `Paused` or `Ready` (loaded but not started)  |
| `<WhileLoading>`   | `Loading`, or buffering during playback       |
| `<WhileCompleted>` | `Ended`                                       |
| `<WhileFailed>`    | `Failed` — the busy message is `ErrorMessage` |

Rebuffering during playback does not change `State`; it sets `IsBuffering` and keeps
`<WhileLoading>` active.

## Actions

`MediaPlayer` implements `Fuse.Triggers.IMediaPlayback` (which extends `IPlayback` and
`IProgress`), so the standard Fuse actions work with `Target="player"`:

```ux
<Play Target="player" />                  <!-- start or resume -->
<Pause Target="player" />                 <!-- pause, keep position -->
<Stop Target="player" />                  <!-- pause, return to start -->
<Reset Target="player" />                 <!-- stop, then resume -->
<Seek Target="player" Progress="0.5" />   <!-- seek to 50% -->
<SetVolume Target="player" Value="0.5" /> <!-- volume 0..1 -->
```

The same actions also work on the timeline of a `Timeline`; see the Fuse documentation.
`MediaPlayer` also implements `IProgress`, so it can be used wherever Fuse accepts a
progress source (`Progress` plus the `ProgressChanged` event).

## Events

```ux
<MediaPlayer
	Url="video.mp4"
	Playing="{onPlaying}"
	Paused="{onPaused}"
	Stopped="{onStopped}"
	Ended="{onEnded}"
	LoadingStarted="{onLoadingStarted}"
	LoadingEnded="{onLoadingEnded}"
	BufferedChanged="{onBufferedChanged}"
	DurationChanged="{onDurationChanged}"
	PlaybackPositionChanged="{onPositionChanged}"
	Error="{onError}" />
```

| Event                                                                                        | Arguments                                                                              |
| -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `Playing`, `Paused`, `Stopped`, `Ended`, `LoadingStarted`, `LoadingEnded`, `BufferedChanged` | —                                                                                      |
| `PlaybackPositionChanged`, `DurationChanged`                                                 | `TimeChangedEventArgs.Time` (seconds)                                                  |
| `Error`                                                                                      | `ErrorEventArgs.Message`, `.Exception`, `.Severity` (`Info`/`Warning`/`Error`/`Fatal`) |

## JavaScript API

The element can be controlled from JavaScript through its `ux:Name`:

```ux
<MediaPlayer ux:Name="player" Url="video.mp4" />

<JavaScript>
	player.play();
	player.pause();
	player.stop();

	player.seek(30);              // seconds
	player.setVolume(0.5);        // 0..1
	player.setMuted(true);
	player.setPlaybackRate(1.5);  // 0.25..4.0

	console.log(player.getPosition() + " / " + player.getDuration());
	console.log(player.getState()); // "idle" | "loading" | "ready" |
	                                // "playing" | "paused" | "ended" | "failed"
</JavaScript>
```

Control methods are executed on the UI thread. `getPosition()`, `getDuration()` and
`getState()` are synchronous reads of the current values; poll them if you need a
JavaScript-driven progress indicator (in UX, bind `PlaybackPosition` instead).

## Background playback and audio

By default playback pauses when the app is sent to the background and resumes when it
returns:

| Property                | Type   | Default | Description                                |
| ----------------------- | ------ | ------- | ------------------------------------------ |
| `PauseWhenBackgrounded` | `bool` | `true`  | Pause when the app is no longer visible    |
| `ResumeOnForeground`    | `bool` | `true`  | Resume if playback was paused by the above |

For audio playback set `PauseWhenBackgrounded="false"`. On iOS this additionally requires
the `audio` background mode in the app project.

Audio session behaviour is handled per platform:

- **Android** — the player sets `AudioAttributes` (`USAGE_MEDIA`,
  `AUDIO_CONTENT_TYPE_MOVIE`) and requests audio focus, so it pauses for phone calls and
  other apps, resumes when focus returns, and pauses when headphones are unplugged.
- **iOS** — the audio session uses the `playback` category (audible with the ringer
  switch off), pauses on interruptions and resumes when the system allows it, and pauses
  when the current output device disappears (e.g. headphones unplugged).

## Platform support

| Feature                                      | Android      | iOS                              |
| -------------------------------------------- | ------------ | -------------------------------- |
| Bundled / local files                        | ✅           | ✅                               |
| Progressive HTTP                             | ✅           | ✅                               |
| HLS                                          | ✅           | ✅                               |
| DASH                                         | ✅           | ❌ (AVPlayer supports HLS only)  |
| Looping                                      | ✅           | ✅                               |
| Playback speed                               | ✅           | ✅                               |
| Volume / mute                                | ✅           | ✅                               |
| Audio focus, interruptions, headphone unplug | ✅           | ✅                               |
| Pause/resume on background policy            | ✅           | ✅                               |
| Background audio (screen off)                | ⚠️ see below | ⚠️ needs `audio` background mode |
| Stretch / fit modes                          | ✅           | ✅                               |
| Native playback controls                     | ✅           | ✅                               |
| Keep screen on                               | ✅           | ✅                               |
| Picture-in-Picture                           | ❌           | ✅                               |
| External subtitles, track selection          | ❌           | ❌                               |
| Playlists                                    | ❌           | ❌                               |
| DRM (Widevine / FairPlay)                    | ❌           | ❌                               |
| Download caching                             | ❌           | ❌                               |

**Background audio**: on Android the component does not start a foreground service, so
the system may stop playback when the app is backgrounded for a long time, and there are
no lock-screen or notification controls. On iOS playback continues in the background
when the `audio` background mode is declared and `PauseWhenBackgrounded="false"`.

## Known limitations

- **`Progress` before loading**: setting `Progress` (or seeking by fraction) before the
  duration is known is ignored, since a fraction cannot be converted to seconds. Use
  `PlaybackPosition` for early seeks.
- **`File` loading is synchronous**: bundled/local files are read and copied to the
  `Videos` directory on the UI thread when the source is set. Large files will cause a
  short hitch.
- **Seeking is not coalesced**: animating `Progress` (e.g. a slider drag) issues one seek
  per change. Native players handle this, but on slow devices it is smoother to seek on
  drag-end.
- **No track selection**: multiple audio tracks, subtitles and captions are not exposed.
- **`StretchMode` only**: `ContentAlignment` and `StretchDirection`/`StretchSizing` are
  not supported, since native video surfaces do not offer alignment and do not take part
  in Fuse layout measurement.

## Package layout

```
Fuse.Controls.AVPlayer/
├── AudioVideoPlayer.uno              Element, state machine, triggers, events
├── AudioVideoPlayer.ScriptClass.uno  JavaScript API
├── AudioVideoPlayer.ux               `MediaPlayer` element and platform appearance
├── Android/AVPlayerView.uno          Media3 implementation
├── iOS/AVPlayerView.uno              AVPlayer implementation
├── iOS/AVPlayerContainer.h/.m        Player view container
└── Fuse.Controls.AVPlayer.unoproj
```

The public element is `Fuse.Controls.MediaPlayer`; the shared implementation lives in the
abstract `Fuse.Controls.AVPlayerBase`. Platform views implement the internal
`IAVPlayerView` interface.

### Building

Validate the package with the Uno compiler (Android also type-checks the platform code):

```sh
uno build --target=android Source/Fuse.Controls.AVPlayer/Fuse.Controls.AVPlayer.unoproj
uno build --target=ios     Source/Fuse.Controls.AVPlayer/Fuse.Controls.AVPlayer.unoproj
```

When consuming fuselibs from source, app builds read libraries from `Source/build/`.
Pass `-l` (`--libs`) to an app build, or re-run `uno doctor Source`, after changing a
library so the packaged sources are refreshed:

```sh
uno build --target=android -l MyApp.unoproj
```

Note that the Java and Objective-C parts are only compiled by Gradle/Xcode, so a green
Uno build does not guarantee that the native snippets compile.
