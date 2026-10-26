using Uno;
using Uno.UX;
using Fuse.Scripting;

namespace Fuse
{
	/**
		JavaScript access to @AudioPlayer.

		Properties are not exposed directly to JavaScript; use these methods instead, and
		use `{Property player.X}` bindings when you need live values in UX.
	*/
	public partial class AudioPlayer
	{
		static AudioPlayer()
		{
			ScriptClass.Register(typeof(AudioPlayer),
				new ScriptMethod<AudioPlayer>("play", play),
				new ScriptMethod<AudioPlayer>("resume", resume),
				new ScriptMethod<AudioPlayer>("pause", pause),
				new ScriptMethod<AudioPlayer>("stop", stop),
				new ScriptMethod<AudioPlayer>("seek", seek),
				new ScriptMethod<AudioPlayer>("setVolume", setVolume),
				new ScriptMethod<AudioPlayer>("setRate", setRate),
				new ScriptMethod<AudioPlayer>("getVolume", getVolume),
				new ScriptMethod<AudioPlayer>("getDuration", getDuration),
				new ScriptMethod<AudioPlayer>("getPosition", getPosition),
				new ScriptMethod<AudioPlayer>("getBuffered", getBuffered),
				new ScriptMethod<AudioPlayer>("isBuffering", isBuffering),
				new ScriptMethod<AudioPlayer>("getState", getState));
		}

		/** Starts or resumes playback. @scriptmethod play() */
		static void play(AudioPlayer player)
		{
			player.Resume();
		}

		/** Starts or resumes playback. @scriptmethod resume() */
		static void resume(AudioPlayer player)
		{
			player.Resume();
		}

		/** Pauses playback, keeping the position. @scriptmethod pause() */
		static void pause(AudioPlayer player)
		{
			player.Pause();
		}

		/** Stops playback and returns to the beginning. @scriptmethod stop() */
		static void stop(AudioPlayer player)
		{
			player.Stop();
		}

		/** Seeks to a position in seconds. @scriptmethod seek(positionInSeconds) */
		static void seek(AudioPlayer player, object[] args)
		{
			if (args.Length < 1)
			{
				Fuse.Diagnostics.UserError("seek takes 1 argument (position in seconds)", player);
				return;
			}

			player.Position = Marshal.ToDouble(args[0]);
		}

		/** Sets the volume from 0 to 1. @scriptmethod setVolume(volume) */
		static void setVolume(AudioPlayer player, object[] args)
		{
			if (args.Length < 1)
			{
				Fuse.Diagnostics.UserError("setVolume takes 1 argument (0 to 1)", player);
				return;
			}

			player.Volume = (float)Marshal.ToDouble(args[0]);
		}

		/** Sets the playback rate (0.25 to 4). @scriptmethod setRate(rate) */
		static void setRate(AudioPlayer player, object[] args)
		{
			if (args.Length < 1)
			{
				Fuse.Diagnostics.UserError("setRate takes 1 argument (0.25 to 4)", player);
				return;
			}

			player.Rate = Marshal.ToDouble(args[0]);
		}

		/** Gets the volume, 0 to 1. @scriptmethod getVolume() */
		static object getVolume(Context c, AudioPlayer player, object[] args)
		{
			return (double)player.Volume;
		}

		/** Gets the duration in seconds, 0 until the source is loaded. @scriptmethod getDuration() */
		static object getDuration(Context c, AudioPlayer player, object[] args)
		{
			return player.Duration;
		}

		/** Gets the current position in seconds. @scriptmethod getPosition() */
		static object getPosition(Context c, AudioPlayer player, object[] args)
		{
			return player.Position;
		}

		/** Gets how many seconds are buffered (streams). @scriptmethod getBuffered() */
		static object getBuffered(Context c, AudioPlayer player, object[] args)
		{
			return player.Buffered;
		}

		/** Gets whether the stream is waiting for data. @scriptmethod isBuffering() */
		static object isBuffering(Context c, AudioPlayer player, object[] args)
		{
			return player.IsBuffering;
		}

		/** Gets the playback state as a string: "Stopped", "Playing", "Paused", "Loading" or "Error". @scriptmethod getState() */
		static object getState(Context c, AudioPlayer player, object[] args)
		{
			switch (player.CurrentState)
			{
				case PlaybackState.Playing: return "Playing";
				case PlaybackState.Paused: return "Paused";
				case PlaybackState.Loading: return "Loading";
				case PlaybackState.Error: return "Error";
				default: return "Stopped";
			}
		}
	}
}
