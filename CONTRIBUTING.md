# Contributing

The most useful thing you can send is a report from real use: which agents you ran, what
went wrong, and which rule helped or got in the way. [Open an issue](https://github.com/Soda-null/multi-agent-repo-protocol/issues/new/choose).

For a code change:

1. Change the files under `template/`: that is what users get.
2. Run `tests/smoke_test.sh`. If you added a gate, add a check for it there too.
3. If a rule or a script changes, update both `README.md` and `README_zh.md`.

Keep the project free of dependencies: git, bash and the Python standard library only.
