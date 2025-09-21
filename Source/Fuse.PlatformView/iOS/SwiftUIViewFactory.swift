import Foundation
import SwiftUI
import UIKit

/// SwiftUI View Factory for Fuse Platform Views
///
/// This file contains the core components for integrating SwiftUI views into Fuse applications.
/// It provides a factory pattern for creating and managing SwiftUI views with two-way data binding.

/// Observable data model that manages data synchronization between Fuse and SwiftUI views.
/// This class uses @Published properties to automatically notify SwiftUI views when data changes,
/// and includes callback functions to notify Fuse when data is modified from the SwiftUI side.
@MainActor
public class PlatformViewData: ObservableObject {
    /// Dictionary containing object data passed from Fuse to SwiftUI.
    /// When modified, automatically serializes to JSON and calls the object callback.
    @Published var get: [String: Any] = [:] {
        didSet {
            if let jsonData = try? JSONSerialization.data(
                withJSONObject: get, options: .prettyPrinted),
                let jsonString = String(data: jsonData, encoding: .utf8)
            {
                objectCallback(jsonString)
            }
        }
    }
    /// Array containing list data passed from Fuse to SwiftUI.
    /// When modified, automatically serializes to JSON and calls the array callback.
    @Published var getArray: [Any] = [] {
        didSet {
            if let jsonData = try? JSONSerialization.data(
                withJSONObject: get, options: .prettyPrinted),
                let jsonString = String(data: jsonData, encoding: .utf8)
            {
                arrayCallback(jsonString)
            }
        }
    }
    /// Float value passed between Fuse and SwiftUI.
    /// Changes automatically trigger the float callback to notify Fuse.
    @Published var getFloat: Float = Float.zero {
        didSet {
            floatCallback(getFloat)
        }
    }
    /// Integer value passed between Fuse and SwiftUI.
    /// Changes automatically trigger the integer callback to notify Fuse.
    @Published var getInteger: Int32 = Int32.zero {
        didSet {
            integerCallback(getInteger)
        }
    }
    /// Boolean value passed between Fuse and SwiftUI.
    /// Changes automatically trigger the bool callback to notify Fuse.
    @Published var getBool: Bool = false {
        didSet {
            boolCallback(getBool)
        }
    }
    /// String value passed between Fuse and SwiftUI.
    /// Changes automatically trigger the string callback to notify Fuse.
    @Published var getString: String = "" {
        didSet {
            stringCallback(getString)
        }
    }

    /// Callback function called when integer data changes in SwiftUI
    var integerCallback: (Int32) -> Void
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
        floatCallback: @escaping (Float) -> Void,
        boolCallback: @escaping (Bool) -> Void,
        stringCallback: @escaping (String?) -> Void,
        objectCallback: @escaping (String?) -> Void,
        arrayCallback: @escaping (String?) -> Void,
        eventCallback: @escaping (String?, String?) -> Void
    ) {

        self.integerCallback = integerCallback
        self.floatCallback = floatCallback
        self.boolCallback = boolCallback
        self.stringCallback = stringCallback
        self.objectCallback = objectCallback
        self.arrayCallback = arrayCallback
        self.callback = eventCallback
    }
}

/// Factory class responsible for creating and managing SwiftUI views within Fuse applications.
/// This class maintains a registry of views and their associated data models, handles view creation,
/// and provides methods for updating data from Fuse to SwiftUI views.
///
/// Key responsibilities:
/// - Creating UIHostingController instances for SwiftUI views
/// - Managing PlatformViewData instances for each view
/// - Handling data synchronization from Fuse to SwiftUI
/// - JSON serialization/deserialization for complex data types
@MainActor
@objc public class SwiftUIViewFactory: NSObject {
    /// Dictionary storing PlatformViewData instances keyed by view name
    private static var platformData: [String: PlatformViewData] = [:]

    /// Creates a new SwiftUI view wrapped in a UIHostingController for embedding in Fuse.
    ///
    /// This method creates a PlatformViewData instance with the provided callbacks,
    /// retrieves the registered SwiftUI view by name, and wraps it in a UIHostingController
    /// with the data model injected as an environment object.
    ///
    /// - Parameters:
    ///   - name: The name of the registered SwiftUI view to create
    ///   - dataIntegerCallback: Callback for integer data changes
    ///   - dataFloatCallback: Callback for float data changes
    ///   - dataBoolCallback: Callback for boolean data changes
    ///   - dataStringCallback: Callback for string data changes
    ///   - dataObjectCallback: Callback for object data changes (JSON)
    ///   - dataArrayCallback: Callback for array data changes (JSON)
    ///   - eventCallback: Callback for custom events
    /// - Returns: UIViewController containing the SwiftUI view
    @objc public static func makeSwiftUIView(
        name: String, dataIntegerCallback: @escaping (Int32) -> Void,
        dataFloatCallback: @escaping (Float) -> Void, dataBoolCallback: @escaping (Bool) -> Void,
        dataStringCallback: @escaping (String?) -> Void,
        dataObjectCallback: @escaping (String?) -> Void,
        dataArrayCallback: @escaping (String?) -> Void,
        eventCallback: @escaping (String?, String?) -> Void
    ) -> UIViewController {

        let platformViewDataModel = PlatformViewData(
            integerCallback: dataIntegerCallback,
            floatCallback: dataFloatCallback,
            boolCallback: dataBoolCallback,
            stringCallback: dataStringCallback,
            objectCallback: dataObjectCallback,
            arrayCallback: dataArrayCallback,
            eventCallback: eventCallback)
        platformData[name] = platformViewDataModel
        return UIHostingController(
            rootView: AnyView(getView(name: name).environmentObject(platformViewDataModel)))
    }

