# Fuse.Audio

Audio playback and recording support for Fuse applications.

## Features

- **Audio Playback**: Play bundled files, in-memory data or stream from a `Url`
- **Audio Player**: Play/pause/stop, seeking, volume, mute, balance, playback rate, gapless looping
- **Streaming**: `Buffered` / `IsBuffering` state and a throttled `PositionChanged` event
- **Audio Session**: Audio focus on Android and `AVAudioSession` on iOS, with interruption, ducking and route-change handling
- **Multiple Instances**: Each `AudioPlayer` owns its own native player
- **Audio Recording**: Record audio with configurable settings on iOS and Android
- **Level Metering**: Input level and recording duration at ~20 updates per second
- **Waveform UI**: `Waveform` renders recording levels, playback samples, or a static envelope extracted from a file
- **Recording Limits**: `MaxDuration` / `MaxFileSize` with a `RecordingCompleted` event
- **Audio Sources**: Microphone, voice recognition, voice communication, camcorder, unprocessed
- **Multiple Formats**: Support for WAV, AAC, MP3, and M4A formats
- **Quality Presets**: Low, Medium, High, and Custom quality settings
- **Permission Management**: Asynchronous microphone permission results
- **JavaScript API**: Script methods on both `AudioPlayer` and `AudioRecorder`
- **IMediaPlayback Interface**: Compatible with Fuse's standard playback trigger actions

## Installation

Add the Fuse.Audio package to your project's .unoproj file:

```json
{
  "references": ["Fuse", "FuseJS", "Fuse.Audio"]
}
```

## Audio Playback

### PlaySound

Play bundled audio files with the `PlaySound` trigger action for simple one-shot sounds:

```xml
<Button Text="Play Sound">
  <Clicked>
    <PlaySound File="chime.wav" />
  </Clicked>
</Button>
```

### AudioPlayer

The `AudioPlayer` class provides comprehensive audio playback functionality with full control over playback state, progress, and volume. It implements the `IMediaPlayback` interface for compatibility with standard Fuse playback actions.

```xml
<AudioPlayer ux:Name="audioPlayer"
             File="music.mp3"
             AutoPlay="false"
             Loop="false"
             Volume="1.0"
             Rate="1.0"
             PlaybackStarted="{onPlaybackStarted}"
             PlaybackStopped="{onPlaybackStopped}"
             PlaybackPaused="{onPlaybackPaused}"
             PlaybackCompleted="{onPlaybackCompleted}"
             PlaybackError="{onPlaybackError}"
             ProgressChanged="{onProgressChanged}"
             PositionChanged="{onPositionChanged}" />
```

#### AudioPlayer Properties

- `File` - The audio file to play (FileSource)
- `Url` - A URL to stream from instead of `File` (string, takes precedence when set)
- `AutoPlay` - Whether to automatically start playing when loaded (bool, default: false)
- `Loop` - Whether to loop the audio when it reaches the end (bool, default: false)
- `Volume` - Playback volume from 0.0 to 1.0 (float, default: 1.0)
- `Muted` - Mutes playback without changing `Volume` (bool, default: false)
- `Balance` - Stereo balance, -1.0 (left) to 1.0 (right) (float, default: 0)
- `Rate` - Playback rate from 0.25 to 4.0 (double, default: 1.0)
- `Progress` - Current playback progress from 0.0 to 1.0 (double, read/write)
- `Position` - Current playback position in seconds (double, read/write)
- `Duration` - Total duration of the audio in seconds (double, read-only)
- `Buffered` - Seconds of a stream that are buffered (double, read-only)
- `IsBuffering` - Whether a stream is waiting for more data (bool, read-only)
- `CurrentState` - Current playback state (PlaybackState enum, read-only)

#### Playback States

- `Stopped` - Playback is stopped
- `Playing` - Audio is currently playing
- `Paused` - Playback is paused
- `Loading` - Audio file is loading
- `Error` - An error occurred

### AudioPlayer Controls

`AudioPlayer` implements `IMediaPlayback`, so the standard playback actions work with `Target`:

