using Uno;
using Uno.Compiler.ExportTargetInterop;
using Uno.Threading;

namespace Fuse.Controls.Android
{
	extern(ANDROID) internal static class CameraLoader
	{
		class CameraPromise : Promise<Camera>
		{
			CameraFacing _facing;
			int _cameraId;

			public CameraPromise(CameraFacing facing, int cameraId)
			{
				_facing = facing;
				_cameraId = cameraId;
				Load(cameraId, (int)facing, OnLoaded, OnRejected);
			}

			void OnLoaded(Java.Object session)
			{
				var c = new Camera(session, _cameraId, _facing);
				if (!_cancelled)
					Resolve(c);
				else
					c.Dispose();
			}

			void OnRejected(string msg)
			{
				if (!_cancelled)
					Reject(new Exception(msg));
			}

			bool _cancelled = false;
			public override void Cancel(bool shutdownGracefully = false)
			{
				_cancelled = true;
			}
		}

		class LensPromise : Promise<Camera>
		{
			string _lensId;

			public LensPromise(string lensId)
			{
				_lensId = lensId;
				LoadLens(lensId, OnLoaded, OnRejected);
			}

			void OnLoaded(Java.Object session, int cameraId, int facing)
			{
				var c = new Camera(session, cameraId, (CameraFacing)facing);
				if (!_cancelled)
					Resolve(c);
				else
					c.Dispose();
			}

			void OnRejected(string msg)
			{
				if (!_cancelled)
					Reject(new Exception(msg));
			}

			bool _cancelled = false;
			public override void Cancel(bool shutdownGracefully = false)
			{
				_cancelled = true;
			}
		}

		public static Future<Camera> Load(CameraFacing facing)
		{
			int cameraId;
			if (facing.TryGetCameraId(out cameraId))
				return new CameraPromise(facing, cameraId);
			else
			{
				var p = new Promise<Camera>();
				p.Reject(new Exception("Unsupported camerafacing: " + facing.ToString()));
				return p;
			}
		}

		public static Future<Camera> LoadLens(string lensId)
		{
			return new LensPromise(lensId);
		}

		public static CameraLens[] GetAvailableLenses()
		{
			var count = GetCameraCount();
			var ids = new string[count];
			var facings = new int[count];
			var names = new string[count];
			GetCameraLenses(ids, facings, names);

			var result = new CameraLens[count];
			for (var i = 0; i < count; i++)
				result[i] = new CameraLens(ids[i], (CameraFacing)facings[i], names[i]);

			return result;
		}

		[Foreign(Language.Java)]
		static void Load(int cameraId, int facing, Action<Java.Object> resolve, Action<string> reject)
		@{
			try {
				com.fuse.controls.cameraview.CameraXSession.open(
					com.fuse.Activity.getRootActivity(),
					Integer.toString(cameraId),
					facing,
					true,
					new com.fuse.controls.cameraview.CameraXSession.OpenCallback() {
						public void onOpened(com.fuse.controls.cameraview.CameraXSession session) {
							resolve.run(session);
						}
						public void onError(String message) {
							reject.run(message);
						}
					});
			} catch (Exception e) {
				reject.run(e.getMessage());
			}
		@}

		[Foreign(Language.Java)]
		static void LoadLens(string lensId, Action<Java.Object,int,int> resolve, Action<string> reject)
		@{
			try {
				final int cameraId = Integer.parseInt(lensId);
				android.hardware.camera2.CameraManager manager =
					(android.hardware.camera2.CameraManager) com.fuse.Activity.getRootActivity()
						.getSystemService(android.content.Context.CAMERA_SERVICE);
				android.hardware.camera2.CameraCharacteristics characteristics =
					manager.getCameraCharacteristics(lensId);
				Integer lensFacing = characteristics.get(
					android.hardware.camera2.CameraCharacteristics.LENS_FACING);

				final int facing = (lensFacing != null
					&& lensFacing == android.hardware.camera2.CameraMetadata.LENS_FACING_FRONT) ? 1 : 0;

				com.fuse.controls.cameraview.CameraXSession.open(
					com.fuse.Activity.getRootActivity(),
					lensId,
					facing,
					false,
					new com.fuse.controls.cameraview.CameraXSession.OpenCallback() {
						public void onOpened(com.fuse.controls.cameraview.CameraXSession session) {
							resolve.run(session, cameraId, facing);
						}
						public void onError(String message) {
							reject.run(message);
						}
					});
			} catch (Exception e) {
				reject.run(e.getMessage());
			}
		@}

		[Foreign(Language.Java)]
		static int GetCameraCount()
		@{
			try {
				android.hardware.camera2.CameraManager manager =
					(android.hardware.camera2.CameraManager) com.fuse.Activity.getRootActivity()
						.getSystemService(android.content.Context.CAMERA_SERVICE);
				int count = 0;
				for (String id : manager.getCameraIdList()) {
					android.hardware.camera2.CameraCharacteristics characteristics =
						manager.getCameraCharacteristics(id);
					Integer lensFacing = characteristics.get(
						android.hardware.camera2.CameraCharacteristics.LENS_FACING);
					if (lensFacing != null
						&& (lensFacing == android.hardware.camera2.CameraMetadata.LENS_FACING_BACK
							|| lensFacing == android.hardware.camera2.CameraMetadata.LENS_FACING_FRONT))
						count++;
				}
				return count;
			} catch (Exception e) {
				android.util.Log.d("CameraView", "Failed to enumerate cameras: " + e.getMessage());
				return 0;
			}
		@}

		[Foreign(Language.Java)]
		static void GetCameraLenses(string[] ids, int[] facings, string[] names)
		@{
			try {
				android.hardware.camera2.CameraManager manager =
					(android.hardware.camera2.CameraManager) com.fuse.Activity.getRootActivity()
						.getSystemService(android.content.Context.CAMERA_SERVICE);
				int index = 0;
				for (String id : manager.getCameraIdList()) {
					android.hardware.camera2.CameraCharacteristics characteristics =
						manager.getCameraCharacteristics(id);
					Integer lensFacing = characteristics.get(
						android.hardware.camera2.CameraCharacteristics.LENS_FACING);
					if (lensFacing == null)
						continue;

					boolean isFront = lensFacing == android.hardware.camera2.CameraMetadata.LENS_FACING_FRONT;
					boolean isBack = lensFacing == android.hardware.camera2.CameraMetadata.LENS_FACING_BACK;
					if (!isFront && !isBack)
						continue;

					float[] focalLengths = characteristics.get(
						android.hardware.camera2.CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS);
					String name = (isFront ? "Front" : "Back") + " camera " + id;
					if (focalLengths != null && focalLengths.length > 0)
						name += String.format(java.util.Locale.US, " (%.1fmm)", focalLengths[0]);

					ids.set(index, id);
					facings.set(index, isFront ? 1 : 0);
					names.set(index, name);
					index++;
				}
			} catch (Exception e) {
				android.util.Log.d("CameraView", "Failed to enumerate lenses: " + e.getMessage());
			}
		@}
	}

