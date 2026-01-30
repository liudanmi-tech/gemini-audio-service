-- 列表首屏性能优化：sessions 分页查询复合索引
-- 用于 WHERE user_id=? ORDER BY created_at DESC LIMIT n 走索引，避免 filesort
CREATE INDEX IF NOT EXISTS idx_sessions_user_created ON sessions(user_id, created_at DESC);
