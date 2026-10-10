# Changelog

All notable changes to the Fuse.Controls.NativeNavigation project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial implementation of Fuse.Controls.NativeNavigation library
- `NativeNavigationView` component for native navigation containers
- iOS implementation using `UINavigationController`
- `PushView` action for navigating forward in navigation stack
- `PopView` action for navigating backward in navigation stack
- Template-based page definition system using `ux:Template`
- `DefaultTemplate` property for specifying initial root view
- `INativeNavigationView` interface for platform-specific implementations
- **Separate TreeRenderer Context Architecture** - Major architectural improvement
- Automatic template discovery and instantiation
- **FuseJS Pages Support** - Full integration with JavaScript observable arrays
- `Pages` property for binding to JavaScript page stacks similar to Navigator
- JavaScript navigation methods: `push()`, `pop()`, `replace()`, `goToRoot()`
- Data context binding for page objects with `$path` property support
- Automatic change detection and navigation updates from JavaScript
- Full backward compatibility with existing template-based navigation
- Native navigation stack management with proper lifecycle handling
- Native rendering context support (`VisualContext.Native`)
- **Isolated rendering contexts** - Each template gets separate ViewControllerRoot
- **ViewControllerRoot class** - Manages isolated native rendering contexts
- **ViewControllerContext class** - Wraps template instances with rendering roots
- Integration with Fuse's ViewHandle system for native view access
- Integration with Fuse's `CreateNativeView()` system
- Deferred navigation to handle asynchronous native view creation
- Template instance management and cleanup
- Cross-platform architecture supporting iOS with Android planned
- Factory pattern for creating platform-specific implementations
- Comprehensive documentation and examples
- Multiple example applications:
  - `MinimalExample.ux` - Simple 3-page demo with DefaultTemplate
  - `NativeContextExample.ux` - NativeViewHost integration demo
  - `IntegrationTest.ux` - Interface integration verification
  - `SeparateContextTest.ux` - Separate TreeRenderer context architecture test
  - `TestApp.ux` - Full-featured showcase
  - `Example.ux` - Documentation example
- Project structure following Fuse conventions
- Integration with Fuse's UX markup system

### iOS Implementation Details
- Wraps `UINavigationController` for native iOS navigation
- Uses actual Fuse-rendered native views (UIView) in view controllers
- Automatic navigation bar with native back buttons
- Native iOS transitions and animations
- Support for swipe-to-go-back gestures
- Proper view controller lifecycle management
- Native memory management
- System-level accessibility support
- **No double-parent issues** - Templates render in isolated contexts
- **Proper memory management** - Automatic cleanup of rendering contexts
- Fallback placeholder view controllers with diagnostic information
- Integration with NativeViewHost for optimal native rendering

### Technical Architecture
- Base cross-platform `NativeNavigationView` class with native context support
- `INativeNavigationView` interface for clean platform abstraction
- Platform-specific implementations in dedicated directories
- Factory pattern for creating platform-specific implementations
- **Separate TreeRenderer Context Architecture** - Prevents double-parent conflicts
- **ViewControllerRoot pattern** - Isolated native rendering contexts per template
- Integration with Fuse's `CreateNativeView()` system
- Uses Fuse's template system for page content
- Template instance management with proper rooting/unrooting
- Native view handle integration for actual UIView access
- Deferred navigation handling for asynchronous view creation
- Action-based navigation triggers following Fuse patterns
- Foreign function interface for iOS native code integration
- Proper integration with Fuse's diagnostic system

### Documentation
- Comprehensive README with usage examples
- DefaultTemplate property documentation
- Native rendering context best practices
- NativeViewHost integration guide
- API documentation for all public classes and methods
- Platform comparison guide
- Installation and setup instructions
- Troubleshooting guide with native rendering diagnostics
- Performance comparison with existing Fuse navigation

### Future Roadmap
- Android implementation using Fragment navigation
- Enhanced native view integration and rendering optimization
- Navigation bar customization options
- Modal presentation modes
- Custom transition animations
- Deep linking support
- Navigation state persistence
- Pop-to-root functionality
- Breadcrumb navigation for deep stacks
- Better error handling for native rendering failures
- **Enhanced isolated rendering** - Even better template isolation and performance

## Notes

This is the initial release focusing on iOS implementation with proper native rendering integration, interface-based architecture, and **separate TreeRenderer context architecture**. The architecture is designed to support Android implementation in future releases. The library provides a native alternative to Fuse's built-in navigation system, offering better performance and platform-native user experience at the cost of some customization flexibility.

Key improvements in this version include:
- **DefaultTemplate property** for controlling initial navigation state
- **INativeNavigationView interface** for clean platform abstraction and type safety
- **Separate TreeRenderer Context Architecture** - Major architectural improvement that eliminates double-parent issues
- **ViewControllerRoot class** - Creates isolated native rendering contexts for each template
- **ViewControllerContext management** - Proper lifecycle management of template instances and rendering contexts
- **No double-parent conflicts** - Templates render in separate contexts, not added to NativeNavigationView.Children
- **Proper integration** with Fuse's native rendering system using CreateNativeView() and ViewHandle
- **Factory pattern** for creating platform-specific implementations
- **Native view integration** to access actual native views (UIView on iOS) for optimal performance and platform integration
- **Clean memory management** - Automatic cleanup of isolated rendering contexts

The separate TreeRenderer context architecture is the most significant improvement, solving the fundamental double-parent problem where template native views would conflict between Fuse's visual hierarchy and UIViewController ownership. Each template now gets its own isolated rendering context with proper cleanup, following patterns established by Fuse.Views and similar components. The interface-based design resolves compilation issues and enables clean separation between cross-platform logic and platform-specific implementations, making future Android support straightforward to implement.
