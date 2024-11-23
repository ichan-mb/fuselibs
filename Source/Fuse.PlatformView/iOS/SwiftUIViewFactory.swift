import Foundation
import SwiftUI
import UIKit


@MainActor
public class PlatformViewData: ObservableObject {
    @Published var get: [String: Any] = [:] {
        didSet {
            if let jsonData = try? JSONSerialization.data(withJSONObject: get, options: .prettyPrinted),
                let jsonString = String(data: jsonData, encoding: .utf8) {
                objectCallback(jsonString)
            }
        }
    }
    @Published var getArray: [Any] = [] {
        didSet {
            if let jsonData = try? JSONSerialization.data(withJSONObject: get, options: .prettyPrinted),
                let jsonString = String(data: jsonData, encoding: .utf8) {
                arrayCallback(jsonString)
            }
        }
    }
    @Published var getFloat: Float = Float.zero {
        didSet {
            floatCallback(getFloat)
        }
    }
    @Published var getInteger: Int32 = Int32.zero {
        didSet {
            integerCallback(getInteger)
        }
    }
    @Published var getBool: Bool = false {
        didSet {
            boolCallback(getBool)
        }
    }
    @Published var getString: String = "" {
        didSet {
            stringCallback(getString)
        }
    }

    var integerCallback: (Int32) -> Void
    var floatCallback: (Float) -> Void
    var boolCallback: (Bool) -> Void
    var stringCallback: (String?) -> Void
    var objectCallback: (String?) -> Void
    var arrayCallback: (String?) -> Void
    var callback: (String?, String?) -> Void

    init(integerCallback: @escaping (Int32) -> Void,
            floatCallback: @escaping (Float) -> Void,
            boolCallback: @escaping (Bool) -> Void,
            stringCallback: @escaping (String?) -> Void,
            objectCallback: @escaping (String?) -> Void,
            arrayCallback: @escaping (String?) -> Void,
            eventCallback: @escaping (String?, String?) -> Void) {

        self.integerCallback = integerCallback
        self.floatCallback = floatCallback
        self.boolCallback = boolCallback
        self.stringCallback = stringCallback
        self.objectCallback = objectCallback
        self.arrayCallback = arrayCallback
        self.callback = eventCallback
    }
}

@MainActor
@objc public class SwiftUIViewFactory: NSObject {
    private static var platformData: [String: PlatformViewData] = [:]

    @objc public static func makeSwiftUIView(name: String, dataIntegerCallback: @escaping (Int32) -> Void, dataFloatCallback: @escaping (Float) -> Void, dataBoolCallback: @escaping (Bool) -> Void, dataStringCallback: @escaping (String?) -> Void, dataObjectCallback: @escaping (String?) -> Void, dataArrayCallback: @escaping (String?) -> Void, eventCallback: @escaping (String?, String?) -> Void) -> UIViewController {

        let platformViewDataModel = PlatformViewData(integerCallback: dataIntegerCallback,
                floatCallback: dataFloatCallback,
                boolCallback: dataBoolCallback,
                stringCallback: dataStringCallback,
                objectCallback: dataObjectCallback,
                arrayCallback: dataArrayCallback,
                eventCallback: eventCallback)
        platformData[name] = platformViewDataModel
        return UIHostingController(rootView: AnyView(getView(name: name).environmentObject(platformViewDataModel)))
    }

    @objc public static func setData(viewName: String, data: String, isArray: Bool) {
        let platformViewDataModel = platformData[viewName]
        if isArray {
            platformViewDataModel?.getArray = convertJSONStringToArray(data) ?? []
        }else {
            platformViewDataModel?.get = convertJSONStringToDictionary(data) ?? [:]
        }
    }

    @objc public static func setData(viewName: String, dataFloat: Float) {
        let platformViewDataModel = platformData[viewName]
        platformViewDataModel?.getFloat = dataFloat
    }

    @objc public static func setData(viewName: String, dataInteger: Int32) {
        let platformViewDataModel = platformData[viewName]
        platformViewDataModel?.getInteger = dataInteger
    }

    @objc public static func setData(viewName: String, dataBool: Bool) {
        let platformViewDataModel = platformData[viewName]
        platformViewDataModel?.getBool = dataBool
    }

    @objc public static func setData(viewName: String, dataString: String) {
        let platformViewDataModel = platformData[viewName]
        platformViewDataModel?.getString = dataString
    }

    static func getView(name: String) -> any View {
        guard let unwrappedView = viewRegistration[name] else {
            return AnyView(Text("SwiftUI View named \(name) not found"))
        }
        return unwrappedView
    }

    static func convertJSONStringToDictionary(_ jsonString: String) -> [String: Any]? {
        guard let data = jsonString.data(using: .utf8) else {
            print("Error: Unable to convert string to Data")
            return [:]
        }

        do {
            let jsonDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            return jsonDict
        } catch {
            print("Error deserializing JSON: \(error.localizedDescription)")
            return [:]
        }
    }

    static func convertJSONStringToArray(_ jsonString: String) -> [Any]? {
        guard let data = jsonString.data(using: .utf8) else {
            print("Error: Unable to convert string to Data")
            return []
        }

        do {
            guard let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [Any] else {
                return []
            }
            var output: [Any] = []
            for data in jsonArray {
                if data is Optional<[String: Any]> {
                    output.append(data as! [String: Any])
                }else if data is Optional<Bool> {
                    output.append(data as! Bool)
                }else if data is Optional<Int32> {
                    output.append(data as! Int32)
                }else if data is Optional<Float> {
                    output.append(data as! Float)
                }else if data is Optional<String> {
                    output.append(data as! String)
                }else {
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
