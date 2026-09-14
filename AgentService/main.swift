import AgentBridge
import Foundation

final class AgentService: NSObject, CoachAgentProtocol, @unchecked Sendable {
    let runner = CoachAgentRunner()
    private let queue = DispatchQueue(label: "coach.agent.service")
    func analyze(request: Data, audio: Data, provider: String, reply: @escaping @Sendable (Data?, String?) -> Void) {
        queue.async { [self] in
            do { reply(try runner.run(request: request, audio: audio, provider: provider), nil) }
            catch { reply(nil, (error as? CoachAgentFailure)?.rawValue ?? "failed") }
        }
    }
    func cancel() { runner.cancel() }
}

final class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        let service = AgentService()
        connection.exportedInterface = NSXPCInterface(with: CoachAgentProtocol.self)
        connection.exportedObject = service
        connection.invalidationHandler = { service.cancel() }
        connection.interruptionHandler = { service.cancel() }
        connection.resume()
        return true
    }
}

let delegate = ServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
