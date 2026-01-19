# v0.4 数据库迁移说明

## 迁移内容

本次迁移将添加以下内容：

1. **skills 表** - 技能库表
   - skill_id (主键)
   - name, description, category
   - priority, enabled, version
   - metadata (JSONB)

2. **skill_executions 表** - 技能执行记录表
   - id (UUID 主键)
   - session_id, skill_id (外键)
   - scene_category, confidence_score
   - execution_time_ms, success, error_message

3. **strategy_analysis 表更新** - 添加新字段
   - applied_skills (JSONB) - 应用的技能列表
   - scene_category (VARCHAR) - 场景类别
   - scene_confidence (FLOAT) - 场景置信度

## 执行方式

### 方式 1: 使用 Python 脚本（推荐）

```bash
python3 database/migrations/run_migration_v0.4.py
```

**前提条件：**
- PostgreSQL 数据库服务正在运行
- 已配置正确的 DATABASE_URL 环境变量（在 .env 文件中）
- 数据库已创建

### 方式 2: 使用 psql 命令行工具

```bash
# 连接到数据库
psql -U postgres -d gemini_audio_db

# 执行迁移脚本
\i database/migrations/add_skills_tables.sql

# 或者直接执行
psql -U postgres -d gemini_audio_db -f database/migrations/add_skills_tables.sql
```

### 方式 3: 使用数据库管理工具

使用 pgAdmin、DBeaver 或其他 PostgreSQL 管理工具，打开 `database/migrations/add_skills_tables.sql` 文件并执行。

## 环境变量配置

确保 `.env` 文件中包含正确的数据库连接信息：

```env
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/gemini_audio_db
```

或者：

```env
DATABASE_URL=postgresql://用户名:密码@主机:端口/数据库名
```

## 验证迁移

迁移成功后，可以执行以下 SQL 验证：

```sql
-- 检查 skills 表
SELECT * FROM skills;

-- 检查 skill_executions 表
SELECT * FROM skill_executions;

-- 检查 strategy_analysis 表的新字段
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'strategy_analysis' 
AND column_name IN ('applied_skills', 'scene_category', 'scene_confidence');
```

## 回滚（如果需要）

如果需要回滚迁移，可以执行：

```sql
-- 删除新添加的表
DROP TABLE IF EXISTS skill_executions;
DROP TABLE IF EXISTS skills;

-- 删除 strategy_analysis 表的新字段
ALTER TABLE strategy_analysis
    DROP COLUMN IF EXISTS applied_skills,
    DROP COLUMN IF EXISTS scene_category,
    DROP COLUMN IF EXISTS scene_confidence;

-- 删除索引
DROP INDEX IF EXISTS idx_strategy_analysis_scene_category;
DROP INDEX IF EXISTS idx_skill_executions_skill_id;
DROP INDEX IF EXISTS idx_skill_executions_session_id;
DROP INDEX IF EXISTS idx_skills_enabled;
DROP INDEX IF EXISTS idx_skills_category;
```

## 注意事项

1. **备份数据**：在执行迁移前，建议备份数据库
2. **测试环境**：先在测试环境执行，确认无误后再在生产环境执行
3. **权限**：确保数据库用户有创建表和索引的权限
4. **依赖**：确保 `sessions` 表已存在（skill_executions 表依赖它）
