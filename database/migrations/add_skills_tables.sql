-- v0.4 技能化架构数据库迁移脚本
-- 添加 skills、skill_executions 表，更新 strategy_analysis 表

-- 技能库表
CREATE TABLE IF NOT EXISTS skills (
    skill_id VARCHAR(100) PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    category VARCHAR(50) NOT NULL,
    skill_path VARCHAR(500) NOT NULL,
    priority INTEGER DEFAULT 0,
    enabled BOOLEAN DEFAULT TRUE,
    version VARCHAR(50),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_skills_category ON skills(category);
CREATE INDEX IF NOT EXISTS idx_skills_enabled ON skills(enabled);

-- 技能执行记录表
CREATE TABLE IF NOT EXISTS skill_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    skill_id VARCHAR(100) NOT NULL REFERENCES skills(skill_id),
    scene_category VARCHAR(50),
    confidence_score FLOAT,
    execution_time_ms INTEGER,
    success BOOLEAN DEFAULT TRUE,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_skill_executions_session_id ON skill_executions(session_id);
CREATE INDEX IF NOT EXISTS idx_skill_executions_skill_id ON skill_executions(skill_id);

-- 更新 strategy_analysis 表，添加新字段
ALTER TABLE strategy_analysis
    ADD COLUMN IF NOT EXISTS applied_skills JSONB DEFAULT '[]',
    ADD COLUMN IF NOT EXISTS scene_category VARCHAR(50),
    ADD COLUMN IF NOT EXISTS scene_confidence FLOAT;

CREATE INDEX IF NOT EXISTS idx_strategy_analysis_scene_category ON strategy_analysis(scene_category);
