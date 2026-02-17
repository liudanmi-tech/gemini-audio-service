-- 分析进度可见性：sessions 表增加 analysis_stage
-- 分析过程中写入当前阶段，供状态接口返回给客户端展示（如「正在上传到云端」「正在分析」）
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS analysis_stage VARCHAR(100);