    /// Updates object or array data for the specified SwiftUI view.
    ///
    /// - Parameters:
    ///   - viewName: The name of the SwiftUI view to update
    ///   - data: JSON string containing the data to set
    ///   - isArray: True if the data represents an array, false for object
    @objc public static func setData(viewName: String, data: String, isArray: Bool) {
        let platformViewDataModel = platformData[viewName]
        if isArray {
            platformViewDataModel?.getArray = convertJSONStringToArray(data) ?? []
        } else {
            platformViewDataModel?.get = convertJSONStringToDictionary(data) ?? [:]
        }
    }

    /// Updates float data for the specified SwiftUI view.
    ///
    /// - Parameters:
    ///   - viewName: The name of the SwiftUI view to update
    ///   - dataFloat: The float value to set
    @objc public static func setData(viewName: String, dataFloat: Float) {
        let platformViewDataModel = platformData[viewName]
        platformViewDataModel?.getFloat = dataFloat
    }

    /// Updates integer data for the specified SwiftUI view.
    ///
    /// - Parameters:
    ///   - viewName: The name of the SwiftUI view to update
    ///   - dataInteger: The integer value to set
    @objc public static func setData(viewName: String, dataInteger: Int32) {
        let platformViewDataModel = platformData[viewName]
        platformViewDataModel?.getInteger = dataInteger
    }

    /// Updates boolean data for the specified SwiftUI view.
    ///
    /// - Parameters:
    ///   - viewName: The name of the SwiftUI view to update
    ///   - dataBool: The boolean value to set
    @objc public static func setData(viewName: String, dataBool: Bool) {
        let platformViewDataModel = platformData[viewName]
        platformViewDataModel?.getBool = dataBool
    }

    /// Updates string data for the specified SwiftUI view.
    ///
    /// - Parameters:
    ///   - viewName: The name of the SwiftUI view to update
    ///   - dataString: The string value to set
    @objc public static func setData(viewName: String, dataString: String) {
        let platformViewDataModel = platformData[viewName]
        platformViewDataModel?.getString = dataString
    }

    /// Retrieves a registered SwiftUI view by name from the view registration system.
    /// If the view is not found, returns a default error view.
    ///
    /// - Parameter name: The name of the SwiftUI view to retrieve
    /// - Returns: The SwiftUI view or an error view if not found
    static func getView(name: String) -> any View {
        guard let unwrappedView = viewRegistration[name] else {
            return AnyView(Text("SwiftUI View named \(name) not found"))
        }
        return unwrappedView
    }

    /// Converts a JSON string to a Swift dictionary for use in SwiftUI views.
    ///
    /// - Parameter jsonString: The JSON string to convert
    /// - Returns: Dictionary representation of the JSON, or empty dictionary if conversion fails
    static func convertJSONStringToDictionary(_ jsonString: String) -> [String: Any]? {
        guard let data = jsonString.data(using: .utf8) else {
            print("Error: Unable to convert string to Data")
            return [:]
        }

        do {
            let jsonDict =
                try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            return jsonDict
        } catch {
            print("Error deserializing JSON: \(error.localizedDescription)")
            return [:]
        }
    }

    /// Converts a JSON string to a Swift array for use in SwiftUI views.
    /// Handles type casting for common data types (dictionaries, booleans, numbers, strings).
    ///
    /// - Parameter jsonString: The JSON string to convert
    /// - Returns: Array representation of the JSON, or empty array if conversion fails
    static func convertJSONStringToArray(_ jsonString: String) -> [Any]? {
        guard let data = jsonString.data(using: .utf8) else {
            print("Error: Unable to convert string to Data")
            return []
        }

        do {
            guard
                let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [Any]
            else {
                return []
            }
            var output: [Any] = []
            for data in jsonArray {
                if data is [String: Any]? {
                    output.append(data as! [String: Any])
                } else if data is Bool? {
                    output.append(data as! Bool)
                } else if data is Int32? {
                    output.append(data as! Int32)
                } else if data is Float? {
                    output.append(data as! Float)
                } else if data is String? {
                    output.append(data as! String)
                } else {
                    output.append(data)
                }
            }
            return output
        } catch {
            print("Error deserializing JSON: \(error.localizedDescription)")
            return []
        }
    }

}
