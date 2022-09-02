# 目录

[Rust源码剖析](index.md)
[前言](preface.md)

- [Rust编译器](rustc/readme.md)
  - [基础结构](rustc/basic/readme.md)
  - [词法分析](rustc/lexer/readme.md)
  - [语法分析](rustc/parser/readme.md)
  - [语义分析](rustc/checker/readme.md)
    - [Lint工具](rustc/checker/lint/readme.md)
      - [Lint 与 LintPass](rustc/checker/lint/lint-pass.md)
      - [CombinedLintPass](rustc/checker/lint/combinedlintpass.md)
  - [中间代码表示](rustc/ir/readme.md)

- [Rust外围工具](rust-tools/readme.md)
  - [Cargo包管理](rust-tools/cargo/readme.md)
  - [WASM包管理](rust-tools/wasm/readme.md)
  - [Clippy](rust-tools/clippy/readme.md)

- [Rust开源项目](open-source/readme.md)
