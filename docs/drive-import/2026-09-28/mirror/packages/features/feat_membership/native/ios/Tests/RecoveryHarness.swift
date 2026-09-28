import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

// TEST-ONLY backends: no encryption or Keychain behavior is claimed by this harness.
final class TestBlob: RecoveryBlobStorage {
    let namespace: String
    var bytes: Data?
    var unreadable = false
    var failInsert = false
    var failReplaceBefore = false
    var failReplaceAfter = false
    init(_ namespace: String = "com.africlub.test") { self.namespace = namespace }
    func read() throws -> Data? { if unreadable { throw RecoveryFailure("recovery_device_locked") }; return bytes }
    func insert(_ value: Data) throws {
        if failInsert { throw RecoveryFailure() }
        try requireRecovery(bytes == nil); bytes = value
    }
    func replace(_ value: Data) throws {
        if failReplaceBefore { throw RecoveryFailure() }
        try requireRecovery(bytes != nil); bytes = value
        if failReplaceAfter { throw RecoveryFailure() }
    }
}
final class FileTestBlob: RecoveryBlobStorage {
    let namespace = "com.africlub.test"
    let path: URL
    init(_ root: String) { path = URL(fileURLWithPath: root + "/UNPROTECTED_TEST_BACKEND") }
    func read() throws -> Data? { FileManager.default.fileExists(atPath: path.path) ? try Data(contentsOf: path) : nil }
    func insert(_ value: Data) throws { try requireRecovery(try read() == nil); try value.write(to: path, options: .atomic) }
    func replace(_ value: Data) throws { try requireRecovery(try read() != nil); try value.write(to: path, options: .atomic) }
}
final class Toggle: @unchecked Sendable { private let mutex = NSLock(); private var v = true
    var value: Bool { get { mutex.lock(); defer {mutex.unlock()}; return v } set {mutex.lock();v=newValue;mutex.unlock()} }
}
final class Counter: @unchecked Sendable { private let mutex = NSLock(); private var n = 0
    func add() {mutex.lock(); n += 1; mutex.unlock()}; var count: Int {mutex.lock();defer{mutex.unlock()};return n}
}
struct HarnessFailure: Error { let message: String }
func check(_ c: Bool, _ m: String = "assertion") throws { if !c {throw HarnessFailure(message: m)} }
func fails(_ code: String? = nil, _ work: () throws -> Void) throws {
    do {try work()} catch let e as RecoveryFailure { if let code {try check(e.code == code, "expected \(code), got \(e.code)")};return }
    throw HarnessFailure(message: "expected failure")
}
let user = "20000000-0000-4000-8000-000000000001"
let scope = "africlub-membership-v1:24:\(user)"
let otherScope = "africlub-payment-handoff-v1:24:\(user)"
let app = "com.africlub.test"
func temporary() throws -> String {
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).resolvingSymlinksInPath().appendingPathComponent("africlub-swift-" + UUID().uuidString).path
    try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    return root
}
struct Fixture {
    let root: String
    let blob: TestBlob
    let store: NativeRecoveryStore
    let owner = RecoveryProtocol.newID()
    let request = RecoveryProtocol.newID()
    init(fault: @escaping (String) throws -> Void = { _ in }) throws {
        root = try temporary(); blob = TestBlob(); store = try NativeRecoveryStore(root: root, applicationID: app, storage: blob, fault: fault)
    }
    func acquire(_ s: String = scope) throws -> String { guard let v = try store.acquire(owner: owner, scope: s, acquisitionID: request) else {throw HarnessFailure(message:"busy")};return v }
    func close() {try? store.close(owner: owner);try? FileManager.default.removeItem(atPath: root)}
}

