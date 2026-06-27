import Foundation
import SwiftUI

// MARK: - 生图协议
enum ImageProtocol: String, CaseIterable, Codable, Identifiable {
    case openai = "OpenAI 兼容"
    case sdWebUI = "Stable Diffusion WebUI"
    case comfyUI = "ComfyUI"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var supportsModel: Bool {
        switch self {
        case .openai: return true
        case .sdWebUI, .comfyUI: return false
        }
    }
    
    var supportsSize: Bool {
        switch self {
        case .openai: return true
        case .sdWebUI, .comfyUI: return false
        }
    }
    
    var supportsSteps: Bool {
        switch self {
        case .sdWebUI, .comfyUI: return true
        case .openai: return false
        }
    }
    
    var supportsNegativePrompt: Bool {
        switch self {
        case .sdWebUI: return true
        case .openai, .comfyUI: return false
        }
    }
}

// MARK: - 供应商
struct Provider: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var protocolType: ImageProtocol
    var apiURL: String
    var apiKey: String
    var model: String
    
    init(id: UUID = UUID(), name: String, protocolType: ImageProtocol,
         apiURL: String = "", apiKey: String = "", model: String = "") {
        self.id = id
        self.name = name
        self.protocolType = protocolType
        self.apiURL = apiURL
        self.apiKey = apiKey
        self.model = model
    }
}

// MARK: - 图片尺寸
struct ImageSizeOption: Identifiable, Codable, Equatable {
    var id: String { label }
    let label: String
    let width: Int
    let height: Int
    
    static let presets: [ImageSizeOption] = [
        ImageSizeOption(label: "方形 1024×1024", width: 1024, height: 1024),
        ImageSizeOption(label: "横版 1792×1024", width: 1792, height: 1024),
        ImageSizeOption(label: "竖版 1024×1792", width: 1024, height: 1792),
        ImageSizeOption(label: "1080p 横版 1920×1080", width: 1920, height: 1080),
        ImageSizeOption(label: "1080p 竖版 1080×1920", width: 1080, height: 1920),
        ImageSizeOption(label: "2K 横版 2560×1440", width: 2560, height: 1440),
        ImageSizeOption(label: "2K 竖版 1440×2560", width: 1440, height: 2560),
        ImageSizeOption(label: "4K 横版 3840×2160", width: 3840, height: 2160),
        ImageSizeOption(label: "4K 竖版 2160×3840", width: 2160, height: 3840),
        ImageSizeOption(label: "自定义", width: 1024, height: 1024),
    ]
}

// MARK: - 生成记录
struct GenerationRecord: Identifiable, Codable {
    let id: UUID
    let prompt: String
    let negativePrompt: String
    let providerName: String
    let protocolType: ImageProtocol
    let model: String
    let sizeLabel: String
    let imageData: Data?
    let imageURL: String?
    let timestamp: Date
    let isSuccess: Bool
    let errorMessage: String?
    
    init(id: UUID = UUID(), prompt: String, negativePrompt: String = "",
         providerName: String, protocolType: ImageProtocol, model: String = "",
         sizeLabel: String = "", imageData: Data? = nil,
         imageURL: String? = nil, timestamp: Date = Date(),
         isSuccess: Bool, errorMessage: String? = nil) {
        self.id = id
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        self.providerName = providerName
        self.protocolType = protocolType
        self.model = model
        self.sizeLabel = sizeLabel
        self.imageData = imageData
        self.imageURL = imageURL
        self.timestamp = timestamp
        self.isSuccess = isSuccess
        self.errorMessage = errorMessage
    }
}

// MARK: - App 配置
class AppConfig: ObservableObject {
    @Published var providers: [Provider] = []
    @Published var activeProviderID: UUID?
    @Published var imageSize: ImageSizeOption = ImageSizeOption.presets[0]
    @Published var customWidth: Int = 1024
    @Published var customHeight: Int = 1024
    @Published var steps: Double = 20
    @Published var history: [GenerationRecord] = []
    
