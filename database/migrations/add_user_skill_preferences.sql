CREATE TABLE IF NOT EXISTS user_skill_preferences (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    skill_id VARCHAR(100) NOT NULL,
    selected BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, skill_id)
);

CREATE INDEX IF NOT EXISTS idx_usp_user_id ON user_skill_preferences(user_id);
