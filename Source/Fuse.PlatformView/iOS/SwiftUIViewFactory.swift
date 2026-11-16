import Darwin
import Foundation
import SwiftUI
import UIKit

/// SwiftUI View Factory for Fuse Platform Views
///
/// This file contains the core components for integrating SwiftUI views into Fuse applications.
/// It provides a factory pattern for creating and managing SwiftUI views with two-way data binding.

/// Registry of SwiftUI views available to Fuse `PlatformView`s, keyed by `ViewName`.
///
/// Prefer `PlatformViewRegistry.register` over assigning directly.
public var viewRegistration: [String: AnyView] = [:]

/// Registration API for SwiftUI views embedded in Fuse.
///
/// Views should be registered before a `PlatformView` with the same `ViewName` is created.
///
/// ```swift
/// PlatformViewRegistry.register("MyView", MyView())
/// ```
@MainActor
public final class PlatformViewRegistry {
    private init() {}

    private static var didBootstrap = false

    /// Runs the app-provided `FusePlatformViewSetup` hook once, if present.
    ///
    /// Apps register their views by exporting a C function named `FusePlatformViewSetup`, for example:
    /// ```swift
    /// @_cdecl("FusePlatformViewSetup")
    /// public func fusePlatformViewSetup() {
    ///     PlatformViewRegistry.register("MyView", MyView())
    /// }
    /// ```
    private static func bootstrapIfNeeded() {
        if didBootstrap { return }
        didBootstrap = true

        guard let handle = dlopen(nil, RTLD_NOW) else { return }
        defer { dlclose(handle) }

        guard let symbol = dlsym(handle, "FusePlatformViewSetup") else { return }

        typealias SetupFunction = @convention(c) () -> Void
        unsafeBitCast(symbol, to: SetupFunction.self)()
    }

    /// Registers a SwiftUI view under the given name.
    public static func register<V: View>(_ name: String, _ view: V) {
        bootstrapIfNeeded()
        viewRegistration[name] = AnyView(view)
    }

    /// Removes the view registered under the given name.
    public static func unregister(_ name: String) {
        bootstrapIfNeeded()
        viewRegistration.removeValue(forKey: name)
    }

    /// Returns the view registered under the given name, if any.
    public static func view(for name: String) -> AnyView? {
        bootstrapIfNeeded()
        return viewRegistration[name]
    }
}

/// Observable data model that manages data synchronization between Fuse and SwiftUI views.
/// This class uses @Published properties to automatically notify SwiftUI views when data changes,
/// and includes callback functions to notify Fuse when data is modified from the SwiftUI side.
///
/// Callbacks are suppressed while `applyWithoutCallback` is running so that data pushed from
/// Fuse is not echoed back to Fuse as if it had been changed by the native view.
@MainActor
public class PlatformViewData: ObservableObject {
    /// Dictionary containing object data passed from Fuse to SwiftUI.
    /// When modified by the native view, automatically serializes to JSON and calls the object callback.
    @Published var get: [String: Any] = [:] {
        didSet {
            guard !suppressCallbacks, let jsonString = PlatformViewData.jsonString(from: get) else {
                return
            }
            objectCallback(jsonString)
        }
    }
    /// Array containing list data passed from Fuse to SwiftUI.
    /// When modified by the native view, automatically serializes to JSON and calls the array callback.
    @Published var getArray: [Any] = [] {
        didSet {
            guard !suppressCallbacks, let jsonString = PlatformViewData.jsonString(from: getArray)
            else { return }
            arrayCallback(jsonString)
        }
    }
    /// Float value passed between Fuse and SwiftUI.
    /// Changes automatically trigger the float callback to notify Fuse.
    @Published var getFloat: Float = Float.zero {
        didSet {
            guard !suppressCallbacks else { return }
            floatCallback(getFloat)
        }
    }
    /// Double value passed between Fuse and SwiftUI.
    /// Changes automatically trigger the double callback to notify Fuse.
    @Published var getDouble: Double = 0.0 {
        didSet {
            guard !suppressCallbacks else { return }
            doubleCallback(getDouble)
        }
    }
    /// Integer value passed between Fuse and SwiftUI.
    /// Changes automatically trigger the integer callback to notify Fuse.
    @Published var getInteger: Int32 = Int32.zero {
        didSet {
            guard !suppressCallbacks else { return }
            integerCallback(getInteger)
        }
    }
    /// Boolean value passed between Fuse and SwiftUI.
    /// Changes automatically trigger the bool callback to notify Fuse.
    @Published var getBool: Bool = false {
        didSet {
            guard !suppressCallbacks else { return }
            boolCallback(getBool)
        }
    }
    /// String value passed between Fuse and SwiftUI.
    /// Changes automatically trigger the string callback to notify Fuse.
    @Published var getString: String = "" {
        didSet {
            guard !suppressCallbacks else { return }
            stringCallback(getString)
        }
    }

