-- 录音分析失败原因可见性：sessions 表增加 error_message
-- 分析失败时写入错误信息，供状态/详情接口返回给客户端展示
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS error_message TEXT;
