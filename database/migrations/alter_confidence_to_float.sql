-- 可选迁移：将 scene_confidence / confidence_score 从 JSONB 改为 FLOAT
-- 仅当线上表已是 JSONB 且需与当前 ORM（Float）一致时执行
-- 若 add_skills_tables.sql 已按 FLOAT 建表，可跳过本脚本

-- strategy_analysis.scene_confidence
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'strategy_analysis'
      AND column_name = 'scene_confidence' AND data_type = 'jsonb'
  ) THEN
    ALTER TABLE strategy_analysis ALTER COLUMN scene_confidence TYPE FLOAT USING (scene_confidence::text::float);
  END IF;
END $$;

-- skill_executions.confidence_score
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'skill_executions'
      AND column_name = 'confidence_score' AND data_type = 'jsonb'
  ) THEN
    ALTER TABLE skill_executions ALTER COLUMN confidence_score TYPE FLOAT USING (confidence_score::text::float);
  END IF;
END $$;