```xml
<!-- Play/Resume Audio -->
<Button Text="Play">
  <Clicked>
    <Play Target="audioPlayer" />
  </Clicked>
</Button>

<!-- Pause Audio -->
<Button Text="Pause">
  <Clicked>
    <Pause Target="audioPlayer" />
  </Clicked>
</Button>

<!-- Stop Audio (also resets to the beginning) -->
<Button Text="Stop">
  <Clicked>
    <Stop Target="audioPlayer" />
  </Clicked>
</Button>
```

Seeking and volume are exposed as bindable properties:

```xml
<Slider Minimum="0" Maximum="1" Value="{Property audioPlayer.Progress}" />
<Slider Minimum="0" Maximum="1" Value="{Property audioPlayer.Volume}" />
```

### Audio Session, Interruptions and Audio Focus

On both platforms playback participates in the system's shared audio session:

- **Android** requests audio focus (`AudioAttributes.USAGE_MEDIA` + `AudioFocusRequest`),
  so media volume keys target the right stream and other apps can take over playback.
- **iOS** activates an `AVAudioSession` with the `Playback` category, so audio is not
  muted by the ringer switch.

When another app takes focus, or a call/notification interrupts playback:

- permanent focus loss pauses playback and it stays paused,
- transient loss and interruptions pause playback and resume automatically afterwards,
- "can duck" lowers the native volume to 30% until focus is regained,
- losing the output device (headphones unplugged, Bluetooth disconnected) pauses playback.

Paused/stopped players do not hold the audio session or focus.

### Streaming and Playback Rate

Set `Url` to stream audio instead of loading a bundle file. `Buffered` and `IsBuffering`
let you build a streaming progress UI, and `PositionChanged` fires about 10 times per
second without needing a data binding:

```xml
<AudioPlayer ux:Name="radio" Url="https://example.com/stream.mp3" />

<Button Text="Play">
  <Clicked>
    <Play Target="radio" />
  </Clicked>
</Button>

<Text Value="{Property radio.IsBuffering}" />
<Slider Minimum="0" Maximum="1" Value="{Property radio.Progress}" />
```

Playback rate works on local files on both platforms (Android API 23+). On iOS, streams
keep their pitch when the rate changes; on Android the pitch changes with the rate.

`Balance` is applied through per-channel volume on Android and through pan on iOS local
files. `AVPlayer` has no pan control, so `Balance` has no effect while streaming on iOS.

`Loop` is implemented natively for local files on both platforms (gapless). Streams
restart from the beginning when they end.

### Progress Tracking and Seeking

Bind to progress and duration properties for real-time updates:

```xml
<StackPanel>
  <!-- Progress display -->
  <Text Value="Progress: {Property audioPlayer.Progress}" />
  <Text Value="Position: {Property audioPlayer.Position}s / {Property audioPlayer.Duration}s" />

  <!-- Interactive progress slider -->
  <Slider Value="{Property audioPlayer.Progress}"
          Minimum="0" Maximum="1" />

  <!-- Volume control -->
  <Slider Value="{Property audioPlayer.Volume}"
          Minimum="0" Maximum="1" />
</StackPanel>
```

### Targeting Specific AudioPlayers

Use the `Target` property to choose which AudioPlayer an action controls:

```xml
<!-- Multiple AudioPlayer instances -->
<AudioPlayer ux:Name="musicPlayer" File="music.mp3" />
<AudioPlayer ux:Name="effectPlayer" File="effect.wav" />

<!-- Target a specific player -->
<Button Text="Play Music">
  <Clicked>
    <Play Target="musicPlayer" />
  </Clicked>
</Button>

<Button Text="Play Effect">
  <Clicked>
    <Play Target="effectPlayer" />
  </Clicked>
</Button>

<!-- Without Target, the action searches up the node hierarchy -->
<StackPanel>
  <AudioPlayer ux:Name="player" File="audio.mp3" />
  <Button Text="Play">
    <Clicked>
      <Play /> <!-- Will find the player automatically -->
    </Clicked>
  </Button>
</StackPanel>
```

### AudioPlayer Events

Handle playback events in JavaScript:

