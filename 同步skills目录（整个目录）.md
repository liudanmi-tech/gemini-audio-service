v0.4 完整上传指南

## 快速上传（一键上传所有文件）

在本地终端执行：

```bash
cd ~/Desktop/AI军师/gemini-audio-service

chmod +x v0.4上传代码到服务器.sh

./v0.4上传代码到服务器.sh
```

**脚本会自动上传以下所有文件**：

### 1. skills目录（整个目录）

- `skills/__init__.py`

- `skills/loader.py`

- `skills/registry.py`

- `skills/router.py`

- `skills/executor.py`

- `skills/composer.py`

- `skills/workplace_jungle/` (包含SKILL.md、scripts、references、assets)

- `skills/family_relationship/` (包含SKILL.md、references)

- `skills/education_communication/` (包含SKILL.md、references)

- `skills/brainstorm/` (包含SKILL.md、references)

### 2. 数据库迁移文件

- `database/migrations/run_migration_v0.4.py`

- `database/migrations/add_skills_tables.sql`

### 3. 数据库模型

- `database/models.py`

### 4. API文件

- `api/skills.py`

### 5. 主程序

- `main.py`

### 6. Python脚本

- `注册技能到数据库.py`

- `测试v0.4功能.py`

### 7. Shell脚本

- `测试v0.4架构.sh`

- `服务器执行v0.4部署.sh`

- `在服务器上执行.sh`

- `v0.4自动化部署脚本.sh`

- `验证部署.sh` ⭐ **新增**

---

## 手动上传（如果脚本不可用）

### 方法1: 使用rsync同步（推荐，支持断点续传）

```bash
cd ~/Desktop/AI军师/gemini-audio-service



# 同步skills目录（整个目录）

rsync -avz --progress skills/ admin@47.79.254.213:~/gemini-audio-service/skills/



# 同步其他文件

rsync -avz --progress \

database/migrations/run_migration_v0.4.py \

database/migrations/add_skills_tables.sql \

database/models.py \

api/skills.py \

main.py \

admin@47.79.254.213:~/gemini-audio-service/



# 同步脚本文件

rsync -avz --progress \

注册技能到数据库.py \

测试v0.4功能.py \

测试v0.4架构.sh \

服务器执行v0.4部署.sh \

在服务器上执行.sh \

v0.4自动化部署脚本.sh \

验证部署.sh \

admin@47.79.254.213:~/gemini-audio-service/
```

### 方法2: 使用scp逐个上传

```bash
cd ~/Desktop/AI军师/gemini-audio-service



# 1. 上传skills目录（整个目录）

scp -r skills admin@47.79.254.213:~/gemini-audio-service/



# 2. 上传数据库迁移文件

scp database/migrations/run_migration_v0.4.py admin@47.79.254.213:~/gemini-audio-service/database/migrations/

scp database/migrations/add_skills_tables.sql admin@47.79.254.213:~/gemini-audio-service/database/migrations/



# 3. 上传数据库模型

scp database/models.py admin@47.79.254.213:~/gemini-audio-service/database/



# 4. 上传API文件

scp api/skills.py admin@47.79.254.213:~/gemini-audio-service/api/



# 5. 上传main.py

scp main.py admin@47.79.254.213:~/gemini-audio-service/



# 6. 上传Python脚本

scp 注册技能到数据库.py admin@47.79.254.213:~/gemini-audio-service/

scp 测试v0.4功能.py admin@47.79.254.213:~/gemini-audio-service/



# 7. 上传Shell脚本

scp 测试v0.4架构.sh admin@47.79.254.213:~/gemini-audio-service/

scp 服务器执行v0.4部署.sh admin@47.79.254.213:~/gemini-audio-service/

scp 在服务器上执行.sh admin@47.79.254.213:~/gemini-audio-service/

scp v0.4自动化部署脚本.sh admin@47.79.254.213:~/gemini-audio-service/

scp 验证部署.sh admin@47.79.254.213:~/gemini-audio-service/
```

