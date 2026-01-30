# Cursor 终端网络 / SSH 设置说明

## 为什么现在 SSH 不行了？

从 **Cursor 2.0** 起，Agent 执行的终端命令默认在**沙箱终端**里跑：

- 只能访问当前工作区目录
- **默认没有网络**（不能访问外网、不能 SSH）

所以你之前能 SSH，多半是：

1. 用的是更早版本（还没有沙箱），或  
2. 当时是在**你自己打开的终端**里手动执行命令（不是 Agent 代你执行）

现在 Agent 代你执行命令时，会进沙箱，所以会报 `Operation not permitted` / `Network access: Blocked`。

---

## 不需要装插件，用设置即可

网络/SSH 相关的是 Cursor **自带设置**，不需要额外下载插件。

---

## 方法一：终端命令白名单（Allowlist）

把需要联网/SSH 的命令加入白名单，它们会在沙箱外执行（一般就有网络）。

1. 打开设置：**Cmd + ,**（Mac）或 **File → Preferences → Settings**
2. 搜索：**allowlist**（不要搜 whitelist）
3. 找到 **Cursor: Terminal Allowlist**，点 **Edit in settings.json**
4. 在 `settings.json` 里加上（或合并进已有配置）：

```json
{
  "cursor.terminal.allowList": [
    "ssh",
    "scp"
  ]
}
```

注意：

- 必须是**数组** `[]`，不能是字符串
- 写的是「会用到的那条命令」；如果 Agent 实际跑的是 `ssh admin@47.79.254.213 '...'`，可能要把整条命令或常用变体也加进去（例如 `ssh admin@47.79.254.213`）
- 不支持管道 `|`、链式 `&&`，复杂命令要拆成多条再分别加

加完后**重启 Cursor** 或重开 Agent 对话再试一次 SSH。

---

## 方法二：降低终端安全级别（慎用）

有的版本支持通过「安全级别」放宽限制（可能连带放开网络）：

1. **Cmd + ,** 打开设置，搜索 **terminal** 或 **security**
2. 看是否有 **Cursor: Terminal Security Level** 或类似项
3. 若存在且当前是 `high`，可尝试改为 `medium` 或 `none`（**none 会关闭沙箱，有安全风险，仅在自己电脑上临时用**）

若没有这项，说明当前版本可能没有在 UI 里暴露，只能等后续版本或看官方文档。

---

## 方法三：在你自己的终端里跑（最稳）

不依赖 Cursor 是否给 Agent 开网络，**保证能 SSH** 的做法是：

1. 在 Cursor 里用 **Terminal → New Terminal** 开一个终端（这是**你的**终端，不是沙箱）
2. 在这个终端里自己执行：
   ```bash
   ssh admin@47.79.254.213
   ```
   或运行项目里的脚本：
   ```bash
   cd /Users/liudan/Desktop/AI军师/gemini-audio-service
   ./run_nginx_fix_on_server.sh
   ```

这里跑的命令是**你本机环境**，和以前能 SSH 时一样，不需要改 Cursor 设置。

---

## 方法四：用系统自带终端 / iTerm

完全不用 Cursor 内置终端，改用系统终端：

1. 打开 **Terminal.app** 或 **iTerm**
2. `cd` 到项目目录，执行 SSH 或 `./run_nginx_fix_on_server.sh`

这样也一定会有网络、能 SSH；只是命令不是由 Cursor Agent 发起，而是你自己在外部终端里执行。

---

## 小结

| 方式           | 是否要装插件 | 说明 |
|----------------|--------------|------|
| Allowlist      | 否           | 在设置里加 `cursor.terminal.allowList`，把 `ssh`/`scp` 等加进去 |
| Security Level | 否           | 若有该设置，可尝试调低（注意安全） |
| 自己在 Cursor 终端里执行 | 否 | 用 Cursor 的 New Terminal，在里面跑 SSH/脚本 |
| 系统终端 / iTerm | 否        | 在 Cursor 外开终端执行，保证有网络 |

**推荐**：  
- 想继续让 Agent 执行 SSH：先试 **方法一（Allowlist）**，把 `ssh`、`scp` 等加进去。  
- 若仍被拦或没有对应设置：直接用 **方法三或四**，在自己终端或系统终端里执行 SSH / `run_nginx_fix_on_server.sh`，不依赖 Cursor 是否「打开网络」。
