using Uno;
using Uno.Collections;

namespace Fuse.Controls
{
	/**
		A face found by `CameraView.startFaceDetection()`.

		The bounds are normalized to the camera preview (0 to 1), with the origin
		in the top left corner of the preview as it is displayed.
	*/
	public class DetectedFace
	{
		public const string IdName = "id";
		public const string XName = "x";
		public const string YName = "y";
		public const string WidthName = "width";
		public const string HeightName = "height";
		public const string RollName = "roll";
		public const string YawName = "yaw";

		/** The tracking id of the face, or -1 when the platform does not track faces. */
		public readonly int Id;
		public readonly float X;
		public readonly float Y;
		public readonly float Width;
		public readonly float Height;
		/** Head rotation around the view axis, in degrees. */
		public readonly float Roll;
		/** Head rotation around the vertical axis, in degrees. */
		public readonly float Yaw;

		public DetectedFace(int id, float x, float y, float width, float height, float roll, float yaw)
		{
			Id = id;
			X = x;
			Y = y;
			Width = width;
			Height = height;
			Roll = roll;
			Yaw = yaw;
		}
	}

	/**
		Collects the faces of a single frame and reports them as one array.
	*/
	internal class FaceCollector
	{
		readonly List<DetectedFace> _faces = new List<DetectedFace>();
		readonly Action<DetectedFace[]> _onFaces;

		public FaceCollector(Action<DetectedFace[]> onFaces)
		{
			_onFaces = onFaces;
		}

		public void OnFace(int id, float x, float y, float width, float height, float roll, float yaw)
		{
			_faces.Add(new DetectedFace(id, x, y, width, height, roll, yaw));
		}

		public void OnFrame()
		{
			var faces = _faces.ToArray();
			_faces.Clear();
			_onFaces(faces);
		}
	}
}
