-- 技能表增加 prompt_template 列：模板落表后查表即可用，不依赖 SKILL.md 文件
ALTER TABLE skills ADD COLUMN IF NOT EXISTS prompt_template TEXT;
