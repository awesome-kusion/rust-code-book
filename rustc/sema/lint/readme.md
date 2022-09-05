# Lint

## Background

Lint is a kind of static analysis tools, which originated from C language. Lint tools usually check potential problems and errors in code, including (but not limited to) programming style (indentation, blank lines, spaces), code quality (unused variables, missing documents), and error codes (division by zero, duplicate definitions, circular references). Generally speaking, in addition to identifying errors, lint tools also have some fix / refactor suggest and auto fix capabilities. Using lint tools in the project can effectively reduce errors and improve the project quality. In addition, for a programming language, the lint tool is usually a prerequisite for the development of other tools, such as the error prompt of IDE plug-ins(e.g., LSP) and the pipeline detection of CI.

## Lint vs. LintPass

### Definition

There are two main structures about lint in rustc, `Lint` and `LintPass`. First, we need to distinguish the concepts of Lint and LintPass. In many documents of rustc, they are both referred to as 'Lint', which is easy to cause confusion. The difference between them is explained by rustc-dev-guide as follows:

> Lint declarations don't carry any "state" - they are merely global identifiers and descriptions of lints. We assert at runtime that they are not registered twice (by lint name).
Lint passes are the meat of any lint.

In terms of definition, `Lint` is just a description of the lint check defined, such as name, level, description, code and other attributes. It does't carry any state of checking. Rustc checks the uniqueness of registered lints at runtime.`LintPass` is a implementation of `lint`, which contains the `check_*` methods that are called when checking.

In terms of code implementation, `Lint` is defined as a struct in Rust, and all lint definitions are an instance / object of this struct. And `LintPass` is a trait. Trait is similar to the interface in Java / C + +. Every definition of lintpass needs to implement the methods defined in the interface.

```rust
/// Specification of a single lint.
#[derive(Copy, Clone, Debug)]
pub struct Lint {
    pub name: &'static str,
    /// Default level for the lint.
    pub default_level: Level,
    /// Description of the lint or the issue it detects.
    ///
    /// e.g., "imports that are never used"
    pub desc: &'static str,
    ...
}

pub trait LintPass {
    fn name(&self) -> &'static str;
}
```

It should be noted that although we just said that `trait` is similar to an interface and `Lint` is a struct, the relationship between `Lint` and `LintPass` is not a "class" and its "methods" in OO. Instead, declaring `LintPass` will generate a struct with the same name, this struct implements the trait , and the `get_lints()` method in this struct will generate the corresponding `Lint` definition.


![lint vs. lintpass](./images/lint_lintpass.jpeg)

This is also consistent with the description of the rustc-dev-guide:

> A lint might not have any lint pass that emits it, it could have many, or just one -- the compiler doesn't track whether a pass is in any way associated with a particular lint, and frequently lints are emitted as part of other work (e.g., type checking, etc.).

### Definition of Lint and LintPass

Rustc provides macros for both Lint and LintPass to define their structure.
The macro `declare_lint` that defines Lint is simple, it can be found in `rustc_lint_defs::lib.rs`. The `declare_lint` macro parses the input arguments and produces a Lint struct named `$NAME`.

```rust
#[macro_export]
macro_rules! declare_lint {
    ($(#[$attr:meta])* $vis: vis $NAME: ident, $Level: ident, $desc: expr) => (
        $crate::declare_lint!(
            $(#[$attr])* $vis $NAME, $Level, $desc,
        );
    );
    ($(#[$attr:meta])* $vis: vis $NAME: ident, $Level: ident, $desc: expr,
     $(@feature_gate = $gate:expr;)?
     $(@future_incompatible = FutureIncompatibleInfo { $($field:ident : $val:expr),* $(,)*  }; )?
     $($v:ident),*) => (
        $(#[$attr])*
        $vis static $NAME: &$crate::Lint = &$crate::Lint {
            name: stringify!($NAME),
            default_level: $crate::$Level,
            desc: $desc,
            edition_lint_opts: None,
            is_plugin: false,
            $($v: true,)*
            $(feature_gate: Some($gate),)*
            $(future_incompatible: Some($crate::FutureIncompatibleInfo {
                $($field: $val,)*
                ..$crate::FutureIncompatibleInfo::default_fields_for_macro()
            }),)*
            ..$crate::Lint::default_fields_for_macro()
        };
    );
    ($(#[$attr:meta])* $vis: vis $NAME: ident, $Level: ident, $desc: expr,
     $lint_edition: expr => $edition_level: ident
    ) => (
        $(#[$attr])*
        $vis static $NAME: &$crate::Lint = &$crate::Lint {
            name: stringify!($NAME),
            default_level: $crate::$Level,
            desc: $desc,
            edition_lint_opts: Some(($lint_edition, $crate::Level::$edition_level)),
            report_in_external_macro: false,
            is_plugin: false,
        };
    );
}
```

