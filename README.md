# Rust源码剖析 中文版

## 前言

写这个电子书是因为一开始在做 KusionStack、KCLVM 项目中编译器研发的相关工作，本着学习优秀编译器的设计想法，开始学习 Rustc 的源码。这个过程中记录了一些笔记和文档，在[柴大](https://github.com/chai2010)鼓励下整理成文章正式发在了公众号上。没想到很受欢迎，于是决定坚持写下去。接下来会去写一些 Rustc 中的源码实现、标准库、工具，以及一些 Rust 的开源项目（比如 &#x1F449; [KusionStack](https://github.com/KusionStack/kusion) &#x1F449; [KCLVM](https://github.com/KusionStack/KCLVM)）。

这些文章中的内容大部分是我阅读源码时的一些记录和个人理解，以及 rust-dev-guide 中对应的一些描述。本人水平有限，所以可能会有一些不准确甚至错误的地方，也欢迎大家提 PR/Issue/Discussion，或者下方扫码加群讨论。

再引个流：

- *KusionStack一站式可编程配置技术栈(Go实现): <https://github.com/KusionStack/kusion>*
- *KusionStack内置的KCL配置语言(Rust实现): <https://github.com/KusionStack/KCLVM>*

[![Star History Chart](https://api.star-history.com/svg?repos=awesome-kusion/rust-code-book&type=Date)](https://star-history.com/#awesome-kusion/rust-code-book&Date)

---

目标：学习分析 Rust 编译器（Rustc）、标准库、开源项目源代码。

![cover](cover.jpg)

- 代码仓库: [https://github.com/awesome-kusion/rust-code-book](https://github.com/awesome-kusion/rust-code-book)
- 在线阅读: [https://awesome-kusion.github.io/rust-code-book](https://awesome-kusion.github.io/rust-code-book)
- 微信群:
![wechat](wechat.png)
