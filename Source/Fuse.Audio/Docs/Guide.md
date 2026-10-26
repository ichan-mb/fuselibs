# Audio guide

Fuse.Audio provides audio playback and recording for iOS and Android. This guide covers
the two main classes, `AudioPlayer` and `AudioRecorder`, the JavaScript API, and the
platform behaviour you should know about.

Add the package to your project file:

```json
{
  "references": ["Fuse", "FuseJS", "Fuse.Audio"]
}
```

The package adds the permissions it needs automatically: `RECORD_AUDIO` and `INTERNET`
on Android, and the default `NSMicrophoneUsageDescription` on iOS.

## Playing audio

### Bundled files

`AudioPlayer` loads a `FileSource`, which is what `File="..."` resolves to in UX:

```xml
<AudioPlayer ux:Name="player" File="music.mp3" />

<StackPanel Orientation="Horizontal" ItemSpacing="10">
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
	<Button Text="Stop">
		<Clicked>
			<Stop Target="player" />
		</Clicked>
	</Button>
</StackPanel>
```

`AudioPlayer` implements `IMediaPlayback`, so the standard `Play`, `Pause` and `Stop`
actions work with `Target`. Without `Target` they search up the node hierarchy.

`AutoPlay` starts playback as soon as the source is ready. `Loop` restarts playback when
it ends; for local files this is done by the native player, so there is no gap.

### Streaming from a URL

Set `Url` instead of `File`:

```xml
<AudioPlayer ux:Name="radio" Url="https://example.com/stream.mp3" />
```

When both are set, `Url` wins. Progressive streams and HLS are supported on iOS; on
Android anything `MediaPlayer` can play from a URL works.

Streams expose their buffering state:

```xml
<Text Value="{Property radio.IsBuffering}" />
<Slider Minimum="0" Maximum="1" Value="{Property radio.Progress}" />
```

`Buffered` tells you how many seconds ahead of the current position the stream has
downloaded. For live streams with no known length, `Duration` stays `0` and `Progress`
stays `0`; use `Position` for a running clock instead.

### State and events

`CurrentState` is one of `Stopped`, `Playing`, `Paused`, `Loading` or `Error`. Loading is
asynchronous, so a player that is preparing a source reports `Loading` and then
`Stopped` (or `Playing` when `AutoPlay` is set).

| Event                 | Arguments                                   | When                                        |
| --------------------- | ------------------------------------------- | ------------------------------------------- |
| `PlaybackStarted`     | `filePath`, `state`, `progress`, `duration` | Playback began                              |
| `PlaybackPaused`      | same                                        | Playback paused                             |
| `PlaybackStopped`     | same                                        | Playback stopped                            |
| `PlaybackCompleted`   | same                                        | Playback reached the end                    |
| `PlaybackError`       | same, plus `errorMessage`                   | The source could not be played              |
| `ProgressChanged`     | `position`, `progress`, `duration`          | Progress was changed by seeking or stopping |
| `PositionChanged`     | `position`, `progress`, `duration`          | While playing, about 10 times per second    |
| `AudioSampleReceived` | sample data                                 | When `SampleConfig` sampling is active      |

Events are bound in UX, not with `.add()` in JavaScript:

```xml
<AudioPlayer ux:Name="player" File="music.mp3" PositionChanged="{onPosition}" />
```

```javascript
function onPosition(args) {
  console.log(args.position + " / " + args.duration);
}
```

`PositionChanged` is throttled to a change of about 0.1 seconds, so it is safe to drive a
progress bar from it without binding every frame.

## Volume, balance, rate and mute

- `Volume` is `0` to `1`.
- `Muted` silences playback without changing `Volume`, so unmuting restores the
  previous level.
- `Balance` is `-1` (all left) to `1` (all right). On Android it is applied through
  per-channel volume; on iOS through pan. `AVPlayer` has no pan control, so `Balance` has
  no effect while streaming on iOS.
- `Rate` is `0.25` to `4`. Android requires API 23 or newer. On iOS, local playback
  changes pitch with the rate while streams keep their pitch.

## Audio session, interruptions and audio focus

Playback participates in the system's shared audio session:

- On Android the player requests audio focus with media usage attributes, so the media
  volume keys target the right stream and other apps can take over playback.
- On iOS the player activates an `AVAudioSession` with the `Playback` category, so audio
  is not muted by the ringer switch.

When focus is taken away, or a call or notification interrupts playback:

- a permanent loss pauses playback and it stays paused,
- a transient loss or interruption pauses playback and resumes it automatically when it
  ends,
- a "can duck" request lowers the native volume to 30% until focus is regained,
- losing the output device (headphones unplugged, Bluetooth disconnected) pauses
  playback.

The session and audio focus are only held while something is actually playing, and they
are released when a player is unrooted.

## Reading values and calling methods

In UX, bind to properties directly:

```xml
<Slider Minimum="0" Maximum="1" Value="{Property player.Progress}" />
<Text Value="{Property player.Position}" />
```

