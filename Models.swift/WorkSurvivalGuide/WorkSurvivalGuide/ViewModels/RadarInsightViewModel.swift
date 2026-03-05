//
//  RadarInsightViewModel.swift
//  WorkSurvivalGuide
//
//  场景洞察 ViewModel：SSE 流式生成 + UserDefaults 本地缓存
//

import SwiftUI
import Foundation

@MainActor
class RadarInsightViewModel: ObservableObject {

    // MARK: - State

    enum StreamState: Equatable {
        case idle                  // 未生成，显示 [Insight] 按钮
        case loading               // 已点击，等待第一个 SSE event
        case streaming             // 正在流式生成
        case complete              // 全部生成完毕（含从缓存加载）
        case tooFew                // 录音数 < 3
        case error(String)         // 网络/服务端错误

        static func == (lhs: StreamState, rhs: StreamState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading),
                 (.streaming, .streaming), (.complete, .complete), (.tooFew, .tooFew): return true
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    @Published var state: StreamState = .idle
    @Published var scenes: [SceneInsightResult] = []
    @Published var streamingSceneId: String? = nil

    // MARK: - Cache key (set when entering a period)

    private var currentCacheKey: String = ""
    private var streamTask: Task<Void, Never>? = nil

    private let udKey = "radar_insight_cache"

    // MARK: - Public API

    /// 进入新时间段时调用（重置状态 + 尝试从缓存加载）
    func resetAndCheckCache(startDate: String, endDate: String, totalSessions: Int) {
        streamTask?.cancel()
        state = .idle
        scenes = []
        streamingSceneId = nil

        let key = "\(startDate)_\(endDate)_\(totalSessions)"
        currentCacheKey = key

        if let cached = loadFromCache(key: key) {
            scenes = cached
            state = .complete
        }
    }

    /// 用户点击 [Insight] 按钮时调用
    func generate(startDate: String, endDate: String, totalSessions: Int) {
        if case .streaming = state { return }
        if case .loading = state  { return }

        // 缓存命中：直接展示（key 已在 resetAndCheckCache 时计算，这里再验一次）
        let key = "\(startDate)_\(endDate)_\(totalSessions)"
        if case .complete = state, currentCacheKey == key { return }

        if totalSessions < 3 {
            state = .tooFew
            return
        }

        streamTask = Task { [weak self] in
            guard let self else { return }
            await self.runStream(startDate: startDate, endDate: endDate, cacheKey: key)
        }
    }

    // MARK: - SSE Streaming

    private func runStream(startDate: String, endDate: String, cacheKey: String) async {
        state = .loading
        scenes = []
        streamingSceneId = nil

        let baseURL = AppConfig.shared.writeBaseURL
        let token = KeychainManager.shared.getToken() ?? ""
        guard !token.isEmpty,
              let url = URL(string: "\(baseURL)/skills-radar/insight?start_date=\(startDate)&end_date=\(endDate)")
        else {
            state = .error("Auth error")
            return
        }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 180

        do {
            let (asyncBytes, response) = try await URLSession.shared.bytes(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                state = .error("Server error")
                return
            }

            state = .streaming
            var currentId: String? = nil

            for try await line in asyncBytes.lines {
                guard line.hasPrefix("data: ") else { continue }
                let jsonStr = String(line.dropFirst(6))
                guard let data = jsonStr.data(using: .utf8),
                      let event = try? JSONDecoder().decode(InsightSSEEvent.self, from: data)
                else { continue }

                switch event.type {
                case "scene_start":
                    guard let sid = event.scene_id,
                          let label = event.scene_label,
                          let emoji = event.scene_emoji else { continue }
                    currentId = sid
                    streamingSceneId = sid
                    scenes.append(SceneInsightResult(
                        sceneId: sid,
                        sceneLabel: label,
                        sceneEmoji: emoji,
                        sessionCount: event.session_count ?? 0,
                        insightText: "",
                        skills: [],
                        recommendations: []
                    ))

                case "token":
                    guard let tok = event.token,
                          let idx = scenes.firstIndex(where: { $0.sceneId == currentId })
                    else { continue }
                    scenes[idx].insightText += tok

                case "scene_done":
                    guard let sid = event.scene_id,
                          let idx = scenes.firstIndex(where: { $0.sceneId == sid })
                    else { continue }
                    scenes[idx].skills = event.skills ?? []
                    scenes[idx].recommendations = event.recommendations ?? []
                    streamingSceneId = nil

                case "all_done":
                    streamingSceneId = nil
                    state = .complete
                    saveToCache(key: cacheKey, scenes: scenes)

                case "error":
                    state = .error(event.message ?? "Generation failed")
                    return

                default:
                    break
                }
            }

            if case .streaming = state {
                state = .complete
                saveToCache(key: cacheKey, scenes: scenes)
            }

        } catch {
            if !Task.isCancelled {
                state = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Cache

    private func loadFromCache(key: String) -> [SceneInsightResult]? {
        guard let data = UserDefaults.standard.data(forKey: udKey),
              let cache = try? JSONDecoder().decode(InsightCache.self, from: data),
              cache.cacheKey == key
        else { return nil }
        return cache.scenes
    }

    private func saveToCache(key: String, scenes: [SceneInsightResult]) {
        let cache = InsightCache(cacheKey: key, scenes: scenes, generatedAt: Date())
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: udKey)
        }
    }
}
