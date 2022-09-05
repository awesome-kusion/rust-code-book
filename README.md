# Rust源码剖析

引个流先：

- *KusionStack一站式可编程配置技术栈(Go实现): <https://github.com/KusionStack/kusion>*
- *KusionStack内置的KCL配置语言(Rust实现): <https://github.com/KusionStack/KCLVM>*

## 序言

写这个电子书是因为一开始在做 KusionStack、KCLVM 项目中编译器研发的相关工作，本着学习优秀编译器的设计想法，开始学习 Rustc 的源码。这个过程中记录了一些笔记和文档，在[柴大](https://github.com/chai2010)鼓励下整理成文章正式发在了公众号上。没想到很受欢迎，于是决定坚持写下去。接下来会去写一些 Rustc 中的源码实现、标准库、工具，以及一些 Rust 的开源项目。

KCLVM 是我们在 Kusion 这个项目中使用 Rust 开发的语言编译器，书中的部分内容在这个项目中也有对应的应用。对云原生生态、技术感兴趣的同学可以了解下  &#x1F449; [KusionStack](https://github.com/KusionStack/kusion) 这个项目；对 Rust、编程语言、编译器感兴趣的同学可以看下 &#x1F449; [KCLVM](https://github.com/KusionStack/KCLVM)。

最后，这些文章中的内容大部分是我阅读源码时的一些记录和个人理解，以及 rust-dev-guide 中对应的一些描述。本人水平有限，所以可能会有一些不准确甚至错误的地方，也欢迎大家提 PR/Issue/Discussion，或者下方扫码加群讨论。如果对 Rust 源码有自己分析和见解，同样欢迎提 PR 投稿。

---

## 电子书

目标：学习分析 Rust 编译器（Rustc）、标准库、开源项目源代码。

![cover](cover.jpg)

- 代码仓库: [https://github.com/awesome-kusion/rust-code-book](https://github.com/awesome-kusion/rust-code-book)
- 在线阅读: [https://awesome-kusion.github.io/rust-code-book](https://awesome-kusion.github.io/rust-code-book)

## 目录

- [序言](preface.md)
- [简介](intro/readme.md)
- [Rust编译器](rustc/readme.md)
  - [概述](rustc/overview/readme.md)
  - [命令行解析](rustc/invocation/readme.md)
  - [词法分析](rustc/lexer/readme.md)
  - [语法分析](rustc/parser/readme.md)
    - [抽象语法树](rustc/parser/ast/readme.md)
      - [抽象语法树定义](rustc/parser/ast/ast.md)
      - [访问者模式](rustc/parser/ast/visitor.md)
    - [EarlyLint](rustc/parser/early-lint/readme.md)
  - [语义分析](rustc/sema/readme.md)
    - [Lint](rustc/sema/lint/readme.md)
      - [Lint 与 LintPass](rustc/sema/lint/lint-pass.md) &#x2705;
      - [CombinedLintPass](rustc/sema/lint/combinedlintpass.md) &#x2705;
      - [Lint 执行流程[WIP]](rustc/sema/lint/lint.md)  &#x1F552;
    - [Resolver](rustc/sema/resovler/readme.md)
    - [HIR lowering](rustc/sema/hir-lowering/readme.md)
      - [类型推导](rustc/sema/hir-lowering/type-inference/readme.md)
      - [Trait solving](rustc/sema/hir-lowering/trait-solving/readme.md)
      - [类型检查](rustc/sema/hir-lowering/type-checking/readme.md)
      - [LateLint](rustc/sema/late-lint/readme.md)
    - [MIR lowering](rustc/sema/mir-lowering/readme.md)
      - [Borrow checking](rustc/sema/mir-lowering/borrow-check/readme.md)
      - [MIR 优化](rustc/sema/mir-lowering/mir-optimized/readme.md)
  - [代码生成](rustc/codegen/readme.md)
  - [通用结构](rustc/general/readme.md)
    - [错误系统[WIP]](rustc/general/errors/readme.md)  &#x1F552;
    - [SourceMap & Span[WIP]](rustc/general/sourcemap-span/readme.md)  &#x1F552;

- [Rust外围工具](rust-tools/readme.md)
  - [Cargo包管理](rust-tools/cargo/readme.md)
  - [WASM包管理](rust-tools/wasm/readme.md)
  - [Clippy](rust-tools/clippy/readme.md)

- [Rust开源项目](open-source/readme.md)
  - [KCLVM](open-source/KCLVM/readme.md)
    - [KCL](open-source/KCLVM/KCL.md) &#x2705;
    - [KCLVM dev guide[WIP]](open-source/KCLVM/dev-guide/readme.md) &#x1F552;
      - [quick start](open-source/KCLVM/dev-guide/quick_start.md) &#x2705;

- [附录](appendix/readme.md)

---

[![Star History Chart](https://api.star-history.com/svg?repos=awesome-kusion/rust-code-book&type=Date)](https://star-history.com/#awesome-kusion/rust-code-book&Date)

- 微信群:
![wechat](wechat.png)
