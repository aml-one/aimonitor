import Foundation
import Darwin
import IOKit

// For proc_pid_info / PROC_PIDTASKINFO
import Darwin.sys.proc_info
@_silgen_name("proc_pidinfo")
func proc_pidinfo_swift(_ pid: Int32, _ flavor: Int32, _ arg: UInt64,
                        _ buffer: UnsafeMutableRawPointer, _ buffersize: Int32) -> Int32

class SystemMonitor: ObservableObject {

    // MARK: - CPU
    @Published var cpuUsage: Double = 0
    @Published var cpuHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var cpuCoreCount: Int = 0

    // MARK: - Memory
    @Published var memoryUsedGB: Double = 0
    @Published var memoryTotalGB: Double = 0
    @Published var memoryHistory: [Double] = Array(repeating: 0, count: 60)

    // MARK: - GPU
    @Published var gpuUsage: Double = 0
    @Published var gpuHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var gpuAvailable: Bool = false

    // MARK: - Self (this app's own process)
    @Published var selfCPU: Double = 0          // 0‥1 fraction of one core
    @Published var selfMemoryMB: Double = 0     // resident set in MB
    @Published var selfCPUHistory: [Double]  = Array(repeating: 0, count: 60)
    @Published var selfMemHistory: [Double]  = Array(repeating: 0, count: 60)

    private var prevSelfUserNS:   UInt64 = 0
    private var prevSelfSystemNS: UInt64 = 0
    private var prevSelfTime:     Double = 0

    private var timer: Timer?
    private var prevCpuInfo: processor_info_array_t?
    private var prevNumCpuInfo: mach_msg_type_number_t = 0

    init() {
        var cores: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname("hw.logicalcpu", &cores, &size, nil, 0)
        cpuCoreCount = Int(cores)

        var totalMem: UInt64 = 0
        var memSize = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalMem, &memSize, nil, 0)
        memoryTotalGB = Double(totalMem) / 1_073_741_824

        startMonitoring()

