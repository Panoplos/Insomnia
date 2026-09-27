import AppKit
import IOKit.ps
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let statusRow = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let toggleRow = NSMenuItem(title: "", action: #selector(toggle(_:)), keyEquivalent: "t")
    private let autoRow = NSMenuItem(title: "", action: #selector(toggleAutoOff(_:)), keyEquivalent: "b")
    private let loginRow = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin(_:)), keyEquivalent: "l")
    private var sleepDisabled = false
    private var autoOffOnBattery = UserDefaults.standard.object(forKey: "autoOffOnBattery") as? Bool ?? true

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        statusRow.isEnabled = false
        toggleRow.target = self
        toggleRow.keyEquivalentModifierMask = []
        autoRow.target = self
        autoRow.keyEquivalentModifierMask = []

        menu.addItem(statusRow)
        menu.addItem(toggleRow)
        menu.addItem(autoRow)
        if #available(macOS 13.0, *) {
            loginRow.target = self
            loginRow.keyEquivalentModifierMask = []
            menu.addItem(loginRow)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Insomnia", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        refresh()
        watchPowerSource()
        enforcePowerPolicy()
    }

    // Re-read real state every time the menu opens (state can change via pmset in Terminal).
    func menuNeedsUpdate(_ menu: NSMenu) { refresh() }

    private func refresh() {
        sleepDisabled = Self.readSleepDisabled()
        statusRow.title = sleepDisabled ? "🌙 Insomnia: ON" : "💤 Insomnia: OFF"
        toggleRow.title = sleepDisabled ? "Allow Sleep Again" : "Prevent Sleep (Even Lid Closed)"
        autoRow.title = "Auto-Sleep on Battery"
        autoRow.state = autoOffOnBattery ? .on : .off
        if #available(macOS 13.0, *) {
            loginRow.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }

        let battery = Self.onBattery()
        let button = statusItem.button
        button?.image = NSImage(systemSymbolName: sleepDisabled ? "moon.stars.fill" : "moon.zzz",
                               accessibilityDescription: sleepDisabled ? "Sleep disabled" : "Sleep allowed")
        // Dimmed only while on battery AND sleeping normally.
        button?.appearsDisabled = battery && !sleepDisabled
    }

    // With "Auto-Sleep on Battery" on (the default), insomnia follows the
    // charger: on battery -> sleep allowed, on AC -> sleep prevented.
    private func enforcePowerPolicy() {
        guard autoOffOnBattery else { return }
        let target = Self.onBattery() ? 0 : 1
        guard sleepDisabled != (target == 1) else { return }
        applySleepDisabled(target)
        refresh()
    }

    @objc private func toggleAutoOff(_ sender: NSMenuItem) {
        autoOffOnBattery.toggle()
        UserDefaults.standard.set(autoOffOnBattery, forKey: "autoOffOnBattery")
        if autoOffOnBattery { enforcePowerPolicy() }
        refresh()
    }

    @objc private func toggleLogin(_ sender: NSMenuItem) {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                } else {
                    try SMAppService.mainApp.register()
                }
            } catch {
                NSSound.beep() // registration failed (e.g. app not in /Applications)
            }
            refresh()
        }
    }

    private func watchPowerSource() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let source = IOPSNotificationCreateRunLoopSource({ rawContext in
            guard let rawContext else { return }
            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(rawContext).takeUnretainedValue()
            DispatchQueue.main.async { appDelegate.enforcePowerPolicy() }
        }, context).takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    static func onBattery() -> Bool {
        let blob = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(blob).takeRetainedValue() as [CFTypeRef]
        for source in sources {
            let description = IOPSGetPowerSourceDescription(blob, source).takeUnretainedValue() as! [String: Any]
            switch description[kIOPSPowerSourceStateKey] as? String {
            case kIOPSBatteryPowerValue: return true
            case kIOPSACPowerValue: return false
            default: continue
            }
        }
        return false
    }

    static func readSleepDisabled() -> Bool {
        let output = run("/usr/bin/pmset", ["-g"])
        for line in output.split(separator: "\n") where line.contains("SleepDisabled") {
            return line.split(whereSeparator: { $0 == " " || $0 == "\t" }).last == "1"
        }
        return false
    }

    @objc private func toggle(_ sender: NSMenuItem) {
        applySleepDisabled(sleepDisabled ? 0 : 1)
    }

    // Toggles sleep, and on first use installs the sudoers rule (one password
    // prompt). Used by both the manual toggle and the battery policy, so the
    // policy also gets a prompt instead of failing silently.
    private func applySleepDisabled(_ target: Int) {
        if sudoDisableSleep(target) { refresh(); return }

        // Rule allows exactly these two pmset invocations, nothing else.
        // No backslashes or double quotes in `shell`, so it drops into Applescript unescaped.
        let rule = "\(NSUserName()) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0"
        let shell = "echo '\(rule)' > /etc/sudoers.d/insomnia && chown root:wheel /etc/sudoers.d/insomnia && chmod 0440 /etc/sudoers.d/insomnia && (visudo -cf /etc/sudoers.d/insomnia || rm -f /etc/sudoers.d/insomnia)"
        let script = "do shell script \"\(shell)\" with administrator privileges with prompt \"Insomnia needs one-time admin access to toggle sleep without a password.\""
        let osa = Process()
        osa.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        osa.arguments = ["-e", script]
        osa.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                _ = self?.sudoDisableSleep(target)
                self?.refresh()
            }
        }
        try? osa.run()
    }

    private func sudoDisableSleep(_ target: Int) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        p.arguments = ["-n", "/usr/bin/pmset", "-a", "disablesleep", "\(target)"]
        try? p.run()
        p.waitUntilExit()
        return p.terminationStatus == 0
    }
}

private func run(_ path: String, _ args: [String]) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    let pipe = Pipe()
    p.standardOutput = pipe
    try? p.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return String(decoding: data, as: UTF8.self)
}

// CLI self-checks: `Insomnia --check` prints the sleep state, `--battery`
// prints the power source, then exits.
if CommandLine.arguments.contains("--check") {
    print(AppDelegate.readSleepDisabled() ? "SleepDisabled=1 (insomnia ON)" : "SleepDisabled=0 (insomnia OFF)")
    exit(0)
}
if CommandLine.arguments.contains("--battery") {
    print(AppDelegate.onBattery() ? "on battery" : "on AC power")
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
