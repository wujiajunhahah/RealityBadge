import SwiftUI
import AVFoundation
import UIKit
import PhotosUI

// MARK: - 优化版拍摄界面
// 使用苹果原生 PhotosUI API

struct CaptureViewNative: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera: CameraController

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImage: Image?
    @State private var showImagePicker = false

    init() {
        let targets: [String] = ["screen", "ipad", "headphones", "cup", "umbrella", "paper"]
        let engine = SemanticEngine(targetKeywords: targets)
        let tmpSettings = RBSettings()
        _camera = StateObject(wrappedValue: CameraController(engine: engine, settings: tmpSettings))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.isAuthorized {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
            } else {
                permissionView
            }

            // UI 层
            uiLayer
        }
        .onAppear {
            if camera.isAuthorized {
                camera.start()
            }
        }
        .onDisappear {
            camera.stop()
        }
    }

    private var uiLayer: some View {
        VStack {
            // 顶部栏
            HStack {
                Button {
                    camera.stop()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                Spacer()

                // 相册按钮 - 使用原生 PhotosUI
                Button {
                    showImagePicker = true
                } label: {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            // 底部控制
            VStack(spacing: 20) {
                // 识别状态
                if let label = camera.currentScores?.semanticLabel,
                   camera.progress > 0.5 {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(camera.progress >= 1 ? Color(UIColor.systemGreen) : Color(UIColor.systemBlue))
                            .frame(width: 8, height: 8)

                        Text(label)
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }

                // 快门按钮
                Button {
                    capturePhoto()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 4)
                            .frame(width: 72, height: 72)

                        Circle()
                            .trim(from: 0, to: camera.progress)
                            .stroke(Color(UIColor.systemBlue), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 72, height: 72)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.3), value: camera.progress)

                        Circle()
                            .fill(camera.progress >= 1 ? Color(UIColor.systemGreen) : Color.white)
                            .frame(width: 56, height: 56)
                            .overlay {
                                Image(systemName: camera.progress >= 1 ? "checkmark" : "camera.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(camera.progress >= 1 ? .white : .black)
                            }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 34)
        }
        .photosPicker(
            isPresented: $showImagePicker,
            selection: $selectedItems,
            maxSelectionCount: 1,
            matching: .images
        )
    }

    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("需要相机权限")
                .font(.system(.title3, weight: .semibold))

            Text("请在设置中允许访问相机")
                .font(.system(.subheadline))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("打开设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBlue))
            .clipShape(Capsule())
        }
        .padding(32)
    }

    private func capturePhoto() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        camera.capturePhoto()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let image = camera.capturedFrame {
                // 创建徽章并保存
                let newBadge = Badge(
                    title: camera.currentScores?.semanticLabel ?? "新徽章",
                    date: .now,
                    style: .minimal,
                    done: true
                )
                state.recentBadges.append(newBadge)
                RBRepository.badges.save(newBadge)
            }
        }
    }
}

// MARK: - PhotosUI 集成示例
struct PhotoPickerView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImage: Image?

    var body: some View {
        VStack {
            // 选择照片按钮
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 1,
                matching: .images
            ) {
                Label("选择照片", systemImage: "photo")
                    .font(.system(.headline, weight: .semibold))
            }
            .onChange(of: selectedItems) { _, newItems in
                Task {
                    if let item = newItems.first {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            selectedImage = Image(uiImage: uiImage)
                        }
                    }
                }
            }

            // 显示选中的图片
            if let selectedImage = selectedImage {
                selectedImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
            }
        }
        .padding()
    }
}

#Preview {
    CaptureViewNative()
        .environmentObject(AppState())
}
