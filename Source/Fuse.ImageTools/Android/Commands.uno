using Uno;
using Fuse;
using Fuse.Android.Permissions;
using Fuse.Scripting;

namespace Fuse.ImageTools
{
  // Android permission-gated command wrappers.
  internal abstract extern(Android) class PCommand
  {
    PlatformPermission[] _requiredPermissions;

    public PCommand(PlatformPermission[] requiredPermissions)
    {
      _requiredPermissions = requiredPermissions;
    }

    public static PlatformPermission[] ImagePermissions
    {
      get
      {
        return AndroidProperties.BuildVersion >= 33 ?
          new PlatformPermission[]
          {
            Permissions.Android.READ_MEDIA_IMAGES, Permissions.Android.READ_MEDIA_VIDEO, Permissions.Android.READ_MEDIA_AUDIO
          } : new PlatformPermission[]
          {
            Permissions.Android.READ_EXTERNAL_STORAGE, Permissions.Android.WRITE_EXTERNAL_STORAGE
          };
      }
    }

    public void Execute()
    {
      if defined(Android)
      {
        Permissions.Request(_requiredPermissions).Then(OnPermissions, OnRejected);
      }
      else
      {
        OnGranted();
      }
    }

    void OnPermissions(PlatformPermission[] grantedPermissions)
    {
      if(grantedPermissions.Length!=_requiredPermissions.Length)
      {
        OnRejected(new Exception("Required permission(s) not granted."));
      }
      else
      {
        OnGranted();
      }
    }

    abstract void OnGranted();
    abstract void OnRejected(Exception e);
  }

  extern (Android) class ResizeCommand : PCommand {
    string _path;
    int _desiredWidth;
    int _desiredHeight;
    int _mode;
    string _format;
    int _quality;
    int _background;
    bool _inPlace;
    Action<string> _resolve;
    Action<string> _reject;
    public ResizeCommand(string path, int desiredWidth, int desiredHeight, int mode, string format, int quality, int background, Action<string> Resolve, Action<string> Reject, bool inPlace) : base(ImagePermissions)
    {
      _path = path;
      _desiredWidth = desiredWidth;
      _desiredHeight = desiredHeight;
      _mode = mode;
      _format = format;
      _quality = quality;
      _background = background;
      _inPlace = inPlace;
      _resolve = Resolve;
      _reject = Reject;
    }
    override void OnGranted()
    {
      AndroidImageUtils.Resize(_path, _desiredWidth, _desiredHeight, _mode, _format, _quality, _background, _resolve, _reject, _inPlace);
    }

    override void OnRejected(Exception e)
    {
      _reject(e.Message);
    }
  }

  extern (Android) class CropCommand : PCommand {
    string _path;
    int _x;
    int _y;
    int _width;
    int _height;
    string _format;
    int _quality;
    bool _inPlace;
    Action<string> _resolve;
    Action<string> _reject;
    public CropCommand(string path, int x, int y, int desiredWidth, int desiredHeight, string format, int quality, Action<string> Resolve, Action<string> Reject, bool inPlace) : base(ImagePermissions)
    {
      _path = path;
      _x = x;
      _y = y;
      _width = desiredWidth;
      _height = desiredHeight;
      _format = format;
      _quality = quality;
      _inPlace = inPlace;
      _resolve = Resolve;
      _reject = Reject;
    }
    override void OnGranted()
    {
      AndroidImageUtils.Crop(_path, _x, _y, _width, _height, _format, _quality, _resolve, _reject, _inPlace);
    }

    override void OnRejected(Exception e)
    {
      _reject(e.Message);
    }
  }

  extern (Android) class RotateCommand : PCommand {
    string _path;
    double _degrees;
    string _format;
    int _quality;
    bool _inPlace;
    Action<string> _resolve;
    Action<string> _reject;
    public RotateCommand(string path, double degrees, string format, int quality, Action<string> Resolve, Action<string> Reject, bool inPlace) : base(ImagePermissions)
    {
      _path = path;
      _degrees = degrees;
      _format = format;
      _quality = quality;
      _inPlace = inPlace;
      _resolve = Resolve;
      _reject = Reject;
    }
    override void OnGranted()
    {
      AndroidImageUtils.Rotate(_path, _degrees, _format, _quality, _resolve, _reject, _inPlace);
    }
    override void OnRejected(Exception e)
    {
      _reject(e.Message);
    }
  }