    /// True while data is being pushed from Fuse, so native-to-Fuse callbacks are not fired.
    private var suppressCallbacks = false

    /// Callback function called when integer data changes in SwiftUI
    var integerCallback: (Int32) -> Void
    /// Callback function called when double data changes in SwiftUI
    var doubleCallback: (Double) -> Void
    /// Callback function called when float data changes in SwiftUI
    var floatCallback: (Float) -> Void
    /// Callback function called when boolean data changes in SwiftUI
    var boolCallback: (Bool) -> Void
    /// Callback function called when string data changes in SwiftUI
    var stringCallback: (String?) -> Void
    /// Callback function called when object data changes in SwiftUI
    var objectCallback: (String?) -> Void
    /// Callback function called when array data changes in SwiftUI
    var arrayCallback: (String?) -> Void
    /// General event callback for custom events from SwiftUI views
    var callback: (String?, String?) -> Void

    /// Invoked when Fuse sends a command to this native view via `PlatformView.Invoke`.
    /// The first argument is the command name, the second is the JSON arguments (or an empty string).
    var onCommand: (String, String) -> Void = { _, _ in }

    /// Invoked when the native view becomes visible.
    var onAppear: () -> Void = {}

    /// Invoked when the native view is no longer visible.
    var onDisappear: () -> Void = {}

    func notifyAppeared() { onAppear() }
    func notifyDisappeared() { onDisappear() }

    /// Environment overrides supplied by Fuse (for example `colorScheme` and `layoutDirection`).
    @Published var environment: [String: Any] = [:]

    /// Initializes the data model with all necessary callback functions for two-way data binding.
    ///
    /// - Parameters:
    ///   - integerCallback: Called when integer data changes
    ///   - floatCallback: Called when float data changes
    ///   - boolCallback: Called when boolean data changes
    ///   - stringCallback: Called when string data changes
    ///   - objectCallback: Called when object data changes (JSON serialized)
    ///   - arrayCallback: Called when array data changes (JSON serialized)
    ///   - eventCallback: Called for custom events with event name and value
    init(
        integerCallback: @escaping (Int32) -> Void,
        doubleCallback: @escaping (Double) -> Void,
        floatCallback: @escaping (Float) -> Void,
        boolCallback: @escaping (Bool) -> Void,
        stringCallback: @escaping (String?) -> Void,
        objectCallback: @escaping (String?) -> Void,
        arrayCallback: @escaping (String?) -> Void,
        eventCallback: @escaping (String?, String?) -> Void
    ) {

        self.integerCallback = integerCallback
        self.doubleCallback = doubleCallback
        self.floatCallback = floatCallback
        self.boolCallback = boolCallback
        self.stringCallback = stringCallback
        self.objectCallback = objectCallback
        self.arrayCallback = arrayCallback
        self.callback = eventCallback
    }

    /// Applies a change to the model without firing native-to-Fuse callbacks.
    /// Used when data is pushed from Fuse, so the change is not echoed back.
    func applyWithoutCallback(_ apply: () -> Void) {
        suppressCallbacks = true
        apply()
        suppressCallbacks = false
    }

    /// Serializes a value to JSON, returning nil if the value is not valid JSON.
    private static func jsonString(from value: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(value),
            let jsonData = try? JSONSerialization.data(
                withJSONObject: value, options: [.prettyPrinted]),
            let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            return nil
        }
        return jsonString
    }
}

/// Applies Fuse-provided environment overrides (color scheme, layout direction) to a hosted view.
struct PlatformViewEnvironment: ViewModifier {
    @ObservedObject var model: PlatformViewData

    func body(content: Content) -> AnyView {
        var result = AnyView(content)

        if let scheme = model.environment["colorScheme"] as? String {
            if scheme == "dark" {
                result = AnyView(result.environment(\.colorScheme, .dark))
            } else if scheme == "light" {
                result = AnyView(result.environment(\.colorScheme, .light))
            }
        }

        if let direction = model.environment["layoutDirection"] as? String {
            if direction == "rtl" {
                result = AnyView(result.environment(\.layoutDirection, .rightToLeft))
            } else if direction == "ltr" {
                result = AnyView(result.environment(\.layoutDirection, .leftToRight))
            }
        }

        if let label = model.environment["accessibilityLabel"] as? String, !label.isEmpty {
            result = AnyView(result.accessibilityLabel(Text(label)))
        }

        if let hint = model.environment["accessibilityHint"] as? String, !hint.isEmpty {
            result = AnyView(result.accessibilityHint(Text(hint)))
        }

        return result
    }
}

