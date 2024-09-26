# 也许是 AO 生态的胜利之匙：以低代码赢得开发者青睐

[English](./WinningOverDevelopersWithLowCodeSolutions.md) | 中文版


是什么阻碍了 Web3 的大规模采用？

很简单，因为值得人们使用的去中心化应用太少了。

基于 Web3 基础设施、开发工具、软件工程实践等方面的现状，很多类型的去中心化应用当前几乎是无法实现的。

在基础设施方面，我认为 AO 的出现填补了其中一部分重大的空白。但是，目前构建大型去中心化应用的工程复杂性，仍然是令人望而生畏的。
这使得我们无法在资源受限的情况下——在事物发展的初始阶段，通常如此——开发出更多样化的、更大规模、往往也意味着更棒、功能更丰富的去中心化应用。

不要相信那些类似“智能合约 / 链上程序应该就是很简单的，没有必要搞得太复杂”之类倒果为因的鬼话！

现实问题并不是“不想”，而是“不能”——臣妾做不到啊。

## 我看 AO

[AO](https://ao.arweave.dev/) 是运行在 [Arweave](https://www.arweave.org/) 上的计算机系统，旨在实现可验证的无限计算能力。

AO，是 Actor Oriented（面向参与者）的简称。顾名思义，这说明运行在 AO 上的去中心化应用需要采用 [Actor 模型](https://en.wikipedia.org/wiki/Actor_mode)为基础的设计和编程方法。 

事实上，AO 并不是最早将 Actor 模型用于区块链（或者说“去中心化基础设施”）的。

比如，[TON](https://docs.ton.org/learn/overviews/ton-blockchain) 的智能合约就是使用 Actor 模型构建的。

说到 TON，我个人觉得它和 AO 在某些方面颇有相似之处。
对于尚未深入了解 Web3 的 Web2 开发者来说，想要迅速理解 AO 或 TON 相对其他“单体区块链（以太坊、Solana、Sui 等）”的最大特色，一个方便的抓手是：把运行在它们之上的智能合约（链上程序）想成是“[微服务](https://en.wikipedia.org/wiki/Microservices)”。而 AO 或 TON 是支持这些微服务运行的基础设施，比如 Kafka、Kubernetes 等。

作为一个 20 多年来主要专注于应用开发的一名资深 [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete) boy，
我个人非常乐见 TON、AO 这样的非单体区块链的出现，并对它们的发展充满期待。
下面我想从一个应用开发者的视角，谈谈我对 AO 的看法，可能很多观点还不太成熟。
也许部分应用开发者会心有戚戚焉，那就足矣。

那么，将 Actor 模型应用于区块链，真的有必要吗？答案是肯定的。看看已经取得“大规模采用”的 Web2 应用，你就会明白。

太多的架构师已经知道如何将 Web2 应用“搞大”：微服务架构（MSA）、事件驱动的架构（EDA）、消息通信机制、最终一致性模型、分片……这些东西，不管叫什么，总是与 Actor 模型共生共存的。其中的一些概念，甚至可以说只是一个事物的不同方面。在下面的行文中，我们不对“微服务”和 Actor 做区分，你可以认为它们是同义词。

今日互联网的繁荣，离不开这些架构师的智慧。他们不断地探索、实践、总结，最终形成了一套完整的工程实践体系。

作为 Web3 基础设施，AO 做的很棒。
最少，AO 作为（我眼中的）当前 Web3 领域的最佳去中心化[消息代理](https://en.wikipedia.org/wiki/Message_broker)，已经展现出巨大的潜力。
我相信传统 Web2 应用的开发者由此可以马上理解其中的重大意义：
倘若没有 [Kafka](https://kafka.apache.org) 或者类 Kafka 的消息代理可用，你能想象现在很多大型的互联网应用“程序要怎么写”吗？


### 难搞的“最终一致性”模型

虽然 Actor 模型在很多方面具有理论上的优势，但是不管是 Actor 模型也好，微服务架构也好，在我看来，更多是开发者为了开发某些应用（特别是大型应用）所不得不承受之“恶”。

让我们用一个简单的例子来向非技术读者说明这一点。假设世界上所有银行都基于一个“世界计算机”来开展业务，而这个世界计算机是一个单体架构的系统。那么，当工商银行的客户“张三”向在招商银行开设账户的“李四”汇款 100 元的时候，开发者可以这样编写转账程序的代码：

1. 开始一个事务（或者说“交易”，它们在英文中同一个词）；
2. 在张三的账户上扣减 100 元；
3. 在李四的账户上增加 100 元；
4. 提交事务。

以上步骤不管哪一步出现问题，比如说第三步，在李四的账户上增加金额，因为某种原因失败了，那么整个操作都会被回滚，就像什么都没有发生过一样。
对了，程序这样写，我们称之为采用“强一致性”模型。

倘若这个世界计算机是个采用 MSA 的系统呢？那么，管理工商银行账户的那个微服务（或者说 Actor）与管理招商银行账户的那个微服务，几乎不太可能是同一个。我们先假设它们确实不是同一个，前者我们称为 Actor ICBC，后者我们称为 Actor CMB。此时，开发者可能需要这样编写转账的代码：

1. Actor ICBC 先记录好以下信息：“张三向李四转账100 元”；Actor ICBC 在张三的账户上扣减 100 元，并向 Actor CMB 发送一条消息：“张三向李四转账100 元”；
2. Actor CMB 收到消息，在李四的账户上增加 100 元，然后向 Actor ICBC 发送一条消息“李四已收到张三汇入的 100 元”；
3. Actor ICBC 收到消息，记录好：“张三向李四转账 100 元，已成功”。

上面只是“一切都好”的过程。但是，如果某个步骤，比如说第二个步骤，“在李四的账户上增加 100 元”，出现了问题，怎么办？


开发者需要针对这个可能发生的问题，编写这样的处理逻辑：

* Actor CMB 向 Actor ICBC 发送一条消息：“张三向李四转账 100 元，处理失败”。  
* Actor ICBC 收到消息，在张三的账户上增加 100 元，并记录：“张三向李四转账 100 元，已失败”。

程序这样写，我们称之为采用最终一致性模型。

以上，非技术读者应该能直观感受到开发单体架构的应用与开发 MSA 应用之间的巨大差异了吧？
要知道，上面所说的转账示例只是一个非常简单的应用而已，如果我们把它称之为应用，而不是功能的话。大型应用里面的功能往往比这样的例子要复杂的太多。


### “这个多大合适？”

采用 MSA 架构一个常见的问题是“这个微服务应该多大？”——或者换句话说，"这个微服务是不是太大了，应该一分为二？”

很不幸，这个问题没有标准答案，它是一门艺术😂。微服务越小，就越容易通过创建新实例并按需移动它们来优化系统。但是，微服务越小，开发人员就越难实施复杂的流程，正如上面展示的那样。

对了，将一个应用拆分为多个微服务，从数据库设计角度看，即所谓的“分片（Sharding）”。微服务架构的最佳实践之一，就是每个微服务仅使用一个属于自己的本地数据库。简单来说，分片允许水平扩展。当数据集变得太大，无法通过传统方式处理时，除了将它们拆分成更小的片段以外，别无他法（来进行扩展）。

回到微服务的拆分问题。为了更好地践行这门艺术，我们需要掌握一些思维工具的使用。
DDD（[领域驱动设计](https://en.wikipedia.org/wiki/Domain-driven_design)）的 “聚合（Aggregate）”就是这样一件你必须拥有的“大杀器”。
我的意思是，它能帮助你摧毁软件设计中的“核心复杂性”。

我认为聚合是 DDD 在战术层面最为重要的一个概念。

什么是聚合？聚合在对象之间，特别是实体与实体之间划出边界。一个聚合一定包含且仅包含一个*聚合根*实体，以及可能包含不定数量的*聚合内部实体*（或者叫*非聚合根实体*）。

我们可以使用聚合这一概念对应用所服务的领域进行分析和建模；然后在编码的时候，就可以按照聚合来切分微服务。
最简单的做法，就是将每个聚合实现为一个微服务。

不过，即使你的手艺再娴熟，这种事情你也不能保证第一次就做对。
这个时候，一件让你可以尽快对建模结果进行验证、不行就推倒重来的工具，对你来说就弥足珍贵了。


### “非得学这个吗？”


还有什么东西可能构成大型 Web2 应用迁移到 AO 生态的障碍？我想谈谈语言和程序运行时的问题。

AO 是一个数据协议。你可以认为它是一套定义 AO 网络中的各个“[单元](https://cookbook_ao.g8way.io/concepts/units.html)”如何实现协作的接口规范。

目前，AO 的官方实现包含了一个基于 WASM 的虚拟机环境，以及一个编译为WASM 的 Lua 运行时环境（ao-lib），旨在简化 AO 进程的开发。

Lua 是一种小而美的语言。

一般认为，Lua 的优势在于它的轻量级和易于嵌入其他语言，这使得它在特定场景（比如游戏开发）中特别有用。

但是，对于开发大型互联网应用来说，Lua 语言并不是主流的选择。大型的互联网应用开发通常倾向于使用如 Java、C#、PHP、Python、JavaScript、Ruby 等语言，因为这些语言提供了更全面的生态系统和工具链，以及更广泛的社区支持。

有人可能要争论，这些语言都可以编译成 WASM 字节码，在 WASM 虚拟机里运行。但是事实上，目前互联网应用采用 WASM 作为后端的运行环境并不是一个主流选择，虽然 WASM 在 Web 前端开发领域的表现很强势。注意，智能合约（链上程序）是 Web3 时代的“新后端”。


## “一般人我不告诉 TA”

我们都知道，公链之争，其实是争夺应用开发者的战争。

我们之前已经讨论了采用微服务架构（或者说 Actor 模型）的优势，以及它为应用开发带来的复杂性。有句话怎么说来着？

> 复杂性不会消失，只会转移。

比如，即使在工程化更成熟的 Web2 环境中，基于消息通信来实现“最终一致性”对于许多开发者而言已经是不小的挑战。
在新生的 AO 平台上开发 Dapp，这个挑战似乎还要更加明显——当然这是完全可以理解的。
[这个链接](https://github.com/dddappp/A-AO-Demo?tab=readme-ov-file#an-ao-dapp-development-demo-with-a-low-code-approach)文章的开篇就展示了一个例子。

那么，在这种情况下 AO 要如何赢得开发者？

当然是继续向已经获得“大规模采用”的 Web2 学习。这不仅包括学习其基础设施，还包括开发方法论、开发工具和软件工程实践等各个方面。

低代码开发平台绝对是 Web3 领域值得大力投入的一个方向。我的意思是，我们可以把应用开发的相当部分的“复杂性”转移给低代码平台。

我首先想要澄清一下 Low-Code（低代码）和 No-Code（无代码）的区别——当然，这只是我的个人看法：

* 低代码是针对专业开发人员的。
    业界对低代码平台应具备的核心功能已达成共识（事实上的标准）。
    底线是它们必须采用 "模型驱动 "的方法。

* 无代码指的是一大类面向 "最终用户 "的工具。
    对于什么是 No-code 业界没有统一标准。
    它们允许用户创建简单的应用程序，如产品广告页、在线问卷调查、个人博客等。
    只要某项工作，以前大家认为需要开发人员才能完成，现在借助某个工具的帮助，可以由普通用户完成了，这个工具就会被称之为 No-code。

那么，我所谈论的低代码平台的“事实上的标准”是什么呢？你可以参考[这里](https://www.dddappp.org/#what-is-a-true-low-code-development-platform)的阐述。

你可能听说过“表单驱动”的低代码平台或者“表格驱动”的低代码平台，但在这里，我特指的是“模型驱动”的低代码平台。你可以将我的描述理解为对“低代码平台”概念的狭义解释。

传统应用的低代码开发平台已经进入了成熟的早期阶段。有人可能会说：“我似乎没有听说过‘模型驱动’的 Web3 低代码开发平台。”
确实，这是一件相对罕见的事物。让我们来分析一下原因。

首先，为什么传统的低代码平台没有进入 Web3 领域？我认为，主要是因为它们所采用的建模范式并不适用于 Web3。

传统的企业平台使用 E-R 模型和/或关系模型。
例如，[OutSystems](https://www.outsystems.com/) 同时使用 E-R 模型和关系模型；
而有些平台则只采用其中一种。E-R 模型和关系模型在概念上是相似的。
这些平台生成的代码可以在传统的企业软件基础设施（如 SQL 数据库）上运行。
但它们很难在 Web3 基础设施如区块链上运行，因为区块链上的“去中心化账本”与 SQL 数据库差异太大。

那么，现有的去中心化应用“低代码平台”表现如何呢？

开发一个真正的低代码平台——尤其是采用模型驱动方法——并非易事。有些人可能会试图回避这项艰巨的工作。
但是，专业低代码平台的核心功能具有其他解决方案无法比拟的独特价值。
例如，“可配置的智能合约模板”可以帮助开发人员更快地复制“现成的代码”，但对于那些创新应用来说，这些模板并无太大用处。
对于平台开发人员来说，用不同的语言（如 Solidity、Move 等）编写和维护一个适用于多个链的“智能合约模板”库也是一个巨大的挑战。
此外，“智能合约”只是应用程序的链上部分，稍微大一些的去中心化应用程序通常还需要链下部分。


### dddappp：真 Web3 低代码开发平台

那么，是否存在一个不投机取巧、勇于直面挑战的“真正的”——采用“模型驱动”方法的——Web3 低代码开发平台？

我非常自豪地宣布，我所在的团队开发的 [dddappp](https://www.dddappp.org) 是一个真正的去中心化应用低代码开发平台。它很可能是目前唯一一个采用“模型驱动”方法的 Web3 低代码开发平台。

那么，dddappp 到底有何独特之处？它为什么可以做到其他平台（最少是暂时）没有做到的事情？

关键是 dddappp 采用的建模范式。我们选择了 DDD 风格的领域模型。

DDD 风格的领域模型是一个相对高层次抽象的 OO（面向对象）模型。
自动化工具可以很容易地将这样的高层次的领域模型映射到低层次的实现模型，如面向对象编程模型、关系数据模型等。

什么是“高层次抽象”？
这么说吧，它尽可能多地帮助你表述你对领域的认知“是什么”，而不是技术细节上解决问题要“怎么做”。


有经验的开发者马上能理解这是一件说起来容易做起来难的事情。
我们能做到这一点，完全是因为机缘巧合，我们在这个领域积累了丰富的经验——我们从 2016 年就开始做这个事情了。
我们甚至写了[一本书](https://item.jd.com/12834017.html)来向开发者们分享我们的经验。

关键在于，我们发明了一种用于领域建模的极具表现力的 DSL，名为 DDDML（“领域驱动设计建模语言”英文的首字母缩写）。
使用它，不仅可以准确地描述领域知识，还可以轻松地将这些模型映射到软件实现代码中。

对了，与其他 "竞争对手 "相比，我们的 DSL 更贴近问题领域和自然语言，我们相信这使得它能够与人工智能（AI）完美结合。


我们自己一直把 DDDML 称为“DDD 原生 DSL”。

还记得我之前提到的来自 DDD 的“聚合”概念吗？
我们使用的 DSL 从一开始就支持定义聚合，打开任何一个 DDDML 模型文件，你几乎都能看到 `aggregates` 这个关键字。

如果你熟悉 DDD 的相关概念，会很容易看明白 DDDML 所描述的模型；
如果你不熟悉，那也不要紧，DDD 既有经典著作的系统性的论述，更有拥趸们与时俱进的实践经验，
只要你愿意“拿来”，它们几乎是唾手可得。


DDD 方法论的强大底蕴常常给我们带来惊喜。
我们在开发传统应用（其后端主要由 Java 或 C# 编写）时，就一直在使用“领域模型驱动”的方法，极大提升了开发效率。
当我们进入 Web3 的新天地后，我们发现，不用给 DDDML 增加太多的东西，就能够使用它来驱动去中心化应用的开发。


### 牛刀小试

在这篇文章的前半部分，我们谈到了使用 AO 开发应用面临的一些挑战。

那么，dddappp 采用的技术方案能真正帮助到 AO 生态的开发者吗？
请看我们最近完成的一个[基于 AO 的概念验证](https://github.com/dddappp/A-AO-Demo)。

在这个演示里面，我们相信有些问题我们已经提供了非常有吸引力的解决方案。
我们演示了如何使用 DSL 定义聚合、值对象、服务（这些都是 DDD 的概念），展示了生成代码的大致样貌。你可以想象一下，如果不用工具，开发人员真的愿意手写这些代码？
特别是，我们还演示了生成的代码如何使用 [SAGA](https://microservices.io/patterns/data/saga.html) 模式优雅地实现“最终一致性”的处理。

我们把这个演示称为 PoC，但是实际上我认为它已经超越了 PoC。因为它现在就可以马上帮助到 AO 生态的开发者。
AO 生态的开发者现在就可以使用它来理清应用的设计思路、生成代码（这些代码最少可以作为实现参考）、提升效率。
从某种程度上来说，这个工具你已经可以说它是一个 MVP（最小可行产品）。
因为 MVP 的定义是，只要能够帮助到最终用户，对最终用户有价值，那就可以称之为 MVP。毕竟，开发者就是低代码工具的最终用户。


如果有经验的应用开发者仔细研究过这个 PoC，他们就完全有理由不再怀疑低代码方法在提升应用开发效率方面的巨大潜力。
毕竟，我们在 AO 生态之外已经多次证明了这一点。
即使不提我们在 Web2 时代使用相同方法开发过的复杂商业应用，单单观察我们在 Move 生态中的实践，也足以让人信服。



我们利用 DSL 解决了 Move（一种静态智能合约语言）缺乏“接口”抽象的限制，帮助开发者轻松实现“依赖注入”，
详情请见[此示例](https://github.com/dddappp/sui-interface-demo)。

我们可以通过简单的声明将 Move 合约拆分成多个包（即“项目”），见[此示例](https://github.com/wubuku/aptos-constantinople)。
需要注意的是，大多数 Move 公链对每次发布的包的大小都有限制。

如果你认为我们分享的只是一些“示例”，我们可能只是在制作一些玩具，那你就大错特错了。

我们深度参与了一些严肃的商业应用的开发（主要集中在 Move 生态）过程，在这个过程中，我们几乎就是一直在“吃自己的狗粮”。
我们可以非常自信地说，目前，至少在后端（我指的是链上合约和链下查询服务，后者有时候被称为 indexer）开发领域，我们兑现了 10 倍开发效率的承诺。


我们甚至基于“低代码”开发“无代码”应用（再啰嗦一遍：无代码工具是面向最终用户的应用）。
我们在 Aptos 新加坡黑客松上构建了一个副产品，叫做 Move Forms，获得了当期第二名的好成绩。
我们会利用“业余时间”持续地构建这个 Web3 原生表单工具。


如果你联系我们，我们可以向你展示更多生产级的案例。我们的案例包括了社交，DeFi，全链游戏等。



不少人可能对低代码平台可以开发的去中心化应用的类型有疑问。
说实话的，我们目前没有发现低代码方式对可开发的应用类型有什么明显的限制。
我们在应用开发过程中，感受更深的是当前 Web3 基础设施的局限性，而非低代码的局限性。


我不知道大家有没有发现一个有趣的现实，就是传统低代码平台，大家会普遍认为它们比较开发企业软件（比如 OA、CRM、ERP 这些），而不适合开发互联网应用；
但从我们展示的内容看，似乎 dddappp 已经突破了这种限制？你的感觉没错。
当初我们之所以在 Web2 时代要做这个事情——基于 DDD 领域模型驱动的低代码平台，这在 Web2 时代是一个非常大胆的尝试，
就是想“让低代码平台可以开发大型互联网应用”。



### “搞搞 AppCU 怎么样？”


虽然 Lua 和 WASM 的组合很好，但是老实说，短时间内，我无法想象依靠它们能将那些用传统上以 Java、C#、PHP、Python 等语言编写的大型 Web2 互联网应用程序（如亚马逊、淘宝、eBay、Shopee 等）迁移到 AO 上。

正如之前所述，AO 是一个数据协议。理论上，任何人都可以使用自己喜欢的编程语言开发自己的“实现”，并接入 AO 网络，与其他单元进行交互和协作。

在 AO 网络中，应用的业务逻辑在计算单元（Compute Units）中执行。
因此，对于应用开发者而言，他们最希望看到的是计算单元在支持的开发栈方面更加多元化和包容。
据我所知，AO 开发者社区已经在这个方向上努力，例如支持在 AO 上运行 EVM 智能合约等。

然而，我认为这个问题也许可以从另一个方向取得突破。我相信 AppCU 是一个好主意。
AppCU，我指的是 Application-specific Compute Unit。
用 Appchain（[Application-specific blockchain](https://www.coinbase.com/learn/crypto-glossary/what-is-an-application-specific-blockchain-appchain)）做个类比，有助于理解我的意思。

如果把计算单元排除在外，AO 的其他部分，从某种程度上来讲，可以看作一个 Web3 版本的 Kafka——一个去中心化的消息代理。
让传统应用的开发者可以使用他们熟练的语言和工具，基于一个类 Kafka 的消息代理，来开发微服务架构的应用——“哈哈，这一套我熟”。


从零开始构建一个 AppCU 对大多数开发者来说可能并不容易，构建一个 Appchain 也同样如此。因此，在这种情况下，一个得心应手的工具是必不可少的。

我想，不必再强调 [Cosmos SDK](https://docs.cosmos.network)（用于构建 Appchain 的工具）在 [Cosmos](https://cosmos.network) 生态发展中所发挥的重要作用了吧？

那些尝试过 Cosmos SDK 的开发者，一定会对这个工具的便利性和强大功能印象深刻。如果 Cosmos SDK 能够做到，那么 AO 生态的开发者社区也没有理由做不到。
不管怎么说，开发一个计算单元比开发一条链总是要简单一些吧？

Cosmos SDK 确实是一个“高效率”工具，但严格来说，它并不是一个低代码平台。我们相信低代码平台在提升开发效率方面有着更大的潜力。


## “AI 会干掉低代码平台吗？”

最后，我想要谈谈一个我回答了无数次的问题：“AI 会干掉低代码平台吗？”

在我看来，AI 近些年取得的巨大进展并没有为复杂软件开发的方法论带来什么本质变化。
即使 AI 参与到复杂应用的开发过程中，它仍然有必要遵循“正确的”方法——就像人一样。

软件工程中每一个层次的抽象都有它的价值。
开发复杂软件第一个正确的“姿势”，就是要先做好业务分析、领域建模。
而使用自然语言无法精确地描述“对领域的认知”，这极大地阻碍了“将其转化为软件代码”的效率。

dddappp 的最独特之处在于它使用的 DSL。正是有了它，dddappp 可以使 AI 可以专注于它最擅长的事情：

* AI 推荐参考模型，并辅助我们迭代模型。
  * 我们可以通过自然语言和 AI 交流，让 AI 帮助我们分析需求、推荐参考模型。AI 拥有海量的知识，这是它们擅长的。
  * AI 将领域模型以 DSL 输出，这样的领域模型（最少语法的正确性）可以使用工具来验证。
  * 如果没有误用 DSL，低代码工具的实现也没有 bug，那么，从模型生成的代码，准确率可以说是 100%。这不是生成式 AI 通过“文字接龙游戏”产生的代码可比的。
  * 低代码工具直接从模型生成可以执行的应用。这个阶段，建模可以先忽略“对象的方法”（也就是操作业务逻辑的细节）。生成的应用马上就可以跑起来。
  * 用户和开发者先确认“数据模型”。如果有问题，反馈给 AI，让 AI 帮助调整模型，低代码工具重新生成应用。
* AI 辅助实现“操作业务逻辑”。
  * 确定模型后，应用开发者在一个个非常特定的上下文里面对业务逻辑进行编码。在这样的一个清晰的上下文，IDE 很容易生成高质量的 prompts 提交给 AI，然后 AI 可以回复准确率很高的代码片段。


所以，我对这个问题的回答是：不。我们认为两者会相得益彰——最少对于 dddappp 如此。