---

## 上传后设置权限

在服务器上执行：

```bash
ssh admin@47.79.254.213

cd ~/gemini-audio-service



# 设置所有脚本执行权限

chmod +x *.sh

chmod +x 注册技能到数据库.py 测试v0.4功能.py

chmod +x database/migrations/run_migration_v0.4.py
```

---

## 验证上传

在服务器上执行：

```bash
ssh admin@47.79.254.213

cd ~/gemini-audio-service



# 检查skills目录

ls -la skills/

ls -la skills/*/SKILL.md



# 检查Python文件

ls -la database/migrations/run_migration_v0.4.py

ls -la api/skills.py

ls -la main.py



# 检查脚本文件

ls -la 验证部署.sh

ls -la 服务器执行v0.4部署.sh

ls -la 测试v0.4架构.sh
```

**预期结果**: 所有文件都应该存在且有正确的权限（脚本文件应该可执行）

---

## 上传文件清单

### 必需文件（部署v0.4必需）

1. ✅ `skills/` - 技能目录（包含所有技能）

2. ✅ `database/migrations/run_migration_v0.4.py` - 数据库迁移脚本

3. ✅ `database/migrations/add_skills_tables.sql` - SQL迁移脚本

4. ✅ `database/models.py` - 数据库模型（包含Skill、SkillExecution模型）

5. ✅ `api/skills.py` - 技能管理API

6. ✅ `main.py` - 主程序（包含技能化架构集成）

### 可选文件（测试和部署辅助）

7. ✅ `注册技能到数据库.py` - 技能注册脚本

8. ✅ `测试v0.4功能.py` - 功能测试脚本

9. ✅ `测试v0.4架构.sh` - 架构验证脚本

10. ✅ `服务器执行v0.4部署.sh` - 部署脚本

11. ✅ `在服务器上执行.sh` - 部署脚本（备用）

12. ✅ `v0.4自动化部署脚本.sh` - 自动化部署脚本

13. ✅ `验证部署.sh` - 部署后验证脚本 ⭐ **新增**

---

## 常见问题

### 问题1: 上传中断

**解决方案**: 使用 `rsync` 替代 `scp`（支持断点续传）

```bash
rsync -avz --progress skills/ admin@47.79.254.213:~/gemini-audio-service/skills/
```

### 问题2: 权限错误

**症状**: `Permission denied`

**解决方案**: 检查SSH免密登录配置或使用密码登录

```bash
# 配置免密登录

./配置SSH免密登录.sh
```

### 问题3: 文件上传不完整

**症状**: 文件存在但内容不完整

**解决方案**: 重新上传文件，使用 `rsync` 验证文件一致性

```bash
rsync -avz --progress --checksum file.txt admin@47.79.254.213:~/gemini-audio-service/
```

### 问题4: skills目录上传失败

**症状**: `scp` 无法上传整个目录

**解决方案**: 使用 `rsync` 或逐个上传子目录

```bash
# 方法1: 使用rsync（推荐）

rsync -avz --progress skills/ admin@47.79.254.213:~/gemini-audio-service/skills/



# 方法2: 使用tar压缩后上传

tar -czf skills.tar.gz skills/

scp skills.tar.gz admin@47.79.254.213:~/gemini-audio-service/

ssh admin@47.79.254.213 "cd ~/gemini-audio-service && tar -xzf skills.tar.gz && rm skills.tar.gz"
```

---

## 快速命令总结

### 一键上传所有文件

```bash
./v0.4上传代码到服务器.sh
```

### 使用rsync同步（支持断点续传）

```bash
rsync -avz --progress skills/ admin@47.79.254.213:~/gemini-audio-service/skills/

rsync -avz --progress *.py *.sh admin@47.79.254.213:~/gemini-audio-service/
```

### 验证上传

```bash
ssh admin@47.79.254.213 "cd ~/gemini-audio-service && ls -la skills/ *.sh *.py"
```

---

**文档版本**: v0.4

**创建日期**: 2026-01-16