/// Factory class responsible for creating and managing SwiftUI views within Fuse applications.
/// This class maintains a registry of views and their associated data models, handles view creation,
/// and provides methods for updating data from Fuse to SwiftUI views.
///
/// Data models are keyed by a per-instance id (created by `PlatformNativeView`) rather than by view
/// name, so multiple `PlatformView` instances showing the same `ViewName` keep independent state.
@MainActor
@objc public class SwiftUIViewFactory: NSObject {
    /// Dictionary storing PlatformViewData instances keyed by instance id
    private static var platformData: [Int32: PlatformViewData] = [:]

    /// Creates a new SwiftUI view wrapped in a UIHostingController for embedding in Fuse.
    ///
    /// This method creates a PlatformViewData instance with the provided callbacks,
    /// retrieves the registered SwiftUI view by name, and wraps it in a UIHostingController
    /// with the data model injected as an environment object.
    ///
    /// - Parameters:
    ///   - id: Unique instance id used to address this view's data model
    ///   - name: The name of the registered SwiftUI view to create
    ///   - dataIntegerCallback: Callback for integer data changes
    ///   - dataFloatCallback: Callback for float data changes
    ///   - dataBoolCallback: Callback for boolean data changes
    ///   - dataStringCallback: Callback for string data changes
    ///   - dataObjectCallback: Callback for object data changes (JSON)
    ///   - dataArrayCallback: Callback for array data changes (JSON)
    ///   - eventCallback: Callback for custom events
    ///   - notFoundCallback: Invoked when no view is registered under `name`
    /// - Returns: UIViewController containing the SwiftUI view
    @objc public static func makeSwiftUIView(
        id: Int32,
        name: String, dataIntegerCallback: @escaping (Int32) -> Void,
        dataDoubleCallback: @escaping (Double) -> Void,
        dataFloatCallback: @escaping (Float) -> Void, dataBoolCallback: @escaping (Bool) -> Void,
        dataStringCallback: @escaping (String?) -> Void,
        dataObjectCallback: @escaping (String?) -> Void,
        dataArrayCallback: @escaping (String?) -> Void,
        eventCallback: @escaping (String?, String?) -> Void,
        notFoundCallback: @escaping (String) -> Void,
        loadedCallback: @escaping () -> Void,
        appearedCallback: @escaping () -> Void,
        disappearedCallback: @escaping () -> Void
    ) -> UIViewController {

        let platformViewDataModel = PlatformViewData(
            integerCallback: dataIntegerCallback,
            doubleCallback: dataDoubleCallback,
            floatCallback: dataFloatCallback,
            boolCallback: dataBoolCallback,
            stringCallback: dataStringCallback,
            objectCallback: dataObjectCallback,
            arrayCallback: dataArrayCallback,
            eventCallback: eventCallback)
        platformViewDataModel.onAppear = appearedCallback
        platformViewDataModel.onDisappear = disappearedCallback
        platformData[id] = platformViewDataModel

        let content: AnyView
        if let registered = PlatformViewRegistry.view(for: name) {
            content = registered
            loadedCallback()
        } else {
            notFoundCallback(name)
            content = AnyView(Text("SwiftUI view named \(name) was not found"))
        }

        let rootView =
            content
            .environmentObject(platformViewDataModel)
            .modifier(PlatformViewEnvironment(model: platformViewDataModel))
            .onAppear { platformViewDataModel.notifyAppeared() }
            .onDisappear { platformViewDataModel.notifyDisappeared() }

        return UIHostingController(rootView: AnyView(rootView))
    }

    /// Releases the data model associated with the given instance id.
    ///
    /// - Parameter id: The instance id to release
    @objc public static func dispose(id: Int32) {
        platformData.removeValue(forKey: id)
    }

    /// Updates object or array data for the specified SwiftUI view instance.
    ///
    /// - Parameters:
    ///   - id: The instance id to update
    ///   - data: JSON string containing the data to set
    ///   - isArray: True if the data represents an array, false for object
    @objc public static func setData(id: Int32, data: String, isArray: Bool) {
        guard let platformViewDataModel = platformData[id] else { return }
        platformViewDataModel.applyWithoutCallback {
            if isArray {
                platformViewDataModel.getArray = convertJSONStringToArray(data) ?? []
            } else {
                platformViewDataModel.get = convertJSONStringToDictionary(data) ?? [:]
            }
        }
    }

