import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var config: AppConfig
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Provider 选择
                    settingsSection("模型服务") {
                        providerPicker
                        apiURLField
                        apiKeyField
                        modelField
                    }
                    
                    // MARK: - 生成参数
                    settingsSection("生成参数") {
                        sizePicker
                        if config.provider.supportsSteps {
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
        }
    }
    
    // MARK: - 分组容器
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }
    
    // MARK: - Provider 选择
    private var providerPicker: some View {
        SettingsRow(icon: "square.3.layers.3d", label: "服务商") {
            Menu {
                ForEach(ImageProvider.allCases, id: \.self) { provider in
                    Button(provider.rawValue) {
                        config.provider = provider
                        config.apiURL = provider.endpoint
                        config.model = provider.defaultModel
                        config.saveConfig()
                    }
                }
            } label: {
                HStack {
                    Text(config.provider.rawValue)
                        .foregroundColor(.accentColor)
                    Image(systemName: "chevron.up.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - API URL
    private var apiURLField: some View {
        SettingsRow(icon: "link", label: "API 地址") {
            TextField("https://api.example.com/v1/images/generations", text: $config.apiURL)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .onChange(of: config.apiURL) { new in
                    config.apiURL = new
                    config.saveConfig()
                }
        }
    }
    
    // MARK: - API Key
    private var apiKeyField: some View {
        SettingsRow(icon: "key.fill", label: "API Key") {
            HStack {
                if showKey {
                    TextField("sk-...", text: $config.apiKey)
                        .font(.subheadline)
                        .multilineTextAlignment(.trailing)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } else {
                    SecureField("sk-...", text: $config.apiKey)
                        .font(.subheadline)
                        .multilineTextAlignment(.trailing)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                Button(action: { showKey.toggle() }) {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: config.apiKey) { new in
                config.apiKey = new
                config.saveConfig()
            }
        }
    }
    @State private var showKey = false
    
    // MARK: - 模型
    private var modelField: some View {
        SettingsRow(icon: "cpu", label: "模型") {
            TextField("dall-e-3 / gpt-image-2", text: $config.model)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .onChange(of: config.model) { new in
                    config.model = new
                    config.saveConfig()
                }
        }
    }
    
    // MARK: - 尺寸
    private var sizePicker: some View {
        SettingsRow(icon: "rectangle.split.3x3", label: "图片尺寸") {
            Menu {
                ForEach(ImageSize.allCases, id: \.self) { size in
                    Button(size.displayName) {
                        config.imageSize = size
                        config.saveConfig()
                    }
                }
            } label: {
                HStack {
                    Text(config.imageSize.displayName)
                        .foregroundColor(.accentColor)
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
                config.saveConfig()
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
                Text("v1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("支持 OpenAI DALL-E 3、OpenAI 兼容协议、Stable Diffusion WebUI、ComfyUI 等多种生图服务")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 32)
        }
        .padding(16)
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
