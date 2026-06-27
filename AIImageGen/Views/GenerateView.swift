import SwiftUI
import PhotosUI

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
    
    // 图生图
    @State private var sourceImage: UIImage?
    @State private var showImagePicker = false
    @State private var isImageToImage = false
    
    // 选择供应商和模型
    @State private var selectedProviderID: UUID?
    @State private var selectedModel: String = ""
    
    private let service = ImageGenService()
    
    var selectedProvider: Provider? {
        config.providers.first { $0.id == selectedProviderID }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerView
                
                // 供应商+模型选择
                providerModelSelector
                
                // 图片预览区
                imagePreviewCard
                
                // 图生图 - 选择参考图
                if isImageToImage {
                    sourceImageSelector
                }
                
                // Prompt 输入
                promptInputCard
                
                if showNegativePrompt {
                    negativePromptInput
                }
                
                controlButtons
                generateButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .alert("生成失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: { Text(errorMessage) }
        .onAppear {
            if selectedProviderID == nil {
                selectedProviderID = config.activeProviderID ?? config.providers.first?.id
            }
            if let p = selectedProvider {
                selectedModel = p.model
            }
            withAnimation(.easeOut(duration: 0.6)) { animateCard = true }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $sourceImage)
        }
    }
    
    // MARK: - 顶部标题
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI 生图").font(.system(size: 34, weight: .bold))
                Text(isImageToImage ? "图生图模式" : "文生图模式")
                    .font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                Circle().fill(isGenerating ? Color.orange : Color.green).frame(width: 8, height: 8)
                Text(isGenerating ? "生成中" : "就绪").font(.caption).foregroundColor(.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.top, 60)
    }
    
    // MARK: - 供应商+模型选择器
    private var providerModelSelector: some View {
        VStack(spacing: 8) {
            // 供应商选择
            HStack {
                Image(systemName: "square.3.layers.3d").foregroundColor(.accentColor).font(.caption)
                Text("供应商").font(.caption).foregroundColor(.secondary)
                Spacer()
                Menu {
                    ForEach(config.providers) { p in
                        Button(action: {
                            selectedProviderID = p.id
                            selectedModel = p.model
                            config.activeProviderID = p.id
                            config.saveProviders()
                        }) {
                            HStack {
                                Text(p.name)
                                if p.id == selectedProviderID { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedProvider?.name ?? "选择供应商").foregroundColor(.accentColor).font(.subheadline)
                        Image(systemName: "chevron.up.down").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
            
            // 模型选择（如果支持）
            if let p = selectedProvider, p.protocolType.supportsModel {
                HStack {
                    Image(systemName: "cpu").foregroundColor(.accentColor).font(.caption)
                    Text("模型").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    
                    let models = p.availableModels.isEmpty ? (p.model.isEmpty ? [] : [p.model]) : p.availableModels
                    
                    if models.isEmpty {
                        TextField("输入模型名", text: $selectedModel)
                            .font(.subheadline).multilineTextAlignment(.trailing)
                            .autocapitalization(.none).autocorrectionDisabled()
                            .onChange(of: selectedModel) { new in
                                if var prov = selectedProvider {
                                    prov.model = new
                                    config.updateProvider(prov)
                                }
                            }
                    } else {
                        Menu {
                            ForEach(models, id: \.self) { m in
                                Button(m) {
                                    selectedModel = m
                                    if var prov = selectedProvider {
                                        prov.model = m
                                        config.updateProvider(prov)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedModel.isEmpty ? "选择模型" : selectedModel)
                                    .foregroundColor(.accentColor).font(.subheadline).lineLimit(1)
                                Image(systemName: "chevron.up.down").font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
            }
            
            // 显示当前 API 地址
            if let prov = selectedProvider, !prov.apiURL.isEmpty {
                HStack {
                    Image(systemName: "link").foregroundColor(.accentColor.opacity(0.6)).font(.caption)
                    Text(prov.apiURL)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.6))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
            }
        }
    }
    
    // MARK: - 图片预览
    private var imagePreviewCard: some View {
        ZStack {
            if let image = generatedImage {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.ultraThinMaterial, lineWidth: 1))
                    .shadow(color: .accentColor.opacity(0.2), radius: 20, y: 10)
            } else {
                RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial).aspectRatio(1, contentMode: .fit)
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: isImageToImage ? "arrow.triangle.swap" : "sparkles.rectangle.stack")
                                .font(.system(size: 50)).foregroundColor(.accentColor.opacity(0.5))
                            Text(isImageToImage ? "选择参考图并输入提示词" : "输入提示词开始生成")
                                .font(.headline).foregroundColor(.secondary)
                        }
                    }
            }
            
            if isGenerating {
                ZStack {
                    RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial).aspectRatio(1, contentMode: .fit)
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.5).tint(.accentColor)
                        Text("正在生成...").font(.headline).foregroundColor(.secondary)
                        Text("这可能需要 10-30 秒").font(.caption).foregroundColor(.secondary.opacity(0.5))
                    }
                }
            }
        }
        .opacity(animateCard ? 1 : 0).offset(y: animateCard ? 0 : 20)
    }
    
    // MARK: - 参考图选择
    private var sourceImageSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("参考图片", systemImage: "photo.on.rectangle").font(.headline)
            
            HStack(spacing: 12) {
                if let image = sourceImage {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80).clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("已选择参考图").font(.subheadline).foregroundColor(.secondary)
                        Text("\(Int(image.size.width))×\(Int(image.size.height))").font(.caption2).foregroundColor(.secondary.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    Button("更换") { showImagePicker = true }.font(.caption)
                    Button("清除") { sourceImage = nil }.font(.caption).foregroundColor(.red)
                } else {
                    Button(action: { showImagePicker = true }) {
                        HStack {
                            Image(systemName: "plus.circle").font(.title3)
                            Text("从相册选择").font(.subheadline)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5])))
                    }
                }
            }
        }
    }
    
    // MARK: - Prompt 输入
    private var promptInputCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("提示词 (Prompt)", systemImage: "text.quote").font(.headline)
            TextEditor(text: $prompt).frame(height: 100).padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            HStack {
                Text("\(prompt.count) 字").font(.caption).foregroundColor(.secondary)
                Spacer()
                Button("清除") { prompt = "" }.font(.caption).foregroundColor(.secondary)
            }
        }
    }
    
    private var negativePromptInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("负面提示词 (Negative Prompt)", systemImage: "exclamationmark.bubble")
                .font(.headline).foregroundColor(.red.opacity(0.7))
            TextEditor(text: $negativePrompt).frame(height: 80).padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.2), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - 控制按钮
    private var controlButtons: some View {
        HStack(spacing: 12) {
            // 文生图/图生图切换
            ToggleButton(
                icon: "arrow.triangle.swap",
                title: "图生图",
                isOn: $isImageToImage
            )
            
            if selectedProvider?.protocolType.supportsNegativePrompt ?? false {
                ToggleButton(icon: "hand.raised", title: "负面词", isOn: $showNegativePrompt)
            }
            
            Menu {
                ForEach(ImageSizeOption.presets) { size in
                    Button(size.label) { config.imageSize = size; config.saveSettings() }
                }
            } label: {
                ControlChip(icon: "rectangle.split.3x3", title: config.currentSize.label)
            }
            
            if selectedProvider?.protocolType.supportsSteps ?? false {
                Menu {
                    ForEach([10, 15, 20, 25, 30, 40, 50], id: \.self) { step in
                        Button("\(step) 步") { config.steps = Double(step); config.saveSettings() }
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
                Image(systemName: isGenerating ? "stop.circle.fill" : "sparkle.magic").font(.title2)
                Text(isGenerating ? "生成中..." : "✨ 生成图片").font(.headline).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(
                LinearGradient(colors: [.accentColor, .accentColor.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            )
            .foregroundColor(.white)
            .shadow(color: .accentColor.opacity(0.3), radius: 10, y: 5)
        }
        .disabled(isGenerating || prompt.trimmingCharacters(in: .whitespaces).isEmpty || selectedProvider == nil || (isImageToImage && sourceImage == nil))
        .opacity((prompt.trimmingCharacters(in: .whitespaces).isEmpty || selectedProvider == nil || (isImageToImage && sourceImage == nil)) ? 0.5 : 1)
    }
    
    // MARK: - 生成逻辑
    private func generate() {
        guard !prompt.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard let provider = selectedProvider else {
            errorMessage = "请先选择供应商"; showError = true; return
        }
        
        isGenerating = true
        
        Task {
            do {
                let image: UIImage
                if isImageToImage, let src = sourceImage {
                    image = try await service.generateImageToImage(prompt: prompt, sourceImage: src, provider: provider, steps: config.steps)
                } else {
                    image = try await service.generate(prompt: prompt, negativePrompt: negativePrompt, provider: provider, size: config.currentSize, steps: config.steps)
                }
                
                await MainActor.run {
                    generatedImage = image; isGenerating = false
                    config.addRecord(GenerationRecord(
                        prompt: prompt, negativePrompt: negativePrompt,
                        providerName: provider.name, protocolType: provider.protocolType,
                        model: selectedModel, sizeLabel: config.currentSize.label,
                        imageData: image.pngData(), isSuccess: true, isImageToImage: isImageToImage
                    ))
                }
            } catch {
                await MainActor.run {
                    isGenerating = false; errorMessage = error.localizedDescription; showError = true
                    config.addRecord(GenerationRecord(
                        prompt: prompt, negativePrompt: negativePrompt,
                        providerName: provider.name, protocolType: provider.protocolType,
                        model: selectedModel, sizeLabel: config.currentSize.label,
                        isSuccess: false, errorMessage: error.localizedDescription, isImageToImage: isImageToImage
                    ))
                }
            }
        }
    }
}

// MARK: - 图片选择器
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard let result = results.first else { return }
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                if let image = object as? UIImage {
                    DispatchQueue.main.async { self?.parent.image = image }
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
                Text(title).font(.caption)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(isOn ? Color.red.opacity(0.15) : Color.secondary.opacity(0.1))
            .foregroundColor(isOn ? .red : .secondary).clipShape(Capsule())
            .overlay(Capsule().stroke(isOn ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1))
        }
    }
}

struct ControlChip: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title).font(.caption)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
        .foregroundColor(.secondary).clipShape(Capsule())
    }
}
