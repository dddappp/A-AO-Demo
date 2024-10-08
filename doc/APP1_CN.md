| 标题                 | 描述                                                                           | 作者                     | 应用类型 |
| -------------------- | ------------------------------------------------------------------------------ | ------------------------ | -------- |
| AppCU 低代码开发平台 | 采用领域模型驱动的方式开发 AppCU，显著提升 AO 应用的开发效率并大幅降低复杂性。 | yangjiefeng at gmail.com | 开发工具 |


# 摘要

我们的低代码开发平台支持开发者使用他们熟悉的通用编程语言（我们打算先支持 Java）和工具，
通过构建 AppCU（应用特定计算单元）的方式，快速开发 AO 去中心化应用。


# 动机

AO 生态的繁荣取决于开发者的参与；而开发者的参与取决于基于 AO 可构建的应用的多样性及开发效率。
我们相信 AppCU 为解决这些问题提供了一个全新的思路。

关于 AppCU，可以与 Appchain（应用特定区块链）做个类比来理解这一概念。
更详细的阐述可见[这里](https://github.com/dddappp/A-AO-Demo/blob/main/doc/WinningOverDevelopersWithLowCodeSolutions.md#why-not-appcu)。


# 原理及可实行性

AO 是一个数据协议。可以认为它是一套定义 AO 网络中的各个“[单元](https://cookbook_ao.g8way.io/concepts/units.html)”如何实现协作的接口规范。
目前，AO 的官方实现包含了一个基于 WASM 的虚拟机环境，以及一个编译为WASM 的 Lua 运行时环境（ao-lib），旨在简化 AO 进程的开发。
理论上，任何人都可以使用自己喜好的编程语言开发自己的“实现”，接入 AO 网络，与其他单元进行交互和协作。


在 AO 网络中，应用的业务逻辑在计算单元（Compute Units）中执行。
如果把计算单元排除在外，AO 的其他部分，从某种程度上来讲，可以看作一个去中心化的消息代理系统——你可以看作是“Web3 版本的 Kafka”。
（让传统应用的开发者可以使用他们熟练的语言和工具，基于一个类 Kafka 的消息代理，来开发微服务架构的应用，这是一个极具吸引力的主张。）

所以，从 AO 的本质出发，我们不难判断 AppCU 在技术可行性上没有疑问。
那么，接下来的关键问题是：以低代码方式开发 AppCU 是否可行，以及，它可以在多大程度上提升开发效率。

我们确实很少看到“模型驱动”的去中心化应用的低代码平台。

传统应用的低代码开发平台已经进入了成熟的早期阶段；为什么它们没有进入 Web3 领域？
我们认为，主要是因为它们所采用的建模范式并不适用于去中心化应用的开发。
传统的企业平台使用 E-R 模型和/或关系模型。
例如，[OutSystems](https://www.outsystems.com/) 同时使用 E-R 模型和关系模型；
而有些平台则只采用其中一种。E-R 模型和关系模型在概念上是相似的。
这些平台生成的代码可以在传统的企业软件基础设施（如 SQL 数据库）上运行。
但它们很难在 Web3 基础设施如区块链上运行，因为区块链上的“去中心化账本”与 SQL 数据库差异太大。

所以，问题的关键是建模范式。我们的低代码平台选择了 DDD（领域驱动设计）风格的领域模型。
DDD 领域模型是一个相对高层次抽象的 OO（面向对象）模型。
自动化工具可以很容易地将这样的高层次的领域模型映射到低层次的实现模型，包括但不仅限于面向对象编程模型、关系数据模型等。

这是我们最近完成的一个[低代码开发 AO 去中心化应用的概念验证](https://github.com/dddappp/A-AO-Demo)。

在这个演示里，我们展示了如何使用 DSL 定义聚合、值对象、服务（这些都是 DDD 的概念），以及低代码工具可以生成的 AO Lua 代码的大致样貌。
特别是，我们还展示了生成的代码如何使用 [SAGA](https://microservices.io/patterns/data/saga.html) 模式优雅地实现“最终一致性”的处理。
（大家可以想象一下，如果没有工具的帮助，开发人员真的愿意手动编写这么多代码吗？）

虽然这个概念验证没有演示如何生成（非 Lua 实现的）AppCU，
但是我们确信它已经展示了低代码方式在提升 AO 去中心化应用开发效率上的巨大潜力。


# 参考实现

对于我们采用的低代码方法可以如何帮助开发者解决软件开发的核心复杂性问题、
让他们可以更专注于所服务的领域的业务逻辑的实现，
不用提我们在 Web2 时代使用相同的方法开发过的那些复杂的传统应用，
单单观察我们在 Move 生态中的实践，也足以让人信服。

比如，我们利用 DSL 解决了 Move（作为静态语言）缺乏“接口”抽象的限制，帮助开发者轻松实现“依赖注入”，
详情请见[此示例](https://github.com/dddappp/sui-interface-demo)。

我们可以通过简单的声明将 Move 合约拆分成多个包（即“项目”），见[此示例](https://github.com/wubuku/aptos-constantinople)。
需要注意的是，大多数 Move 公链对每次发布的包的大小都有限制。

在 Move 生态之外，我们还实现了[低代码开发 Solana 应用的 PoC](https://github.com/dddappp/A-Solana-Demo)；
以及[低代码开发 EVM 应用的 PoC](https://github.com/wubuku/hello-mud)。

我们不仅仅是在“制作一些玩具”。我们深度参与了一些严肃的商业应用的开发（主要集中在 Move 生态）过程，在这个过程中，我们一直在“吃自己的狗粮”。
我们可以非常自信地说，至少在后端（链上合约和链下查询服务，后者有时候被称为 indexer）开发领域，我们兑现了 10 倍开发效率的承诺。

我们甚至基于“低代码”开发“无代码”应用（题外话：无代码工具是面向最终用户的应用；而低代码面向专业开发者）。
我们在 Aptos 新加坡黑客松上构建了一个副产品，叫做 Move Forms，获得了当期第二名的好成绩。（我们会利用“业余时间”持续地构建这个 Web3 原生表单工具。）

联系我们，我们可以展示更多生产级的案例。我们的案例包括了社交，DeFi，全链游戏等。


# 所需资源

如果有熟悉 [aoconnect](https://cookbook_ao.g8way.io/guides/aoconnect/installing-connect.html) 实现的伙伴加入，
对我们的项目会有很大帮助。

我们首先会尝试在 AppCU 中可能集成 aocconect，极可能重用 aoconnect 已有的功能；
而不是使用其他语言（我们相对熟悉 Java、C# 等后端“常用”语言）重新实现它们。
在这个过程中，我们可能会发现 aoconnenct 的可改进之处。
我们希望有人可以帮助我们 fork 代码库，进行修改；当然，改进的结果也会反馈给上游的 aoconnect 代码库。

即使最后发现集成 aoconnect 不是一个最佳方案，
我们也可以从他/她那里更快地了解 aoconnect 的实现细节，少走弯路。

