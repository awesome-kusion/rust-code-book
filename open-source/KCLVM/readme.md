# KCL

![license](https://img.shields.io/badge/license-Apache--2.0-green.svg)

Kusion Configuration Language (KCL) is an open source constraint-based record & functional language mainly used in [Kusion Stack](https://kusionstack.io). KCL improves the writing of a large number of complicated configuration data and logic through mature programming language theory and practice, and simplifies and verifies the development and operation of configuration through declarative syntax combined with technical features such as static typing.

## Features

+ **Well-designed**: Independently designed syntax, semantics, runtime and system modules, providing core language elements such as configuration, schema, lambda and rule.
+ **Modeling**: Schema-centric modeling abstraction.
+ **Easy to use**: the language itself covers most configuration and policy functions.
+ **Stability**: Static type system and custom rule constraints.
+ **Scalability**: Configuration block definition ability and rich configuration merge coverage ability.
+ **Automation capabilities**: Rich language-level CRUD API and multi-language API.
+ **High performance**: The language compiler is implemented in Rust and C mainly with LLVM optimizer, supports compilation to native and WASM targets and executes efficiently.
+ **Cloud Native Affinity**: Native support for [OpenAPI](https://github.com/KusionStack/kcl-openapi) and Kubernetes CRD Specs to KCL conversion, support for Kubernetes YAML specification.
+ **Development friendly**: Rich language tools (Lint, Test, Vet, Doc, etc.), [IDE Plugins](https://github.com/KusionStack/vscode-kcl) and [language plugins](https://github.com/KusionStack/kcl-plugin).

## What is it for?

You can use KCL to

+ generate low-level configuration data like JSON, YAML, etc.
+ reduce boilerplate in configuration data with the schema modeling.
+ define schemas with rule constraints for configuration data and validate them automatically.
+ write configuration data separately and merge them using different strategies.
+ organize, simplify, unify and manage large configurations without side effects.
+ define your application delivery and operation ecosystem with [Kusion Stack](https://kusionstack.io).

## Installation

[Download](https://github.com/KusionStack/KCLVM/releases) the latest release from GitHub and add `{install-location}/kclvm/bin` to the environment `PATH`.

## Quick Showcase

`./samples/fib.k` is an example of calculating the Fibonacci sequence.

```kcl
schema Fib:
    n1: int = n - 1
    n2: int = n1 - 1
    n: int
    value: int

    if n <= 1:
        value = 1
    elif n == 2:
        value = 1
    else:
        value = Fib {n: n1}.value + Fib {n: n2}.value

fib8 = Fib {n: 8}.value
```

We can execute the following command to get a YAML output.

```
kcl ./samples/fib.k
```

YAML output

```yaml
fib8: 21
```

## Documentation

Detailed documentation is available at https://kusionstack.io

## Contributing

See [Developing Guide](./docs/dev_guide/1.about_this_guide.md).

## Roadmap

See [KCLVM Roadmap](https://kusionstack.io/docs/governance/intro/roadmap#kclvm-%E8%B7%AF%E7%BA%BF%E8%A7%84%E5%88%92).

## License

[Apache License Version 2.0]
