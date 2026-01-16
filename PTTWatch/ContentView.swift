import SwiftUI
import WatchKit

struct ContentView: View {
    @EnvironmentObject var viewModel: WatchPTTViewModel

    var body: some View {
        VStack(spacing: 8) {
            // 状态栏
            HStack {
                Circle()
                    .fill(viewModel.isConnected ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(viewModel.roomName)
                    .font(.caption2)
                    .lineLimit(1)
            }

            // 讲话者
            if let speaker = viewModel.currentSpeaker {
                Text(speaker)
                    .font(.caption)
                    .foregroundColor(.cyan)
                    .lineLimit(1)
            } else if viewModel.isTalking {
                Text("正在发射...")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Text("守听中")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            // PTT 按钮
            PTTButton(
                isTalking: viewModel.isTalking,
                isConnected: viewModel.isConnected,
                onPress: { viewModel.startTalking() },
                onRelease: { viewModel.stopTalking() }
            )

            Spacer()

            // 连接状态提示
            if !viewModel.isConnected {
                Text("请在 iPhone 上连接")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding()
    }
}

struct PTTButton: View {
    let isTalking: Bool
    let isConnected: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    @State private var isPressed = false

    var body: some View {
        Circle()
            .fill(buttonColor)
            .frame(width: 100, height: 100)
            .overlay(
                VStack(spacing: 4) {
                    Image(systemName: isTalking ? "mic.fill" : "mic")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                    if isTalking {
                        Text("TX")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isConnected else { return }
                        if !isPressed {
                            isPressed = true
                            onPress()
                        }
                    }
                    .onEnded { _ in
                        if isPressed {
                            isPressed = false
                            onRelease()
                        }
                    }
            )
            .opacity(isConnected ? 1.0 : 0.5)
    }

    private var buttonColor: Color {
        if !isConnected {
            return .gray
        }
        return isTalking ? .red : .blue
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchPTTViewModel())
}