        // Restore reduced-updates preference
        if UserDefaults.standard.bool(forKey: "reducedUpdates") {
            setInterval(1.0)
        }
    }

    deinit {
        timer?.invalidate()
        if let prev = prevCpuInfo {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: prev),
                          vm_size_t(MemoryLayout<integer_t>.stride * Int(prevNumCpuInfo)))
        }
    }

    func startMonitoring() {
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.update()
        }
    }

    func setInterval(_ interval: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.update()
        }
    }

    private func update() {
        let cpu  = readCPUUsage()
        let mem  = readMemoryUsage()
        let gpu  = readGPUUsage()
        let self_ = readSelfUsage()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.cpuUsage = cpu
            self.cpuHistory.append(cpu)
            if self.cpuHistory.count > 60 { self.cpuHistory.removeFirst() }

            self.memoryUsedGB = mem
            let fraction = self.memoryTotalGB > 0 ? mem / self.memoryTotalGB : 0
            self.memoryHistory.append(fraction)
            if self.memoryHistory.count > 60 { self.memoryHistory.removeFirst() }

            self.gpuUsage = gpu
            self.gpuAvailable = gpu >= 0
            self.gpuHistory.append(max(gpu, 0))
            if self.gpuHistory.count > 60 { self.gpuHistory.removeFirst() }

            self.selfCPU = self_.cpu
            self.selfCPUHistory.append(self_.cpu)
            if self.selfCPUHistory.count > 60 { self.selfCPUHistory.removeFirst() }

            self.selfMemoryMB = self_.memMB
            let memFrac = self.memoryTotalGB > 0 ? (self_.memMB / 1024) / self.memoryTotalGB : 0
            self.selfMemHistory.append(memFrac)
            if self.selfMemHistory.count > 60 { self.selfMemHistory.removeFirst() }
        }
    }

    // MARK: - CPU

    private func readCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                  &numCPUs, &cpuInfo, &numCpuInfo) == KERN_SUCCESS,
              let info = cpuInfo else { return 0 }

        var totalUsage = 0.0
        var validCores = 0

        for i in 0..<Int(numCPUs) {
            let base = Int(CPU_STATE_MAX) * i
            let user   = Double(info[base + Int(CPU_STATE_USER)])
            let system = Double(info[base + Int(CPU_STATE_SYSTEM)])
            let nice   = Double(info[base + Int(CPU_STATE_NICE)])
            let idle   = Double(info[base + Int(CPU_STATE_IDLE)])

            if let prev = prevCpuInfo {
                let pUser   = Double(prev[base + Int(CPU_STATE_USER)])
                let pSystem = Double(prev[base + Int(CPU_STATE_SYSTEM)])
                let pNice   = Double(prev[base + Int(CPU_STATE_NICE)])
                let pIdle   = Double(prev[base + Int(CPU_STATE_IDLE)])

                let total = (user - pUser) + (system - pSystem) + (nice - pNice) + (idle - pIdle)
                if total > 0 {
                    totalUsage += (total - (idle - pIdle)) / total
                    validCores += 1
                }
            }
        }

        if let prev = prevCpuInfo {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: prev),
                          vm_size_t(MemoryLayout<integer_t>.stride * Int(prevNumCpuInfo)))
        }
        prevCpuInfo = info
        prevNumCpuInfo = numCpuInfo

        return validCores > 0 ? totalUsage / Double(validCores) : 0
    }

    // MARK: - Memory

    private func readMemoryUsage() -> Double {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let kerr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kerr == KERN_SUCCESS else { return 0 }

        let page = Double(vm_kernel_page_size)
        let active     = Double(stats.active_count) * page
        let wired      = Double(stats.wire_count) * page
        let compressed = Double(stats.compressor_page_count) * page
        return (active + wired + compressed) / 1_073_741_824
    }

    // MARK: - GPU

    private func readGPUUsage() -> Double {
        if let v = queryAccelerator("IOAccelerator") { return v }
        if let v = queryAccelerator("AGXAccelerator") { return v }
        return -1  // unavailable
    }

    private func queryAccelerator(_ name: String) -> Double? {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching(name)
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &props,
                                                    kCFAllocatorDefault, 0) == kIOReturnSuccess,
                  let dict = props?.takeRetainedValue() as? [String: Any],
                  let perf = dict["PerformanceStatistics"] as? [String: Any] else { continue }

            for key in ["Device Utilization %", "GPU Activity(%)"] {
                if let v = perf[key] as? Double { return v / 100.0 }
                if let v = perf[key] as? Int    { return Double(v) / 100.0 }
            }
        }
        return nil
    }

    // MARK: - Self-process stats

    private func readSelfUsage() -> (cpu: Double, memMB: Double) {
        let pid = getpid()

        // Memory via task_info (doesn't need entitlements)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) /
                    mach_msg_type_number_t(MemoryLayout<natural_t>.size)
        let memMB: Double = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { ptr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), ptr, &count)
            }
        } == KERN_SUCCESS ? Double(info.resident_size) / 1_048_576 : 0

        // CPU% via proc_pidinfo – cumulative ns, so diff across samples
        var ti = proc_taskinfo()
        let ret = withUnsafeMutablePointer(to: &ti) {
            proc_pidinfo_swift(pid, PROC_PIDTASKINFO, 0,
                               UnsafeMutableRawPointer($0),
                               Int32(MemoryLayout<proc_taskinfo>.size))
        }
        var cpu = 0.0
        if ret > 0 {
            let userNS   = ti.pti_total_user
            let systemNS = ti.pti_total_system
            let now      = Date().timeIntervalSinceReferenceDate
            if prevSelfTime > 0 {
                let elapsedNS = (now - prevSelfTime) * 1_000_000_000
                let usedNS    = Double((userNS - prevSelfUserNS) + (systemNS - prevSelfSystemNS))
                if elapsedNS > 0 { cpu = usedNS / elapsedNS }
            }
            prevSelfUserNS   = userNS
            prevSelfSystemNS = systemNS
            prevSelfTime     = now
        }
        return (cpu, memMB)
    }
}
