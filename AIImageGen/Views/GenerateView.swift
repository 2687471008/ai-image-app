import SwiftUI

struct GenerateView: View {
    @EnvironmentObject var config: AppConfig
    @State private var prompt: String = ""
    @State private var negativePrompt: String = ""
    @State private var isGenerating = false
    @State private var generatedImage: UIImage?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showNegativePrompt = false
    @State private var animateCard = false
    
    private let service = ImageGenService()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 顶部标题
                headerView
                
                // 图片预览区
                imagePreviewCard
                
                // Prompt 输入
                promptInputCard
                
                // 负面提示词
                if showNegativePrompt {
                    negativePromptInput
                }
                
                // 控制按钮
                controlButtons
                
                // 生成按钮
                generateButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .alert("生成失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - 顶部标题
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI 生图")
                    .font(.system(size: 34, weight: .bold))
                Text(config.provider.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            // Provider 指示器
            HStack(spacing: 4) {
                Circle()
                    .fill(isGenerating ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)
                Text(isGenerating ? "生成中" : "就绪")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.top, 60)
    }
    
    // MARK: - 图片预览
    private var imagePreviewCard: some View {
        ZStack {
            if let image = generatedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.ultraThinMaterial, lineWidth: 1)
                    )
                    .shadow(color: .accentColor.opacity(0.2), radius: 20, y: 10)
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles.rectangle.stack")
                                .font(.system(size: 50))
                                .foregroundColor(.accentColor.opacity(0.5))
                            Text("输入提示词开始生成")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
            }
            
            if isGenerating {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .aspectRatio(1, contentMode: .fit)
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.accentColor)
                        Text("正在生成...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("这可能需要 10-30 秒")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
            }
        }
        .opacity(animateCard ? 1 : 0)
        .offset(y: animateCard ? 0 : 20)
    }
    
    // MARK: - Prompt 输入
    private var promptInputCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("提示词 (Prompt)", systemImage: "text.quote")
                .font(.headline)
            
            TextEditor(text: $prompt)
                .frame(height: 100)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            HStack {
                Text("\(prompt.count) 字")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("清除") {
                    prompt = ""
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - 负面提示词
    private var negativePromptInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("负面提示词 (Negative Prompt)", systemName: "text.badge.xmark")
                .font(.headline)
                .foregroundColor(.red.opacity(0.7))
            
            TextEditor(text: $negativePrompt)
                .frame(height: 80)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - 控制按钮
    private var controlButtons: some View {
        HStack(spacing: 12) {
            // 负面提示词开关
            ToggleButton(
                icon: "hand.raised",
                title: "负面词",
                isOn: $showNegativePrompt
            )
            
            // 尺寸
            Menu {
                ForEach(ImageSize.allCases, id: \.self) { size in
                    Button(size.displayName) {
                        config.imageSize = size
                        config.saveConfig()
                    }
                }
            } label: {
                ControlChip(icon: "rectangle.split.3x3", title: config.imageSize.displayName)
            }
            
            // 步数（SD 专用）
            if config.provider.supportsSteps {
                Menu {
                    ForEach([10, 15, 20, 25, 30, 40, 50], id: \.self) { step in
                        Button("\(step) 步") {
                            config.steps = Double(step)
                            config.saveConfig()
                        }
                    }
                } label: {
                    ControlChip(icon: "number", title: "\(Int(config.steps)) 步")
                }
            }
        }
    }
    
    // MARK: - 生成按钮
    private var generateButton: some View {
        Button(action: generate) {
            HStack(spacing: 12) {
                Image(systemName: isGenerating ? "stop.circle.fill" : "sparkle.magic")
                    .font(.title2)
                Text(isGenerating ? "生成中..." : "✨ 生成图片")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.accentColor, .accentColor.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            )
            .foregroundColor(.white)
            .shadow(color: .accentColor.opacity(0.3), radius: 10, y: 5)
        }
        .disabled(isGenerating || prompt.trimmingCharacters(in: .whitespaces).isEmpty)
        .opacity(prompt.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
    }
    
    // MARK: - 生成逻辑
    private func generate() {
        guard !prompt.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isGenerating = true
        
        Task {
            do {
                let image = try await service.generate(
                    prompt: prompt,
                    negativePrompt: negativePrompt,
                    config: config
                )
                
                await MainActor.run {
                    generatedImage = image
                    isGenerating = false
                    
                    // 保存记录
                    let record = GenerationRecord(
                        prompt: prompt,
                        negativePrompt: negativePrompt,
                        provider: config.provider,
                        model: config.model,
                        imageData: image.pngData(),
                        isSuccess: true
                    )
                    config.addRecord(record)
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = error.localizedDescription
                    showError = true
                    
                    config.addRecord(GenerationRecord(
                        prompt: prompt,
                        negativePrompt: negativePrompt,
                        provider: config.provider,
                        model: config.model,
                        isSuccess: false,
                        errorMessage: error.localizedDescription
                    ))
                }
            }
        }
    }
}

// MARK: - 辅助组件
struct ToggleButton: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isOn ?
                Color.red.opacity(0.15) :
                Color.secondary.opacity(0.1)
            )
            .foregroundColor(isOn ? .red : .secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isOn ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
    }
}

struct ControlChip: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
        .foregroundColor(.secondary)
        .clipShape(Capsule())
    }
}
