-- 若 run_fix_json_to_jsonb.py 中 confidence_score/scene_confidence 迁移失败，
-- 可在服务器上用 psql 执行本文件，将这两列从 json 改为 double precision。
-- 用法: psql "$DATABASE_URL" -f database/migrations/fix_confidence_columns_manual.sql

ALTER TABLE strategy_analysis
  ALTER COLUMN scene_confidence TYPE double precision
  USING (COALESCE((scene_confidence::text)::double precision, 0.5));

ALTER TABLE skill_executions
  ALTER COLUMN confidence_score TYPE double precision
  USING (COALESCE((confidence_score::text)::double precision, 0.5));