    var activeProvider: Provider? {
        providers.first { $0.id == activeProviderID }
    }
    
    var currentSize: ImageSizeOption {
        if imageSize.label == "自定义" {
            return ImageSizeOption(label: "自定义 \(customWidth)×\(customHeight)", width: customWidth, height: customHeight)
        }
        return imageSize
    }
    
    private let defaults = UserDefaults.standard
    private let providersKey = "saved_providers"
    private let activeKey = "active_provider_id"
    private let historyKey = "generation_history"
    private let sizeKey = "saved_image_size"
    private let stepsKey = "saved_steps"
    private let customWKey = "custom_width"
    private let customHKey = "custom_height"
    
    init() {
        loadAll()
    }
    
    func loadAll() {
        // 加载供应商
        if let data = defaults.data(forKey: providersKey),
           let list = try? JSONDecoder().decode([Provider].self, from: data) {
            providers = list
        }
        
        // 加载活跃供应商
        if let idStr = defaults.string(forKey: activeKey),
           let id = UUID(uuidString: idStr) {
            activeProviderID = id
        }
        
        // 如果没有任何供应商，添加默认空模板
        if providers.isEmpty {
            providers = [
                Provider(name: "我的供应商", protocolType: .openai, apiURL: "", apiKey: "", model: "dall-e-3"),
                Provider(name: "SD WebUI", protocolType: .sdWebUI, apiURL: "http://192.168.1.100:7860/sdapi/v1/txt2img"),
                Provider(name: "ComfyUI", protocolType: .comfyUI, apiURL: "http://192.168.1.100:8188/prompt"),
            ]
            activeProviderID = providers[0].id
            saveProviders()
        }
        
        // 如果活跃供应商不存在，选第一个
        if activeProviderID == nil || !providers.contains(where: { $0.id == activeProviderID }) {
            activeProviderID = providers.first?.id
        }
        
        // 加载尺寸
        if let data = defaults.data(forKey: sizeKey),
           let size = try? JSONDecoder().decode(ImageSizeOption.self, from: data) {
            imageSize = size
        }
        customWidth = defaults.integer(forKey: customWKey).nonZero ?? 1024
        customHeight = defaults.integer(forKey: customHKey).nonZero ?? 1024
        steps = defaults.double(forKey: stepsKey).nonZero ?? 20
        
        // 加载历史
        if let data = defaults.data(forKey: historyKey),
           let records = try? JSONDecoder().decode([GenerationRecord].self, from: data) {
            history = records
        }
    }
    
    func saveProviders() {
        guard let data = try? JSONEncoder().encode(providers) else { return }
        defaults.set(data, forKey: providersKey)
        defaults.set(activeProviderID?.uuidString, forKey: activeKey)
    }
    
    func saveSettings() {
        if let data = try? JSONEncoder().encode(imageSize) {
            defaults.set(data, forKey: sizeKey)
        }
        defaults.set(customWidth, forKey: customWKey)
        defaults.set(customHeight, forKey: customHKey)
        defaults.set(steps, forKey: stepsKey)
    }
    
    func addProvider(_ provider: Provider) {
        providers.append(provider)
        saveProviders()
    }
    
    func updateProvider(_ provider: Provider) {
        if let idx = providers.firstIndex(where: { $0.id == provider.id }) {
            providers[idx] = provider
            saveProviders()
        }
    }
    
    func deleteProvider(_ id: UUID) {
        providers.removeAll { $0.id == id }
        if activeProviderID == id {
            activeProviderID = providers.first?.id
        }
        saveProviders()
    }
    
    func addRecord(_ record: GenerationRecord) {
        history.insert(record, at: 0)
        if history.count > 200 {
            history = Array(history.prefix(200))
        }
        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: historyKey)
        }
    }
    
    func clearHistory() {
        history.removeAll()
        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: historyKey)
        }
    }
}

extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
