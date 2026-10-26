namespace Fuse.Audio
{
	/** Describes how the platform's audio focus changed for this application.

		Audio focus is a shared OS resource: only one app should play media at a time.
		Android reports these changes through `AudioManager.OnAudioFocusChangeListener`,
		while iOS reports an equivalent situation through `AVAudioSessionInterruptionNotification`.
		Both are translated into this enum so the playback policy lives in one place.
	*/
	internal enum AudioFocusChange
	{
		/** Focus was lost permanently. Playback should pause and not resume automatically. */
		Lost = 0,

		/** Focus was lost temporarily (for example an incoming call). Playback should pause and resume later. */
		LostTransient = 1,

		/** Another app is playing something more important. Lower the volume instead of pausing. */
		CanDuck = 2,

		/** Focus was regained. Resume interrupted playback and restore ducked volumes. */
		Gained = 3
	}
}