```javascript
function onPlaybackStarted(args) {
  console.log("Playback started: " + args.filePath);
  console.log("Duration: " + args.duration + "s");
}

function onPlaybackStopped(args) {
  console.log("Playback stopped at: " + args.progress);
}

function onPlaybackPaused(args) {
  console.log("Playback paused at: " + args.position + "s");
}

function onPlaybackCompleted(args) {
  console.log("Playback completed");
}

function onPlaybackError(args) {
  console.log("Playback error: " + args.errorMessage);
}

function onProgressChanged(args) {
  console.log("Progress: " + args.progress);
}
```

### JavaScript API

`AudioPlayer` exposes methods to JavaScript. Call them on a `ux:Name`d player:

```javascript
audioPlayer.play(); // or resume()
audioPlayer.pause();
audioPlayer.stop();
audioPlayer.seek(30.0); // seconds
audioPlayer.setVolume(0.5);
audioPlayer.setRate(1.25);

var duration = audioPlayer.getDuration();
var position = audioPlayer.getPosition();
var buffered = audioPlayer.getBuffered();
var buffering = audioPlayer.isBuffering();
var state = audioPlayer.getState(); // "Stopped" | "Playing" | "Paused" | "Loading" | "Error"
```

Properties are not assigned directly from JavaScript. For live values in UX use
`{Property player.Position}`, `{Property player.Progress}` and so on; for values in
JavaScript call the getters above.

Events are bound in UX, not with `.add()`:

```xml
<AudioPlayer ux:Name="audioPlayer" File="music.mp3"
             PositionChanged="{onPosition}" />
```

```javascript
function onPosition(args) {
  console.log(args.position + " / " + args.duration);
}
```

## Audio Recording

### AudioRecorder

The `AudioRecorder` class provides comprehensive audio recording functionality:

```xml
<AudioRecorder ux:Name="recorder"
               SampleRate="44100"
               BitRate="128000"
               Channels="1"
               Format="M4A"
               Quality="Medium"
               RecordingStarted="{onRecordingStarted}"
               RecordingStopped="{onRecordingStopped}"
               RecordingError="{onRecordingError}"
               PermissionChanged="{onPermissionChanged}" />
```

### Recording Controls

Use trigger actions to control recording:

```xml
<!-- Start Recording -->
<Button Text="Start Recording">
  <Clicked>
    <StartRecording />
  </Clicked>
</Button>

<!-- Stop Recording -->
<Button Text="Stop Recording">
  <Clicked>
    <StopRecording />
  </Clicked>
</Button>

<!-- Pause Recording (Android N+ / iOS) -->
<Button Text="Pause Recording">
  <Clicked>
    <PauseRecording />
  </Clicked>
</Button>

<!-- Resume Recording -->
<Button Text="Resume Recording">
  <Clicked>
    <ResumeRecording />
  </Clicked>
</Button>

<!-- Request Permission -->
<Button Text="Request Permission">
  <Clicked>
    <RequestRecordingPermission />
  </Clicked>
</Button>
```

### Targeting Specific Recorders

Use the `Source` property to target specific AudioRecorder instances:

```xml
<!-- Multiple AudioRecorder instances -->
<AudioRecorder ux:Name="highQualityRecorder" Quality="High" />
<AudioRecorder ux:Name="lowQualityRecorder" Quality="Low" />

<!-- Target specific recorder using Source property -->
<Button Text="Start HQ Recording">
  <Clicked>
    <StartRecording Source="highQualityRecorder" />
  </Clicked>
</Button>

<Button Text="Start LQ Recording">
  <Clicked>
    <StartRecording Source="lowQualityRecorder" />
  </Clicked>
</Button>

<!-- Without Source property, searches up node hierarchy -->
<StackPanel>
  <AudioRecorder ux:Name="recorder" />
  <Button Text="Start Recording">
    <Clicked>
      <StartRecording /> <!-- Will find recorder automatically -->
    </Clicked>
  </Button>
</StackPanel>
```

### Recording Levels, Duration and Limits

While recording, `LevelChanged` fires about 20 times per second with the input peak
(`Level`, 0..1) and the position (`Position`, seconds). `RecordingDuration` and
`RecordingLevel` are also exposed as properties for simple bindings.

`MaxDuration` (seconds) and `MaxFileSize` (bytes) stop the recording automatically when
reached; `RecordingCompleted` then fires in addition to `RecordingStopped`.