  extern (Android) class FlipCommand : PCommand {
    string _path;
    bool _horizontal;
    bool _vertical;
    string _format;
    int _quality;
    bool _inPlace;
    Action<string> _resolve;
    Action<string> _reject;
    public FlipCommand(string path, bool horizontal, bool vertical, string format, int quality, Action<string> Resolve, Action<string> Reject, bool inPlace) : base(ImagePermissions)
    {
      _path = path;
      _horizontal = horizontal;
      _vertical = vertical;
      _format = format;
      _quality = quality;
      _inPlace = inPlace;
      _resolve = Resolve;
      _reject = Reject;
    }
    override void OnGranted()
    {
      AndroidImageUtils.Flip(_path, _horizontal, _vertical, _format, _quality, _resolve, _reject, _inPlace);
    }
    override void OnRejected(Exception e)
    {
      _reject(e.Message);
    }
  }

  extern (Android) class AutoOrientCommand : PCommand {
    string _path;
    string _format;
    int _quality;
    bool _inPlace;
    Action<string> _resolve;
    Action<string> _reject;
    public AutoOrientCommand(string path, string format, int quality, Action<string> Resolve, Action<string> Reject, bool inPlace) : base(ImagePermissions)
    {
      _path = path;
      _format = format;
      _quality = quality;
      _inPlace = inPlace;
      _resolve = Resolve;
      _reject = Reject;
    }
    override void OnGranted()
    {
      AndroidImageUtils.AutoOrient(_path, _format, _quality, _resolve, _reject, _inPlace);
    }
    override void OnRejected(Exception e)
    {
      _reject(e.Message);
    }
  }

  extern (Android) class ThumbnailCommand : PCommand {
    string _path;
    int _maxWidth;
    int _maxHeight;
    string _format;
    int _quality;
    Action<string> _resolve;
    Action<string> _reject;
    public ThumbnailCommand(string path, int maxWidth, int maxHeight, string format, int quality, Action<string> Resolve, Action<string> Reject) : base(ImagePermissions)
    {
      _path = path;
      _maxWidth = maxWidth;
      _maxHeight = maxHeight;
      _format = format;
      _quality = quality;
      _resolve = Resolve;
      _reject = Reject;
    }
    override void OnGranted()
    {
      AndroidImageUtils.Thumbnail(_path, _maxWidth, _maxHeight, _format, _quality, _resolve, _reject);
    }
    override void OnRejected(Exception e)
    {
      _reject(e.Message);
    }
  }

  extern (Android) class ConvertCommand : PCommand {
    string _path;
    string _format;
    int _quality;
    bool _inPlace;
    Action<string> _resolve;
    Action<string> _reject;
    public ConvertCommand(string path, string format, int quality, Action<string> Resolve, Action<string> Reject, bool inPlace) : base(ImagePermissions)
    {
      _path = path;
      _format = format;
      _quality = quality;
      _inPlace = inPlace;
      _resolve = Resolve;
      _reject = Reject;
    }
    override void OnGranted()
    {
      AndroidImageUtils.Convert(_path, _format, _quality, _resolve, _reject, _inPlace);
    }
    override void OnRejected(Exception e)
    {
      _reject(e.Message);
    }
  }

  extern (Android) class SaveCommand : PCommand {
    string _path;
    string _directory;
    string _name;
    string _format;
    int _quality;
    Action<string> _resolve;
    Action<string> _reject;
    public SaveCommand(string path, string directory, string name, string format, int quality, Action<string> Resolve, Action<string> Reject) : base(ImagePermissions)
    {
      _path = path;
      _directory = directory;
      _name = name;
      _format = format;
      _quality = quality;
      _resolve = Resolve;
      _reject = Reject;
    }
    override void OnGranted()
    {
      AndroidImageUtils.Save(_path, _directory, _name, _format, _quality, _resolve, _reject);
    }
    override void OnRejected(Exception e)
    {
      _reject(e.Message);
    }
  }