Properties are not assigned directly from JavaScript. Call the methods instead:

```javascript
player.play(); // or resume()
player.pause();
player.stop();
player.seek(30.0); // seconds
player.setVolume(0.5);
player.setRate(1.25);

var duration = player.getDuration();
var position = player.getPosition();
var buffered = player.getBuffered();
var buffering = player.isBuffering();
var state = player.getState(); // "Stopped" | "Playing" | "Paused" | "Loading" | "Error"
```

## Recording

### Permissions

Microphone access must be granted before recording. The package declares what each
platform needs, but you still have to ask at runtime:

```xml
<AudioRecorder ux:Name="recorder" PermissionChanged="{onPermission}" />

<Button Text="Allow microphone">
	<Clicked>
		<RequestRecordingPermission Target="recorder" />
	</Clicked>
</Button>
```

```javascript
function onPermission(args) {
  if (!args.granted) console.log("Microphone permission denied");
}
```

`HasRecordingPermission()` tells you the current state synchronously; the request itself
is asynchronous and reports through `PermissionChanged`.

### Controlling recording

```xml
<Button Text="Record">
	<Clicked>
		<StartRecording Target="recorder" />
	</Clicked>
</Button>
<Button Text="Stop">
	<Clicked>
		<StopRecording Target="recorder" />
	</Clicked>
</Button>
```

`PauseRecording` and `ResumeRecording` are also available; pausing requires Android 7.0
(API 24) on Android, and works on all supported iOS versions.

### Choosing the input source

`Source` selects and tunes the microphone:

| Value                | Android                                  | iOS                   |
| -------------------- | ---------------------------------------- | --------------------- |
| `Default`            | `MIC`                                    | default mode          |
| `Microphone`         | `MIC`                                    | default mode          |
| `VoiceRecognition`   | `VOICE_RECOGNITION`                      | `measurement` mode    |
| `VoiceCommunication` | `VOICE_COMMUNICATION`                    | `voiceChat` mode      |
| `Camcorder`          | `CAMCORDER`                              | `videoRecording` mode |
| `Unprocessed`        | `UNPROCESSED` (API 24+), otherwise `MIC` | default mode          |

### Levels and duration

While recording, `LevelChanged` fires about 20 times per second with the input peak.
`Waveform` draws a scrolling history of those values for you:

```xml
<AudioRecorder ux:Name="recorder" LevelChanged="{onLevel}" />
<Waveform Recorder="recorder" Height="48" BarColor="#0a0" />
```

```javascript
function onLevel(args) {
  console.log(args.level + " at " + args.position + " s");
}
```

`args.level` is normalized to `0..1`. `RecordingLevel` and `RecordingDuration` are also
available as bindable properties if you would rather build your own meter.

Metering reads the platform's own recorder (`getMaxAmplitude` on Android,
`peakPowerForChannel` on iOS), so it does not open a second microphone capture and works
on devices that reject concurrent capture.

### Limits and completion

`MaxDuration` (seconds) and `MaxFileSize` (bytes) stop the recording automatically when
reached. Set them to `0` for no limit. They are applied when recording starts:

```xml
<AudioRecorder ux:Name="recorder" MaxDuration="60" RecordingCompleted="{onCompleted}" />
```

`RecordingCompleted` fires when a limit stopped the recording. `RecordingStopped` also
fires in that case, because the state changed. Use `RecordingCompleted` when you need to
distinguish "the user stopped it" from "it hit the limit".

### Output files and formats

Recordings are written to:

- iOS: `Documents/Recordings/recording_<timestamp>.<ext>`
- Android: the app-specific external files directory, `Music/Recordings/`

| Format | iOS                         | Android              |
| ------ | --------------------------- | -------------------- |
| `M4A`  | AAC in MP4                  | AAC in MP4           |
| `AAC`  | AAC                         | AAC (ADTS)           |
| `WAV`  | linear PCM                  | still encoded as AAC |
| `MP3`  | AAC (iOS cannot encode MP3) | AAC (ADTS)           |

`SampleRate`, `BitRate` and `Channels` are applied on start. The `Quality` presets
(`Low`, `Medium`, `High`, `Custom`) set those three values for you.

### JavaScript API

```javascript
var granted = recorder.hasPermission();
recorder.requestPermission(); // result arrives through PermissionChanged

recorder.start();
recorder.pause();
recorder.resume();
recorder.stop();

var state = recorder.getState(); // "Stopped" | "Recording" | "Paused"
var duration = recorder.getDuration(); // seconds
var level = recorder.getLevel(); // 0..1
```

## Waveform UI

`Waveform` keeps the most recent values and renders them as bars, newest on the right:

```xml
<!-- Follow a recording -->
<Waveform Recorder="recorder" Height="48" BarColor="#0a0" />

<!-- Follow playback samples (requires SampleConfig, Android only) -->
<Waveform Player="player" Height="48" BarCount="48" Mirrored="false" />
```