The definition of LintPass involves two macros:

- declare_lint_pass: Generate a struct named `$name` and call the macro `impl_lint_pass`.

```rust
macro_rules! declare_lint_pass {
    ($(#[$m:meta])* $name:ident => [$($lint:expr),* $(,)?]) => {
        $(#[$m])* #[derive(Copy, Clone)] pub struct $name;
        $crate::impl_lint_pass!($name => [$($lint),*]);
    };
}
```

- impl_lint_pass: Implements the `fn name()` and `fn get_lints()` methods for the generated `LintPass` structure.

```rust
macro_rules! impl_lint_pass {
    ($ty:ty => [$($lint:expr),* $(,)?]) => {
        impl $crate::LintPass for $ty {
            fn name(&self) -> &'static str { stringify!($ty) }
        }
        impl $ty {
            pub fn get_lints() -> $crate::LintArray { $crate::lint_array!($($lint),*) }
        }
    };
}
```

### EarlyLintPass and LateLintPass

In the macro definition of `LintPass`, only the `fn name()` and `fn get_lints()` methods are defined, but the `check_*` functions for checking are not provided. This is because Rustc divides `LintPass` into two more specific categories: `EarlyLintPass` and `LateLintPass`. The main difference is whether the checked element has type information, i.e. is performed before or after the type checking. For example, `WhileTrue` checks for `while true{...}` in the code and prompts the user to use `loop{...}` instead it. This check does not require any type information and is therefore defined as an `EarlyLint` (`impl EarlyLintPass for WhileTrue` in the code.

```rust
declare_lint! {
    WHILE_TRUE,
    Warn,
    "suggest using `loop { }` instead of `while true { }`"
}

declare_lint_pass!(WhileTrue => [WHILE_TRUE]);

impl EarlyLintPass for WhileTrue {
    fn check_expr(&mut self, cx: &EarlyContext<'_>, e: &ast::Expr) {
        ...
    }
}
```

Rustc uses 3 macros to define `EarlyLintPass`:

- early_lint_methods: early_lint_methods defines the `check_*` functions that need to be implemented in `EarlyLintPass`, and passes these functions and the received parameters `$args` to the next macro.

```rust
macro_rules! early_lint_methods {
    ($macro:path, $args:tt) => (
        $macro!($args, [
            fn check_param(a: &ast::Param);
            fn check_ident(a: &ast::Ident);
            fn check_crate(a: &ast::Crate);
            fn check_crate_post(a: &ast::Crate);
            ...
        ]);
    )
}
```

- declare_early_lint_pass: Generate trait `EarlyLintPass` and call macro `expand_early_lint_pass_methods`.

```rust
macro_rules! declare_early_lint_pass {
    ([], [$($methods:tt)*]) => (
        pub trait EarlyLintPass: LintPass {
            expand_early_lint_pass_methods!(&EarlyContext<'_>, [$($methods)*]);
        }
    )
}
```

- expand_early_lint_pass_methods: Provides default implementations for `check_*` methods: nothing to do(`{}` in code).

```rust
macro_rules! expand_early_lint_pass_methods {
    ($context:ty, [$($(#[$attr:meta])* fn $name:ident($($param:ident: $arg:ty),*);)*]) => (
        $(#[inline(always)] fn $name(&mut self, _: $context, $(_: $arg),*) {})*
    )
}
```

The benefits are as follows:

1. Because `LintPass` is a trait, every definition of `LintPass` needs to implement all of its methods. But early lint and late lint occur at different stages of compilation, and the input parameters are also different (AST and HIR). Therefore, the definition of LintPass contains only two general methods `fn name()` and `fn get_lints()`. The check methods are defined in the more specific `EarlyLintPass` and `LateLintPass`.
2. Likewise, for `EarlyLintPass`, every definition of lintpass must implement all of its methods. But not every lintpass needs to check all nodes of the AST. `expand_early_lint_pass_methods` provides default implementations for its methods. In this way, when defining a specific lintpass, you only need to pay attention to implement its related check methods. For example, for the definition of `WhileTrue`, since `while true { }` only appears in the `ast::Expr` node, it only needs to implement the `check_expr` function. Calling the `WhileTrue` check function at any other node, such as call `WhileTrue.check_ident()` when checking an identifier node on the AST, will only execute execute an empty methods as defined in the macro `expand_early_lint_pass_methods`.

### Meaning of pass

In Rustc, in addition to `Lint` and `LintPass`, there are some `*Pass` naming, such as `Mir` and `MirPass`, the `rustc_passes` package, etc. The **Compilers, Principles, Techiques, & Tools** has a corresponding explanation for Pass:

> 1.2.8 Combine multiple steps into a pass
The previous discussion of steps was about the logical organization of a compiler. In a particular implementation, the activities of multiple steps can be combined into a pass. Each pass reads in an input file and produces an output file.

In the macro `declare_lint_pass` that declares `LintPass`, its second parameter is a list, indicating that a lintpass can generate multiple lints. There are also some CombinedLintPass in Rustc that also aggregates all builtin lints into one lintpass. This is basically the same as the definition of "pass" in the Dragon Book: `LintPass` can combine multiple `Lint` checks, each LintPass reads an AST/HIR and produces a corresponding result.

## Simple design of Lint

In the definition of LintPass, a default implementation is provided for all `check_*` methods of each lintpass. So far, we can implement a simple Lint tool：

```rust
struct Linter { }
impl ast_visit::Visitor for Linter {
    fn visit_crate(a: ast:crate){
        for lintpass in lintpasses{
            lintpass.check_crate(a)
        }
        walk_crate();
    }
    fn visit_stmt(a: ast:stmt){
        for lintpass in lintpasses{
            lintpass.check_stmt(a)
        }
        walk_stmt();
    }
    ...
}

let linter = Linter::new();

for c in crates{
    linter.visit_crate(c);
}
```

`Visitor` is a tool for traversing the AST. Here, the `visit_*` methods are implemented for Linter, and all lintpass `check_*` methods are called during traversal. `walk_*` will continue to call other `visit_*` methods to traverse its child nodes. So, for each crate, just call the `visit_crate()` function to traverse the AST and complete the lint check.

## CombinedLintpass

但是，Rustc 自身和 clippy 提供的 Lint 定义多达550+多个。考虑到性能因素，定义大量的 LintPass，分别注册和调用显然是不合适的。Rustc 提供了一种更优的解决方法：既然可以将多个 Lint 组织为一个 LintPass，同样也可以将多个 LintPass 组合成一个 CombinedLintPass。
> [Compiler lint passes are combined into one pass](https://rustc-dev-guide.rust-lang.org/diagnostics/lintstore.html#compiler-lint-passes-are-combined-into-one-pass)
> Within the compiler, for performance reasons, we usually do not register dozens of lint passes. Instead, we have a single lint pass of each variety (e.g., BuiltinCombinedModuleLateLintPass) which will internally call all of the individual lint passes; this is because then we get the benefits of static over dynamic dispatch for each of the (often empty) trait methods.
> Ideally, we'd not have to do this, since it adds to the complexity of understanding the code. However, with the current type-erased lint store approach, it is beneficial to do so for performance reasons.

### BuiltinCombinedEarlyLintPass

CombinedLintPass 同样分为 early 和 late 两类。 以 builtin 的 early lint 为例，Rustc 在 `rustc_lint::src::lib.rs` 中为这些 lintpass 定义了一个 `BuiltinCombinedEarlyLintPass` 结构。

```rust
early_lint_passes!(declare_combined_early_pass, [BuiltinCombinedEarlyLintPass]);
```

虽然这个定义看起来只有一行，但其中通过若干个宏的展开，汇总了14个 `LintPass`，并且每个 `LintPass` 提供了50多个 `check_*` 方法。接下来一一说明这些宏。

#### BuiltinCombinedEarlyLintPass 的宏定义

##### early_lint_passes

```rust
macro_rules! early_lint_passes {
    ($macro:path, $args:tt) => {
        $macro!(
            $args,
            [
                UnusedParens: UnusedParens,
                UnusedBraces: UnusedBraces,
                UnusedImportBraces: UnusedImportBraces,
                UnsafeCode: UnsafeCode,
                AnonymousParameters: AnonymousParameters,
                EllipsisInclusiveRangePatterns: EllipsisInclusiveRangePatterns::default(),
                NonCamelCaseTypes: NonCamelCaseTypes,
                DeprecatedAttr: DeprecatedAttr::new(),
                WhileTrue: WhileTrue,
                NonAsciiIdents: NonAsciiIdents,
                HiddenUnicodeCodepoints: HiddenUnicodeCodepoints,
                IncompleteFeatures: IncompleteFeatures,
                RedundantSemicolons: RedundantSemicolons,
                UnusedDocComment: UnusedDocComment,
            ]
        );
    };
}
```

首先是 early_lint_passes 宏，这个宏的主要作用是定义了所有的 early lintpass。这里的 lintpass 是成对出现的，`:`左边为 lintpass 的 Identifier，`:`右边为 lintpass 的constructor。所以会出现 `EllipsisInclusiveRangePatterns::default()` 和 `DeprecatedAttr::new()`这种形式。early_lint_passes 会将定义的 early lintpass 和 第二个参数一起传递给下一个宏。
通过这个宏，之前的`BuiltinCombinedEarlyLintPass`的定义被展开为：

```rust
declare_combined_early_pass!([BuiltinCombinedEarlyLintPass], [
                UnusedParens: UnusedParens,
                UnusedBraces: UnusedBraces,
                UnusedImportBraces: UnusedImportBraces,
                UnsafeCode: UnsafeCode,
                AnonymousParameters: AnonymousParameters,
                EllipsisInclusiveRangePatterns: EllipsisInclusiveRangePatterns::default(),
                NonCamelCaseTypes: NonCamelCaseTypes,
                DeprecatedAttr: DeprecatedAttr::new(),
                WhileTrue: WhileTrue,
                NonAsciiIdents: NonAsciiIdents,
                HiddenUnicodeCodepoints: HiddenUnicodeCodepoints,
                IncompleteFeatures: IncompleteFeatures,
                RedundantSemicolons: RedundantSemicolons,
                UnusedDocComment: UnusedDocComment,
            ])
```

##### declare_combined_early_pass

```rust
macro_rules! declare_combined_early_pass {
    ([$name:ident], $passes:tt) => (
        early_lint_methods!(declare_combined_early_lint_pass, [pub $name, $passes]);
    )
}
```

declare_combined_early_pass 宏接收 early_lint_passes宏传来的 name(BuiltinCombinedEarlyLintPass) 和 passes，并继续传递给 early_lint_methods 宏。
通过这个宏，`BuiltinCombinedEarlyLintPass`的定义继续展开为：

```rust
early_lint_methods!(declare_combined_early_lint_pass, 
                    [pub BuiltinCombinedEarlyLintPass, 
                      [
                            UnusedParens: UnusedParens,
                            UnusedBraces: UnusedBraces,
                            UnusedImportBraces: UnusedImportBraces,
                            UnsafeCode: UnsafeCode,
                            AnonymousParameters: AnonymousParameters,
                            EllipsisInclusiveRangePatterns: EllipsisInclusiveRangePatterns::default(),
                            NonCamelCaseTypes: NonCamelCaseTypes,
                            DeprecatedAttr: DeprecatedAttr::new(),
                            WhileTrue: WhileTrue,
                            NonAsciiIdents: NonAsciiIdents,
                            HiddenUnicodeCodepoints: HiddenUnicodeCodepoints,
                            IncompleteFeatures: IncompleteFeatures,
                            RedundantSemicolons: RedundantSemicolons,
                            UnusedDocComment: UnusedDocComment,
               ]
                    ]);
```

##### early_lint_methods

```rust
macro_rules! early_lint_methods {
    ($macro:path, $args:tt) => (
        $macro!($args, [
            fn check_param(a: &ast::Param);
            fn check_ident(a: &ast::Ident);
            fn check_crate(a: &ast::Crate);
            fn check_crate_post(a: &ast::Crate);
            ...
        ]);
    )
}
```

early_lint_methods 宏在前一篇文章中也介绍过，它定义了 `EarlyLintPass` 中需要实现的 `check_*`函数，并且将这些函数以及接收的参数 `$args`传递给下一个宏。因为 `BuiltinCombinedEarlyLintPass` 也是 early lint 的一种，所以同样需要实现这些函数。
通过这个宏，`BuiltinCombinedEarlyLintPass`的定义继续展开为：

```rust
declare_combined_early_lint_pass!(
    [pub BuiltinCombinedEarlyLintPass, 
        [
            UnusedParens: UnusedParens,
            UnusedBraces: UnusedBraces,
            UnusedImportBraces: UnusedImportBraces,
            UnsafeCode: UnsafeCode,
            AnonymousParameters: AnonymousParameters,
            EllipsisInclusiveRangePatterns: EllipsisInclusiveRangePatterns::default(),
            NonCamelCaseTypes: NonCamelCaseTypes,
            DeprecatedAttr: DeprecatedAttr::new(),
            WhileTrue: WhileTrue,
            NonAsciiIdents: NonAsciiIdents,
            HiddenUnicodeCodepoints: HiddenUnicodeCodepoints,
            IncompleteFeatures: IncompleteFeatures,
            RedundantSemicolons: RedundantSemicolons,
            UnusedDocComment: UnusedDocComment,
        ]
    ],
    [
        fn check_param(a: &ast::Param);
        fn check_ident(a: &ast::Ident);
        fn check_crate(a: &ast::Crate);
        fn check_crate_post(a: &ast::Crate);
        ...
    ]
)
```

##### declare_combined_early_lint_pass

```rust
macro_rules! declare_combined_early_lint_pass {
    ([$v:vis $name:ident, [$($passes:ident: $constructor:expr,)*]], $methods:tt) => (
        #[allow(non_snake_case)]
        $v struct $name {
            $($passes: $passes,)*
        }
        impl $name {
            $v fn new() -> Self {
                Self {
                    $($passes: $constructor,)*
                }
            }
            $v fn get_lints() -> LintArray {
                let mut lints = Vec::new();
                $(lints.extend_from_slice(&$passes::get_lints());)*
                lints
            }
        }
        impl EarlyLintPass for $name {
            expand_combined_early_lint_pass_methods!([$($passes),*], $methods);
        }
        #[allow(rustc::lint_pass_impl_without_macro)]
        impl LintPass for $name {
            fn name(&self) -> &'static str {
                panic!()
            }
        }
    )
}
```

declare_combined_early_lint_pass宏是生成 `BuiltinCombinedEarlyLintPass` 的主体。这个宏中做了以下工作：

- 生成一个名为 `BuiltinCombinedEarlyLintPass` 的 struct，其中的属性为宏 `early_lint_passes` 提供的 lintpass 的 identifier。
- 实现 `fn new()` `fn name()` 和 `fn get_lints()` 方法。其中 `new()` 调用了 `early_lint_passes` 提供的 lintpass 的 constructor。
- 调用宏 `expand_combined_early_lint_pass_methods`，实现自身的 `check_*` 方法。

通过这个宏，`BuiltinCombinedEarlyLintPass`的定义变为：

```rust
pub struct BuiltinCombinedEarlyLintPass {
            UnusedParens: UnusedParens,
            UnusedBraces: UnusedBraces,
            UnusedImportBraces: UnusedImportBraces,
            UnsafeCode: UnsafeCode,
            AnonymousParameters: AnonymousParameters,
            EllipsisInclusiveRangePatterns: EllipsisInclusiveRangePatterns,
            NonCamelCaseTypes: NonCamelCaseTypes,
            DeprecatedAttr: DeprecatedAttr,
            WhileTrue: WhileTrue,
            NonAsciiIdents: NonAsciiIdents,
            HiddenUnicodeCodepoints: HiddenUnicodeCodepoints,
            IncompleteFeatures: IncompleteFeatures,
            RedundantSemicolons: RedundantSemicolons,
            UnusedDocComment: UnusedDocComment,
}
impl BuiltinCombinedEarlyLintPass {
    pub fn new() -> Self {
        Self {
            UnusedParens: UnusedParens,
            UnusedBraces: UnusedBraces,
            UnusedImportBraces: UnusedImportBraces,
            UnsafeCode: UnsafeCode,
            AnonymousParameters: AnonymousParameters,
            EllipsisInclusiveRangePatterns: EllipsisInclusiveRangePatterns::default(),
            NonCamelCaseTypes: NonCamelCaseTypes,
            DeprecatedAttr: DeprecatedAttr::new(),
            WhileTrue: WhileTrue,
            NonAsciiIdents: NonAsciiIdents,
            HiddenUnicodeCodepoints: HiddenUnicodeCodepoints,
            IncompleteFeatures: IncompleteFeatures,
            RedundantSemicolons: RedundantSemicolons,
            UnusedDocComment: UnusedDocComment,
        }
    }
    pub fn get_lints() -> LintArray {
        let mut lints = Vec::new();
        lints.extend_from_slice(&UnusedParens::get_lints());
        lints.extend_from_slice(&UnusedBraces::get_lints());
        lints.extend_from_slice(&UnusedImportBraces::get_lints());
        lints.extend_from_slice(&UnsafeCode::get_lints());
        lints.extend_from_slice(&AnonymousParameters::get_lints());
        lints.extend_from_slice(&EllipsisInclusiveRangePatterns::get_lints());
        lints.extend_from_slice(&NonCamelCaseTypes::get_lints());
        lints.extend_from_slice(&DeprecatedAttr::get_lints());
        lints.extend_from_slice(&WhileTrue::get_lints());
        lints.extend_from_slice(&NonAsciiIdents::get_lints());
        lints.extend_from_slice(&HiddenUnicodeCodepoints::get_lints());
        lints.extend_from_slice(&IncompleteFeatures::get_lints());
        lints.extend_from_slice(&RedundantSemicolons::get_lints());
        lints.extend_from_slice(&UnusedDocComment::get_lints());
        
        lints
    }
}
impl EarlyLintPass for BuiltinCombinedEarlyLintPass {
    expand_combined_early_lint_pass_methods!([$($passes),*], $methods);
}
#[allow(rustc::lint_pass_impl_without_macro)]
impl LintPass for BuiltinCombinedEarlyLintPass {
    fn name(&self) -> &'static str {
        panic!()
    }
}
```

##### expand_combined_early_lint_pass_methods

```rust
macro_rules! expand_combined_early_lint_pass_methods {
    ($passes:tt, [$($(#[$attr:meta])* fn $name:ident($($param:ident: $arg:ty),*);)*]) => (
        $(fn $name(&mut self, context: &EarlyContext<'_>, $($param: $arg),*) {
            expand_combined_early_lint_pass_method!($passes, self, $name, (context, $($param),*));
        })*
    )
}
```

expand_combined_early_lint_pass_methods宏在 `BuiltinCombinedEarlyLintPass` 中展开所有 `early_lint_methods` 中定义的方法。
通过这个宏，`BuiltinCombinedEarlyLintPass`的定义变为（省略其他定义）：

```rust
impl EarlyLintPass for BuiltinCombinedEarlyLintPass {
    fn check_param(&mut self, context: &EarlyContext<'_>, a: &ast::Param) {
        expand_combined_early_lint_pass_method!($passes, self, $name, (context, $($param),*));
    }
    fn check_ident(&mut self, context: &EarlyContext<'_>, a: &ast::Ident) {
        expand_combined_early_lint_pass_method!($passes, self, $name, (context, $($param),*));
    }
    fn check_crate(&mut self, context: &EarlyContext<'_>, a: &ast::Crate) {
        expand_combined_early_lint_pass_method!($passes, self, $name, (context, $($param),*));
    }
    ...
    
}
```

##### expand_combined_early_lint_pass_method

```rust
macro_rules! expand_combined_early_lint_pass_method {
    ([$($passes:ident),*], $self: ident, $name: ident, $params:tt) => ({
        $($self.$passes.$name $params;)*
    })
}
```

expand_combined_early_lint_pass_method：在展开的`check_*` 函数中调用每一个 `LintPass` 的 `check_*`。
通过这个宏，`BuiltinCombinedEarlyLintPass`的定义变为（省略其他定义）：

```rust
impl EarlyLintPass for BuiltinCombinedEarlyLintPass {
    fn check_param(&mut self, context: &EarlyContext<'_>, a: &ast::Param) {
        self.UnusedParens.check_param(context, a);
        self.UnusedBraces.check_param(context, a);
        self.UnusedImportBraces.check_param(context, a);
        ...
    }
    fn check_ident(&mut self, context: &EarlyContext<'_>, a: &ast::Ident) {
        self.UnusedParens.check_ident(context, a);
        self.UnusedBraces.check_ident(context, a);
        self.UnusedImportBraces.check_ident(context, a);
        ...
    }
    fn check_crate(&mut self, context: &EarlyContext<'_>, a: &ast::Crate) {
        self.UnusedParens.check_crate(context, a);
        self.UnusedBraces.check_crate(context, a);
        self.UnusedImportBraces.check_crate(context, a);
        ...
    }
    ...
    
}
```

#### BuiltinCombinedEarlyLintPass 的最终定义

通过以上宏的展开，`BuiltinCombinedEarlyLintPass`的定义实际为如下形式：

```rust
pub struct BuiltinCombinedEarlyLintPass {
    UnusedParens: UnusedParens,
    UnusedBraces: UnusedBraces,
    ...
}

impl BuiltinCombinedEarlyLintPass{
    pub fn new() -> Self {
        UnusedParens: UnusedParens,
        UnusedBraces: UnusedBraces,
        ...
    }
    
    pub fn get_lints() -> LintArray {
        let mut lints = Vec::new();
        lints.extend_from_slice(&UnusedParens::get_lints());
        lints.extend_from_slice(&UnusedBraces::get_lints());
        ...
        lints
    }
}

impl EarlyLintPass for BuiltinCombinedEarlyLintPass {
    fn check_crates(&mut self, context: &EarlyContext<'_>, a: &ast::Crate){
        self.UnusedParens.check_crates (context, a);
        self.UnusedBraces.check_crates (context, a);
        ...
    }
    fn check_ident(&mut self, context: &EarlyContext<'_>, a: Ident){
        self.UnusedParens.check_ident (context, a);
        self.UnusedBraces.check_ident (context, a);
        ...
    }
    .. 
}
```

通过这个定义，可以在遍历 AST 时使用 `BuiltinCombinedEarlyLintPass` 的 `check_*` 方法实现多个 lintpass 的检查。

## Lint 的进一步优化

基于 CombinedLintPass ，可以对之前提出的 Linter 的设计做进一步优化。
![Linter](./images/combinedlintpass-01.jpg)

这里，可以用 CombinedLintPass 的`check_*` 方法，在 Visitor 遍历 AST 时执行对应的检查。虽然效果与之前一致，但因为宏的关系，所有的 `check_*` 方法和需要执行的 lintpass 都被收集到了一个结构中，也更容易管理。同样的，因为 CombinedLintPass 实际上调用的是每个 lintpass 各自的 check 方法，虽然调用起来可能下图一样很复杂，但因为 lintpass 中定义的 check 方法大部分是由宏生成的空检查，所以也不会造成性能上的损失。
![调用关系](./images/combinedlintpass-02.jpg)

## Lint 的执行流程[WIP]
