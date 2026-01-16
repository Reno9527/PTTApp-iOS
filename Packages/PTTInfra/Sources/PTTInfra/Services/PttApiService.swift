import Foundation

/// PTT API 服务
///
/// 与 ptt.pgarlic.com 服务器通信
public final class PttApiService: @unchecked Sendable {

    // MARK: - 配置

    private var baseURL: String = "https://ptt.pgarlic.com"

    /// Token 存储（使用锁保护并发访问）
    private var _token: String?
    private let tokenLock = NSLock()
    private var token: String? {
        get { tokenLock.withLock { _token } }
        set { tokenLock.withLock { _token = newValue } }
    }

    private let session: URLSession

    // MARK: - 初始化

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10
        self.session = URLSession(configuration: config)
    }

    // MARK: - 内部辅助

    /// 构建 API URL，避免强制解包崩溃
    private func makeURL(_ path: String) throws -> URL {
        let urlString = "\(baseURL)\(path)"
        guard let url = URL(string: urlString) else {
            throw PttApiError.invalidURL(urlString)
        }
        return url
    }

    /// 检查 HTTP 响应状态码，401/403 映射为 tokenExpired
    private func checkResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PttApiError.networkError
        }

        switch httpResponse.statusCode {
        case 200...299:
            return  // 正常响应
        case 401, 403:
            // Token 过期或无权限
            token = nil  // 清除无效 token
            throw PttApiError.tokenExpired
        default:
            throw PttApiError.networkError
        }
    }

    // MARK: - 服务器配置

    /// 设置服务器地址
    /// - Parameter url: 服务器地址 (例如 https://ptt.example.com)
    public func setServerUrl(_ url: String) {
        // 移除末尾的斜杠
        baseURL = url.hasSuffix("/") ? String(url.dropLast()) : url
        print("[PttApiService] Server URL set to: \(baseURL)")
    }

    /// 获取当前服务器地址
    public func getServerUrl() -> String {
        return baseURL
    }

    // MARK: - 公开 API

    /// 登录
    /// - Parameters:
    ///   - username: 用户名
    ///   - password: 密码
    /// - Returns: 登录结果，包含 token
    public func login(username: String, password: String) async throws -> LoginResult {
        let url = try makeURL("/user/login")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: Any] = ["username": username, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[PttApiService] POST /user/login")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PttApiError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        print("[PttApiService] Response code: \(code ?? -1)")

        guard code == 20000 || code == 60204 else {
            let message = json["message"] as? String ?? "登录失败"
            throw PttApiError.serverError(message)
        }

        guard let resultData = json["data"] as? [String: Any],
              let tokenValue = resultData["token"] as? String,
              !tokenValue.isEmpty else {
            throw PttApiError.serverError("用户名或密码错误")
        }

        // 保存 token
        self.token = tokenValue
        print("[PttApiService] Login success, token saved")

        return LoginResult(token: tokenValue)
    }

    /// 获取用户信息
    /// - Returns: 用户信息
    public func getUserInfo() async throws -> UserInfo {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        let url = try makeURL("/user/info")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")

        print("[PttApiService] GET /user/info")

        let (data, response) = try await session.data(for: request)

        // 检查 401/403 token 过期
        try checkResponse(response)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        guard code == 20000 || code == 60204 else {
            let message = json["message"] as? String ?? "获取用户信息失败"
            throw PttApiError.serverError(message)
        }

        guard let userData = json["data"] as? [String: Any] else {
            throw PttApiError.parseError
        }

        let id = userData["id"] as? Int ?? 0
        let callsign = userData["callsign"] as? String ?? ""
        let ssid = userData["ssid"] as? Int ?? 106
        let roles = userData["roles"] as? [String] ?? []
        let isAdmin = roles.contains("admin")
        let groupId = userData["group_id"] as? Int ?? 0
        let dmrid = userData["dmrid"] as? String
        let mdcid = userData["mdcid"] as? String

        print("[PttApiService] UserInfo: id=\(id), callsign=\(callsign), ssid=\(ssid), isAdmin=\(isAdmin), groupId=\(groupId), dmrid=\(dmrid ?? "nil"), mdcid=\(mdcid ?? "nil")")
        print("[PttApiService] Full userData: \(userData)")

        return UserInfo(
            id: id,
            callsign: callsign,
            ssid: ssid,
            isAdmin: isAdmin,
            groupId: groupId,
            dmrid: dmrid,
            mdcid: mdcid
        )
    }

    /// 修改密码
    /// - Parameters:
    ///   - userId: 用户 ID
    ///   - newPassword: 新密码
    /// - Note: 后端 API 期望的是 `{ "id": userId, "password": newPassword }` 格式
    public func changePassword(userId: Int, newPassword: String) async throws {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        let url = try makeURL("/user/password")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")

        // 后端期望的格式：{ "id": userId, "password": newPassword }
        let body: [String: Any] = [
            "id": userId,
            "password": newPassword
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[PttApiService] POST /user/password: userId=\(userId)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PttApiError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        guard code == 20000 || code == 60204 else {
            let message = json["message"] as? String ?? "修改密码失败"
            throw PttApiError.serverError(message)
        }

        print("[PttApiService] Password changed successfully")
    }

    /// 获取对讲组列表
    public func getGroups() async throws -> [PttGroup] {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        let url = try makeURL("/group/list")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")
        request.httpBody = "{}".data(using: .utf8)

        print("[PttApiService] POST /group/list")

        let (data, response) = try await session.data(for: request)

        // 检查 401/403 token 过期
        try checkResponse(response)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        guard code == 20000 || code == 60204 else {
            let message = json["message"] as? String ?? "获取对讲组失败"
            throw PttApiError.serverError(message)
        }

        var groups: [PttGroup] = []

        if let groupsData = json["data"] {
            if let list = groupsData as? [[String: Any]] {
                groups = list.compactMap { PttGroup(json: $0) }
            } else if let dict = groupsData as? [String: Any],
                      let items = dict["items"] as? [String: [String: Any]] {
                groups = items.values.compactMap { PttGroup(json: $0) }
            }
        }

        print("[PttApiService] Found \(groups.count) groups")
        return groups
    }

    /// 创建群组
    /// - Parameters:
    ///   - name: 群组名称
    ///   - type: 群组类型 (0=公共房间, 5=俱乐部, 6=车友会, 8=私人房间 等)
    ///   - note: 群组描述
    /// - Returns: 创建的群组ID
    public func createGroup(name: String, type: Int, note: String?) async throws -> Int {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        let url = try makeURL("/group/create")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")

        var body: [String: Any] = [
            "name": name,
            "type": type
        ]
        if let note = note, !note.isEmpty {
            body["note"] = note
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[PttApiService] POST /group/create")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PttApiError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        guard code == 20000 || code == 60204 else {
            let message = json["message"] as? String ?? "创建群组失败"
            throw PttApiError.serverError(message)
        }

        // 获取返回的群组ID
        let groupId = (json["data"] as? [String: Any])?["id"] as? Int ?? 0
        print("[PttApiService] Created group: id=\(groupId)")
        return groupId
    }

    /// 更新群组
    /// - Parameters:
    ///   - id: 群组ID
    ///   - name: 新名称
    ///   - type: 群组类型
    ///   - note: 新描述
    public func updateGroup(id: Int, name: String, type: Int, note: String?) async throws {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        let url = try makeURL("/group/update")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")

        var body: [String: Any] = [
            "id": id,
            "name": name,
            "type": type
        ]
        if let note = note {
            body["note"] = note
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[PttApiService] POST /group/update")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PttApiError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        guard code == 20000 || code == 60204 else {
            let message = json["message"] as? String ?? "更新群组失败"
            throw PttApiError.serverError(message)
        }

        print("[PttApiService] Updated group: id=\(id)")
    }

    /// 删除群组
    /// - Parameter id: 群组ID
    public func deleteGroup(id: Int) async throws {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        let url = try makeURL("/group/delete")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")

        let body: [String: Any] = ["id": id]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[PttApiService] POST /group/delete")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PttApiError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        guard code == 20000 || code == 60204 else {
            let message = json["message"] as? String ?? "删除群组失败"
            throw PttApiError.serverError(message)
        }

        print("[PttApiService] Deleted group: id=\(id)")
    }

    /// 获取群组详情（设备列表）
    public func getGroupDetail(groupId: Int) async throws -> GroupDetail {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        let url = try makeURL("/device/db/list")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")

        let body: [String: Any] = ["group_id": groupId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PttApiError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        guard code == 20000 || code == 60204 else {
            let message = json["message"] as? String ?? "获取群组详情失败"
            throw PttApiError.serverError(message)
        }

        var devices: [PttDevice] = []

        if let resultData = json["data"] as? [String: Any],
           let items = resultData["items"] {
            if let itemsMap = items as? [String: [String: Any]] {
                devices = itemsMap.values.compactMap { PttDevice(json: $0) }
            } else if let itemsList = items as? [[String: Any]] {
                devices = itemsList.compactMap { PttDevice(json: $0) }
            }
        }

        // 按在线状态排序
        devices.sort { ($0.isOnline ? 0 : 1) < ($1.isOnline ? 0 : 1) }

        return GroupDetail(groupId: groupId, devices: devices)
    }

    /// 获取我的设备列表
    public func getMyDevices() async throws -> [PttDevice] {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        let url = try makeURL("/device/mydevlist")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")
        request.httpBody = "{}".data(using: .utf8)

        print("[PttApiService] POST /device/mydevlist")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PttApiError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        guard code == 20000 || code == 60204 else {
            let message = json["message"] as? String ?? "获取我的设备失败"
            throw PttApiError.serverError(message)
        }

        var devices: [PttDevice] = []

        if let devicesData = json["data"] {
            // 格式1: 直接是数组
            if let deviceList = devicesData as? [[String: Any]] {
                devices = deviceList.compactMap { PttDevice(json: $0) }
                print("[PttApiService] getMyDevices found \(devices.count) devices (list)")
            }
            // 格式2: {total: N, items: {0: {...}, 1: {...}, ...}}
            else if let dataMap = devicesData as? [String: Any],
                    let items = dataMap["items"] as? [String: [String: Any]] {
                devices = items.values.compactMap { PttDevice(json: $0) }
                print("[PttApiService] getMyDevices found \(devices.count) devices (items map)")
            }
        }

        return devices
    }

    /// 加入群组（更新设备所属群组）
    public func joinGroup(groupId: Int, callsign: String, ssid: Int) async throws -> Bool {
        guard token != nil else {
            throw PttApiError.notAuthenticated
        }

        // 1. 获取设备信息
        guard let device = try await getDevice(callsign: callsign, ssid: ssid) else {
            throw PttApiError.serverError("获取设备信息失败")
        }

        // 2. 更新设备群组（使用 updateDevice 保留其他字段）
        return try await updateDevice(device: device, groupId: groupId)
    }

    /// 获取设备信息 (使用 /device/query API)
    private func getDevice(callsign: String, ssid: Int) async throws -> PttDevice? {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        let url = try makeURL("/device/query")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")

        let body: [String: Any] = ["callsign": callsign, "ssid": ssid]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["code"] as? Int,
              (code == 20000 || code == 60204),
              let resultData = json["data"] as? [String: Any] else {
            return nil
        }

        // queryDevice API 响应格式: { data: { items: { ...设备数据 } } }
        if let deviceData = resultData["items"] as? [String: Any] {
            return PttDevice(json: deviceData)
        }
        // 兼容直接返回设备数据的情况
        return PttDevice(json: resultData)
    }

    /// 设置设备禁收状态 (通过 /device/update API)
    /// - 使用位运算修改 status 的 bit0
    public func setDeviceMuteReceive(callsign: String, ssid: Int, mute: Bool) async throws -> Bool {
        guard token != nil else {
            throw PttApiError.notAuthenticated
        }

        // 1. 获取设备完整信息
        guard let device = try await getDevice(callsign: callsign, ssid: ssid) else {
            throw PttApiError.serverError("获取设备信息失败")
        }

        // 2. 计算新的 status 值
        // bit0 = 禁收, bit1 = 禁发
        let currentStatus = device.status
        let muteTransmitBit = (currentStatus & 2) >> 1  // 保留 bit1 (禁发状态)
        let newMuteReceiveBit = mute ? 1 : 0            // 设置 bit0 (禁收状态)

        let newStatus = newMuteReceiveBit | (muteTransmitBit << 1)

        print("[PttApiService] setDeviceMuteReceive: \(callsign)-\(ssid), status \(currentStatus) -> \(newStatus)")

        // 3. 更新设备（使用 updateDevice 保留 group_id 等字段）
        return try await updateDevice(device: device, status: newStatus)
    }

    /// 设置设备禁发状态 (通过 /device/update API)
    /// - 使用位运算修改 status 的 bit1
    public func setDeviceMuteTransmit(callsign: String, ssid: Int, mute: Bool) async throws -> Bool {
        guard token != nil else {
            throw PttApiError.notAuthenticated
        }

        // 1. 获取设备完整信息
        guard let device = try await getDevice(callsign: callsign, ssid: ssid) else {
            throw PttApiError.serverError("获取设备信息失败")
        }

        // 2. 计算新的 status 值
        // bit0 = 禁收, bit1 = 禁发
        let currentStatus = device.status
        let muteReceiveBit = currentStatus & 1        // 保留 bit0 (禁收状态)
        let newMuteTransmitBit = mute ? 1 : 0         // 设置 bit1 (禁发状态)

        let newStatus = muteReceiveBit | (newMuteTransmitBit << 1)

        print("[PttApiService] setDeviceMuteTransmit: \(callsign)-\(ssid), status \(currentStatus) -> \(newStatus)")

        // 3. 更新设备（使用 updateDevice 保留 group_id 等字段）
        return try await updateDevice(device: device, status: newStatus)
    }

    /// 更改设备所属群组
    public func changeDeviceGroup(callsign: String, ssid: Int, newGroupId: Int) async throws -> Bool {
        guard token != nil else {
            throw PttApiError.notAuthenticated
        }

        // 1. 获取设备信息
        guard let device = try await getDevice(callsign: callsign, ssid: ssid) else {
            throw PttApiError.serverError("获取设备信息失败")
        }

        // 2. 更新设备群组（使用 updateDevice 保留其他字段）
        return try await updateDevice(device: device, groupId: newGroupId)
    }

    // MARK: - 设备管理 (管理员功能)

    /// 发送 AT 指令到设备
    /// - Parameters:
    ///   - callsign: 设备呼号
    ///   - ssid: 设备 SSID
    ///   - command: AT 指令
    /// - Returns: 指令响应
    public func sendATCommand(callsign: String, ssid: Int, command: String) async throws -> String {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        let url = try makeURL("/device/at")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")

        let body: [String: Any] = [
            "callsign": callsign,
            "ssid": ssid,
            "command": command
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[PttApiService] POST /device/at: \(command)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PttApiError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        guard code == 20000 || code == 60204 else {
            let message = json["message"] as? String ?? "AT指令执行失败"
            throw PttApiError.serverError(message)
        }

        // 返回响应内容
        if let resultData = json["data"] as? [String: Any],
           let response = resultData["response"] as? String {
            return response
        }
        if let message = json["message"] as? String {
            return message
        }
        return "OK"
    }

    /// 更新设备完整信息
    /// - Parameters:
    ///   - device: 设备信息
    ///   - name: 新昵称 (可选)
    ///   - groupId: 新群组 ID (可选)
    ///   - status: 新状态 (可选)
    ///   - devModel: 设备型号 (可选)
    ///   - rfType: 射频类型 (可选)
    ///   - priority: 语音优先级 0-255 (可选)
    public func updateDevice(
        device: PttDevice,
        name: String? = nil,
        groupId: Int? = nil,
        status: Int? = nil,
        devModel: Int? = nil,
        rfType: Int? = nil,
        priority: Int? = nil
    ) async throws -> Bool {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        let url = try makeURL("/device/update")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")

        // 传递所有字段，使用新值或保留原值，避免服务器用默认值覆盖
        // 注意: priority 仅在显式设置时发送，避免用客户端默认值覆盖服务端默认值 100
        var body: [String: Any] = [
            "id": device.id,
            "callsign": device.callsign,
            "ssid": device.ssid,
            "name": name ?? device.name ?? "",
            "group_id": groupId ?? device.groupId,
            "status": status ?? device.status,
            "dev_model": devModel ?? device.devModel,
            "rf_type": rfType ?? device.rfType
        ]
        // priority 仅在显式传入时才发送（铁律1：服务端有默认值的字段不发送客户端默认值）
        if let priority = priority {
            body["priority"] = priority
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[PttApiService] POST /device/update: \(body)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PttApiError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        let success = code == 20000 || code == 60204
        print("[PttApiService] Update device result: \(success)")
        return success
    }

    /// 删除设备
    /// - Parameter device: 设备对象
    /// - Returns: 是否成功
    public func deleteDevice(device: PttDevice) async throws -> Bool {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        let url = try makeURL("/device/delete")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")

        // 传递完整设备信息（与 Web 端一致）
        let body: [String: Any] = [
            "id": device.id,
            "callsign": device.callsign,
            "ssid": device.ssid,
            "name": device.name ?? "",
            "status": device.status
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[PttApiService] POST /device/delete: \(body)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PttApiError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        let success = code == 20000 || code == 60204
        print("[PttApiService] Delete device result: \(success)")
        return success
    }

    /// 登出
    public func logout() {
        token = nil
    }

    // MARK: - 用户管理

    /// 获取用户列表
    public func getUserList() async throws -> [PttUser] {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        let url = try makeURL("/user/list")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")
        request.httpBody = "{}".data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PttApiError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        guard code == 20000 || code == 60204 else {
            let message = json["message"] as? String ?? "获取用户列表失败"
            throw PttApiError.serverError(message)
        }

        var users: [PttUser] = []
        if let resultData = json["data"] as? [String: Any],
           let items = resultData["items"] {
            if let itemsMap = items as? [String: [String: Any]] {
                users = itemsMap.values.compactMap { PttUser(json: $0) }
            } else if let itemsList = items as? [[String: Any]] {
                users = itemsList.compactMap { PttUser(json: $0) }
            }
        } else if let list = json["data"] as? [[String: Any]] {
            users = list.compactMap { PttUser(json: $0) }
        }

        return users
    }

    /// 获取当前用户的完整 PttUser 信息
    /// - Parameter userId: 当前用户 ID
    /// - Returns: 完整的 PttUser 对象
    public func getCurrentUserAsPttUser(userId: Int) async throws -> PttUser {
        let users = try await getUserList()
        guard let user = users.first(where: { $0.id == userId }) else {
            throw PttApiError.serverError("用户不存在")
        }
        return user
    }

    /// 添加用户
    public func addUser(phone: String, password: String, name: String? = nil, callsign: String? = nil, roles: [String] = ["ham"]) async throws -> Bool {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        // 正确的端点是 /user/create
        let url = try makeURL("/user/create")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")

        var body: [String: Any] = [
            "phone": phone,
            "password": password,
            "roles": roles,
            "status": 1  // 默认启用
        ]
        if let name = name, !name.isEmpty { body["name"] = name }
        if let callsign = callsign, !callsign.isEmpty { body["callsign"] = callsign }

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = bodyData
        print("[PttApiService] POST /user/create: \(String(data: bodyData, encoding: .utf8) ?? "")")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("[PttApiService] addUser: Invalid response type")
                throw PttApiError.networkError
            }

            print("[PttApiService] addUser: HTTP status = \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                let responseText = String(data: data, encoding: .utf8) ?? ""
                print("[PttApiService] addUser: HTTP error, response = \(responseText)")
                throw PttApiError.networkError
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("[PttApiService] addUser: Failed to parse JSON")
                throw PttApiError.parseError
            }

            print("[PttApiService] addUser: Response = \(json)")

            let code = json["code"] as? Int
            if code != 20000 && code != 60204 {
                let message = json["message"] as? String ?? "添加用户失败"
                throw PttApiError.serverError(message)
            }

            // code == 20000 表示成功，直接返回
            // 注意：服务器的 isok 和 message 字段可能不一致，以 code 为准
            return true
        } catch let error as PttApiError {
            throw error
        } catch {
            print("[PttApiService] addUser: Network error = \(error)")
            throw PttApiError.networkError
        }
    }

    /// 更新用户（保留原始用户的所有字段）
    /// - Parameters:
    ///   - originalUser: 原始用户对象（包含所有字段）
    ///   - phone: 新手机号（可选）
    ///   - password: 新密码（可选）
    ///   - name: 新姓名（可选）
    ///   - callsign: 新呼号（可选）
    ///   - roles: 新角色（可选）
    public func updateUser(originalUser: PttUser, phone: String? = nil, password: String? = nil, name: String? = nil, callsign: String? = nil, roles: [String]? = nil, dmrid: String? = nil, mdcid: String? = nil) async throws -> Bool {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        // 正确的端点是 /user/update
        let url = try makeURL("/user/update")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")

        // 从原始用户获取所有字段
        var body = originalUser.toUpdateDict()

        // 覆盖需要更新的字段
        if let phone = phone { body["phone"] = phone }
        if let password = password, !password.isEmpty { body["password"] = password }
        if let name = name { body["name"] = name }
        if let callsign = callsign { body["callsign"] = callsign }
        if let roles = roles { body["roles"] = roles }
        if let dmrid = dmrid { body["dmrid"] = dmrid }
        if let mdcid = mdcid { body["mdcid"] = mdcid }

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = bodyData
        print("[PttApiService] POST /user/update: \(String(data: bodyData, encoding: .utf8) ?? "")")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("[PttApiService] updateUser: Invalid response type")
                throw PttApiError.networkError
            }

            print("[PttApiService] updateUser: HTTP status = \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                let responseText = String(data: data, encoding: .utf8) ?? ""
                print("[PttApiService] updateUser: HTTP error, response = \(responseText)")
                throw PttApiError.networkError
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("[PttApiService] updateUser: Failed to parse JSON")
                throw PttApiError.parseError
            }

            print("[PttApiService] updateUser: Response = \(json)")

            let code = json["code"] as? Int
            if code != 20000 && code != 60204 {
                let message = json["message"] as? String ?? "更新用户失败"
                throw PttApiError.serverError(message)
            }
            return true
        } catch let error as PttApiError {
            throw error
        } catch {
            print("[PttApiService] updateUser: Network error = \(error)")
            throw PttApiError.networkError
        }
    }

    /// 删除用户
    public func deleteUser(userId: Int) async throws -> Bool {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        // 正确的端点是 /user/delete
        let url = try makeURL("/user/delete")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")

        let body: [String: Any] = [
            "id": userId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PttApiError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        if code != 20000 && code != 60204 {
            let message = json["message"] as? String ?? "删除用户失败"
            throw PttApiError.serverError(message)
        }
        return true
    }

    /// 切换用户启用/禁用状态
    public func toggleUserStatus(user: PttUser, enabled: Bool) async throws -> Bool {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        let url = try makeURL("/user/update")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")

        // 保留原始字段，只修改 status
        var body = user.toUpdateDict()
        body["status"] = enabled ? 1 : 0

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PttApiError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        if code != 20000 && code != 60204 {
            let message = json["message"] as? String ?? "更新状态失败"
            throw PttApiError.serverError(message)
        }
        return true
    }

    // MARK: - 注册管理

    /// 获取注册申请列表
    public func getRegistrationList() async throws -> [PttRegistration] {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        let url = try makeURL("/user/reg/list")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")
        request.httpBody = "{}".data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PttApiError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        guard code == 20000 || code == 60204 else {
            let message = json["message"] as? String ?? "获取注册列表失败"
            throw PttApiError.serverError(message)
        }

        var registrations: [PttRegistration] = []
        if let resultData = json["data"] as? [String: Any],
           let items = resultData["items"] {
            if let itemsMap = items as? [String: [String: Any]] {
                registrations = itemsMap.values.compactMap { PttRegistration(json: $0) }
            } else if let itemsList = items as? [[String: Any]] {
                registrations = itemsList.compactMap { PttRegistration(json: $0) }
            }
        } else if let list = json["data"] as? [[String: Any]] {
            registrations = list.compactMap { PttRegistration(json: $0) }
        }

        return registrations
    }

    /// 审核注册申请
    /// - Parameters:
    ///   - regId: 注册ID
    ///   - status: 状态 (1=通过, 2=拒绝)
    ///   - note: 备注
    public func reviewRegistration(regId: Int, status: Int, note: String? = nil) async throws -> Bool {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        let url = try makeURL("/user/reg/update")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")

        var body: [String: Any] = [
            "id": regId,
            "status": status
        ]
        if let note = note { body["note"] = note }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PttApiError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        if code != 20000 && code != 60204 {
            let message = json["message"] as? String ?? "审核失败"
            throw PttApiError.serverError(message)
        }
        return true
    }

    /// 删除注册申请
    public func deleteRegistration(regId: Int) async throws -> Bool {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        let url = try makeURL("/user/reg/delete")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")

        let body: [String: Any] = ["id": regId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PttApiError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        if code != 20000 && code != 60204 {
            let message = json["message"] as? String ?? "删除失败"
            throw PttApiError.serverError(message)
        }
        return true
    }

    /// 从 API URL 提取 UDP 主机地址
    public func extractUdpHost() -> String {
        guard let url = URL(string: baseURL) else {
            return "ptt.pgarlic.com"
        }
        return url.host ?? "ptt.pgarlic.com"
    }

    // MARK: - 平台服务器列表 (登录前)

    /// 获取平台服务器列表（无需登录）
    /// - Returns: 服务器列表
    public static func fetchPlatformList() async throws -> [PlatformServer] {
        let urlString = "https://ptt.pgarlic.com/platform/list"
        guard let url = URL(string: urlString) else {
            throw PttApiError.invalidURL(urlString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = "{}".data(using: .utf8)

        print("[PttApiService] POST /platform/list")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PttApiError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        guard code == 20000 else {
            let message = json["message"] as? String ?? "获取服务器列表失败"
            throw PttApiError.serverError(message)
        }

        var servers: [PlatformServer] = []
        if let resultData = json["data"] as? [String: Any],
           let items = resultData["items"] as? [[String: Any]] {
            servers = items.compactMap { PlatformServer(json: $0) }
        }

        print("[PttApiService] Got \(servers.count) platform servers")
        return servers
    }

    // MARK: - 节点管理 (服务器互联)

    /// 获取服务器节点列表
    /// - Parameter search: 搜索关键字（可选）
    /// - Returns: 节点列表
    public func getServerNodes(search: String? = nil) async throws -> [PttServerNode] {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        let url = try makeURL("/server/list")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")

        var body: [String: Any] = [:]
        if let search = search, !search.isEmpty {
            body["search"] = search
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[PttApiService] POST /server/list")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PttApiError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        guard code == 20000 || code == 60204 else {
            let message = json["message"] as? String ?? "获取节点列表失败"
            throw PttApiError.serverError(message)
        }

        var nodes: [PttServerNode] = []
        let resultData = json["data"]

        // 处理多种数据格式
        if let dataArray = resultData as? [[String: Any]] {
            // 格式1: data 直接是数组
            for item in dataArray {
                if let node = PttServerNode(json: item) {
                    nodes.append(node)
                }
            }
        } else if let dataMap = resultData as? [String: Any] {
            // 格式2: data 是对象，包含 items
            if let items = dataMap["items"] {
                if let itemsArray = items as? [[String: Any]] {
                    // items 是数组
                    for item in itemsArray {
                        if let node = PttServerNode(json: item) {
                            nodes.append(node)
                        }
                    }
                } else if let itemsMap = items as? [String: [String: Any]] {
                    // items 是字典 (key: value)
                    for (_, item) in itemsMap {
                        if let node = PttServerNode(json: item) {
                            nodes.append(node)
                        }
                    }
                }
            }
        }

        print("[PttApiService] Got \(nodes.count) server nodes")
        return nodes
    }

    /// 创建服务器节点
    public func createServerNode(
        name: String,
        serverType: Int,
        ipAddr: String?,
        dnsName: String?,
        udpPort: Int,
        note: String?
    ) async throws -> Bool {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        let url = try makeURL("/server/create")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")

        var body: [String: Any] = [
            "name": name,
            "server_type": serverType,
            "udp_port": udpPort,
            "status": 1
        ]
        if let ipAddr = ipAddr, !ipAddr.isEmpty {
            body["ip_addr"] = ipAddr
        }
        if let dnsName = dnsName, !dnsName.isEmpty {
            body["dns_name"] = dnsName
        }
        if let note = note, !note.isEmpty {
            body["note"] = note
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[PttApiService] POST /server/create")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PttApiError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        if code == 20000 || code == 60204 {
            print("[PttApiService] Server node created successfully")
            return true
        } else {
            let message = json["message"] as? String ?? "创建节点失败"
            throw PttApiError.serverError(message)
        }
    }

    /// 更新服务器节点
    public func updateServerNode(
        id: Int,
        name: String,
        serverType: Int,
        ipAddr: String?,
        dnsName: String?,
        udpPort: Int,
        status: Int,
        note: String?,
        owerId: Int? = nil,
        owerCallsign: String? = nil
    ) async throws -> Bool {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        let url = try makeURL("/server/update")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")

        var body: [String: Any] = [
            "id": id,
            "name": name,
            "server_type": serverType,
            "udp_port": udpPort,
            "status": status
        ]
        if let ipAddr = ipAddr {
            body["ip_addr"] = ipAddr
        }
        if let dnsName = dnsName {
            body["dns_name"] = dnsName
        }
        if let note = note {
            body["note"] = note
        }
        // 保留所有者信息
        if let owerId = owerId {
            body["ower_id"] = owerId
        }
        if let owerCallsign = owerCallsign {
            body["ower_callsign"] = owerCallsign
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[PttApiService] POST /server/update")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PttApiError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        if code == 20000 || code == 60204 {
            print("[PttApiService] Server node updated successfully")
            return true
        } else {
            let message = json["message"] as? String ?? "更新节点失败"
            throw PttApiError.serverError(message)
        }
    }

    /// 删除服务器节点
    public func deleteServerNode(id: Int) async throws -> Bool {
        guard let token = token else {
            throw PttApiError.notAuthenticated
        }

        let url = try makeURL("/server/delete")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "x-token")

        let body: [String: Any] = ["id": id]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[PttApiService] POST /server/delete")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PttApiError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PttApiError.parseError
        }

        let code = json["code"] as? Int
        if code == 20000 || code == 60204 {
            print("[PttApiService] Server node deleted successfully")
            return true
        } else {
            let message = json["message"] as? String ?? "删除节点失败"
            throw PttApiError.serverError(message)
        }
    }

    /// 切换服务器节点状态 (启用/禁用)
    public func toggleServerNodeStatus(node: PttServerNode) async throws -> Bool {
        let newStatus = node.status == 1 ? 2 : 1
        return try await updateServerNode(
            id: node.id,
            name: node.name,
            serverType: node.serverType,
            ipAddr: node.ipAddr,
            dnsName: node.dnsName,
            udpPort: node.udpPort,
            status: newStatus,
            note: node.note,
            owerId: node.owerId,
            owerCallsign: node.owerCallsign
        )
    }
}

// MARK: - 数据模型

public struct LoginResult: Sendable {
    public let token: String
}

public struct UserInfo: Sendable {
    public let id: Int
    public let callsign: String
    public let ssid: Int
    public let isAdmin: Bool
    public let groupId: Int
    public let dmrid: String?
    public let mdcid: String?
}

// MARK: - 用户模型

public struct PttUser: Sendable, Identifiable {
    public let id: Int
    public let name: String           // 姓名
    public let phone: String          // 手机号
    public let callsign: String       // 呼号
    public let roles: [String]
    public let createTime: String?
    public let updateTime: String?

    // 额外字段 - 更新时需要保留
    public let birthday: String?      // 出生日期
    public let avatar: String?        // 头像
    public let sex: Int               // 性别: 0=未知, 1=男, 2=女
    public let address: String?       // 地址
    public let mail: String?          // 邮箱
    public let introduction: String?  // 简介
    public let gird: String?          // 网格
    public let status: Int            // 状态
    public let nickname: String?      // 昵称
    public let groupId: Int           // 群组ID（禁用时需保留）
    public let dmrid: String?         // DMR ID（协议传输 + 后端存储）
    public let mdcid: String?         // MDC ID（仅后端存储）

    // 兼容旧代码
    public var username: String { phone }
    public var ssid: Int { 106 }

    public var isAdmin: Bool {
        roles.contains("admin")
    }

    public var displayName: String {
        if !callsign.isEmpty {
            return callsign
        }
        return name.isEmpty ? phone : name
    }

    public var rolesText: String {
        if roles.contains("admin") {
            return "管理员"
        } else if roles.contains("ham") {
            return "HAM用户"
        } else {
            return "普通用户"
        }
    }

    /// 是否启用（status == 1 表示启用）
    public var isEnabled: Bool {
        status == 1
    }

    /// 状态文本
    public var statusText: String {
        isEnabled ? "启用" : "禁用"
    }

    /// 转换为用于更新的字典（保留所有原始字段）
    public func toUpdateDict() -> [String: Any] {
        var dict: [String: Any] = ["id": id]
        dict["name"] = name
        dict["phone"] = phone
        dict["callsign"] = callsign
        dict["roles"] = roles
        if let birthday = birthday { dict["birthday"] = birthday }
        if let avatar = avatar { dict["avatar"] = avatar }
        dict["sex"] = sex
        if let address = address { dict["Address"] = address }
        if let mail = mail { dict["Mail"] = mail }
        if let introduction = introduction { dict["introduction"] = introduction }
        if let gird = gird { dict["gird"] = gird }
        dict["status"] = status
        if let nickname = nickname { dict["nickname"] = nickname }
        dict["group_id"] = groupId
        if let dmrid = dmrid { dict["dmrid"] = dmrid }
        if let mdcid = mdcid { dict["mdcid"] = mdcid }
        return dict
    }

    public init?(json: [String: Any]) {
        guard let id = json["id"] as? Int else {
            return nil
        }
        self.id = id
        self.name = json["name"] as? String ?? ""
        self.phone = json["phone"] as? String ?? ""
        self.callsign = json["callsign"] as? String ?? ""
        self.roles = json["roles"] as? [String] ?? ["user"]
        self.createTime = json["create_time"] as? String
        self.updateTime = json["update_time"] as? String

        // 额外字段
        self.birthday = json["birthday"] as? String
        self.avatar = json["avatar"] as? String
        self.sex = json["sex"] as? Int ?? 0
        self.address = json["Address"] as? String
        self.mail = json["Mail"] as? String
        self.introduction = json["introduction"] as? String
        self.gird = json["gird"] as? String
        self.status = json["status"] as? Int ?? 1
        self.nickname = json["nickname"] as? String
        self.groupId = json["group_id"] as? Int ?? 0
        self.dmrid = json["dmrid"] as? String
        self.mdcid = json["mdcid"] as? String
    }
}

// MARK: - 注册申请模型

public struct PttRegistration: Sendable, Identifiable {
    public let id: Int
    public let name: String           // 姓名
    public let phone: String          // 手机号
    public let callsign: String
    public let status: Int            // 0=待审核, 2=已通过, 其他=已拒绝
    public let note: String?
    public let createTime: String?
    public let updateTime: String?
    public let imageUrl: String?

    // 兼容旧代码
    public var username: String { phone }
    public var ssid: Int { 106 }

    public var statusText: String {
        switch status {
        case 0: return "待审核"
        case 2: return "已通过"
        default: return "已拒绝"
        }
    }

    public var statusColor: String {
        switch status {
        case 0: return "orange"
        case 2: return "green"
        default: return "red"
        }
    }

    public var displayName: String {
        if !callsign.isEmpty {
            return callsign
        }
        return name.isEmpty ? phone : name
    }

    public init?(json: [String: Any]) {
        guard let id = json["id"] as? Int else {
            return nil
        }
        self.id = id
        self.name = json["name"] as? String ?? ""
        self.phone = json["phone"] as? String ?? ""
        self.callsign = json["callsign"] as? String ?? ""
        self.status = json["status"] as? Int ?? 0
        self.note = json["note"] as? String
        self.createTime = json["create_time"] as? String
        self.updateTime = json["update_time"] as? String
        self.imageUrl = json["license_path"] as? String ?? json["op_cert_path"] as? String
    }
}

public struct PttGroup: Sendable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let type: Int
    public let memberCount: Int
    public let onlineCount: Int
    public let description: String?
    public let isDefault: Bool

    public init?(json: [String: Any]) {
        guard let id = json["id"] as? Int,
              let name = json["name"] as? String else {
            return nil
        }
        self.id = id
        self.name = name
        self.type = json["type"] as? Int ?? 0
        self.description = json["note"] as? String ?? json["description"] as? String
        self.isDefault = (json["is_default"] as? Bool) ?? (id == 0)

        // 计算在线人数
        // devlist 是设备ID数组 [Int]，devmap 是设备详情字典 [String: Device]
        var memberCount = 0
        var onlineCount = 0

        if let devmap = json["devmap"] as? [String: [String: Any]] {
            // 优先使用 devmap（包含设备详情和在线状态）
            memberCount = devmap.count
            onlineCount = devmap.values.filter { ($0["is_online"] as? Bool) == true }.count
        } else if let devlist = json["devlist"] as? [Int] {
            // devlist 只有设备ID，无法判断在线状态
            memberCount = devlist.count
            onlineCount = 0
        }

        self.memberCount = memberCount
        self.onlineCount = onlineCount
    }

    /// 群组类型名称
    /// 服务器返回的 type 值 (来自 nrllink-mp/utils/constants.js):
    /// 0=公共房间, 1=中继互联, 2=设备互联, 3=守听, 4=数模互联,
    /// 5=俱乐部, 6=车友会, 7=会议组, 8=私人房间, 100=其他
    public var typeName: String {
        switch type {
        case 0: return "公共房间"
        case 1: return "中继互联"
        case 2: return "设备互联"
        case 3: return "守听"
        case 4: return "数模互联"
        case 5: return "俱乐部"
        case 6: return "车友会"
        case 7: return "会议组"
        case 8: return "私人房间"
        case 100: return "其他"
        default: return "未知(\(type))"
        }
    }

    /// 群组类型图标 (SF Symbols)
    public var typeIcon: String {
        switch type {
        case 0: return "antenna.radiowaves.left.and.right"  // 公共房间
        case 1: return "point.3.connected.trianglepath.dotted"  // 中继互联
        case 2: return "cable.connector"          // 设备互联
        case 3: return "headphones"               // 守听
        case 4: return "waveform.and.magnifyingglass"  // 数模互联
        case 5: return "star.fill"                // 俱乐部
        case 6: return "car.fill"                 // 车友会
        case 7: return "person.3.fill"            // 会议组
        case 8: return "lock.fill"                // 私人房间
        case 100: return "ellipsis.circle"        // 其他
        default: return "questionmark.circle"     // 未知
        }
    }

    /// 是否为会议模式
    public var isConferenceMode: Bool { type == 7 }

    /// 是否有在线成员
    public var hasOnlineMembers: Bool { onlineCount > 0 }
}

