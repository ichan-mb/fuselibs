import SwiftUI

/// Sample SwiftUI view used by the Fuse.PlatformView manual test app.
struct SampleSwiftUIView: View {
    @EnvironmentObject var data: PlatformViewData
    @State private var lastCommand = ""

    var body: some View {
        VStack(spacing: 8) {
            Text(data.getString)
                .font(.headline)

            Text("count: \(data.getInteger) double: \(data.getDouble)")
                .font(.caption)

            if let name = data.get["name"] as? String {
                Text("profile: \(name)")
                    .font(.caption)
            }

            Button("Native tap") {
                data.callback("tapped", "{\"source\":\"swift\"}")
            }

            Text(lastCommand)
                .font(.caption2)
        }
        .padding()
        .onAppear {
            data.onCommand = { command, arguments in
                lastCommand = "\(command) \(arguments)"
                if command == "bump" {
                    data.getInteger += 1
                }
            }
        }
    }
}

/// Registration bootstrap: Fuse.PlatformView looks up this exported C symbol on first use.
@_cdecl("FusePlatformViewSetup")
public func fusePlatformViewSetup() {
    PlatformViewRegistry.register("SampleView", SampleSwiftUIView())
}
