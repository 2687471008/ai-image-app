import Foundation
import UIKit

// MARK: - 图片生成服务
class ImageGenService {
    
    enum ServiceError: LocalizedError {
        case invalidURL
        case noAPIKey
        case noActiveProvider
        case networkError(String)
        case decodeError
        case noImageInResponse
        case timeout
        case noImageSelected
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "API 地址格式错误"
            case .noAPIKey: return "请先配置 API Key"
            case .noActiveProvider: return "请先选择一个供应商"
            case .networkError(let msg): return "网络错误: \(msg)"
            case .decodeError: return "响应解析失败"
            case .noImageInResponse: return "返回数据中没有图片"
            case .timeout: return "请求超时，请检查网络或 API 地址"
            case .noImageSelected: return "请先选择一张参考图片"
            }
        }
    }
    
    // MARK: - 拉取模型列表
    func fetchModels(provider: Provider) async -> [String] {
        guard !provider.protocolType.modelListPath.isEmpty else { return [] }
        
        let baseURL = provider.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard !baseURL.isEmpty, let url = URL(string: baseURL + provider.protocolType.modelListPath) else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        if !provider.apiKey.isEmpty {
            switch provider.protocolType {
            case .gemini:
                // Gemini 用 query param
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.queryItems = [URLQueryItem(name: "key", value: provider.apiKey)]
                if let newURL = components?.url {
                    request.url = newURL
                }
            default:
                request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
            }
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return []
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return []
            }
            
            switch provider.protocolType {
            case .openai:
                if let models = json["data"] as? [[String: Any]] {
                    return models.compactMap { $0["id"] as? String }
                        .filter { $0.contains("image") || $0.contains("dall-e") || $0.contains("gpt") }
                }
            case .gemini:
                if let models = json["models"] as? [[String: Any]] {
                    return models.compactMap { $0["name"] as? String }
                        .map { $0.replacingOccurrences(of: "models/", with: "") }
                        .filter { $0.contains("imagen") || $0.contains("gemini-2.0-flash-exp-image") }
                }
            default:
                break
            }
            
            return []
        } catch {
            return []
        }
    }
    
    // MARK: - 检查连通性
    func checkConnectivity(provider: Provider) async -> (Bool, String) {
        // 对 Gemini 用不同的检查方式
        if provider.protocolType == .gemini {
            return await checkGeminiConnectivity(provider: provider)
        }
        
        guard let url = URL(string: provider.apiURL), !provider.apiURL.isEmpty else {
            return (false, "API 地址无效")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        
        if !provider.apiKey.isEmpty {
            request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, "无响应")
            }
            
            if httpResponse.statusCode == 200 {
                return (true, "连接成功 ✅")
            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                return (false, "API Key 无效 (HTTP \(httpResponse.statusCode))")
            } else if httpResponse.statusCode == 404 {
                return (false, "地址可能正确，但 GET 请求返回 404（部分 API 只接受 POST）")
            } else {
                let body = String(data: data, encoding: .utf8) ?? ""
                return (false, "HTTP \(httpResponse.statusCode): \(body.prefix(100))")
            }
        } catch let error as URLError {
            switch error.code {
            case .timedOut: return (false, "连接超时 ⏱️")
            case .cannotConnectToHost: return (false, "无法连接到服务器 🔌")
            case .notConnectedToInternet: return (false, "网络不可用 📡")
            case .dnsLookupFailed: return (false, "DNS 解析失败 🌐")
            default: return (false, "连接失败: \(error.localizedDescription)")
            }
        } catch {
            return (false, "连接失败: \(error.localizedDescription)")
        }
    }
    
    private func checkGeminiConnectivity(provider: Provider) async -> (Bool, String) {
        let baseURL = provider.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard !baseURL.isEmpty, !provider.apiKey.isEmpty else {
            return (false, "请填写 API Key")
        }
        
        guard let url = URL(string: "\(baseURL)/v1/models?key=\(provider.apiKey)") else {
            return (false, "地址无效")
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, "无响应")
            }
            if httpResponse.statusCode == 200 {
                return (true, "连接成功 ✅")
            } else {
                return (false, "HTTP \(httpResponse.statusCode)，请检查 API Key")
            }
        } catch {
            return (false, "连接失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 生成图片（文生图）
    func generate(
        prompt: String,
        negativePrompt: String,
        provider: Provider,
        size: ImageSizeOption,
        steps: Double
    ) async throws -> UIImage {
        switch provider.protocolType {
        case .openai:
            return try await generateOpenAI(prompt: prompt, provider: provider, size: size)
        case .gemini:
            return try await generateGemini(prompt: prompt, provider: provider)
        case .sdWebUI:
            return try await generateSDWebUI(prompt: prompt, negativePrompt: negativePrompt, provider: provider, size: size, steps: steps, isImg2Img: false, sourceImage: nil)
        case .comfyUI:
            return try await generateComfyUI(prompt: prompt, provider: provider, steps: steps)
        }
    }
    
    // MARK: - 图生图
    func generateImageToImage(
        prompt: String,
        sourceImage: UIImage,
        provider: Provider,
        steps: Double
    ) async throws -> UIImage {
        switch provider.protocolType {
        case .sdWebUI:
            return try await generateSDWebUI(prompt: prompt, negativePrompt: "", provider: provider, size: ImageSizeOption(label: "", width: Int(sourceImage.size.width), height: Int(sourceImage.size.height)), steps: steps, isImg2Img: true, sourceImage: sourceImage)
        case .gemini:
            // Gemini 的图生图就是传图片+prompt
            return try await generateGemini(prompt: prompt, provider: provider, sourceImage: sourceImage)
        default:
            throw ServiceError.networkError("该协议不支持图生图")
        }
    }
    
    // MARK: - OpenAI / 兼容协议
    private func generateOpenAI(prompt: String, provider: Provider, size: ImageSizeOption) async throws -> UIImage {
        guard let url = URL(string: provider.apiURL) else { throw ServiceError.invalidURL }
        guard !provider.apiKey.isEmpty else { throw ServiceError.noAPIKey }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120
        
        // OpenAI DALL-E 3 只支持 1024x1024 / 1792x1024 / 1024x1792
        // 其他兼容 API 可能只支持 1024x1024，所以用最安全的尺寸
        let safeSizes = ["1024x1024", "1792x1024", "1024x1792"]
        let sizeString = "\(size.width)x\(size.height)"
        let finalSize = safeSizes.contains(sizeString) ? sizeString : "1024x1024"
        
        var body: [String: Any] = [
            "prompt": prompt,
            "n": 1,
            "size": finalSize,
            "response_format": "b64_json"
        ]
        if !provider.model.isEmpty { body["model"] = provider.model }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw ServiceError.networkError("无响应") }
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "未知错误"
            throw ServiceError.networkError("HTTP \(httpResponse.statusCode): \(errorBody)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ServiceError.decodeError }
        
        if let dataArr = json["data"] as? [[String: Any]], let first = dataArr.first {
            if let b64 = first["b64_json"] as? String,
               let imageData = Data(base64Encoded: b64),
               let image = UIImage(data: imageData) { return image }
            if let urlStr = first["url"] as? String,
               let imgURL = URL(string: urlStr),
               let imgData = try? Data(contentsOf: imgURL),
               let image = UIImage(data: imgData) { return image }
        }
        throw ServiceError.noImageInResponse
    }
    
    // MARK: - Google Gemini Imagen
    private func generateGemini(prompt: String, provider: Provider, sourceImage: UIImage? = nil) async throws -> UIImage {
        let baseURL = provider.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard !baseURL.isEmpty else { throw ServiceError.invalidURL }
        guard !provider.apiKey.isEmpty else { throw ServiceError.noAPIKey }
        
        let modelName = provider.model.isEmpty ? "imagen-3.0-generate-001" : provider.model
        guard let url = URL(string: "\(baseURL)/v1/models/\(modelName):generateImages?key=\(provider.apiKey)") else {
            throw ServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        
        var body: [String: Any] = [
            "prompt": prompt,
            "sampleCount": 1
        ]
        
        // 如果有参考图片，传图生图
        if let srcImage = sourceImage, let imageData = srcImage.jpegData(compressionQuality: 0.8) {
            let base64Image = imageData.base64EncodedString()
            body["image"] = ["bytesBase64Encoded": base64Image]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw ServiceError.networkError("无响应") }
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "未知错误"
            throw ServiceError.networkError("HTTP \(httpResponse.statusCode): \(errorBody)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ServiceError.decodeError }
        
        // Gemini Imagen 返回格式
        if let predictions = json["predictions"] as? [[String: Any]], let first = predictions.first {
            if let b64 = first["bytesBase64Encoded"] as? String,
               let imageData = Data(base64Encoded: b64),
               let image = UIImage(data: imageData) { return image }
        }
        
        throw ServiceError.noImageInResponse
    }
    
    // MARK: - Stable Diffusion WebUI（文生图 + 图生图）
    private func generateSDWebUI(prompt: String, negativePrompt: String, provider: Provider, size: ImageSizeOption, steps: Double, isImg2Img: Bool, sourceImage: UIImage?) async throws -> UIImage {
        let endpoint = isImg2Img ? provider.apiURL.replacingOccurrences(of: "/txt2img", with: "/img2img") : provider.apiURL
        guard let url = URL(string: endpoint) else { throw ServiceError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300
        
        if !provider.apiKey.isEmpty {
            request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        var body: [String: Any] = [
            "prompt": prompt,
            "negative_prompt": negativePrompt,
            "steps": Int(steps),
            "batch_size": 1,
            "width": size.width > 0 ? size.width : 1024,
            "height": size.height > 0 ? size.height : 1024,
            "cfg_scale": 7
        ]
        
        // 图生图需要传 init_images
        if isImg2Img, let srcImage = sourceImage, let imageData = srcImage.pngData() {
            body["init_images"] = [imageData.base64EncodedString()]
            body["denoising_strength"] = 0.75
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw ServiceError.networkError("无响应") }
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "未知错误"
            throw ServiceError.networkError("HTTP \(httpResponse.statusCode): \(errorBody)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ServiceError.decodeError }
        
        if let images = json["images"] as? [String],
           let b64 = images.first,
           let imageData = Data(base64Encoded: b64),
           let image = UIImage(data: imageData) { return image }
        
        throw ServiceError.noImageInResponse
    }
    
    // MARK: - ComfyUI
    private func generateComfyUI(prompt: String, provider: Provider, steps: Double) async throws -> UIImage {
        guard let url = URL(string: provider.apiURL) else { throw ServiceError.invalidURL }
        
        let workflow: [String: Any] = [
            "prompt": [
                "3": ["class_type": "KSampler", "inputs": ["seed": Int.random(in: 1...999999999), "steps": Int(steps), "cfg": 7, "sampler_name": "euler", "scheduler": "normal", "denoise": 1, "model": ["4"], "positive": ["6"], "negative": ["7"], "latent_image": ["5"]]],
                "4": ["class_type": "CheckpointLoaderSimple", "inputs": ["ckpt_name": "sd_xl_base_1.0.safetensors"]],
                "5": ["class_type": "EmptyLatentImage", "inputs": ["width": 1024, "height": 1024, "batch_size": 1]],
                "6": ["class_type": "CLIPTextEncode", "inputs": ["text": prompt, "clip": ["4"]]],
                "7": ["class_type": "CLIPTextEncode", "inputs": ["text": "", "clip": ["4"]]],
                "8": ["class_type": "VAEDecode", "inputs": ["samples": ["3"], "vae": ["4"]]],
                "9": ["class_type": "SaveImage", "inputs": ["filename_prefix": "ai_image", "images": ["8"]]]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300
        request.httpBody = try JSONSerialization.data(withJSONObject: workflow)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw ServiceError.networkError("无响应") }
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "未知错误"
            throw ServiceError.networkError("HTTP \(httpResponse.statusCode): \(errorBody)")
        }
        
        throw ServiceError.networkError("ComfyUI 需要配置输出节点，请在 ComfyUI 界面查看结果")
    }
}