/// 群组详情
public struct GroupDetail: Sendable {
    public let groupId: Int
    public let devices: [PttDevice]

    public var onlineCount: Int {
        devices.filter { $0.isOnline }.count
    }
}

/// PTT 设备
public struct PttDevice: Sendable, Identifiable {
    public let id: Int
    public let callsign: String
    public let ssid: Int
    public let name: String?
    public let isOnline: Bool
    public let status: Int
    public let groupId: Int
    public let devModel: Int
    public let rfType: Int
    public let priority: Int
    public let qth: String?
    public let lastVoiceEndTime: String?

    public init?(json: [String: Any]) {
        guard let id = json["id"] as? Int,
              let callsign = json["callsign"] as? String else {
            return nil
        }
        self.id = id
        self.callsign = callsign
        self.ssid = json["ssid"] as? Int ?? 0
        self.name = json["name"] as? String
        self.isOnline = json["is_online"] as? Bool ?? (json["status"] as? Int == 0)
        self.status = json["status"] as? Int ?? 0
        self.groupId = json["group_id"] as? Int ?? 0
        self.devModel = json["dev_model"] as? Int ?? 0
        self.rfType = json["rf_type"] as? Int ?? 0
        self.priority = json["priority"] as? Int ?? 100  // 服务端默认值为 100
        self.qth = json["qth"] as? String
        self.lastVoiceEndTime = json["last_voice_end_time"] as? String
    }

