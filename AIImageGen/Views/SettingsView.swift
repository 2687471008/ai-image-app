import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var config: AppConfig
    @State private var showAddProvider = false
    @State private var editingProvider: Provider?
    @State private var testingProvider: Provider?
    @State private var testResult: (Bool, String)?
    @State private var isTesting = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - 供应商管理
                    providerSection
                    
                    // MARK: - 生成参数
                    settingsSection("生成参数") {
                        sizePicker
                        if config.activeProvider?.protocolType.supportsSteps ?? false {
                            stepsSlider
                        }
                    }
                    
                    // MARK: - 关于
                    settingsSection("关于") {
                        aboutRow
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAddProvider = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAddProvider) {
                ProviderEditView(mode: .add) { provider in
                    config.addProvider(provider)
                    config.activeProviderID = provider.id
                }
            }
            .sheet(item: $editingProvider) { provider in
                ProviderEditView(mode: .edit(provider)) { updated in
                    config.updateProvider(updated)
                }
            }
        }
    }
    
    // MARK: - 供应商管理
    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("供应商")
                .font(.headline)
            
            if config.providers.isEmpty {
                VStack(spacing: 8) {
                    Text("还没有供应商")
                        .foregroundColor(.secondary)
                    Button("添加供应商") {
                        showAddProvider = true
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
            } else {
                ForEach(config.providers) { provider in
                    ProviderCard(
                        provider: provider,
                        isActive: provider.id == config.activeProviderID,
                        isTesting: testingProvider?.id == provider.id && isTesting,
                        testResult: testingProvider?.id == provider.id ? testResult : nil,
                        onSelect: {
                            config.activeProviderID = provider.id
                            config.saveProviders()
                        },
                        onEdit: {
                            editingProvider = provider
                        },
                        onDelete: {
                            config.deleteProvider(provider.id)
                        },
                        onTest: {
                            testConnectivity(provider)
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - 连通性测试
    private func testConnectivity(_ provider: Provider) {
        testingProvider = provider
        isTesting = true
        testResult = nil
        
        let service = ImageGenService()
        Task {
            let result = await service.checkConnectivity(provider: provider)
            await MainActor.run {
                testResult = result
                isTesting = false
            }
        }
    }
    
    // MARK: - 分组容器
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }
    
    // MARK: - 尺寸
    private var sizePicker: some View {
        SettingsRow(icon: "rectangle.split.3x3", label: "图片尺寸") {
            Menu {
                ForEach(ImageSizeOption.presets) { size in
                    Button(size.label) {
                        config.imageSize = size
                        config.saveSettings()
                    }
                }
            } label: {
                HStack {
                    Text(config.currentSize.label)
                        .foregroundColor(.accentColor)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - 步数
    private var stepsSlider: some View {
        VStack(spacing: 8) {
            SettingsRow(icon: "number", label: "采样步数") {
                Text("\(Int(config.steps))")
                    .foregroundColor(.accentColor)
                    .fontWeight(.semibold)
            }
            
            Slider(value: $config.steps, in: 5...50, step: 1) {
                Text("步数")
            } minimumValueLabel: {
                Text("5").font(.caption2).foregroundColor(.secondary)
            } maximumValueLabel: {
                Text("50").font(.caption2).foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .onChange(of: config.steps) { _ in
                config.saveSettings()
            }
        }
    }
    
    // MARK: - 关于
    private var aboutRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkle.magic")
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                Text("AI Image Gen")
                    .font(.subheadline)
                Spacer()
                Text("v2.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("支持 OpenAI 兼容协议、Stable Diffusion WebUI、ComfyUI 等多种生图服务，可自由添加和管理供应商")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 32)
        }
        .padding(16)
    }
}

// MARK: - 供应商卡片
struct ProviderCard: View {
    let provider: Provider
    let isActive: Bool
    let isTesting: Bool
    let testResult: (Bool, String)?
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onTest: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // 协议图标
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: protocolIcon)
                        .foregroundColor(isActive ? .white : .secondary)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(provider.protocolType.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isActive {
                    Text("使用中")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                }
                
                // 测试结果
                if let result = testResult {
                    Image(systemName: result.0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result.0 ? .green : .red)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }
            
            // 测试结果详情
            if let result = testResult {
                HStack {
                    Image(systemName: result.0 ? "checkmark" : "xmark")
                        .font(.caption2)
                    Text(result.1)
                        .font(.caption2)
                    Spacer()
                }
                .foregroundColor(result.0 ? .green : .orange)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            
            // 操作按钮
            HStack(spacing: 0) {
                Button(action: onTest) {
                    HStack(spacing: 4) {
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                        }
                        Text(isTesting ? "测试中" : "测试连通性")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .disabled(isTesting)
                
                Divider()
                    .frame(height: 20)
                
                Button(action: onEdit) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("编辑")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                
                Divider()
                    .frame(height: 20)
                
                Button(role: .destructive, action: onDelete) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("删除")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            .foregroundColor(.secondary)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isActive ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
                )
        )
    }
    
    private var protocolIcon: String {
        switch provider.protocolType {
        case .openai: return "sparkle.magic"
        case .sdWebUI: return "paintbrush"
        case .comfyUI: return "square.grid.3x3"
        }
    }
}

// MARK: - 供应商编辑页
struct ProviderEditView: View {
    enum Mode {
        case add
        case edit(Provider)
        
        var title: String {
            switch self {
            case .add: return "添加供应商"
            case .edit: return "编辑供应商"
            }
        }
    }
    
    let mode: Mode
    let onSave: (Provider) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var protocolType: ImageProtocol = .openai
    @State private var apiURL: String = ""
    @State private var apiKey: String = ""
    @State private var model: String = ""
    @State private var showKey = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("供应商名称", text: $name)
                    
                    Picker("协议类型", selection: $protocolType) {
                        ForEach(ImageProtocol.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                }
                
                Section("API 配置") {
                    TextField("API 地址", text: $apiURL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    
                    HStack {
                        if showKey {
                            TextField("API Key", text: $apiKey)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("API Key", text: $apiKey)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }
                        Button(action: { showKey.toggle() }) {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if protocolType.supportsModel {
                        TextField("模型名称（可选）", text: $model)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                }
                
                Section {
                    Button("保存") {
                        let provider: Provider
                        switch mode {
                        case .add:
                            provider = Provider(
                                name: name,
                                protocolType: protocolType,
                                apiURL: apiURL,
                                apiKey: apiKey,
                                model: model
                            )
                        case .edit(let existing):
                            provider = Provider(
                                id: existing.id,
                                name: name,
                                protocolType: protocolType,
                                apiURL: apiURL,
                                apiKey: apiKey,
                                model: model
                            )
                        }
                        onSave(provider)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .onAppear {
            if case .edit(let provider) = mode {
                name = provider.name
                protocolType = provider.protocolType
                apiURL = provider.apiURL
                apiKey = provider.apiKey
                model = provider.model
            }
        }
    }
}

// MARK: - 设置行组件
struct SettingsRow<Content: View>: View {
    let icon: String
    let label: String
    @ViewBuilder let content: Content
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            Text(label)
                .font(.subheadline)
            
            Spacer()
            
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        
        Divider()
            .padding(.leading, 48)
    }
}
