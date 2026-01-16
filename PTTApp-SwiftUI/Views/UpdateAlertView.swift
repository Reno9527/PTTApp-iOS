import SwiftUI
import UIKit

/// 更新提示弹窗
struct UpdateAlertView: View {
    let updateInfo: AppUpdateService.UpdateInfo
    let onDismiss: () -> Void

    @State private var copied = false

    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            // 弹窗内容
            VStack(spacing: 16) {
                // 标题
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    Text("发现新版本")
                        .font(.headline)
                }

                // 版本信息
                VStack(spacing: 8) {
                    Text("v\(updateInfo.newVersion)")
                        .font(.title2)
                        .fontWeight(.bold)

                    if !updateInfo.releaseNotes.isEmpty {
                        Text(updateInfo.releaseNotes)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                Divider()

                // 下载地址
                VStack(spacing: 8) {
                    Text("请在电脑浏览器中打开以下网址下载更新：")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    HStack {
                        Text(updateInfo.downloadURL)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.blue)

                        Button(action: copyURL) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .foregroundColor(copied ? .green : .blue)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(8)

                    if copied {
                        Text("已复制到剪贴板")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                // 提示信息
                Text("手机无法直接安装，必须在电脑端使用 AltStore 或 Sideloadly 等工具安装")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // 关闭按钮
                Button(action: onDismiss) {
                    Text("知道了")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding(24)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 20)
            .padding(.horizontal, 32)
        }
    }

    private func copyURL() {
        #if canImport(UIKit)
        UIPasteboard.general.string = updateInfo.downloadURL
        #endif
        withAnimation {
            copied = true
        }
        // 2秒后恢复
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copied = false
            }
        }
    }
}