    /// 显示名称
    public var displayName: String {
        "\(callsign)-\(ssid)"
    }

    /// 是否禁收 (bit0)
    public var isMuteReceive: Bool {
        (status & 1) == 1
    }

    /// 是否禁发 (bit1)
    public var isMuteTransmit: Bool {
        (status & 2) == 2
    }

    /// 状态文本
    public var statusText: String {
        var statuses: [String] = []
        if isMuteReceive { statuses.append("禁收") }
        if isMuteTransmit { statuses.append("禁发") }
        return statuses.isEmpty ? "正常" : statuses.joined(separator: ", ")
    }

    /// 设备型号名称
    /// 来源: nrllink-mp/utils/constants.js
    public var devModelName: String {
        switch devModel {
        case 0: return "未知"
        case 1: return "NRL-2100"
        case 2: return "NRL-2200"
        case 3: return "NRL-2300"
        case 4: return "win-PC"
        case 5: return "IOS"
        case 6: return "Android"
        case 7: return "树莓派"
        case 8: return "NRL-2600"
        case 9: return "NR-3188"
        case 10: return "NRL-7100"
        case 11: return "NRL-FT891"
        case 12: return "NRL-TS480"
        case 13: return "NRL-IC2720"
        case 14: return "NRL-2730"
        case 15: return "NRL-FT7900"
        case 16: return "NRL-V71/D710"
        case 17: return "NRL-3100"
        case 18: return "NRL-8100-HF"
        case 19: return "DR-635"
        case 20: return "FTM-300D"
        case 21: return "FTM-400D"
        case 22: return "ESP32"
        case 23: return "MMDVM"
        case 25: return "4G便携"
        case 100: return "微信小程序"
        case 101: return "安卓APP"
        case 102: return "苹果APP"
        case 106: return "救援APP"
        case 200: return "NRL-Server"
        default: return "其他(\(devModel))"
        }
    }

