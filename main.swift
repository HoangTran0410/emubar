// EmuBar: the Android emulators running on this Mac, hidden (headless) ones too, in the menu bar.
// The icon shows how many; red when one is hidden for over an hour or burning CPU (a headless phone left streaming
// video ran at ~650% CPU for 12 h unseen, 2026-10-25). The menu lists each with uptime and CPU now, and closes it.
import AppKit

struct Emu {
    let pid: Int32, avd: String, hidden: Bool, minutes: Int, cpuTime: Double
    var cpu: Double = 0                                              // % of one core, since the last poll
}

let adb = NSHomeDirectory() + "/Library/Android/sdk/platform-tools/adb"

@discardableResult
func run(_ path: String, _ args: [String], timeout: TimeInterval = 5) -> String {
    let p = Process(); p.executableURL = URL(fileURLWithPath: path); p.arguments = args
    let out = Pipe(); p.standardOutput = out; p.standardError = Pipe(); p.standardInput = FileHandle.nullDevice
    do { try p.run() } catch { return "" }
    let stop = DispatchWorkItem { if p.isRunning { p.terminate() } }   // a hung adb never holds the menu
    DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: stop)
    let data = out.fileHandleForReading.readDataToEndOfFile()        // read while it runs: ps -ww overflows the 64 KB pipe
    p.waitUntilExit(); stop.cancel()
    return String(data: data, encoding: .utf8) ?? ""
}

func seconds(_ t: String) -> Double {                                // ps time / etime: [[dd-]hh:]mm:ss[.cc]
    var days = 0.0, rest = Substring(t)
    if let d = t.firstIndex(of: "-") { days = Double(t[..<d]) ?? 0; rest = t[t.index(after: d)...] }
    return rest.split(separator: ":").reduce(0.0) { $0 * 60 + (Double($1) ?? 0) } + days * 86400
}

func list() -> [Emu] {
    run("/bin/ps", ["-wwAo", "pid=,etime=,time=,args="]).split(separator: "\n").compactMap { line in
        let f = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
        guard f.count == 4, f[3].contains("qemu-system"), let r = f[3].range(of: "-avd ") else { return nil }
        let avd = f[3][r.upperBound...].split(separator: " ").first.map(String.init) ?? "?"
        let hidden = f[3].contains("-headless") || f[3].contains("-no-window")
        return Emu(pid: Int32(f[0]) ?? 0, avd: avd, hidden: hidden, minutes: Int(seconds(String(f[1])) / 60), cpuTime: seconds(String(f[2])))
    }
}

/// The adb serial of an AVD: each emulator says its own name.
func serial(of avd: String) -> String? {
    for l in run(adb, ["devices"]).split(whereSeparator: \.isNewline) where l.hasPrefix("emulator-") {
        let s = String(l.split(separator: "\t")[0])
        if run(adb, ["-s", s, "emu", "avd", "name"]).split(whereSeparator: \.isNewline).first?.trimmingCharacters(in: .whitespacesAndNewlines) == avd { return s }
    }
    return nil
}

func close(_ e: Emu, wait: Bool = false) {
    let work = {
        if let s = serial(of: e.avd) { run(adb, ["-s", s, "emu", "kill"]) }    // a clean stop: no lock file, no crash dialog next time
        for _ in 0..<150 where kill(e.pid, 0) == 0 { usleep(200_000) }   // up to 30 s: Android shuts down first
        if kill(e.pid, 0) == 0 { kill(e.pid, SIGTERM) }
        for _ in 0..<25 where kill(e.pid, 0) == 0 { usleep(200_000) }
    }
    if wait { work() } else { DispatchQueue.global().async(execute: work) }
}

