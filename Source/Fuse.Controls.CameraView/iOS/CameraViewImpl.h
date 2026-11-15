#ifndef CameraView_h
#define CameraView_h

#include <AVFoundation/AVFoundation.h>
#include <Foundation/Foundation.h>
#include <UIKit/UIKit.h>

#include "CameraPreview.h"
#include "RecordingSession.h"

namespace fcv {
typedef void *disposable_t;


enum CaptureMode {
  CAPTURE_MODE_PHOTO = 0,
  CAPTURE_MODE_VIDEO = 1,
};

enum CaptureState {
  CAPTURE_STATE_IDLE = 0,
  CAPTURE_STATE_CAPTURING_PHOTO = 1,
  CAPTURE_STATE_RECORDING_VIDEO = 2,
};

enum CameraFacing {
  CAMERA_FACING_FRONT = 0,
  CAMERA_FACING_BACK = 1,
};

enum FlashMode {
  FLASH_MODE_AUTO = AVCaptureFlashModeAuto,
  FLASH_MODE_ON = AVCaptureFlashModeOn,
  FLASH_MODE_OFF = AVCaptureFlashModeOff,
};

struct CameraInfo {
  CaptureMode captureMode;
  FlashMode flashMode;
  CameraFacing cameraFacing;
  NSArray<NSNumber *> *supportedFlashModes;
  NSArray<NSValue *> *photoResolutions;
  float zoom;
  bool torchOn;
  float exposureCompensation;
  NSString *lensId;
  NSString *whiteBalance;
  NSString *focusMode;
  NSString *mirrorMode;
};

struct CameraCapabilities {
  bool zoomSupported;
  float minZoom;
  float maxZoom;
  bool torchSupported;
  float minExposureCompensation;
  float maxExposureCompensation;
  float exposureCompensationStep;
  bool manualExposureSupported;
  float minIso;
  float maxIso;
  float minShutterSeconds;
  float maxShutterSeconds;
  NSArray<NSNumber *> *supportedFlashModes;
  NSArray<NSValue *> *photoResolutions;
  NSArray<NSNumber *> *supportedFacings;
  bool manualWhiteBalanceSupported;
};

struct VideoOptions {
  int width;
  int height;
  int frameRate;
  int bitRate;
  bool audioEnabled;
  bool stabilizationEnabled;
};


struct AVState {
		CameraPreview* preview;
		AVCaptureSession* session;
		AVCaptureDeviceInput* deviceInput;
		AVCaptureDeviceInput* audioDeviceInput;
		AVCapturePhotoOutput* photoOutput;
		AVCaptureMovieFileOutput* movieFileOutput;
		AVCaptureMetadataOutput* metadataOutput;
		id metadataDelegate;
		AVCaptureVideoDataOutput* videoDataOutput;
		id videoDataDelegate;
		NSString* presetBeforeVideoData;
		NSString* whiteBalanceMode;
		float whiteBalanceKelvin;
		float whiteBalanceTint;
		NSString* focusMode;
		NSString* mirrorMode;
		id errorCallback;
		NSMutableArray* pendingPhotoDelegates;
		RecordingSession* recordingSession;
		dispatch_queue_t queue;
		id sessionRuntimeErrorObserver;
		id sessionInterruptedObserver;
		id sessionInterruptionEndedObserver;
	};

