//
//  AboutView.swift
//  PTT 互联
//
//  Created by 刘光辉 (BG4QG) on 2024.
//  Copyright © 2024-2026 刘光辉. All rights reserved.
//

import SwiftUI
import UIKit

/// 关于页面
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var updateService = AppUpdateService.shared
    @State private var isChecking = false
    @State private var showNoUpdateAlert = false

    /// 获取应用版本号
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// 获取 Build 号
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - 头部 Logo 和版本
                    headerSection

                    // MARK: - 协议说明
                    protocolSection

                    // MARK: - 客户端实现
                    implementationSection

                    // MARK: - NRL Team
                    nrlTeamSection

                    // MARK: - 免责声明
                    disclaimerSection

                    // MARK: - 底部版权
                    copyrightFooter
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("已是最新版本", isPresented: $showNoUpdateAlert) {
                Button("好的", role: .cancel) { }
            } message: {
                Text("当前版本 \(appVersion) (Build \(buildNumber)) 已是最新版本")
            }
            .overlay {
                if updateService.showUpdateAlert, let updateInfo = updateService.updateAvailable {
                    UpdateAlertView(updateInfo: updateInfo) {
                        updateService.showUpdateAlert = false
                    }
                }
            }
        }
    }

    // MARK: - 头部区域

    private var headerSection: some View {
        VStack(spacing: 12) {
            // App 图标
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .padding(.top, 30)

            Text("PTT 互联")
                .font(.title)
                .fontWeight(.bold)

            Text("版本 \(appVersion) (Build \(buildNumber))")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // 检查更新按钮
            Button(action: checkForUpdate) {
                HStack(spacing: 6) {
                    if isChecking {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text(isChecking ? "检查中..." : "检查更新")
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(8)
            }
            .disabled(isChecking)
            .padding(.top, 8)

            Spacer().frame(height: 20)
        }
    }

    /// 检查更新
    private func checkForUpdate() {
        isChecking = true

        // 请求版本信息
        guard let url = URL(string: "https://app.pgarlic.com/version.json") else {
            isChecking = false
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isChecking = false

                guard let data = data, error == nil else {
                    return
                }

                do {
                    let serverVersion = try JSONDecoder().decode(AppUpdateService.VersionInfo.self, from: data)
                    let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
                    let serverBuildNum = Int(serverVersion.build) ?? 0
                    let currentBuildNum = Int(currentBuild) ?? 0

                    if serverBuildNum > currentBuildNum {
                        // 有新版本
                        updateService.updateAvailable = AppUpdateService.UpdateInfo(
                            newVersion: serverVersion.version,
                            newBuild: serverVersion.build,
                            releaseNotes: serverVersion.releaseNotes ?? "",
                            downloadURL: "https://app.pgarlic.com/"
                        )
                        updateService.showUpdateAlert = true
                    } else {
                        // 已是最新版本
                        showNoUpdateAlert = true
                    }
                } catch {
                    print("[AboutView] 解析版本信息失败: \(error)")
                }
            }
        }.resume()
    }

    // MARK: - 协议说明

    private var protocolSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "antenna.radiowaves.left.and.right.circle.fill", title: "协议说明", color: .orange)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("本应用遵循 NRL21 通信协议")
                        .font(.subheadline)

                    Text("该协议由 BH4RPN 设计并维护")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer().frame(height: 4)

                    Text("网络中继基于 nrllink Go 架构实现")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 4)
            }
        }
    }

    // MARK: - 客户端实现

    private var implementationSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "iphone.gen3", title: "客户端实现", color: .blue)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("iOS 移动客户端")
                        .font(.subheadline)

                    HStack(spacing: 4) {
                        Text("由")
                            .foregroundColor(.secondary)
                        Text("刘光辉（BG4QG）")
                            .fontWeight(.medium)
                        Text("独立设计与实现")
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)

                    Spacer().frame(height: 8)

                    Text("实现范围：")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        featureRow("NRL21 协议客户端")
                        featureRow("低延迟语音通信链路")
                        featureRow("实时音频处理与编码")
                        featureRow("跨平台交互界面")
                    }
                }
                .padding(.leading, 4)
            }
        }
    }

    // MARK: - NRL Team

    private var nrlTeamSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "person.3.fill", title: "NRL Team", color: .purple)

                Divider()

                VStack(spacing: 10) {
                    teamMemberRow(role: "软件", callsign: "BH4RPN")
                    teamMemberRow(role: "运维", callsign: "BG6FCS")
                    teamMemberRow(role: "硬件", callsign: "BH4TDV")
                    teamMemberRow(role: "苹果", callsign: "BG4QG")
                    teamMemberRow(role: "安卓", callsign: "BA4QGT")
                }
                .padding(.leading, 4)
            }
        }
    }

    /// 团队成员行
    private func teamMemberRow(role: String, callsign: String) -> some View {
        HStack {
            Text(role)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)

            Text(callsign)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Spacer()
        }
    }

    // MARK: - 免责声明

    private var disclaimerSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "exclamationmark.shield.fill", title: "免责声明", color: .red)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("本软件按「现状」提供，不作任何明示或暗示的保证。作者不对因使用本软件产生的任何直接或间接损失承担责任。")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("本应用仅供业余无线电爱好者学习与交流使用，用户应遵守所在地区的无线电管理法规。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 4)
            }
        }
    }

    // MARK: - 底部版权

    private var copyrightFooter: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 24)

            Divider()
                .padding(.horizontal, 40)

            Spacer().frame(height: 16)

            VStack(spacing: 4) {
                Text("© 2024-2026 刘光辉（BG4QG）")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("客户端实现保留所有权利")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))

                Spacer().frame(height: 8)

                Text("NRL21 协议 © BH4RPN")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
    }

    // MARK: - 辅助组件

    /// 区块卡片容器
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading) {
            content()
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .padding(.vertical, 8)
    }

    /// 区块标题
    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }

    /// 功能项
    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.caption)
                .foregroundColor(.green)

            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    AboutView()
}
