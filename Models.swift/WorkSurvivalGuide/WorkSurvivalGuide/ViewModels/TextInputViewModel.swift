//
//  TextInputViewModel.swift
//  WorkSurvivalGuide
//
//  文字输入 ViewModel
//

import Foundation

class TextInputViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var isSubmitting: Bool = false
    @Published var errorMessage: String? = nil

    private let networkManager = NetworkManager.shared

    var canSubmit: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }

    func submit(onSuccess: @escaping () -> Void) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let response = try await networkManager.createFromText(text: text)
                await MainActor.run {
                    self.isSubmitting = false
                    print("✅ [TextInputViewModel] 文字提交成功: \(response.sessionId)")
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TaskUploaded"),
                        object: nil
                    )
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    self.isSubmitting = false
                    self.errorMessage = "提交失败：\(error.localizedDescription)"
                    print("❌ [TextInputViewModel] 提交失败: \(error)")
                }
            }
        }
    }
}
