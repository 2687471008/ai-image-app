import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var config: AppConfig
    @State private var selectedRecord: GenerationRecord?
    @State private var showDetail = false
    @State private var showClearAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if config.history.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(config.history) { record in
                            HistoryRow(record: record)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedRecord = record
                                    showDetail = true
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .onDelete { indexSet in
                            config.history.remove(atOffsets: indexSet)
                            config.saveHistory()
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("历史记录")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !config.history.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            showClearAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .alert("清空历史", isPresented: $showClearAlert) {
                Button("取消", role: .cancel) {}
                Button("清空", role: .destructive) {
                    config.clearHistory()
                }
            } message: {
                Text("确定要清空所有生成记录吗？")
            }
            .sheet(isPresented: $showDetail) {
                if let record = selectedRecord {
                    HistoryDetailView(record: record)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            Text("还没有生成记录")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Text("去「生成」页面试试吧")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.5))
        }
    }
}

// MARK: - 历史记录行
struct HistoryRow: View {
    let record: GenerationRecord
    
    var body: some View {
        HStack(spacing: 16) {
            // 缩略图
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .frame(width: 60, height: 60)
                
                if let data = record.imageData,
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: record.isSuccess ? "photo" : "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(record.isSuccess ? .accentColor : .red)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(record.prompt)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Label(record.provider.rawValue, systemImage: "sparkle.magic")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if !record.isSuccess {
                        Label("失败", systemImage: "xmark")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
                
                Text(record.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.5))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - 历史详情
struct HistoryDetailView: View {
    let record: GenerationRecord
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 图片
                    if let data = record.imageData,
                       let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding(.horizontal)
                    }
                    
                    // 信息卡片
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(label: "提示词", value: record.prompt)
                        
                        if !record.negativePrompt.isEmpty {
                            InfoRow(label: "负面词", value: record.negativePrompt, color: .red)
                        }
                        
                        InfoRow(label: "模型", value: record.provider.rawValue)
                        InfoRow(label: "时间", value: record.timestamp.formatted())
                        
                        if let error = record.errorMessage {
                            InfoRow(label: "错误", value: error, color: .red)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .foregroundColor(color)
        }
    }
}