```xml
<AudioRecorder ux:Name="recorder"
               MaxDuration="60"
               Source="VoiceRecognition"
               LevelChanged="{onLevelChanged}"
               RecordingCompleted="{onRecordingCompleted}" />

<!-- Scrolling level meter, drawn by the package -->
<Waveform Recorder="recorder" Height="48" BarColor="#0a0" />
<Text Value="{Property recorder.RecordingDuration}" />
```

```javascript
function onLevelChanged(args) {
  console.log(args.level + " at " + args.position + " s");
}

function onRecordingCompleted(args) {
  console.log("Reached the limit: " + args.filePath);
}
```

`Waveform` also works with a player (`Player="player"`, requires `SampleConfig`, Android
only) and can be filled manually with `Push`, `SetValues` and `Clear`. Set `File` or
`FilePath` on it to draw the envelope of an existing recording or bundled file;
`AudioWaveform.Extract` exposes the same envelope to C#. See the
[Docs/Guide.md](Docs/Guide.md) for the full control reference.

Level metering reads the platform's own recorder (`getMaxAmplitude` on Android,
`peakPowerForChannel` on iOS), so it does not open a second microphone capture. It works
on every device, unlike the `SampleConfig` sampling path.

### Configuration Options

#### Audio Formats

- `WAV` - Uncompressed audio (iOS only, falls back to AAC on Android)
- `AAC` - Advanced Audio Coding
- `MP3` - MPEG-1 Audio Layer III (falls back to AAC on mobile)
- `M4A` - MPEG-4 Audio (recommended)

#### Quality Presets

- `Low` - 22050 Hz, 64 kbps, Mono
- `Medium` - 44100 Hz, 128 kbps, Mono (default)
- `High` - 48000 Hz, 256 kbps, Stereo
- `Custom` - Use custom settings

#### Audio Sources

- `Default` - The platform default input (the built-in microphone)
- `Microphone` - The built-in microphone
- `VoiceRecognition` - Tuned for speech recognition (iOS: `measurement` mode)
- `VoiceCommunication` - Tuned for calls, usually with echo cancellation (iOS: `voiceChat` mode)
- `Camcorder` - The camera-mounted microphone (iOS: `videoRecording` mode)
- `Unprocessed` - Raw input without platform filtering (Android API 24+)

`MaxDuration` (seconds) and `MaxFileSize` (bytes) are applied when recording starts;
set them to `0` for no limit.

#### Custom Settings

```xml
<AudioRecorder SampleRate="48000"
               BitRate="192000"
               Channels="2"
               Format="M4A"
               Quality="Custom" />
```

### Events

Handle recording events in JavaScript:

```javascript
function onRecordingStarted(args) {
  console.log("Recording started: " + args.filePath);
}

function onRecordingStopped(args) {
  console.log("Recording stopped: " + args.filePath);
}

function onRecordingError(args) {
  console.log("Recording error: " + args.errorMessage);
}

// Periodic input level while recording
function onLevelChanged(args) {
  console.log("Level: " + args.level + " at " + args.position + "s");
}

// The recorder stopped because MaxDuration or MaxFileSize was reached
function onRecordingCompleted(args) {
  console.log("Recording completed: " + args.filePath);
}

// Fired when a microphone permission request completes
function onPermissionChanged(args) {
  console.log("Microphone permission granted: " + args.granted);
}
```

### JavaScript API

Access recorder functionality from JavaScript:

```javascript
// Permission
var granted = recorder.hasPermission();
recorder.requestPermission(); // result arrives through PermissionChanged

// Control
recorder.start();
recorder.pause(); // Android API 24+
recorder.resume();
recorder.stop();

// State
var state = recorder.getState(); // "Stopped" | "Recording" | "Paused"
var duration = recorder.getDuration(); // seconds
var level = recorder.getLevel(); // 0..1
```

## Platform Support

### iOS

- Playback uses `AVAudioPlayer` for local files and `AVPlayer` for streams
- `AVPlayer` has no pan control, so `Balance` is ignored while streaming
- Uses `AVAudioRecorder` for high-quality recording
- Input levels come from `AVAudioRecorder` metering; `MaxDuration` uses `recordForDuration:`
- Supports all audio formats (WAV, AAC, M4A)
- Pause/Resume supported on all iOS versions

