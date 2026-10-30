import SwiftUI

struct ImageDebugMetrics: View {
    #if DEBUG
    @State private var metrics = ImagePipeline.Metrics()
    #endif
    var body: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-verifyPosterLoading") {
            Text("Изображения").font(.caption2).padding(3).background(.regularMaterial).allowsHitTesting(false)
                .accessibilityIdentifier("imageMetrics")
                .accessibilityValue("decoded=\(metrics.decoded);memory=\(metrics.memoryHits);disk=\(metrics.diskHits);requests=\(metrics.requests);failed=\(metrics.failures)")
                .task {
                    while !Task.isCancelled {
                        let next = await ImagePipeline.shared.snapshot()
                        if next != metrics { metrics = next }
                        do { try await Task.sleep(for:.milliseconds(400)) } catch { return }
                    }
                }
        }
        #else
        EmptyView()
        #endif
    }
}
