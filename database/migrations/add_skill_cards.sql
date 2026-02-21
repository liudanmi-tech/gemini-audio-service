-- strategy_analysis 表新增 skill_cards 列：每个技能一张卡片，支持滑动切换
-- skill_cards: [{skill_id, skill_name, content_type, content}, ...]
-- content_type: "strategy" | "emotion"
ALTER TABLE strategy_analysis ADD COLUMN IF NOT EXISTS skill_cards JSONB DEFAULT '[]'::jsonb;