	struct CameraView {
		AVState* avState;
		CaptureMode captureMode;
		CaptureState captureState;
		CameraFacing cameraFacing;
		VideoOptions videoOptions;
	};


disposable_t loadCameraView(CameraPreview *cameraPreview,
                            void (^onResolve)(void *),
                            void (^onReject)(NSString *));
void setCaptureMode(CameraView *cameraView, int captureMode,
                    void (^onResolve)(int), void (^onReject)(NSString *));
void capturePhoto(CameraView *cameraView, void (^onResolve)(id, int),
                  void (^onReject)(NSString *));
void setPhotoResolution(CameraView *cameraView, int width, int height,
                        void (^onResolve)(void), void (^onReject)(NSString *));
void startRecording(CameraView *cameraView,
                    void (^onResolve)(RecordingSession *),
                    void (^onReject)(NSString *));
void setCameraFacing(CameraView *cameraView, int cameraFacing,
                     void (^onResolve)(int), void (^onReject)(NSString *));
void setCameraFocusPoint(CameraView *cameraView, double x, double y,
                         int cameraWidth, int cameraHeight, int isFocusLocked,
                         void (^onResolve)(id), void (^onReject)(NSString *));
void setFlashMode(CameraView *cameraView, int flashMode, void (^onResolve)(int),
                  void (^onReject)(NSString *));
void getCameraInfo(CameraView *cameraView, void (^callback)(CameraInfo));
void getCameraCapabilities(CameraView *cameraView,
                           void (^callback)(CameraCapabilities));
void setVideoOptions(CameraView *cameraView, VideoOptions options,
                     void (^onResolve)(bool), void (^onReject)(NSString *));
void setZoom(CameraView *cameraView, float zoom, void (^onResolve)(float),
             void (^onReject)(NSString *));
void getZoom(CameraView *cameraView, void (^onResolve)(float),
             void (^onReject)(NSString *));
void setTorchMode(CameraView *cameraView, bool on, void (^onResolve)(bool),
                  void (^onReject)(NSString *));
void isTorchOn(CameraView *cameraView, void (^onResolve)(bool),
               void (^onReject)(NSString *));
void setExposureCompensation(CameraView *cameraView, float value,
                             void (^onResolve)(float),
                             void (^onReject)(NSString *));
void getExposureCompensation(CameraView *cameraView, void (^onResolve)(float),
                             void (^onReject)(NSString *));
void getAvailableLenses(CameraView *cameraView,
                        void (^callback)(NSArray<NSString *> *,
                                         NSArray<NSNumber *> *,
                                         NSArray<NSString *> *));
void setCameraLens(CameraView *cameraView, NSString *lensId,
                   void (^onResolve)(NSString *), void (^onReject)(NSString *));
void setManualExposure(CameraView *cameraView, float iso, double shutterSeconds,
                       void (^onResolve)(bool, float, float),
                       void (^onReject)(NSString *));
void setAutoExposure(CameraView *cameraView,
                     void (^onResolve)(bool, float, float),
                     void (^onReject)(NSString *));
void getManualExposure(CameraView *cameraView,
                       void (^onResolve)(bool, float, float),
                       void (^onReject)(NSString *));
void scanBarcode(CameraView *cameraView, NSArray *formats,
                 void (^onResolve)(NSString *, NSString *),
                 void (^onReject)(NSString *));
void setWhiteBalance(CameraView *cameraView, NSString *mode,
                     void (^onResolve)(NSString *),
                     void (^onReject)(NSString *));
void getWhiteBalance(CameraView *cameraView, void (^onResolve)(NSString *mode));
void setWhiteBalanceTemperature(CameraView *cameraView, float kelvin,
                                float tint,
                                void (^onResolve)(bool, float, float),
                                void (^onReject)(NSString *));
void getWhiteBalanceTemperature(CameraView *cameraView,
                                void (^onResolve)(bool, float, float));
void setFocusMode(CameraView *cameraView, NSString *mode,
                  void (^onResolve)(NSString *), void (^onReject)(NSString *));
void getFocusMode(CameraView *cameraView, void (^onResolve)(NSString *mode));
void setMirrorMode(CameraView *cameraView, NSString *mode,
                   void (^onResolve)(NSString *), void (^onReject)(NSString *));
void getMirrorMode(CameraView *cameraView, void (^onResolve)(NSString *mode));
void startErrorMonitoring(CameraView *cameraView,
                          void (^onEvent)(NSString *, NSString *, NSString *),
                          void (^onStarted)(NSString *error));
void stopErrorMonitoring(CameraView *cameraView,
                         void (^onStopped)(bool wasMonitoring));
void startFaceDetection(CameraView *cameraView,
                        void (^onFace)(int, float, float, float, float, float, float),
                        void (^onFrame)(void),
                        void (^onStarted)(NSString *error));
void stopFaceDetection(CameraView *cameraView,
                       void (^onStopped)(bool wasDetecting));
void startBarcodeScanning(CameraView *cameraView, NSArray *formats,
                          void (^onDetected)(NSString *, NSString *),
                          void (^onStarted)(NSString *error));
void stopBarcodeScanning(CameraView *cameraView,
                         void (^onStopped)(bool wasScanning));
void startFrameAnalysis(CameraView *cameraView, int maxFps, int resolutionWidth,
                        int resolutionHeight, int lumaWidth, int lumaHeight,
                        void (^onStatistics)(double, double, double, double, double,
                                             double, double, double),
                        void (^onStarted)(id statistics),
                        void (^onError)(NSString *));
void stopFrameAnalysis(CameraView *cameraView, void (^onStopped)(bool));
NSData *statisticsHistogram(void *statistics);
NSData *statisticsLuma(void *statistics);
int statisticsLumaWidth(void *statistics);
int statisticsLumaHeight(void *statistics);
void setOverlayOptions(CameraView *cameraView, double zebra, double peaking,
                       void (^onResolved)(double, double),
                       void (^onError)(NSString *));
void dispose(disposable_t disposable);
} // namespace fcv

#endif
