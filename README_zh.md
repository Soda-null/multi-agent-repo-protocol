# multi-agent-repo-protocol（多 AI 共用一个仓库的协作规矩）

一套规矩 + git 钩子 + 几个小脚本，让好几个 AI 编程助手（Claude Code、Codex、便宜的 API 模型、本地模型）
在**同一个 git 仓库**里干活时不互相覆盖，而且事后能查清**哪一步是哪个 AI 做的**。

[English](README.md)

## 要解决什么问题

同一个项目同时用好几个 AI，下面这些事会反复发生：

- B 把 A 还没提交的文件当垃圾"整理"掉了，A 的活白干。
- 所有 AI 都用你一个人的 git 身份提交。出了问题，`git blame` 只会说是"你"干的。
- 状态文件里留着一条早就作废的旧决定，下一个 AI 读到了，当成现行规矩照做。
- 一个 AI 自己去调用另一个 AI，把别人的额度花掉了。
- 一个需要判断力的活被派给了便宜模型，它交回一份看着像样、其实不对的东西，还被收下了。

这些 AI 彼此不能说话，**文件是它们之间唯一的通道**。所以这套规矩把一切都落到文件里，
凡是机器能查的规矩，都配一个自动检查。

## 里面有什么

| 部件 | 作用 |
|---|---|
| `AGENTS.md`（+ 指向它的 `CLAUDE.md`） | 一份总章程，所有 AI 读同一份 |
| `docs/agent_board.md` | 任务板：谁现在在改哪些文件 |
| `.githooks/commit-msg` | 提交说明里没写 `Agent: 名字` 就拒绝提交，于是每次提交都能对上是谁 |
| `scripts/agent_worktree.sh` | 并行干活时给每个 AI 一个独立的工作目录（分支 `agent/<名字>`） |
| `scripts/delegate.sh` | 把活派给便宜的 AI——**前提是这个活写明了一条能证明它做对了的命令** |
| `docs/decisions.md` + `docs/glossary.md` | 只能追加的决定账本（带索引），和每个代号一行的白话解释 |
| `scripts/check_current_docs.py` | 入口文件里引用了已作废的决定却没说明，就拦下提交 |
| `scripts/check_doc_structure.py` | 每份文档开头有"是什么/地位/怎么读"三行卡片；索引不漏文件；入口文件不超长 |
| `scripts/worklog.py`、`new_log.py` | 每日日志；按提交时间推算工时（不花 token） |
| `scripts/repo_hygiene.py` | 每周体检：只删垃圾文件和已合并的分支，其余只报告 |
| `.claude/skills/close-session/` | 一个 Claude Code 技能：收工清单 |

## 规矩一页纸

1. **开工：** `git pull`、`git status`、读任务板。没提交的改动属于别的 AI：不许撤销、暂存或"整理"。
2. **认领：** 第一次提交时在任务板上写明自己占了哪些路径；干完就删掉。
3. **署名：** 每次提交末尾写 `Agent: claude-code`（或 `codex`、`deepseek`、`local`、`human`），钩子强制。
4. **只暂存自己改的文件**，一个个点名。共用的目录里绝不 `git add -A`。
5. **并行就分开工作目录。** 合并回 `main` 由人决定。
6. **不许悄悄推翻别的 AI 记下的结论。** 账本只能追加；没有新证据，就把分歧写下来，让人来定。
7. **同级不互相调用。** Codex 和 Claude Code 是人亲自开的两个座位，除非人开口，谁也不调谁（`delegate.sh` 要加 `--peer`）。
8. **派活必须带验收命令。** 说不出哪条命令能证明做对了 → 这就是要判断力的活，留给贵的 AI 和人。
9. **最常读的几个文件只写现在成立的事。** 旧决定要么删掉，要么在同一句里注明"已被取代"，有脚本查。
10. **收工：** 做完的全部提交。你留下没提交的，就是下一个 AI 会弄坏的。

每条规矩是被哪件事逼出来的：[`docs/why.md`](docs/why.md)。

## 安装

```bash
git clone https://github.com/Soda-null/multi-agent-repo-protocol.git
cd multi-agent-repo-protocol
./install.sh /你的/仓库/路径
```

`install.sh` 把模板复制进你的仓库，**已有的文件一个都不覆盖**（会列出跳过了哪些），
把 `CLAUDE.md` 链到 `AGENTS.md`，并打开钩子。之后填好 `AGENTS.md` 的 "Project" 一节和 `STATUS.md` §1。

需要：git ≥ 2.28、bash、Python ≥ 3.9，不用装任何 Python 包。

## 管不了的事

- **文字说过头。** 没有脚本能判断一句话是不是比证据说得更满，只能靠人看。这套规矩直说这一点，不假装能管。
- **派活本身的开销。** 写派活单也花 token。只有活远比说明大时才值得派（经验值：单子不到 1 KB，活要动 20 KB 以上的文件）。

## 自测

```bash
tests/smoke_test.sh
```

它在一个临时仓库里装上这套东西，把每道关卡都走一遍。

## 来历

这套东西来自一个单人研究仓库：2026 年里 Claude Code、Codex、DeepSeek 在里面一起干了大约两个月。
项目本身的内容没有放进来，只开源协作这一层。

## 许可

MIT
