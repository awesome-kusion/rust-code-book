# 序言

写这个电子书是因为一开始在做 KusionStack、KCLVM 项目中编译器研发的相关工作，本着学习优秀编译器的设计想法，开始学习 Rustc 的源码。这个过程中记录了一些笔记和文档，在[柴大](https://github.com/chai2010)鼓励下整理成文章正式发在了公众号上。没想到很受欢迎，于是决定坚持写下去。接下来会去写一些 Rustc 中的源码实现、标准库、工具，以及一些 Rust 的开源项目。

KCLVM 是我们在 Kusion 这个项目中使用 Rust 开发的语言编译器，书中的部分内容在这个项目中也有对应的应用。对云原生生态、技术感兴趣的同学可以了解下  &#x1F449; [KusionStack](https://github.com/KusionStack/kusion) 这个项目；对 Rust、编程语言、编译器感兴趣的同学可以看下 &#x1F449; [KCLVM](https://github.com/KusionStack/KCLVM)。

最后，这些文章中的内容大部分是我阅读源码时的一些记录和个人理解，以及 rust-dev-guide 中对应的一些描述。本人水平有限，所以可能会有一些不准确甚至错误的地方，也欢迎大家提 PR/Issue/Discussion，或者下方扫码加群讨论。如果对 Rust 源码有自己分析和见解，同样欢迎提 PR 投稿。
