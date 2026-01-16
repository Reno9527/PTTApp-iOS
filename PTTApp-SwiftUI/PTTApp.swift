import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// PTT 应用入口
@main
struct PTTApp: App {
    @StateObject private var updateService = AppUpdateService.shared

    init() {
        // 强制使用白天模式
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { window in
                window.overrideUserInterfaceStyle = .light
            }
        }

        // 清理旧的 Live Activity（应用重启时）
        if #available(iOS 16.2, *) {
            Task {
                await PTTLiveActivityService.shared.endAll()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                PTTMainView()
                    .preferredColorScheme(.light)
                    .onAppear {
                        UIApplication.shared.connectedScenes
                            .compactMap { $0 as? UIWindowScene }
                            .flatMap { $0.windows }
                            .forEach { $0.overrideUserInterfaceStyle = .light }
                        // MapView 不预加载，点击位置页面时再创建

                        // 检查更新
                        updateService.checkForUpdate()
                    }

                // 更新提示弹窗
                if updateService.showUpdateAlert, let updateInfo = updateService.updateAvailable {
                    UpdateAlertView(updateInfo: updateInfo) {
                        updateService.showUpdateAlert = false
                    }
                }
            }
        }
    }
}