func ago(_ m: Int) -> String { m >= 60 ? "\(m / 60)h\(String(format: "%02d", m % 60))" : "\(m) phút" }

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var emus: [Emu] = []
    var last: [Int32: (Double, Date)] = [:]
    var warned = Set<Int32>()

    func applicationDidFinishLaunching(_ n: Notification) {
        item.menu = NSMenu(); item.menu!.delegate = self
        poll()
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in self.poll() }
    }

    func bad(_ e: Emu) -> Bool { (e.hidden && e.minutes >= 60) || e.cpu >= 300 }

    func poll() {
        let now = Date()
        var es = list()
        for i in es.indices {
            if let (t, d) = last[es[i].pid] { es[i].cpu = max(0, (es[i].cpuTime - t) / now.timeIntervalSince(d) * 100) }
            last[es[i].pid] = (es[i].cpuTime, now)
        }
        last = last.filter { k, _ in es.contains { $0.pid == k } }
        emus = es
        for e in es where bad(e) && !warned.contains(e.pid) {           // once per emulator: the red icon stays
            warned.insert(e.pid)
            run("/usr/bin/osascript", ["-e", "display notification \"\(e.avd): \(e.hidden ? "ẩn, " : "")\(ago(e.minutes)), \(Int(e.cpu))% CPU\" with title \"Emulator vẫn đang chạy\""])
        }
        draw()
    }

    func draw() {
        guard let b = item.button else { return }
        let img = NSImage(systemSymbolName: "iphone.gen3", accessibilityDescription: "Emulators")
        let hot = emus.contains(where: bad)
        if hot, let i = img { b.image = i.withSymbolConfiguration(.init(paletteColors: [.systemRed])) } else { b.image = img; b.image?.isTemplate = true }
        b.imagePosition = .imageLeading
        let n = emus.count, h = emus.filter(\.hidden).count
        b.title = n == 0 ? "" : h > 0 ? " \(n) (\(h) ẩn)" : " \(n)"
        b.alphaValue = n == 0 ? 0.5 : 1
    }

    func menuNeedsUpdate(_ m: NSMenu) {
        m.removeAllItems()
        if emus.isEmpty { m.addItem(withTitle: "Không có emulator nào chạy", action: nil, keyEquivalent: "") }
        for e in emus {
            let t = "\(e.avd)  ·  \(e.hidden ? "ẩn" : "có cửa sổ")  ·  \(ago(e.minutes))  ·  \(Int(e.cpu))% CPU"
            let it = NSMenuItem(title: t, action: nil, keyEquivalent: "")
            if bad(e) { it.attributedTitle = NSAttributedString(string: "⚠️ " + t, attributes: [.foregroundColor: NSColor.systemRed]) }
            let sub = NSMenu()
            let c = NSMenuItem(title: "Đóng", action: #selector(closeOne(_:)), keyEquivalent: ""); c.target = self; c.representedObject = e.pid
            sub.addItem(c)
            sub.addItem(withTitle: "pid \(e.pid)", action: nil, keyEquivalent: "")
            it.submenu = sub
            m.addItem(it)
        }
        m.addItem(.separator())
        if emus.count > 1 { let a = NSMenuItem(title: "Đóng tất cả", action: #selector(closeAll), keyEquivalent: ""); a.target = self; m.addItem(a) }
        let q = NSMenuItem(title: "Thoát EmuBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); m.addItem(q)
    }

    @objc func closeOne(_ s: NSMenuItem) { if let p = s.representedObject as? Int32, let e = emus.first(where: { $0.pid == p }) { close(e) } }
    @objc func closeAll() { emus.forEach { close($0) } }
}

// from the terminal: the same code the menu runs
let argv = CommandLine.arguments
if argv.contains("--list") { list().forEach { print($0) }; exit(0) }
if let i = argv.firstIndex(of: "--close"), i + 1 < argv.count {
    guard let e = list().first(where: { $0.avd == argv[i + 1] }) else { print("not running: \(argv[i + 1])"); exit(1) }
    close(e, wait: true); print(kill(e.pid, 0) == 0 ? "still running" : "closed \(e.avd)"); exit(0)
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
