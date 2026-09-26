import SwiftUI

struct ContentView: View {
    @StateObject private var browser = BrowserModel()
    @StateObject private var recorder = CameraRecorder()
    @Environment(\.scenePhase) private var scenePhase

    @State private var showBubble = true
    @State private var bubbleOffset = CGSize(width: 0, height: 0)
    @State private var dragStart = CGSize.zero
    @FocusState private var addressFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            addressBar
            ZStack(alignment: .topTrailing) {
                BrowserView(webView: browser.webView)
                if showBubble { cameraBubble }
            }
            toolbar
        }
        .onAppear { recorder.start() }
        .onChange(of: scenePhase) { _, phase in
            // iOS cuts off the camera in the background; stop cleanly so the clip is saved.
            switch phase {
            case .active: recorder.start()
            case .background: recorder.stop()
            default: break
            }
        }
        .alert("FaceCam", isPresented: Binding(
            get: { recorder.statusMessage != nil },
            set: { if !$0 { recorder.statusMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(recorder.statusMessage ?? "")
        }
    }

    // MARK: - Address bar

    private var addressBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("Search or enter address", text: $browser.addressText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.webSearch)
                    .submitLabel(.go)
                    .focused($addressFocused)
                    .onSubmit { browser.submit(browser.addressText) }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground), in: Capsule())
                if addressFocused {
                    Button("Cancel") { addressFocused = false }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            ProgressView(value: browser.progress)
                .progressViewStyle(.linear)
                .frame(height: 2)
                .opacity(browser.isLoading ? 1 : 0)
        }
        .background(.bar)
    }

    // MARK: - Camera bubble

    private var cameraBubble: some View {
        CameraPreviewView(session: recorder.session)
            .frame(width: 110, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(recorder.isRecording ? Color.red : Color.white.opacity(0.8), lineWidth: 3)
            )
            .shadow(radius: 6)
            .padding(12)
            .offset(bubbleOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        bubbleOffset = CGSize(width: dragStart.width + value.translation.width,
                                              height: dragStart.height + value.translation.height)
                    }
                    .onEnded { _ in dragStart = bubbleOffset }
            )
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Button(action: browser.goBack) { Image(systemName: "chevron.backward") }
                .disabled(!browser.canGoBack)
            Spacer()
            Button(action: browser.goForward) { Image(systemName: "chevron.forward") }
                .disabled(!browser.canGoForward)
            Spacer()
            recordButton
            Spacer()
            Button(action: browser.reloadOrStop) {
                Image(systemName: browser.isLoading ? "xmark" : "arrow.clockwise")
            }
            Spacer()
            Button { showBubble.toggle() } label: {
                Image(systemName: showBubble ? "person.crop.square.fill" : "person.crop.square")
            }
        }
        .font(.title3)
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var recordButton: some View {
        Button(action: recorder.toggleRecording) {
            HStack(spacing: 6) {
                Image(systemName: recorder.isRecording ? "stop.circle.fill" : "record.circle")
                    .font(.title)
                    .foregroundStyle(.red)
                if recorder.isRecording {
                    Text(format(recorder.elapsed))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.red)
                }
            }
        }
        .disabled(!recorder.isRunning)
    }

    private func format(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
