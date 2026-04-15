import Flutter
import UIKit

// Native iOS 16+ UIPasteControl wrapper that eliminates the
// "Paste from other apps" permission prompt. When the system
// paste control is tapped, the host UIView's paste(itemProviders:)
// method is invoked and the clipboard text is forwarded to Dart
// via a shared method channel.

@available(iOS 16.0, *)
class PasteButtonHostView: UIView {
    private let channel: FlutterMethodChannel

    init(frame: CGRect, channel: FlutterMethodChannel) {
        self.channel = channel
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = true

        let config = UIPasteControl.Configuration()
        config.displayMode = .iconAndLabel
        config.cornerStyle = .capsule
        config.baseForegroundColor = UIColor(red: 1.0, green: 0.84, blue: 0.3, alpha: 1.0)
        config.baseBackgroundColor = UIColor(red: 1.0, green: 0.84, blue: 0.3, alpha: 0.15)

        let pasteControl = UIPasteControl(configuration: config)
        pasteControl.target = self
        pasteControl.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(pasteControl)
        NSLayoutConstraint.activate([
            pasteControl.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            pasteControl.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            pasteControl.topAnchor.constraint(equalTo: self.topAnchor),
            pasteControl.bottomAnchor.constraint(equalTo: self.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var pasteConfiguration: UIPasteConfiguration? {
        get {
            return UIPasteConfiguration(acceptableTypeIdentifiers: [
                "public.utf8-plain-text",
                "public.plain-text",
                "public.text"
            ])
        }
        set {}
    }

    override func paste(itemProviders: [NSItemProvider]) {
        guard let provider = itemProviders.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            return
        }
        provider.loadObject(ofClass: NSString.self) { [weak self] obj, _ in
            guard let text = obj as? String else { return }
            DispatchQueue.main.async {
                self?.channel.invokeMethod("onPaste", arguments: text)
            }
        }
    }
}

class PasteButtonPlatformView: NSObject, FlutterPlatformView {
    private let _view: UIView

    init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "memoyo/paste_button_\(viewId)", binaryMessenger: messenger)
        if #available(iOS 16.0, *) {
            _view = PasteButtonHostView(frame: frame, channel: channel)
        } else {
            // Fallback: empty view on iOS < 16. Dart side should hide it.
            _view = UIView(frame: frame)
        }
        super.init()
    }

    func view() -> UIView { _view }
}

class PasteButtonFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return PasteButtonPlatformView(frame: frame, viewIdentifier: viewId, arguments: args, messenger: messenger)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