	extern(ANDROID) static class CameraFacingExtension
	{
		public static bool TryGetCameraId(this CameraFacing cameraFacing, out int cameraId)
		{
			cameraId = GetCameraId((int)cameraFacing);
			return cameraId > -1;
		}

		[Foreign(Language.Java)]
		static int GetCameraId(int facing)
		@{
			try {
				android.hardware.camera2.CameraManager manager =
					(android.hardware.camera2.CameraManager) com.fuse.Activity.getRootActivity()
						.getSystemService(android.content.Context.CAMERA_SERVICE);

				int wanted = (facing == 0)
					? android.hardware.camera2.CameraMetadata.LENS_FACING_BACK
					: android.hardware.camera2.CameraMetadata.LENS_FACING_FRONT;

				for (String id : manager.getCameraIdList()) {
					android.hardware.camera2.CameraCharacteristics characteristics =
						manager.getCameraCharacteristics(id);
					Integer lensFacing = characteristics.get(
						android.hardware.camera2.CameraCharacteristics.LENS_FACING);

					if (lensFacing != null && lensFacing == wanted)
						return Integer.parseInt(id);
				}
			} catch (Exception e) {
				android.util.Log.d("CameraView", "Failed to find camera: " + e.getMessage());
			}

			return -1;
		@}
	}
}