### Android

- Playback uses `MediaPlayer` (gapless looping, per-channel volume for balance)
- `Rate` requires Android 6.0 (API 23+); on older versions it stays at 1.0
- Uses `MediaRecorder` for efficient recording
- Input levels come from `MediaRecorder.getMaxAmplitude()`
- `MaxDuration` and `MaxFileSize` use `setMaxDuration` / `setMaxFileSize`
- Supports AAC and M4A formats (WAV/MP3 fall back to AAC)
- Pause/Resume requires Android N+ (API 24+)
- Requires the `RECORD_AUDIO` permission and, for `Url` streaming, `INTERNET`
  (both added automatically by the package)

## Permissions

### iOS

The default `Info.plist` template already includes `NSMicrophoneUsageDescription`, so
no extra configuration is required. To replace the default text, set it in your app's
`.unoproj`:

```json
{
  "ios": {
    "plist": {
      "NSMicrophoneUsageDescription": "This app needs access to the microphone to record audio."
    }
  }
}
```

### Android

Required permissions are automatically added:

- `android.permission.RECORD_AUDIO`

Recordings are written to the app-specific external files directory, so no storage
permission is required.

## File Storage

### iOS

Recordings are saved to:

```
Documents/Recordings/recording_[timestamp].ext
```

### Android

Recordings are saved to:

```
External Files Dir/Music/Recordings/recording_[timestamp].ext
```

## Error Handling

Common error scenarios:

- **Permission denied**: Request microphone permission
- **Storage full**: Check available storage space
- **Format not supported**: Use recommended M4A format
- **Recording in progress**: Stop current recording before starting new one

## Best Practices

1. **Check permissions**: Always verify microphone permission before recording
2. **Use M4A format**: Best compatibility across platforms
3. **Handle errors**: Implement error callbacks for robust apps
4. **Clean up**: Stop recording when app goes to background
5. **Test on device**: Recording doesn't work in simulators/emulators

## Examples

- `Examples/AudioMeteringShowcase.ux1` - Playback controls, streaming state and a recording level meter

### Basic AudioPlayer Example

```xml
<StackPanel>
  <AudioPlayer ux:Name="player" File="music.mp3" />
  <Button Text="Play"><Clicked><Play Target="player" /></Clicked></Button>
  <Button Text="Pause"><Clicked><Pause Target="player" /></Clicked></Button>
  <Button Text="Stop"><Clicked><Stop Target="player" /></Clicked></Button>
  <Slider Value="{Property player.Progress}" Minimum="0" Maximum="1" />
</StackPanel>
```

### Basic AudioRecorder Example

```xml
<StackPanel>
  <AudioRecorder ux:Name="recorder" Quality="Medium" />
  <Button Text="Start"><Clicked><StartRecording /></Clicked></Button>
  <Button Text="Stop"><Clicked><StopRecording /></Clicked></Button>
</StackPanel>
```

### Multiple AudioPlayers Example

```xml
<StackPanel>
  <AudioPlayer ux:Name="musicPlayer" File="music.mp3" />
  <AudioPlayer ux:Name="soundPlayer" File="sound.wav" />

  <Button Text="Play Music"><Clicked><Play Target="musicPlayer" /></Clicked></Button>
  <Button Text="Play Sound"><Clicked><Play Target="soundPlayer" /></Clicked></Button>
</StackPanel>
```

### Multiple Recorders Example

```xml
<StackPanel>
  <AudioRecorder ux:Name="hqRecorder" Quality="High" />
  <AudioRecorder ux:Name="lqRecorder" Quality="Low" />

  <Button Text="Start HQ"><Clicked><StartRecording Source="hqRecorder" /></Clicked></Button>
  <Button Text="Start LQ"><Clicked><StartRecording Source="lqRecorder" /></Clicked></Button>
</StackPanel>
```

## Limitations

### AudioPlayer

- Desktop platform has limited functionality (no seeking, basic progress simulation)
- Some audio formats may not be supported on all platforms
- Real-time progress updates depend on platform capabilities
- `Rate` is ignored below Android 6.0 (API 23)
- `Balance` has no effect while streaming on iOS (`AVPlayer` has no pan control)
- Looping streams restart through the completion path, so they are not gapless; only local
  files loop natively