    /// 设备型号图标 (SF Symbols)
    public var devModelIcon: String {
        switch devModel {
        // 未知/默认 - 使用通用电台图标
        case 0: return "antenna.radiowaves.left.and.right"

        // NRL 系列硬件设备
        case 1, 2, 3, 8, 14, 17:  // NRL-2100/2200/2300/2600/2730/3100
            return "antenna.radiowaves.left.and.right"
        case 10: return "radio"                    // NRL-7100
        case 18: return "dot.radiowaves.right"     // NRL-8100-HF (短波)

        // 车载电台
        case 9:  return "car.fill"                 // NR-3188 车载
        case 11, 12, 13, 15, 16, 19, 20, 21:       // 各种车载电台
            return "car.rear.road.lane"

        // 电脑端
        case 4: return "desktopcomputer"           // win-PC
        case 7: return "cpu"                       // 树莓派

        // 手机APP
        case 5: return "iphone"                    // IOS
        case 6: return "candybarphone"             // Android
        case 100: return "message.fill"            // 微信小程序
        case 101: return "candybarphone"           // 安卓APP
        case 102: return "iphone"                  // 苹果APP
        case 106: return "cross.circle.fill"       // 救援APP

        // 其他硬件
        case 22: return "cpu.fill"                 // ESP32
        case 23: return "waveform.badge.mic"       // MMDVM 数字中继
        case 25: return "radio.fill"               // 4G便携

        // 服务器
        case 200: return "server.rack"             // NRL-Server

        // 其他未知类型也用通用电台图标
        default: return "antenna.radiowaves.left.and.right"
        }
    }

