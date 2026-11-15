using Uno;
using Uno.UX;

using Fuse;
using Fuse.Scripting;

namespace Fuse.Controls
{
	public partial class AVPlayerBase
	{
		static AVPlayerBase()
		{
			// Registered on the base type: ScriptClass lookup walks up the type hierarchy,
			// so both `MediaPlayer` and any UX subclass get these members.
			ScriptClass.Register(typeof(AVPlayerBase),
				new ScriptMethod<AVPlayerBase>("play", play),
				new ScriptMethod<AVPlayerBase>("pause", pause),
				new ScriptMethod<AVPlayerBase>("stop", stop),
				new ScriptMethod<AVPlayerBase>("seek", seek),
				new ScriptMethod<AVPlayerBase>("setVolume", setVolume),
				new ScriptMethod<AVPlayerBase>("setMuted", setMuted),
				new ScriptMethod<AVPlayerBase>("setPlaybackRate", setPlaybackRate),
				new ScriptMethod<AVPlayerBase>("getDuration", getDuration),
				new ScriptMethod<AVPlayerBase>("getPosition", getPosition),
				new ScriptMethod<AVPlayerBase>("getState", getState));
		}

		/**
			Starts or resumes playback.

			@scriptmethod play()
		*/
		static void play(AVPlayerBase player)
		{
			player.Play();
		}

		/**
			Pauses playback, keeping the current position.

			@scriptmethod pause()
		*/
		static void pause(AVPlayerBase player)
		{
			player.Pause();
		}

		/**
			Stops playback and returns to the beginning.

			@scriptmethod stop()
		*/
		static void stop(AVPlayerBase player)
		{
			player.Stop();
		}

		/**
			Seeks to a position in seconds.

			@scriptmethod seek(seconds)
		*/
		static void seek(AVPlayerBase player, object[] args)
		{
			if (!CheckArgumentCount(player, "seek", args, 1))
				return;

			player.Seek(ToDouble(args[0]));
		}

		/**
			Sets the volume, from 0.0 (silent) to 1.0 (full).

			@scriptmethod setVolume(volume)
		*/
		static void setVolume(AVPlayerBase player, object[] args)
		{
			if (!CheckArgumentCount(player, "setVolume", args, 1))
				return;

			player.Volume = (float)ToDouble(args[0]);
		}

		/**
			Mutes or unmutes the audio without changing the volume.

			@scriptmethod setMuted(muted)
		*/
		static void setMuted(AVPlayerBase player, object[] args)
		{
			if (!CheckArgumentCount(player, "setMuted", args, 1))
				return;

			player.Muted = ToBool(args[0]);
		}

		/**
			Sets the playback rate multiplier, from 0.25 to 4.0.

			@scriptmethod setPlaybackRate(rate)
		*/
		static void setPlaybackRate(AVPlayerBase player, object[] args)
		{
			if (!CheckArgumentCount(player, "setPlaybackRate", args, 1))
				return;

			player.PlaybackRate = (float)ToDouble(args[0]);
		}

		/**
			Gets the duration of the media in seconds, or 0 while it is not known.

			@scriptmethod getDuration()
		*/
		static object getDuration(Context c, AVPlayerBase player, object[] args)
		{
			if (!CheckArgumentCount(player, "getDuration", args, 0))
				return 0.0;

			return (object)player._duration;
		}

		/**
			Gets the current playback position in seconds.

			@scriptmethod getPosition()
		*/
		static object getPosition(Context c, AVPlayerBase player, object[] args)
		{
			if (!CheckArgumentCount(player, "getPosition", args, 0))
				return 0.0;

			return (object)player._position;
		}

		/**
			Gets the current playback state as one of `"idle"`, `"loading"`, `"ready"`,
			`"playing"`, `"paused"`, `"ended"` or `"failed"`.

			@scriptmethod getState()
		*/
		static object getState(Context c, AVPlayerBase player, object[] args)
		{
			if (!CheckArgumentCount(player, "getState", args, 0))
				return "";

			return (object)StateToString(player.State);
		}

		static bool CheckArgumentCount(AVPlayerBase player, string methodName, object[] args, int expected)
		{
			if (args.Length == expected)
				return true;

			Fuse.Diagnostics.UserError(methodName + " takes " + expected + " argument(s), but "
				+ args.Length + " were supplied", player);
			return false;
		}

		static double ToDouble(object value)
		{
			if (value is double)
				return (double)value;
			if (value is int)
				return (double)(int)value;
			if (value is float)
				return (double)(float)value;
			return 0.0;
		}

		static bool ToBool(object value)
		{
			if (value is bool)
				return (bool)value;
			return false;
		}

		static string StateToString(MediaPlayerState state)
		{
			switch (state)
			{
				case MediaPlayerState.Loading:
					return "loading";
				case MediaPlayerState.Ready:
					return "ready";
				case MediaPlayerState.Playing:
					return "playing";
				case MediaPlayerState.Paused:
					return "paused";
				case MediaPlayerState.Ended:
					return "ended";
				case MediaPlayerState.Failed:
					return "failed";
				default:
					return "idle";
			}
		}
	}
}
