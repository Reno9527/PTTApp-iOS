import Foundation

/// App更新检查服务
class AppUpdateService: ObservableObject {
    static let shared = AppUpdateService()

    private let versionURL = "https://app.pgarlic.com/version.json"

    struct VersionInfo: Codable {
        let version: String
        let build: String
        let releaseNotes: String?
    }

    struct UpdateInfo {
        let newVersion: String
        let newBuild: String
        let releaseNotes: String
        let downloadURL: String
    }

    @Published var updateAvailable: UpdateInfo?
    @Published var showUpdateAlert = false

    private init() {}

    /// 检查更新
    func checkForUpdate() {
        guard let url = URL(string: versionURL) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                print("[AppUpdateService] 检查更新失败: \(error?.localizedDescription ?? "未知错误")")
                return
            }

            do {
                let serverVersion = try JSONDecoder().decode(VersionInfo.self, from: data)
                self?.compareVersion(serverVersion)
            } catch {
                print("[AppUpdateService] 解析版本信息失败: \(error)")
            }
        }.resume()
    }

    private func compareVersion(_ serverVersion: VersionInfo) {
        let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

        // 比较build号（数字比较）
        let serverBuildNum = Int(serverVersion.build) ?? 0
        let currentBuildNum = Int(currentBuild) ?? 0

        if serverBuildNum > currentBuildNum {
            DispatchQueue.main.async { [weak self] in
                self?.updateAvailable = UpdateInfo(
                    newVersion: serverVersion.version,
                    newBuild: serverVersion.build,
                    releaseNotes: serverVersion.releaseNotes ?? "",
                    downloadURL: "https://app.pgarlic.com/"
                )
                self?.showUpdateAlert = true
                print("[AppUpdateService] 发现新版本: \(serverVersion.version) (build \(serverVersion.build)), 当前: \(currentVersion) (build \(currentBuild))")
            }
        } else {
            print("[AppUpdateService] 当前已是最新版本: \(currentVersion) (build \(currentBuild))")
        }
    }
}
