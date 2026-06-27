import Foundation
import UIKit

// MARK: - 图片生成服务
class ImageGenService {
    
    enum ServiceError: LocalizedError {
        case invalidURL
        case noAPIKey
        case networkError(String)
        case decodeError
        case noImageInResponse
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "API 地址格式错误"
            case .noAPIKey: return "请先配置 API Key"
            case .networkError(let msg): return "网络错误: \(msg)"
            case .decodeError: return "响应解析失败"
            case .noImageInResponse: return "返回数据中没有图片"
            }
        }
    }
    
    // MARK: - 生成图片
    func generate(
        prompt: String,
        negativePrompt: String,
        config: AppConfig
    ) async throws -> UIImage {
        switch config.provider {
        case .openai, .openaiCompatible:
            return try await generateOpenAI(prompt: prompt, config: config)
        case .sdWebUI:
            return try await generateSDWebUI(prompt: prompt, negativePrompt: negativePrompt, config: config)
        case .comfyUI:
            return try await generateComfyUI(prompt: prompt, config: config)
        }
    }
    
    // MARK: - OpenAI / 兼容协议
    private func generateOpenAI(prompt: String, config: AppConfig) async throws -> UIImage {
        guard let url = URL(string: config.apiURL) else {
            throw ServiceError.invalidURL
        }
        guard !config.apiKey.isEmpty else {
            throw ServiceError.noAPIKey
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120
        
        let sizeString: String
        switch config.imageSize {
        case .square: sizeString = "1024x1024"
        case .landscape: sizeString = "1792x1024"
        case .portrait: sizeString = "1024x1792"
        }
        
        var body: [String: Any] = [
            "prompt": prompt,
            "n": 1,
            "size": sizeString,
            "response_format": "b64_json"
        ]
        
        if !config.model.isEmpty {
            body["model"] = config.model
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.networkError("无响应")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "未知错误"
            throw ServiceError.networkError("HTTP \(httpResponse.statusCode): \(errorBody)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ServiceError.decodeError
        }
        
        // 尝试解析 b64_json
        if let dataArr = json["data"] as? [[String: Any]],
           let first = dataArr.first {
            if let b64 = first["b64_json"] as? String,
               let imageData = Data(base64Encoded: b64),
               let image = UIImage(data: imageData) {
                return image
            }
            // 也支持 url 格式
            if let urlStr = first["url"] as? String,
               let imgURL = URL(string: urlStr),
               let imgData = try? Data(contentsOf: imgURL),
               let image = UIImage(data: imgData) {
                return image
            }
        }
        
        throw ServiceError.noImageInResponse
    }
    
    // MARK: - Stable Diffusion WebUI
    private func generateSDWebUI(prompt: String, negativePrompt: String, config: AppConfig) async throws -> UIImage {
        guard let url = URL(string: config.apiURL) else {
            throw ServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300
        
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "prompt": prompt,
            "negative_prompt": negativePrompt,
            "steps": Int(config.steps),
            "batch_size": 1,
            "width": 1024,
            "height": 1024,
            "cfg_scale": 7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.networkError("无响应")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "未知错误"
            throw ServiceError.networkError("HTTP \(httpResponse.statusCode): \(errorBody)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ServiceError.decodeError
        }
        
        if let images = json["images"] as? [String],
           let b64 = images.first,
           let imageData = Data(base64Encoded: b64),
           let image = UIImage(data: imageData) {
            return image
        }
        
        throw ServiceError.noImageInResponse
    }
    
    // MARK: - ComfyUI
    private func generateComfyUI(prompt: String, config: AppConfig) async throws -> UIImage {
        // ComfyUI 需要先提交 prompt，然后轮询获取结果
        // 这里实现简化版，通过 API 提交并等待
        guard let url = URL(string: config.apiURL) else {
            throw ServiceError.invalidURL
        }
        
        // 构建 ComfyUI 工作流 prompt
        let workflow: [String: Any] = [
            "prompt": [
                "3": [
                    "class_type": "KSampler",
                    "inputs": [
                        "seed": Int.random(in: 1...999999999),
                        "steps": Int(config.steps),
                        "cfg": 7,
                        "sampler_name": "euler",
                        "scheduler": "normal",
                        "denoise": 1,
                        "model": ["4"],
                        "positive": ["6"],
                        "negative": ["7"],
                        "latent_image": ["5"]
                    ]
                ],
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
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.networkError("无响应")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "未知错误"
            throw ServiceError.networkError("HTTP \(httpResponse.statusCode): \(errorBody)")
        }
        
        // ComfyUI 返回 prompt_id，需要轮询获取结果
        // 简化版：提示用户 ComfyUI 需要额外配置
        throw ServiceError.networkError("ComfyUI 需要配置输出节点，请在 ComfyUI 界面查看结果")
    }
}
