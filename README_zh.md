# multi-agent-repo-protocol（多 AI 共用一个仓库的协作规矩）

[![smoke test](https://github.com/Soda-null/multi-agent-repo-protocol/actions/workflows/test.yml/badge.svg)](https://github.com/Soda-null/multi-agent-repo-protocol/actions/workflows/test.yml)
[![release](https://img.shields.io/github/v/release/Soda-null/multi-agent-repo-protocol)](https://github.com/Soda-null/multi-agent-repo-protocol/releases)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

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
给每个 AI 单独的分支和目录，并给最重要的几条规矩配上自动检查。
[哪些有检查](#哪些规矩有检查哪些没有)写得很清楚。

## 一分钟试一下

```bash
git clone https://github.com/Soda-null/multi-agent-repo-protocol.git
git init -b main demo
multi-agent-repo-protocol/install.sh demo
cd demo
git add -A
git commit -m "first"                     # 被拒绝：没写是哪个 AI
git commit -m "first" -m "Agent: human"   # 通过
```

## 里面有什么

| 部件 | 作用 |
|---|---|
| `AGENTS.md`（+ 指向它的 `CLAUDE.md`） | 一份总章程，所有 AI 读同一份 |
| `docs/agent_board.md` | 任务板：谁现在在改哪些文件 |
| `.githooks/commit-msg` | 提交说明里没写 `Agent: 名字` 就拒绝提交；AI 不在自己的分支上提交也会被拒绝 |
| `.github/workflows/agent-trailers.yml` | 在 GitHub 上跑同样的检查，没开钩子的 clone 提交了也能被发现 |
| `scripts/agent_worktree.sh` | 给每个 AI 一个独立的工作目录（分支 `agent/<名字>`），还能列出每个 AI 改了什么 |
| `scripts/delegate.sh` | 把活派给便宜的 AI——**前提是这个活写明了一条能证明它做对了的命令** |
| `docs/decisions.md` + `docs/glossary.md` | 只能追加的决定账本（带索引），和每个代号一行的白话解释 |
| `scripts/check_current_docs.py` | 入口文件里引用了已作废的决定却没说明，就拦下提交 |
| `scripts/check_doc_structure.py` | 每份文档开头有"是什么/地位/怎么读"三行卡片；索引不漏文件；入口文件不超长 |
| `scripts/worklog.py`、`new_log.py` | 每日日志；按提交时间推算工时（不花 token） |
| `scripts/repo_hygiene.py` | 每周体检：只删垃圾文件和已合并的分支，其余只报告 |
| `.claude/skills/close-session/` | 一个 Claude Code 技能：收工清单 |

## 规矩一页纸

1. **开工：** 进自己的工作目录，`git merge main`、`git status`、读任务板。没提交的改动属于别的 AI：不许撤销、暂存或"整理"。
2. **认领：** 第一次提交时在任务板上写明自己占了哪些路径；干完就删掉。
3. **署名：** 每次提交末尾写 `Agent: claude-code`（或 `codex`、`deepseek`、`local`、`human`），钩子强制。
4. **只暂存自己改的文件**，一个个点名。共用的目录里绝不 `git add -A`。
5. **每个 AI 只在自己的分支和目录里提交，** 钩子强制。合并回 `main` 由人决定。
6. **不许悄悄推翻别的 AI 记下的结论。** 账本只能追加；没有新证据，就把分歧写下来，让人来定。
7. **同级不互相调用。** Codex 和 Claude Code 是人亲自开的两个座位，除非人开口，谁也不调谁（`delegate.sh` 要加 `--peer`）。
8. **派活必须带验收命令。** 说不出哪条命令能证明做对了 → 这就是要判断力的活，留给贵的 AI 和人。
9. **最常读的几个文件只写现在成立的事。** 旧决定要么删掉，要么在同一句里注明"已被取代"，有脚本查。
10. **收工：** 做完的全部提交。你留下没提交的，就是下一个 AI 会弄坏的。

每条规矩是被哪件事逼出来的：[`docs/why.md`](docs/why.md)。

## 哪些规矩有检查，哪些没有

| 规矩 | 靠什么检查 |
|---|---|
| 每次提交写明是哪个 AI | `commit-msg` 钩子，加上 GitHub 上的 CI |
| AI 只在自己的分支上提交 | `commit-msg` 钩子，只在你的电脑上生效 |
| 入口文件不引用已作废的决定 | `pre-commit` 钩子 |
| 派活要有验收命令；调用同级要加 `--peer` | `delegate.sh` |
| 遵守认领表；不碰别的 AI 没提交的文件；逐个点名暂存；账本只追加 | **没有检查，** 只是写下来的规矩。分开目录之后，前三条没那么容易出事 |

AI 可以用 `git commit --no-verify` 跳过钩子。CI 跳不过去，但它只查署名。

## 平时怎么用

```bash
scripts/agent_worktree.sh codex         # 建 ../你的仓库-codex，分支 agent/codex
scripts/agent_worktree.sh claude-code   # 建 ../你的仓库-claude-code，分支 agent/claude-code
```

让每个 AI 在自己的目录里启动。它要是在别处提交，钩子会拒绝，并告诉它该怎么办。干完之后，在你的主目录里合并：

```bash
scripts/agent_worktree.sh --list        # 看每个 AI 改了什么
git merge --no-ff agent/codex
```

如果两个 AI 改了同一处，git 会在这一步报冲突，由你来定。你自己的提交（`Agent: human`）不受限制。

**代价是每件活多一次合并，** 一次只用一个 AI 也一样。想关掉这条规则，把 `.githooks/commit-msg` 里的 `REQUIRE_AGENT_BRANCH` 改成 `0`。
如果某个工具非要用自己的分支名，也只能这样，因为规则只认 `agent/<名字>` 和 `agent/<名字>-<后缀>`。

## 安装

```bash
git clone https://github.com/Soda-null/multi-agent-repo-protocol.git
cd multi-agent-repo-protocol
./install.sh /你的/仓库/路径
```

`install.sh` 把模板复制进你的仓库，**已有的文件一个都不覆盖**（会列出跳过了哪些），
把 `CLAUDE.md` 链到 `AGENTS.md`，并打开钩子。之后填好 `AGENTS.md` 的 "Project" 一节和 `STATUS.md` §1。

需要：git ≥ 2.28、bash、Python ≥ 3.9，不用装任何 Python 包。Linux、macOS、Windows 都测过。

### 每次新 clone

Git clone 仓库时不会自动打开钩子，所以新 clone 出来的仓库里，没署名的提交也能成功。这里有三层办法：

- **本地：** 每份 clone 跑一次下面这条。`AGENTS.md` 也要求每个 AI 开工时先跑它。

  ```bash
  git config core.hooksPath .githooks
  ```

- **GitHub 上：** 安装时带上的 workflow（GitHub 自动运行的任务）会检查每次 push 和 PR，发现没署名的提交就把这次运行标成失败。
- **想拦住合并：** 运行失败本身拦不住任何事。要在仓库设置里给 `main` 加一条分支保护规则，把 `agent-trailers` 设成必须通过的检查。

不会署名的机器人（比如 Dependabot）过不了这个检查。可以在 workflow 里加 `if: github.actor != 'dependabot[bot]'` 跳过它，或者不把这个检查设成必须通过。

### Windows

先装 [Git for Windows](https://git-scm.com/download/win)（自带 Git Bash）和 Python 3.9 以上，然后在 PowerShell 里：

```powershell
.\install.ps1 C:\你的\仓库\路径
```

Windows 上不一样的地方，都已经处理好了：

- **换行符。** Windows 会把文件的换行改成另一种格式，bash 脚本就跑不起来了。`.gitattributes` 把脚本和钩子固定成 Linux 的换行。
  如果你的仓库里已经有 `.gitattributes`，安装时会跳过它，你要自己把 `template/.gitattributes` 里那几行加进去。
- **`python3` 命令。** Windows 上常常只有 `python` 或 `py`。钩子和派活脚本会自己找到能用的 Python。
  在 PowerShell 里手动跑脚本时写 `python scripts\check_doc_structure.py`。
- **快捷链接（symlink）** 要打开"开发者模式"才能建。没打开的话，`CLAUDE.md` 会变成只有一行 `@AGENTS.md` 的文件
  （Claude Code 会把它当成"去读 AGENTS.md"）。分工作目录时，没提交的大数据会跳过，不会整份复制。
- **`agent_worktree.sh`、`delegate.sh` 请在 Git Bash 里跑。** 钩子由 git 自己调 bash，所以从哪个终端或应用提交都会被检查。
- **时区名**（`LOG_TZ`）在 Windows 上要先 `pip install tzdata`。没装就用本机时间，并给一句提示。

## 管不了的事

- **提交之前的破坏。** Git 没有能在 `git checkout -- 文件` 或 `git stash` 之前运行的钩子。AI 要是不守规矩，跑进别的 AI 的目录，还是能毁掉没提交的改动。
- **AI 撒谎。** 署名只是一句声明，不是证明，谁都能写 `Agent: human`。它防的是忘记写和搞混，防不了故意冒名。
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

## 反馈

在真实项目里用过？欢迎写一份[使用报告](https://github.com/Soda-null/multi-agent-repo-protocol/issues/new?template=field_report.md)，好的坏的都有用。想改代码请看 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可

MIT