@main struct RecoveryHarness {
    static func child() throws {
        let root = CommandLine.arguments[2], store = try NativeRecoveryStore(root: root, applicationID: app, storage: FileTestBlob(root))
        let owner = RecoveryProtocol.newID(), request = RecoveryProtocol.newID()
        let lease = try store.acquire(owner: owner, scope: scope, acquisitionID: request)
        if CommandLine.arguments[1] == "child-probe" {print(lease == nil ? "BUSY" : "ACQUIRED");try store.close(owner: owner);return}
        guard let lease else {throw HarnessFailure(message:"child busy")}
        _ = try store.compareAndSet(owner: owner, scope: scope, lease: lease, expected: nil, value: "reserved-by-child")
        try check(FileManager.default.createFile(atPath: root + "/child-ready", contents: Data()))
        while true {Thread.sleep(forTimeInterval: 1)}
    }
    static func main() throws {
        if CommandLine.arguments.count > 2 && CommandLine.arguments[1].hasPrefix("child-") {try child();return}
        var results: [[String: Any]] = []
        func test(_ name: String, _ work: () throws -> Void) {
            do {try work();results.append(["name":name,"passed":true])}
            catch {results.append(["name":name,"passed":false,"error":String(describing:error)])}
        }
        let install = RecoveryProtocol.newID()
        let snapshot = RecoverySnapshot(applicationID: app, installationID: install, revision: 3, values:[scope:"pending",otherScope:"opened"])
        test("binary snapshot roundtrip") {try check(try RecoverySnapshotCodec.decode(RecoverySnapshotCodec.encode(snapshot)) == snapshot)}
        test("deterministic scope order") {
            let v = RecoverySnapshot(applicationID: app,installationID:install,revision:3,values:[otherScope:"opened",scope:"pending"])
            try check(try RecoverySnapshotCodec.encode(v) == RecoverySnapshotCodec.encode(snapshot))
        }
        test("unicode value roundtrip") {
            let v = RecoverySnapshot(applicationID: app,installationID:install,revision:0,values:[scope:"Kigali ⚽\né"])
            try check(try RecoverySnapshotCodec.decode(RecoverySnapshotCodec.encode(v)) == v)
        }
        test("max 2048 UTF8 bytes accepted") {try RecoveryProtocol.value(String(repeating:"é",count:1024))}
        test("UTF8 byte bound rather than character count") {try fails("recovery_invalid_value"){try RecoveryProtocol.value(String(repeating:"é",count:1025))}}
        test("empty value rejected") {try fails("recovery_invalid_value"){try RecoveryProtocol.value("")}}
        for (name,value) in [("leading zero club","africlub-membership-v1:024:"+user),("zero club","africlub-membership-v1:0:"+user),("unknown scope","africlub-other-v1:24:"+user),("suffix newline",scope+"\n"),("uppercase uuid",scope.replacingOccurrences(of:"8000",with:"A000")),("path traversal","../../"+scope)] {
            test("scope rejects "+name) {try fails("recovery_invalid_scope"){try RecoveryProtocol.scope(value)}}
        }
        test("identifier rejects extra suffix") {try fails {try RecoveryProtocol.identifier(install+"\n")}}
        test("snapshot refuses trailing bytes") {var b=try RecoverySnapshotCodec.encode(snapshot);b.append(0);try fails("recovery_corrupt"){_ = try RecoverySnapshotCodec.decode(b)}}
        test("all truncation positions fail") {let b=try RecoverySnapshotCodec.encode(snapshot);for n in 0..<b.count {try fails("recovery_corrupt"){_ = try RecoverySnapshotCodec.decode(b.prefix(n))}}}
        test("version rejected") {var b=try RecoverySnapshotCodec.encode(snapshot);b[7]=2;try fails("recovery_corrupt"){_ = try RecoverySnapshotCodec.decode(b)}}
        test("oversized snapshot rejected") {try fails("recovery_corrupt"){_ = try RecoverySnapshotCodec.decode(Data(repeating:0,count:160001))}}
        test("negative revision encode rejected") {try fails {_ = try RecoverySnapshotCodec.encode(.init(applicationID:app,installationID:install,revision:-1,values:[:]))}}
        test("duplicate key in binary snapshot rejected") {
            let one=try RecoverySnapshotCodec.encode(.init(applicationID:app,installationID:install,revision:0,values:[scope:"one"]))
            let header=8+4+app.utf8.count+4+36+8+4
            var b=one;b[header-1]=2;b.append(one.suffix(from:header));try fails("recovery_corrupt"){_ = try RecoverySnapshotCodec.decode(b)}
        }
        test("malformed UTF8 rejected") {var b=try RecoverySnapshotCodec.encode(snapshot);b[12]=255;try fails("recovery_corrupt"){_ = try RecoverySnapshotCodec.decode(b)}}
        test("fresh store empty and explicit initialization") {let f=try Fixture();defer{f.close()};let t=try f.acquire();try check(try f.store.load(owner:f.owner,scope:scope,lease:t)==nil);try check(f.blob.bytes != nil)}
        test("CAS success and revision") {let f=try Fixture();defer{f.close()};let t=try f.acquire();try check(try f.store.compareAndSet(owner:f.owner,scope:scope,lease:t,expected:nil,value:"pending"));try check(try RecoverySnapshotCodec.decode(f.blob.bytes!).revision == 1)}
        test("CAS false is only expected value conflict") {let f=try Fixture();defer{f.close()};let t=try f.acquire();let b=f.blob.bytes;try check(try !f.store.compareAndSet(owner:f.owner,scope:scope,lease:t,expected:"other",value:"pending"));try check(f.blob.bytes==b)}
        test("CAS compares exact UTF8 not normalized Unicode") {
            let f=try Fixture();defer{f.close()};let t=try f.acquire()
            _ = try f.store.compareAndSet(owner:f.owner,scope:scope,lease:t,expected:nil,value:"é")
            try check(try !f.store.compareAndSet(owner:f.owner,scope:scope,lease:t,expected:"e\u{0301}",value:"changed"))
            try check(try f.store.load(owner:f.owner,scope:scope,lease:t)=="é")
        }
        test("hard-linked lock refused") {
            let f=try Fixture();defer{f.close()};let path=f.root+"/recovery.lock"
            try check(FileManager.default.createFile(atPath:path,contents:Data(),attributes:[.posixPermissions:0o600]))
            try FileManager.default.linkItem(atPath:path,toPath:f.root+"/lock-alias")
            try fails("recovery_lock_lost"){_ = try f.acquire()}
        }
        test("private anchor permission enforced") {
            let f=try Fixture();defer{f.close()};let t=try f.acquire()
            try FileManager.default.setAttributes([.posixPermissions:0o644],ofItemAtPath:f.root+"/installation.anchor")
            try fails("recovery_lock_lost"){_ = try f.store.load(owner:f.owner,scope:scope,lease:t)}
        }
        test("CAS update preserves other scopes") {let f=try Fixture();defer{f.close()};let t=try f.acquire();_ = try f.store.compareAndSet(owner:f.owner,scope:scope,lease:t,expected:nil,value:"one");try f.store.release(owner:f.owner,scope:scope,acquisitionID:f.request);let t2=try f.acquire(otherScope);_ = try f.store.compareAndSet(owner:f.owner,scope:otherScope,lease:t2,expected:nil,value:"two");try check(try RecoverySnapshotCodec.decode(f.blob.bytes!).values.count==2)}
        test("lock required before read") {let f=try Fixture();defer{f.close()};try fails("recovery_lock_required"){_ = try f.store.load(owner:f.owner,scope:scope,lease:install)}}
        test("wrong owner denied") {let f=try Fixture();defer{f.close()};let t=try f.acquire();try fails("recovery_lock_required"){_ = try f.store.load(owner:install,scope:scope,lease:t)}}
        test("wrong scope denied") {let f=try Fixture();defer{f.close()};let t=try f.acquire();try fails("recovery_lock_required"){_ = try f.store.load(owner:f.owner,scope:otherScope,lease:t)}}
        test("wrong token denied") {let f=try Fixture();defer{f.close()};_ = try f.acquire();try fails("recovery_lock_required"){_ = try f.store.load(owner:f.owner,scope:scope,lease:install)}}
        test("same acquisition recovers same token") {let f=try Fixture();defer{f.close()};try check(try f.acquire()==f.acquire())}
        test("different acquisition remains busy") {let f=try Fixture();defer{f.close()};_ = try f.acquire();try check(try f.store.acquire(owner:f.owner,scope:scope,acquisitionID:install)==nil)}
        test("other engine remains busy") {let f=try Fixture();defer{f.close()};_ = try f.acquire();let other=try NativeRecoveryStore(root:f.root,applicationID:app,storage:f.blob);try check(try other.acquire(owner:install,scope:scope,acquisitionID:install)==nil)}
        test("stale release cannot unlock later acquisition") {let f=try Fixture();defer{f.close()};_ = try f.acquire();try f.store.release(owner:f.owner,scope:scope,acquisitionID:f.request);let t=try f.store.acquire(owner:f.owner,scope:scope,acquisitionID:install)!;try f.store.release(owner:f.owner,scope:scope,acquisitionID:f.request);try check(try f.store.load(owner:f.owner,scope:scope,lease:t)==nil)}
        test("owner dispose releases no state") {let f=try Fixture();defer{f.close()};let t=try f.acquire();_ = try f.store.compareAndSet(owner:f.owner,scope:scope,lease:t,expected:nil,value:"reserved");try f.store.close(owner:f.owner);let t2=try f.acquire();try check(try f.store.load(owner:f.owner,scope:scope,lease:t2)=="reserved")}
        test("missing blob blocks without reset") {let f=try Fixture();defer{f.close()};_ = try f.acquire();try f.store.close(owner:f.owner);f.blob.bytes=nil;try fails("recovery_state_missing"){_ = try f.acquire()};try check(f.blob.bytes==nil)}
        test("missing anchor blocks without reset") {let f=try Fixture();defer{f.close()};_ = try f.acquire();try f.store.close(owner:f.owner);let old=f.blob.bytes;try FileManager.default.removeItem(atPath:f.root+"/installation.anchor");try fails("recovery_state_missing"){_ = try f.acquire()};try check(f.blob.bytes==old)}
        test("corrupt blob blocks without replacement") {let f=try Fixture();defer{f.close()};_ = try f.acquire();try f.store.close(owner:f.owner);f.blob.bytes=Data([1,2]);try fails("recovery_corrupt"){_ = try f.acquire()};try check(f.blob.bytes==Data([1,2]))}
        test("wrong installation binding rejected") {let f=try Fixture();defer{f.close()};let t=try f.acquire();f.blob.bytes=try RecoverySnapshotCodec.encode(.init(applicationID:app,installationID:install,revision:0,values:[:]));try fails("recovery_key_conflict"){_ = try f.store.load(owner:f.owner,scope:scope,lease:t)}}
        test("wrong application binding rejected") {let f=try Fixture();defer{f.close()};let t=try f.acquire();let old=try RecoverySnapshotCodec.decode(f.blob.bytes!);f.blob.bytes=try RecoverySnapshotCodec.encode(.init(applicationID:"com.other.app",installationID:old.installationID,revision:0,values:[:]));try fails("recovery_key_conflict"){_ = try f.store.load(owner:f.owner,scope:scope,lease:t)}}
        test("init namespace mismatch rejected") {let root=try temporary();defer{try? FileManager.default.removeItem(atPath:root)};try fails("recovery_key_conflict"){_ = try NativeRecoveryStore(root:root,applicationID:app,storage:TestBlob("com.other.app"))}}
        test("no eviction at scope limit") {
            let f=try Fixture();defer{f.close()};let t=try f.acquire(),old=try RecoverySnapshotCodec.decode(f.blob.bytes!)
            let values=Dictionary(uniqueKeysWithValues:(1...64).map{("africlub-membership-v1:\($0):"+user,"pending")})
            f.blob.bytes=try RecoverySnapshotCodec.encode(.init(applicationID:app,installationID:old.installationID,revision:0,values:values));try f.store.close(owner:f.owner)
            let s="africlub-membership-v1:65:"+user, t2=try f.acquire(s)
            try fails("recovery_capacity"){_ = try f.store.compareAndSet(owner:f.owner,scope:s,lease:t2,expected:nil,value:"new")}
            try check(try RecoverySnapshotCodec.decode(f.blob.bytes!).values==values);_ = t
        }
        test("revision overflow fails without write") {let f=try Fixture();defer{f.close()};let t=try f.acquire(),old=try RecoverySnapshotCodec.decode(f.blob.bytes!);f.blob.bytes=try RecoverySnapshotCodec.encode(.init(applicationID:app,installationID:old.installationID,revision:Int64.max,values:[:]));try fails("recovery_capacity"){_ = try f.store.compareAndSet(owner:f.owner,scope:scope,lease:t,expected:nil,value:"new")}}
        test("write failure before replacement is conservatively unknown") {let f=try Fixture();defer{f.close()};let t=try f.acquire();f.blob.failReplaceBefore=true;try fails("recovery_write_unknown"){_ = try f.store.compareAndSet(owner:f.owner,scope:scope,lease:t,expected:nil,value:"new")};try check(try f.store.load(owner:f.owner,scope:scope,lease:t)==nil)}
        test("lost reply after replacement preserves reservation") {let f=try Fixture();defer{f.close()};let t=try f.acquire();f.blob.failReplaceAfter=true;try fails("recovery_write_unknown"){_ = try f.store.compareAndSet(owner:f.owner,scope:scope,lease:t,expected:nil,value:"reserved")};try check(try f.store.load(owner:f.owner,scope:scope,lease:t)=="reserved")}
        test("interrupted initialization never silently resets") {let f=try Fixture(fault:{stage in if stage=="after_anchor"{throw RecoveryFailure()}});defer{f.close()};try fails("recovery_write_unknown"){_ = try f.acquire()};try fails("recovery_state_missing"){_ = try f.acquire()}}
        test("reply loss after insertion recovers existing snapshot") {let f=try Fixture(fault:{stage in if stage=="after_insert"{throw RecoveryFailure()}});defer{f.close()};try fails("recovery_write_unknown"){_ = try f.acquire()};_ = try f.acquire()}
        test("locked backing storage is not missing state") {let f=try Fixture();defer{f.close()};let t=try f.acquire();f.blob.unreadable=true;try fails("recovery_device_locked"){_ = try f.store.load(owner:f.owner,scope:scope,lease:t)}}
        test("replaced lock inode detected") {let f=try Fixture();defer{f.close()};let t=try f.acquire();try FileManager.default.moveItem(atPath:f.root+"/recovery.lock",toPath:f.root+"/old.lock");try check(FileManager.default.createFile(atPath:f.root+"/recovery.lock",contents:Data(),attributes:[.posixPermissions:0o600]));try fails("recovery_lock_lost"){_ = try f.store.load(owner:f.owner,scope:scope,lease:t)}}
        test("symlink root rejected") {let f=try Fixture();defer{f.close()};let alias=f.root+"-link";try FileManager.default.createSymbolicLink(atPath:alias,withDestinationPath:f.root);defer{try? FileManager.default.removeItem(atPath:alias)};try fails("recovery_directory_unavailable"){_ = try NativeRecoveryStore(root:alias,applicationID:app,storage:f.blob)}}
        test("symlink lock rejected") {let f=try Fixture();defer{f.close()};try FileManager.default.createSymbolicLink(atPath:f.root+"/recovery.lock",withDestinationPath:"/tmp/africlub-not-opened");try fails("recovery_directory_unavailable"){_ = try f.acquire()}}
        test("world-readable root rejected") {let f=try Fixture();defer{f.close()};try FileManager.default.setAttributes([.posixPermissions:0o755],ofItemAtPath:f.root);try fails("recovery_directory_unavailable"){_ = try NativeRecoveryStore(root:f.root,applicationID:app,storage:f.blob)}}
        test("dispatch roundtrip uses exact channel shapes") {let f=try Fixture();defer{f.close()};let d=try NativeRecoveryDispatcher(store:f.store,owner:f.owner,usable:{true});let a=try d.invoke("tryAcquire",arguments:["scope":scope,"acquisitionId":f.request]);try check(a["busy"] as? Bool == false);let t=a["lease"] as! String;let set=try d.invoke("compareAndSet",arguments:["scope":scope,"lease":t,"expected":NSNull(),"value":"pending"]);try check(set["updated"] as? Bool == true);try check(try d.invoke("load",arguments:["scope":scope,"lease":t])["value"] as? String == "pending");try d.dispose()}
        for method in ["clear","reset","delete","rotateKey","dial","pay","credentialImport"] {test("dispatch rejects "+method){let f=try Fixture();defer{f.close()};let d=try NativeRecoveryDispatcher(store:f.store,usable:{true});try fails("recovery_invalid_request"){_ = try d.invoke(method,arguments:[:])}}}
        test("dispatch rejects request owner override") {let f=try Fixture();defer{f.close()};let d=try NativeRecoveryDispatcher(store:f.store,usable:{true});try fails("recovery_invalid_request"){_ = try d.invoke("tryAcquire",arguments:["scope":scope,"acquisitionId":f.request,"owner":f.owner])}}
        test("dispatch rejects NSNull scope") {let f=try Fixture();defer{f.close()};let d=try NativeRecoveryDispatcher(store:f.store,usable:{true});try fails("recovery_invalid_request"){_ = try d.invoke("tryAcquire",arguments:["scope":NSNull(),"acquisitionId":f.request])}}
        test("dispatch rejects nonstring CAS value") {let f=try Fixture();defer{f.close()};let d=try NativeRecoveryDispatcher(store:f.store,owner:f.owner,usable:{true});let t=try f.acquire();try fails("recovery_invalid_request"){_ = try d.invoke("compareAndSet",arguments:["scope":scope,"lease":t,"expected":NSNull(),"value":true])}}
        test("locked device blocks reads but permits original release") {let f=try Fixture();defer{f.close()};let toggle=Toggle(),d=try NativeRecoveryDispatcher(store:f.store,owner:f.owner,usable:{toggle.value});let a=try d.invoke("tryAcquire",arguments:["scope":scope,"acquisitionId":f.request]);toggle.value=false;try fails("recovery_device_locked"){_ = try d.invoke("load",arguments:["scope":scope,"lease":a["lease"]!])};try check(try d.invoke("release",arguments:["scope":scope,"acquisitionId":f.request])["released"] as? Bool == true);toggle.value=true;_ = try f.acquire()}
        test("two threads cannot simultaneously acquire global lock") {let f=try Fixture();defer{f.close()};let winners=Counter(),store=f.store;DispatchQueue.concurrentPerform(iterations:16){_ in let id=RecoveryProtocol.newID();if (try? store.acquire(owner:id,scope:scope,acquisitionID:id)) != nil {winners.add()}};try check(winners.count==1);let r=RecoveryLeaseRegistry.shared;r.synchronized{if let h=r.leases.removeValue(forKey:f.root){RecoveryFiles.release(h.file)}}}
        test("independent process sees held OS lock") {let f=try Fixture();defer{f.close()};_ = try f.acquire();let p=Process(),out=Pipe();p.executableURL=URL(fileURLWithPath:CommandLine.arguments[0]);p.arguments=["child-probe",f.root];p.standardOutput=out;p.standardError=out;try p.run();p.waitUntilExit();let text=String(data:out.fileHandleForReading.readDataToEndOfFile(),encoding:.utf8)!;try check(p.terminationStatus==0 && text.trimmingCharacters(in:.whitespacesAndNewlines)=="BUSY")}
        test("process death releases lock and preserves saved reservation") {
            let root=try temporary();defer{try? FileManager.default.removeItem(atPath:root)}
            let p=Process();p.executableURL=URL(fileURLWithPath:CommandLine.arguments[0]);p.arguments=["child-hold",root];p.standardOutput=FileHandle.nullDevice;p.standardError=FileHandle.nullDevice;try p.run()
            defer{if p.isRunning {p.terminate();p.waitUntilExit()}}
            let deadline=Date().addingTimeInterval(5)
            while !FileManager.default.fileExists(atPath:root+"/child-ready") && Date()<deadline {Thread.sleep(forTimeInterval:0.01)}
            try check(FileManager.default.fileExists(atPath:root+"/child-ready"))
            let s=try NativeRecoveryStore(root:root,applicationID:app,storage:FileTestBlob(root)),o=RecoveryProtocol.newID(),r=RecoveryProtocol.newID()
            try check(try s.acquire(owner:o,scope:scope,acquisitionID:r)==nil)
            _ = kill(p.processIdentifier,SIGKILL);p.waitUntilExit()
            let t=try s.acquire(owner:o,scope:scope,acquisitionID:r)!
            try check(try s.load(owner:o,scope:scope,lease:t)=="reserved-by-child");try s.close(owner:o)
        }
        let passed=results.filter{$0["passed"] as? Bool == true}.count
        let summary: [String:Any] = ["schemaVersion":1,"platform":"portable Swift on host; test-only blob storage","passed":passed,"failed":results.count-passed,"tests":results,"keychainExecuted":false,"iosHostCompiled":false,"flutterCompiled":false]
        let data=try JSONSerialization.data(withJSONObject:summary,options:[.prettyPrinted,.sortedKeys]);FileHandle.standardOutput.write(data);FileHandle.standardOutput.write(Data([10]));if passed != results.count {exit(1)}
    }
}