  extern (Android) class CompositeCommand : PCommand {
    string _path;
    string _overlayPath;
    int _x;
    int _y;
    double _opacity;
    string _format;
    int _quality;
    bool _inPlace;
    Action<string> _resolve;
    Action<string> _reject;
    public CompositeCommand(string path, string overlayPath, int x, int y, double opacity, string format, int quality, Action<string> Resolve, Action<string> Reject, bool inPlace) : base(ImagePermissions)
    {
      _path = path;
      _overlayPath = overlayPath;
      _x = x;
      _y = y;
      _opacity = opacity;
      _format = format;
      _quality = quality;
      _inPlace = inPlace;
      _resolve = Resolve;
      _reject = Reject;
    }
    override void OnGranted()
    {
      AndroidImageUtils.Composite(_path, _overlayPath, _x, _y, _opacity, _format, _quality, _resolve, _reject, _inPlace);
    }
    override void OnRejected(Exception e)
    {
      _reject(e.Message);
    }
  }

  extern (Android) class FilterCommand : PCommand {
    string _path;
    string _type;
    double _amount;
    int _radius;
    string _format;
    int _quality;
    bool _inPlace;
    Action<string> _resolve;
    Action<string> _reject;
    public FilterCommand(string path, string type, double amount, int radius, string format, int quality, Action<string> Resolve, Action<string> Reject, bool inPlace) : base(ImagePermissions)
    {
      _path = path;
      _type = type;
      _amount = amount;
      _radius = radius;
      _format = format;
      _quality = quality;
      _inPlace = inPlace;
      _resolve = Resolve;
      _reject = Reject;
    }
    override void OnGranted()
    {
      AndroidImageUtils.Filter(_path, _type, _amount, _radius, _format, _quality, _resolve, _reject, _inPlace);
    }
    override void OnRejected(Exception e)
    {
      _reject(e.Message);
    }
  }

  extern (Android) class DrawTextCommand : PCommand {
    string _path;
    string _text;
    int _x;
    int _y;
    double _fontSize;
    string _font;
    int _color;
    string _format;
    int _quality;
    bool _inPlace;
    Action<string> _resolve;
    Action<string> _reject;
    public DrawTextCommand(string path, string text, int x, int y, double fontSize, string font, int color, string format, int quality, Action<string> Resolve, Action<string> Reject, bool inPlace) : base(ImagePermissions)
    {
      _path = path;
      _text = text;
      _x = x;
      _y = y;
      _fontSize = fontSize;
      _font = font;
      _color = color;
      _format = format;
      _quality = quality;
      _inPlace = inPlace;
      _resolve = Resolve;
      _reject = Reject;
    }
    override void OnGranted()
    {
      AndroidImageUtils.DrawText(_path, _text, _x, _y, _fontSize, _font, _color, _format, _quality, _resolve, _reject, _inPlace);
    }
    override void OnRejected(Exception e)
    {
      _reject(e.Message);
    }
  }

  extern (Android) class GetBase64Command : PCommand {
    string _path;
    string _format;
    int _quality;
    Action<string> _resolve;
    Action<string> _reject;
    public GetBase64Command(string path, string format, int quality, Action<string> Resolve, Action<string> Reject) : base(ImagePermissions)
    {
      _path = path;
      _format = format;
      _quality = quality;
      _resolve = Resolve;
      _reject = Reject;
    }
    override void OnGranted()
    {
      AndroidImageUtils.GetBase64FromImage(_path, _format, _quality, _resolve, _reject);
    }
    override void OnRejected(Exception e)
    {
      _reject(e.Message);
    }
  }

  extern (Android) class ImageFromUriCommand : PCommand {
    string _uri;
    Action<string> _resolve;
    Action<string> _reject;
    public ImageFromUriCommand(string uri, Action<string> Resolve, Action<string> Reject) : base(ImagePermissions)
    {
      _uri = uri;
      _resolve = Resolve;
      _reject = Reject;
    }
    override void OnGranted()
    {
      AndroidImageUtils.GetImageFromUri(_uri, _resolve, _reject);
    }
    override void OnRejected(Exception e)
    {
      _reject(e.Message);
    }
  }

  extern (Android) class ImageFromBase64Command : PCommand {
    string _base64Image;
    Action<string> _resolve;
    Action<string> _reject;
    public ImageFromBase64Command(string base64Image, Action<string> Resolve, Action<string> Reject) : base(ImagePermissions)
    {
      _base64Image = base64Image;
      _resolve = Resolve;
      _reject = Reject;
    }
    override void OnGranted()
    {
      AndroidImageUtils.GetImageFromBase64(_base64Image, _resolve, _reject);
    }
    override void OnRejected(Exception e)
    {
      _reject(e.Message);
    }
  }

}