- Stream load errors are only reported while polling during playback; a failure before
  playback starts can stay silent until you press play

### AudioRecorder

- Desktop platforms not yet supported for recording
- MP3 recording not natively supported (falls back to AAC)
- WAV recording on Android is still encoded as AAC, so the file has a `.wav` name but
  AAC content; real PCM/WAV output is not implemented yet
- `Unprocessed` (Android) falls back to the microphone below API 24
- Pause/Resume on Android requires API 24+
- Level metering emits about 20 updates per second; the `SampleConfig` sampling path is
  separate and still opens its own capture
- Recording quality depends on device microphone capabilities

### Waveforms

- `Waveform` draws a **peak envelope**: one value per bar, not a sample-accurate trace.
  It is designed for the scrolling voice-memo look, not for a zoomed-in audio editor.
- Live **recording** metering (`LevelChanged`, `Waveform Recorder="..."`) works on both
  platforms, but it shows the input level rather than the shape of the waveform.
- Live **playback** sampling (`Waveform Player="..."`, `AudioPlayer.AudioSampleReceived`)
  is Android only. It also needs a `SampleConfig` child and a `RECORD_AUDIO` permission
  granted at runtime, because it is built on Android's `Visualizer`. It delivers nothing
  on iOS.
- `SampleConfig` sampling is separate from level metering: on Android recording it opens
  its own microphone capture, which some devices do not allow at the same time as
  `MediaRecorder`.
- `AudioSample.GetFloat32Samples()` is not reliable yet: it converts the 32-bit pattern
  numerically instead of reinterpreting it. Android sampling always emits `Int16`, so
  this only matters if you construct `Float32` samples yourself.
- `AudioWaveform.Extract` decodes the **whole file** on a background thread. It needs the
  track to report a duration, works on local files and bundled files only (not remote
  URLs), and returns at most 512 bars.
- `AudioWaveform` is a C# API. It is not exposed to JavaScript yet.

## Future enhancements

These are the natural next steps; none of them are implemented yet.

- **Live playback visualization on iOS.** Local playback uses `AVAudioPlayer`, which does
  not expose decoded audio. Moving it to `AVAudioEngine` with an `AVAudioPlayerNode` and a
  tap on the mixer would make `AudioSampleReceived` and `Waveform Player="..."` work on
  iOS as well.
- **Sample data in JavaScript.** `AudioSampleEventArgs` currently serializes only
  aggregates (`peakAmplitude`, `rmsAmplitude`). Emitting a downsampled envelope, or a
  `getWaveform(bars)` script method that returns a JS array, would let pure-JS UI draw
  real waveforms.
- **Incremental and remote waveform extraction.** Extract envelopes in chunks while
  reporting progress, cache them next to the recording, and support remote URLs by
  downloading first. Also makes very long files cheap to render.
- **Real PCM/WAV recording on Android.** An `AudioRecord` writer (and `Opus`/`OGG`
  support on API 29+) would make `Format="WAV"` produce an actual WAV file.
- **Input processing controls.** Echo cancellation, noise suppression and automatic gain
  control toggles, plus record-to-memory instead of a file.
- **Recording playback convenience.** A `FileSource` for local paths, so recordings can be
  given to `AudioPlayer.File` directly. Today use `Url="file:///..."`.
- **`FuseJS/Audio` script module.** `playSound` returning a stoppable handle, waveform
  extraction and metering exposed to JavaScript.
- **Better streaming behaviour.** Gapless native looping for streams, seek-completion
  notifications, and reporting `AVPlayerItem` failures as soon as they happen (today they
  are only detected by polling during playback).
- **Recording pause on older Android.** A fallback recorder for API levels below 24.
- **Audio effects.** Equalizer, bass boost and loudness controls on Android; `AVAudioUnitEQ`
  on iOS.
- **Manual test pages.** Playback, recording and waveform pages in the manual testing app
  so these paths can be verified on devices.

## Contributing

Contributions are welcome! Please ensure:

- Code follows Fuse coding standards
- Platform-specific implementations are properly isolated
- Examples and documentation are updated
- Permissions are correctly configured