    /// 射频类型名称
    public var rfTypeName: String {
        switch rfType {
        case 0: return "无射频"
        case 1: return "1W模块"
        case 2: return "2W模块"
        case 3: return "Moto3188/3688"
        case 5: return "Yaesu"
        case 6: return "ICOM"
        case 7: return "其它"
        default: return "未知"
        }
    }

    /// 格式化最后通话时间
    public var formattedLastVoiceTime: String? {
        guard let timeStr = lastVoiceEndTime,
              !timeStr.hasPrefix("0001") else {
            return nil
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: timeStr) {
            // 使用系统本地时区，不需要手动加时区偏移
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "M/d HH:mm"
            outputFormatter.timeZone = TimeZone.current
            return outputFormatter.string(from: date)
        }
        return timeStr
    }
}

// MARK: - 服务器节点模型 (服务器互联)

/// PTT 服务器节点
public struct PttServerNode: Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let serverType: Int
    public let ipAddr: String?
    public let dnsName: String?
    public let udpPort: Int
    public let cpuType: String?
    public let memSize: String?
    public let inputRate: String?
    public let outputRate: String?
    public let netcard: String?
    public let ipType: String?
    public let owerId: Int?
    public let owerCallsign: String?
    public let status: Int  // 1=启用, 2=禁用
    public let isOnline: Bool
    public let createTime: String?
    public let updateTime: String?
    public let note: String?

    public init?(json: [String: Any]) {
        guard let id = json["id"] as? Int,
              let name = json["name"] as? String else {
            return nil
        }
        self.id = id
        self.name = name
        self.serverType = json["server_type"] as? Int ?? 1
        self.ipAddr = json["ip_addr"] as? String
        self.dnsName = json["dns_name"] as? String
        self.udpPort = json["udp_port"] as? Int ?? 60050
        self.cpuType = json["cpu_type"] as? String
        self.memSize = json["mem_size"] as? String
        self.inputRate = json["input_rate"] as? String
        self.outputRate = json["output_rate"] as? String
        self.netcard = json["netcard"] as? String
        self.ipType = json["ip_type"] as? String
        self.owerId = json["ower_id"] as? Int
        self.owerCallsign = json["ower_callsign"] as? String
        self.status = json["status"] as? Int ?? 1
        self.isOnline = json["is_online"] as? Bool ?? false
        self.createTime = json["create_time"] as? String
        self.updateTime = json["update_time"] as? String
        self.note = json["note"] as? String
    }

    /// 服务器类型名称
    /// 1=专用服务器, 2=普通PC, 3=小主机, 4=树莓派等开发板
    public var serverTypeName: String {
        switch serverType {
        case 1: return "专用服务器"
        case 2: return "普通PC"
        case 3: return "小主机"
        case 4: return "树莓派等开发板"
        default: return "其他"
        }
    }

    /// 是否启用
    public var isEnabled: Bool {
        status == 1
    }

    /// 状态文本
    public var statusText: String {
        isEnabled ? "运行中" : "已停止"
    }

    /// 地址显示 (优先显示域名，没有则显示IP)
    public var addressDisplay: String {
        if let dns = dnsName, !dns.isEmpty {
            return dns
        }
        if let ip = ipAddr, !ip.isEmpty {
            return ip
        }
        return "未配置"
    }
}

