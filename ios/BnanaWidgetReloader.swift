import Darwin
import Foundation
import WidgetKit

@objc(BnanaWidgetReloader)
public final class BnanaWidgetReloader: NSObject {
    private static var directorySource: DispatchSourceFileSystemObject?
    private static var pendingReload: DispatchWorkItem?

    @objc(watchDirectory:)
    public static func watchDirectory(_ path: String) {
        guard directorySource == nil else { return }

        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: .write,
            queue: .main
        )

        source.setEventHandler {
            pendingReload?.cancel()

            let reload = DispatchWorkItem {
                reloadAnalytics()
            }

            pendingReload = reload
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: reload)
        }

        source.setCancelHandler {
            close(descriptor)
        }

        directorySource = source
        source.resume()
    }

    @objc public static func reloadAnalytics() {
        WidgetCenter.shared.reloadTimelines(ofKind: "com.aayushmau5.bnana.analytics")
    }
}
