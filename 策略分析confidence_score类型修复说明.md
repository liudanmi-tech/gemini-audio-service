# 策略分析 confidence_score 类型错误修复说明

## 策略失败卡在哪个环节

从日志顺序可以判断：

| 日志内容 | 含义 |
|----------|------|
| `[策略流程] 步骤2.3: 技能执行(transcript+技能prompt->Gemini)...` | 开始执行技能（调用 Gemini） |
| 紧接着出现 `column "confidence_score" is of type json...` 或 `Unknown PG numeric type: 114` | **卡点**：在**把技能执行结果写入数据库**时，向 `skill_executions` 表插入/更新 `confidence_score`（应用传的是 float），而库里该列仍是 **json**，导致报错 |

结论：策略失败卡在 **步骤 2.3 的「记录技能执行到数据库」** 环节（`main.py` 里 `SkillExecution` 的 `confidence_score` 写入）。把该列改为 **double precision** 即可。

---

## 错误现象

日志中出现：

```text
column "confidence_score" is of type json but expression is of type double precision
```

说明数据库里 `skill_executions.confidence_score` 仍是 **json**，而应用按 **double precision（浮点数）** 写入。

## 处理步骤（在服务器上执行）

### 方式一：一键修复并重启（推荐）

在项目根目录执行（需先上传本脚本到服务器）：

```bash
cd ~/gemini-audio-service
bash 服务器上执行-策略confidence_score修复并重启.sh
```

该脚本会依次：执行迁移 → 检查列类型 → 重启 uvicorn（端口 8000）。

### 方式二：分步执行

#### 1. 确认列类型

在项目根目录执行：

```bash
cd ~/gemini-audio-service
source venv/bin/activate
python3 database/migrations/check_json_columns.py
```

查看输出中 **「关键列」** 部分：

- 若 `skill_executions.confidence_score` 显示为 `json` 且带 `需改为 double precision`，说明需要执行下面的迁移。
- 若已是 `double precision`，则类型正确，可排查是否连错库或未重启应用。

#### 2. 执行迁移（推荐）

```bash
python3 database/migrations/run_fix_json_to_jsonb.py
```

关注是否出现：

- `skill_executions.confidence_score -> double precision`：表示该列已改为 double precision。
- 若出现 `❌ skill_executions.confidence_score 失败: ...`，记下报错信息，并执行步骤 3。

#### 3. 若 Python 迁移失败，用手动 SQL

用 psql 连接同一数据库（与 `.env` 里 `DATABASE_URL` 一致），执行：

```bash
# 若 DATABASE_URL 在 .env 里，可先加载再执行
export $(grep -v '^#' .env | xargs)
psql "$DATABASE_URL" -f database/migrations/fix_confidence_columns_manual.sql
```

或逐条执行：

```sql
ALTER TABLE strategy_analysis
  ALTER COLUMN scene_confidence TYPE double precision
  USING (COALESCE((scene_confidence::text)::double precision, 0.5));

ALTER TABLE skill_executions
  ALTER COLUMN confidence_score TYPE double precision
  USING (COALESCE((confidence_score::text)::double precision, 0.5));
```

#### 4. 再次检查并重启应用

```bash
python3 database/migrations/check_json_columns.py
# 确认 skill_executions.confidence_score 为 double precision 后：
# 重启 uvicorn/gunicorn 等应用进程
```

## 本次代码改动摘要

- **check_json_columns.py**：增加对 `scene_confidence`、`confidence_score` 的类型检查，并提示手动 SQL。
- **run_fix_json_to_jsonb.py**：修正输出文案，对这两列显示 `-> double precision`。
- **fix_confidence_columns_manual.sql**：新增，供 psql 手动执行，仅改这两列为 double precision。

应用端模型未改，仍为 `Column(Float)`；修复依赖数据库列类型改为 double precision。