// MARK: - 错误类型

public enum PttApiError: Error, LocalizedError {
    case networkError
    case parseError
    case notAuthenticated
    case serverError(String)
    case invalidURL(String)
    case tokenExpired

    public var errorDescription: String? {
        switch self {
        case .networkError:
            return "网络请求失败"
        case .parseError:
            return "数据解析失败"
        case .notAuthenticated:
            return "未登录"
        case .serverError(let message):
            return message
        case .invalidURL(let url):
            return "无效的 URL: \(url)"
        case .tokenExpired:
            return "登录已过期，请重新登录"
        }
    }

    /// 是否为 Token 过期错误
    public var isTokenExpired: Bool {
        if case .tokenExpired = self { return true }
        return false
    }
}

// MARK: - 平台服务器模型 (登录前选择)

/// 平台服务器节点（用于登录页面选择）
public struct PlatformServer: Sendable, Identifiable, Hashable, Codable {
    public var id: String { "\(host):\(port)" }
    public let name: String
    public let host: String
    public let port: String
    public let online: Int
    public let total: Int

    /// 是否为自定义服务器
    public let isCustom: Bool

    /// 完整 API URL (https，不带端口)
    public var url: String {
        "https://\(host)"
    }

    /// UDP 端口
    public var udpPort: UInt16 {
        UInt16(port) ?? 60050
    }

    /// 显示的在线信息
    public var onlineInfo: String {
        isCustom ? "自定义" : "\(online)/\(total) 在线"
    }

    /// 从 API JSON 初始化
    public init?(json: [String: Any]) {
        guard let name = json["name"] as? String,
              let host = json["host"] as? String,
              let port = json["port"] as? String else {
            return nil
        }
        self.name = name
        self.host = host
        self.port = port
        self.online = json["online"] as? Int ?? 0
        self.total = json["total"] as? Int ?? 0
        self.isCustom = false
    }

    /// 创建自定义服务器
    public init(name: String, host: String, port: String) {
        self.name = name
        self.host = host
        self.port = port
        self.online = 0
        self.total = 0
        self.isCustom = true
    }
}
