import Foundation
import SwiftUI

// MARK: - 支持的 Provider 协议
enum ImageProvider: String, CaseIterable, Codable {
    case openai = "OpenAI DALL-E 3"
    case openaiCompatible = "OpenAI 兼容"
    case sdWebUI = "Stable Diffusion WebUI"
    case comfyUI = "ComfyUI"
    
    var endpoint: String {
        switch self {
        case .openai:
            return "https://api.openai.com/v1/images/generations"
        case .openaiCompatible:
            return "https://hk.geek2api.com/v1/images/generations"
        case .sdWebUI:
            return "http://127.0.0.1:7860/sdapi/v1/txt2img"
        case .comfyUI:
            return "http://127.0.0.1:8188/prompt"
        }
    }
    
    var defaultModel: String {
        switch self {
        case .openai:
            return "dall-e-3"
        case .openaiCompatible:
            return "gpt-image-2"
        case .sdWebUI:
            return ""
        case .comfyUI:
            return ""
        }
    }
    
    var supportsModel: Bool {
        switch self {
        case .openai, .openaiCompatible:
            return true
        case .sdWebUI, .comfyUI:
            return false
        }
    }
    
    var supportsSize: Bool {
        switch self {
        case .openai, .openaiCompatible:
            return true
        case .sdWebUI, .comfyUI:
            return false
        }
    }
    
    var supportsSteps: Bool {
        switch self {
        case .sdWebUI, .comfyUI:
            return true
        case .openai, .openaiCompatible:
            return false
        }
    }
}

// MARK: - 图片尺寸
enum ImageSize: String, CaseIterable, Codable {
    case square = "1024x1024"
    case landscape = "1792x1024"
    case portrait = "1024x1792"
    
    var displayName: String {
        switch self {
        case .square: return "方形 1:1"
        case .landscape: return "横版 16:9"
        case .portrait: return "竖版 9:16"
        }
    }
}

// MARK: - 生成记录
struct GenerationRecord: Identifiable, Codable {
    let id: UUID
    let prompt: String
    let negativePrompt: String
    let provider: ImageProvider
    let model: String
    let imageData: Data?
    let imageURL: String?
    let timestamp: Date
    let isSuccess: Bool
    let errorMessage: String?
    
    init(id: UUID = UUID(), prompt: String, negativePrompt: String = "",
         provider: ImageProvider, model: String, imageData: Data? = nil,
         imageURL: String? = nil, timestamp: Date = Date(),
         isSuccess: Bool, errorMessage: String? = nil) {
        self.id = id
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        self.provider = provider
        self.model = model
        self.imageData = imageData
        self.imageURL = imageURL
        self.timestamp = timestamp
        self.isSuccess = isSuccess
        self.errorMessage = errorMessage
    }
}

// MARK: - App 配置
class AppConfig: ObservableObject {
    @Published var provider: ImageProvider = .openaiCompatible
    @Published var apiURL: String = "https://hk.geek2api.com/v1/images/generations"
    @Published var apiKey: String = ""
    @Published var model: String = "gpt-image-2"
    @Published var imageSize: ImageSize = .square
    @Published var steps: Double = 20
    @Published var history: [GenerationRecord] = []
    
    private let defaults = UserDefaults.standard
    private let historyKey = "generation_history"
    
    init() {
        loadConfig()
        loadHistory()
    }
    
    func loadConfig() {
        if let raw = defaults.string(forKey: "provider"),
           let p = ImageProvider(rawValue: raw) {
            provider = p
        }
        apiURL = defaults.string(forKey: "api_url") ?? provider.endpoint
        apiKey = defaults.string(forKey: "api_key") ?? ""
        model = defaults.string(forKey: "model") ?? provider.defaultModel
        if let raw = defaults.string(forKey: "image_size"),
           let s = ImageSize(rawValue: raw) {
            imageSize = s
        }
        steps = defaults.double(forKey: "steps").nonZero ?? 20
    }
    
    func saveConfig() {
        defaults.set(provider.rawValue, forKey: "provider")
        defaults.set(apiURL, forKey: "api_url")
        defaults.set(apiKey, forKey: "api_key")
        defaults.set(model, forKey: "model")
        defaults.set(imageSize.rawValue, forKey: "image_size")
        defaults.set(steps, forKey: "steps")
    }
    
    func loadHistory() {
        guard let data = defaults.data(forKey: historyKey),
              let records = try? JSONDecoder().decode([GenerationRecord].self, from: data) else {
            return
        }
        history = records
    }
    
    func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: historyKey)
    }
    
    func addRecord(_ record: GenerationRecord) {
        history.insert(record, at: 0)
        if history.count > 100 {
            history = Array(history.prefix(100))
        }
        saveHistory()
    }
    
    func clearHistory() {
        history.removeAll()
        saveHistory()
    }
}

extension Double {
    var nonZero: Double? {
        self == 0 ? nil : self
    }
}
