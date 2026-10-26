using Uno;
using Uno.UX;
using Uno.Collections;
using Fuse.Drawing;
using Fuse.Elements;

namespace Fuse.Controls
{
	/**
		A scrolling waveform / level meter.

		The control draws a fixed number of bars and keeps a history of the most recent
		values, with the newest value on the right. Feed it from a recording or from a
		playing source that has sampling enabled:

		```xml
			<AudioRecorder ux:Name="recorder" LevelChanged="{onLevel}" />
			<Waveform Recorder="recorder" Height="60" BarColor="#0a0" />

			<AudioPlayer ux:Name="player" File="music.mp3">
				<SampleConfig />
			</AudioPlayer>
			<Waveform Player="player" Height="60" BarCount="48" Mirrored="false" />
		```

		When `Recorder` is set the control listens to @AudioRecorder.LevelChanged, which works
		on both iOS and Android and does not open a second microphone capture.

		When `Player` is set the control listens to @AudioPlayer.AudioSampleReceived, which
		requires a @SampleConfig child and is currently Android only.

		You can also drive it manually with `Push` or `SetValues`, for example to draw the
		waveform of a recording that has already been made.

		This is a self-contained control: any children declared in UX are replaced by the
		bars.
	*/
	public class Waveform : Panel
	{
		int _barCount = 32;
		float _barGap = 1.0f;
		float4 _barColor = float4(0.1f, 0.75f, 0.35f, 1.0f);
		bool _mirrored = true;

		AudioRecorder _recorder;
		AudioPlayer _player;

		Grid _grid;
		readonly List<Rectangle> _bars = new List<Rectangle>();
		readonly List<SolidColor> _fills = new List<SolidColor>();
		float[] _values;
		int _head;

		// Static waveform extracted from a file
		FileSource _file;
		string _filePath = "";
		float[] _extracted;
		string _extractedKey = "";
		int _extractRequest;

		/** Number of bars shown (default: 32) */
		public int BarCount
		{
			get { return _barCount; }
			set
			{
				var count = Math.Max(1, Math.Min(256, value));
				if (count == _barCount)
					return;

				_barCount = count;
				if (IsRootingCompleted)
				{
					Rebuild();

					// Reuse the extracted envelope, resampled to the new width
					if (_extracted != null)
						SetValues(Resample(_extracted, _barCount));
				}
			}
		}

		/** Space between bars, in points (default: 1) */
		public float BarGap
		{
			get { return _barGap; }
			set
			{
				var gap = Math.Max(0.0f, value);
				if (Math.Abs(gap - _barGap) < 0.001f)
					return;

				_barGap = gap;
				if (_grid != null)
					_grid.CellSpacing = _barGap;
			}
		}

		/** Bar color (default: green) */
		public float4 BarColor
		{
			get { return _barColor; }
			set
			{
				_barColor = value;
				foreach (var fill in _fills)
					fill.Color = _barColor;
			}
		}

		/** Bars grow from the center line when true (default), or from the bottom when false */
		public bool Mirrored
		{
			get { return _mirrored; }
			set
			{
				if (value == _mirrored)
					return;

				_mirrored = value;
				foreach (var bar in _bars)
					bar.Alignment = _mirrored ? Alignment.Center : Alignment.Bottom;
			}
		}

		/** The recorder to follow; subscribes to LevelChanged */
		public AudioRecorder Recorder
		{
			get { return _recorder; }
			set
			{
				if (value == _recorder)
					return;

				if (IsRootingCompleted)
					UnsubscribeRecorder();

				_recorder = value;

				if (IsRootingCompleted)
					SubscribeRecorder();
			}
		}

		/** The player to follow; subscribes to AudioSampleReceived (requires SampleConfig) */
		public AudioPlayer Player
		{
			get { return _player; }
			set
			{
				if (value == _player)
					return;

				if (IsRootingCompleted)
					UnsubscribePlayer();

				_player = value;

				if (IsRootingCompleted)
					SubscribePlayer();
			}
		}

		/** A bundled (or byte-backed) file to extract a static waveform from */
		public FileSource File
		{
			get { return _file; }
			set
			{
				if (value == _file)
					return;

				_file = value;
				if (value != null)
					_filePath = "";

				RefreshStatic();
			}
		}

		/** Path (or `file://` URL) of a file on disk, for example a recording */
		public string FilePath
		{
			get { return _filePath; }
			set
			{
				var path = value ?? "";
				if (path == _filePath)
					return;

				_filePath = path;
				if (path.Length > 0)
					_file = null;

				RefreshStatic();
			}
		}

		protected override void OnRooted()
		{
			base.OnRooted();

			Rebuild();
			RefreshStatic();
			SubscribeRecorder();
			SubscribePlayer();
		}

