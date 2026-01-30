-- 将可能被建为 json (OID 114) 的列改为 jsonb，避免 asyncpg 报 Unknown PG numeric type: 114
-- 若列已是 jsonb，USING col::jsonb 不会破坏数据

-- strategy_analysis（策略接口查询此表时报错）
ALTER TABLE strategy_analysis
  ALTER COLUMN visual_data TYPE jsonb USING visual_data::jsonb;
ALTER TABLE strategy_analysis
  ALTER COLUMN strategies TYPE jsonb USING strategies::jsonb;
ALTER TABLE strategy_analysis
  ALTER COLUMN applied_skills TYPE jsonb USING COALESCE(applied_skills::jsonb, '[]'::jsonb);

-- analysis_results
ALTER TABLE analysis_results
  ALTER COLUMN dialogues TYPE jsonb USING dialogues::jsonb;
ALTER TABLE analysis_results
  ALTER COLUMN stats TYPE jsonb USING stats::jsonb;
ALTER TABLE analysis_results
  ALTER COLUMN call1_result TYPE jsonb USING call1_result::jsonb;
ALTER TABLE analysis_results
  ALTER COLUMN speaker_mapping TYPE jsonb USING speaker_mapping::jsonb;

-- skills（若存在 metadata 列且为 json）
-- ALTER TABLE skills ALTER COLUMN metadata TYPE jsonb USING metadata::jsonb;
