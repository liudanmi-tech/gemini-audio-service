-- 原音频持久化与说话人映射（声纹方案）
-- sessions: 原音频 OSS URL / 本地路径，供剪切与声纹使用
-- analysis_results: speaker_mapping (Speaker_0/1 -> profile_id), conversation_summary (谁和谁对话)
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS audio_url VARCHAR(500);
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS audio_path VARCHAR(500);

ALTER TABLE analysis_results ADD COLUMN IF NOT EXISTS speaker_mapping JSONB;
ALTER TABLE analysis_results ADD COLUMN IF NOT EXISTS conversation_summary TEXT;