| Property   | Default | Meaning                                                    |
| ---------- | ------- | ---------------------------------------------------------- |
| `Recorder` | –       | Follows `AudioRecorder.LevelChanged`                       |
| `Player`   | –       | Follows `AudioPlayer.AudioSampleReceived`                  |
| `File`     | –       | Draws the extracted waveform of a bundled file             |
| `FilePath` | –       | Draws the extracted waveform of a file on disk             |
| `BarCount` | 32      | Number of bars (1 to 256)                                  |
| `BarGap`   | 1       | Space between bars, in points                              |
| `BarColor` | green   | Bar color                                                  |
| `Mirrored` | `true`  | Grow from the center line, or from the bottom when `false` |

You can also drive it yourself with `Push(value)` (one value, 0..1, at the right edge),
`SetValues(float[])` (replaces the whole waveform; values are right-aligned so the newest
data stays on the right) or `Clear()`.

Rendering is not sample-accurate: level mode shows one peak per metering interval and
player mode shows one peak per sample callback. That is enough for the familiar scrolling
voice-memo look, but not for a zoomed-in audio editor. Player mode additionally requires
the `RECORD_AUDIO` permission to be granted at runtime, because Android's `Visualizer`
needs it, and it delivers nothing on iOS.

### Static waveforms from files

For the familiar voice-message bubble, extract the envelope of an existing file:

```xml
<Waveform FilePath="{recordingPath}" Height="48" BarColor="#08f" />
```

`File` does the same for a bundled file. The envelope is decoded on a background thread
the first time and then reused, and it is resampled when `BarCount` changes.

The API is also available directly:

```uno
AudioWaveform.Extract(path, 64).Then(values => {
	waveform.SetValues(values);
}, error => {
	Fuse.Diagnostics.UserWarning("Could not read the waveform: " + error.Message, this);
});
```

`AudioWaveform.Extract` takes a path (or `file://` URL) or a `FileSource`, and resolves
with `barCount` normalized (`0..1`) peak values. It is an envelope, one value per bar,
not the raw sample data. The future is resolved on the UI thread.

Supported formats are whatever the platform can decode: M4A/AAC, MP3 and WAV on both
platforms, plus anything the system decoder understands. Decoding uses `MediaExtractor`
and `MediaCodec` on Android and `AVAudioFile` on iOS.

## Sample-level access

`AudioPlayer` and `AudioRecorder` accept a `SampleConfig` child that enables raw sample
delivery through `AudioSampleReceived`:

```xml
<AudioPlayer File="music.mp3">
	<SampleConfig SampleRate="48000" ChannelCount="2" BufferSize="2048" />
</AudioPlayer>
```

This is intended for waveform analysis rather than level meters. On Android it is
implemented with the `Visualizer` effect, which reports unsigned 8-bit data that the
package converts to `Int16`; `Float32` is not supported there. On iOS sample capture is
not available yet and reports a warning. For UI meters prefer `LevelChanged`, which works
on every device.

## Platform notes

**Android**

- Playback uses `MediaPlayer`; recording uses `MediaRecorder`.
- `Rate` requires API 23+, pausing a recording requires API 24+.
- Audio focus is requested with `USAGE_MEDIA`, so volume keys control media volume.
- Buffering and errors are delivered by the platform listeners.

**iOS**

- Local playback uses `AVAudioPlayer`; `Url` playback uses `AVPlayer`.
- The `Playback` session category means audio plays even when the ringer switch is off.
- Interruptions and route changes are observed through `AVAudioSession` notifications.
- Recording uses `AVAudioRecorder` with metering enabled.

## Troubleshooting

- **Nothing plays on iOS** — check that the source loaded (`CurrentState` is not
  `Error`). Local files use `AVAudioPlayer` and require a valid file URL or data.
- **Recording fails immediately** — the microphone permission has not been granted, or
  another recording is still running. Only one recording can be active at a time.
- **`Pause` does nothing on Android** — pausing a recording requires API 24; pausing
  playback works everywhere.
- **`Rate` has no effect on Android** — the device is older than API 23.
- **`Balance` has no effect** — expected while streaming on iOS.
- **`Progress` stays at 0 for a stream** — the stream has no known duration. Use
  `Position` and `Buffered` instead.
- **`RecordingCompleted` never fires** — `MaxDuration` and `MaxFileSize` must be set
  before `StartRecording`.
- **`Waveform` stays flat with `Recorder` set** — the recorder must actually be
  recording; level updates only arrive between `StartRecording` and `StopRecording`.
- **`Waveform` stays flat with `Player` set** — player sampling needs a `SampleConfig`
  child, the `RECORD_AUDIO` permission granted at runtime, and Android. iOS does not
  expose decoded audio for sampling.

## Example

`Examples/AudioMeteringShowcase.ux1` demonstrates playback controls, position tracking, a
recording level meter, `MaxDuration`, permission handling and the completion events.