    /// Updates float data for the specified SwiftUI view instance.
    ///
    /// - Parameters:
    ///   - id: The instance id to update
    ///   - dataFloat: The float value to set
    @objc public static func setData(id: Int32, dataFloat: Float) {
        guard let platformViewDataModel = platformData[id] else { return }
        platformViewDataModel.applyWithoutCallback {
            platformViewDataModel.getFloat = dataFloat
        }
    }

    /// Updates double data for the specified SwiftUI view instance.
    ///
    /// - Parameters:
    ///   - id: The instance id to update
    ///   - dataDouble: The double value to set
    @objc public static func setData(id: Int32, dataDouble: Double) {
        guard let platformViewDataModel = platformData[id] else { return }
        platformViewDataModel.applyWithoutCallback {
            platformViewDataModel.getDouble = dataDouble
        }
    }

    /// Updates integer data for the specified SwiftUI view instance.
    ///
    /// - Parameters:
    ///   - id: The instance id to update
    ///   - dataInteger: The integer value to set
    @objc public static func setData(id: Int32, dataInteger: Int32) {
        guard let platformViewDataModel = platformData[id] else { return }
        platformViewDataModel.applyWithoutCallback {
            platformViewDataModel.getInteger = dataInteger
        }
    }

    /// Updates boolean data for the specified SwiftUI view instance.
    ///
    /// - Parameters:
    ///   - id: The instance id to update
    ///   - dataBool: The boolean value to set
    @objc public static func setData(id: Int32, dataBool: Bool) {
        guard let platformViewDataModel = platformData[id] else { return }
        platformViewDataModel.applyWithoutCallback {
            platformViewDataModel.getBool = dataBool
        }
    }

    /// Updates string data for the specified SwiftUI view instance.
    ///
    /// - Parameters:
    ///   - id: The instance id to update
    ///   - dataString: The string value to set
    @objc public static func setData(id: Int32, dataString: String) {
        guard let platformViewDataModel = platformData[id] else { return }
        platformViewDataModel.applyWithoutCallback {
            platformViewDataModel.getString = dataString
        }
    }

    /// Delivers a command from Fuse to the specified SwiftUI view instance.
    ///
    /// - Parameters:
    ///   - id: The instance id to invoke
    ///   - command: The command name
    ///   - arguments: JSON arguments supplied by Fuse, or an empty string
    @objc public static func invoke(id: Int32, command: String, arguments: String) {
        platformData[id]?.onCommand(command, arguments)
    }

    /// Applies environment overrides (color scheme, layout direction) to the specified view.
    ///
    /// - Parameters:
    ///   - id: The instance id to update
    ///   - json: JSON object containing the environment overrides
    @objc public static func setEnvironment(id: Int32, json: String) {
        guard let platformViewDataModel = platformData[id] else { return }
        platformViewDataModel.environment = convertJSONStringToDictionary(json) ?? [:]
    }

    /// Converts a JSON string to a Swift dictionary for use in SwiftUI views.
    ///
    /// - Parameter jsonString: The JSON string to convert
    /// - Returns: Dictionary representation of the JSON, or empty dictionary if conversion fails
    static func convertJSONStringToDictionary(_ jsonString: String) -> [String: Any]? {
        guard let data = jsonString.data(using: .utf8) else {
            print("PlatformView: unable to convert string to Data")
            return [:]
        }

        do {
            return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        } catch {
            print("PlatformView: error deserializing JSON object: \(error.localizedDescription)")
            return [:]
        }
    }

    /// Converts a JSON string to a Swift array for use in SwiftUI views.
    /// `JSONSerialization` already produces the correct native types (String, NSNumber,
    /// NSNull, arrays and dictionaries), so the resulting array is returned unchanged.
    ///
    /// - Parameter jsonString: The JSON string to convert
    /// - Returns: Array representation of the JSON, or empty array if conversion fails
    static func convertJSONStringToArray(_ jsonString: String) -> [Any]? {
        guard let data = jsonString.data(using: .utf8) else {
            print("PlatformView: unable to convert string to Data")
            return []
        }

        do {
            return try JSONSerialization.jsonObject(with: data, options: []) as? [Any] ?? []
        } catch {
            print("PlatformView: error deserializing JSON array: \(error.localizedDescription)")
            return []
        }
    }

}