		protected override void OnUnrooted()
		{
			UnsubscribeRecorder();
			UnsubscribePlayer();

			base.OnUnrooted();
		}

		/** Pushes one value (0..1) into the right edge of the waveform */
		public void Push(float value)
		{
			if (_values == null)
				return;

			_values[_head] = Math.Max(0.0f, Math.Min(1.0f, value));
			_head = (_head + 1) % _values.Length;
			UpdateBars();
		}

		/** Replaces all values; `values[0]` is the left-most bar */
		public void SetValues(float[] values)
		{
			if (_values == null || values == null)
				return;

			for (int i = 0; i < _values.Length; i++)
				_values[i] = 0.0f;

			// Right-align the supplied values so the newest data stays on the right
			var count = Math.Min(values.Length, _values.Length);
			var offset = _values.Length - count;
			for (int i = 0; i < count; i++)
				_values[offset + i] = Math.Max(0.0f, Math.Min(1.0f, values[i]));

			_head = 0;
			UpdateBars();
		}

		/** Resets all bars to zero */
		public void Clear()
		{
			if (_values == null)
				return;

			for (int i = 0; i < _values.Length; i++)
				_values[i] = 0.0f;

			_head = 0;
			UpdateBars();
		}

		void UpdateBars()
		{
			for (int i = 0; i < _bars.Count; i++)
			{
				var value = _values[(_head + i) % _values.Length];
				_bars[i].Height = new Size(value * 100.0f, Unit.Percent);
			}
		}

		void OnLevel(object sender, RecordingLevelEventArgs args)
		{
			Push(args.Level);
		}

		void OnSample(object sender, AudioSampleEventArgs args)
		{
			var sample = args.Sample;
			if (sample == null || sample.ChannelCount < 1 || sample.SampleCount < 1)
				return;

			Push((float)sample.GetPeakAmplitude(0));
		}

		void SubscribeRecorder()
		{
			if (_recorder != null)
				_recorder.LevelChanged += OnLevel;
		}

		void UnsubscribeRecorder()
		{
			if (_recorder != null)
				_recorder.LevelChanged -= OnLevel;
		}

		void SubscribePlayer()
		{
			if (_player != null)
				_player.AudioSampleReceived += OnSample;
		}

		void UnsubscribePlayer()
		{
			if (_player != null)
				_player.AudioSampleReceived -= OnSample;
		}

		// ---- Static waveform ----

		void RefreshStatic()
		{
			if (!IsRootingCompleted)
				return;

			string key;
			if (_file != null)
				key = "file:" + _file.Name;
			else if (!string.IsNullOrEmpty(_filePath))
				key = "path:" + _filePath;
			else
				return;

			if (key == _extractedKey && _extracted != null)
			{
				SetValues(Resample(_extracted, _barCount));
				return;
			}

			_extractedKey = key;

			var request = ++_extractRequest;
			var bars = Math.Max(2, Math.Min(512, _barCount));

			var future = _file != null
				? AudioWaveform.Extract(_file, bars)
				: AudioWaveform.Extract(_filePath, bars);

			future.Then(
				values => OnExtracted(request, values),
				error => OnExtractFailed(request, error));
		}

		void OnExtracted(int request, float[] values)
		{
			if (request != _extractRequest)
				return;

			_extracted = values;
			SetValues(Resample(values, _barCount));
		}

		void OnExtractFailed(int request, Exception error)
		{
			if (request != _extractRequest)
				return;

			Fuse.Diagnostics.UserWarning("Could not extract the waveform: " + error.Message, this);
		}

		static float[] Resample(float[] source, int count)
		{
			var result = new float[count];
			for (int i = 0; i < count; i++)
			{
				var index = (int)((long)i * source.Length / count);
				if (index < 0)
					index = 0;
				if (index >= source.Length)
					index = source.Length - 1;

				result[i] = source[index];
			}

			return result;
		}

		void Rebuild()
		{
			Children.Clear();
			_bars.Clear();
			_fills.Clear();

			_values = new float[Math.Max(1, _barCount)];
			_head = 0;

			_grid = new Grid();
			_grid.RowCount = 1;
			_grid.ColumnCount = _values.Length;
			_grid.CellSpacing = _barGap;
			Children.Add(_grid);

			for (int i = 0; i < _values.Length; i++)
			{
				var fill = new SolidColor(_barColor);
				var bar = new Rectangle();
				bar.Fill = fill;
				bar.Width = new Size(100.0f, Unit.Percent);
				bar.Height = new Size(0.0f, Unit.Percent);
				bar.Alignment = _mirrored ? Alignment.Center : Alignment.Bottom;
				_grid.Children.Add(bar);

				_bars.Add(bar);
				_fills.Add(fill);
			}

			UpdateBars();
		}
	}
}
