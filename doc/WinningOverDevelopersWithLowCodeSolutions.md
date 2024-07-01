
# 也许是 AO 生态的胜利之匙：以低代码赢得开发者青睐

# Perhaps the Key to Victory for the AO Ecosystem: Winning Over Developers with Low-code Solutions


[rough-draft]


---

是什么阻碍了 Web3 的大规模采用？

很简单，因为值得人们使用的去中心化应用太少了。

基于 Web3 基础设施、开发工具、软件工程实践等方面的现状，很多类型的去中心化应用当前几乎是无法实现的。

在基础设施方面，我认为 AO 的出现填补了其中一部分重大的空白。但是，目前构建大型去中心化应用的工程复杂性，仍然是令人望而生畏的。
这使得我们无法在资源受限的情况下——在事物发展的初始阶段，通常如此——开发出更多样化的、更大规模、往往也意味着更棒、功能更丰富的去中心化应用。

不要相信那些类似“智能合约 / 链上程序应该就是很简单的，没有必要搞得太复杂”之类倒果为因的鬼话！

现实问题并不是“不想”，而是“不能”——臣妾做不到啊。


What's holding back the mass adoption of Web3?

Simply put, there are too few decentralized applications (dapps) that are worth using.

Given the current state of Web3 infrastructure, development tools, and software engineering practices, many types of dapps are nearly impossible to implement at present.

In terms of infrastructure, I believe the emergence of AO has filled a significant void. However, the engineering complexity of building large-scale decentralized applications remains daunting.

This complexity prevents us from developing a more diverse array of larger-scale dapps, which often means they would be more impressive and feature-rich, especially with limited resources—as is often the case in the initial stages of things.

Don't fall for the fallacy that "smart contracts/blockchain programs should be simple; there's no need to overcomplicate things!"

Such statements often misrepresent the engineering reality.
The reality is not "I don't want to" but "I can’t".

---

[AO](https://ao.arweave.dev/) 是运行在 [Arweave](https://www.arweave.org/) 上的计算机系统，旨在实现可验证的无限计算能力。

AO，是 Actor Oriented（面向参与者）的简称。顾名思义，这说明运行在 AO 上的去中心化应用需要采用 [Actor 模型](https://en.wikipedia.org/wiki/Actor_mode)为基础的设计和编程方法。 

AO is a computing system running on Arweave, aimed at achieving verifiable infinite computational power.

AO stands for Actor Oriented. As the name suggests, this implies that decentralized applications running on AO need to adopt design and programming methods based on the [actor model](https://en.wikipedia.org/wiki/Actor_model).

----

事实上，AO 并不是最早将 Actor 模型用于区块链（或者说“去中心化基础设施”）的。

比如，[TON](https://docs.ton.org/learn/overviews/ton-blockchain) 的智能合约就是使用 Actor 模型构建的。

说到 TON，我个人觉得它和 AO 在某些方面颇有相似之处。

对于尚未深入了解 Web3 的 Web2 开发者来说，想要迅速理解 AO 或 TON 相对其他“单体区块链”的最大特色，一个方便的抓手是：把运行在它们之上的智能合约（链上程序）想成是“[微服务](https://en.wikipedia.org/wiki/Microservices)”。而 AO 或 TON 是支持这些微服务运行的基础设施，比如 Kafka、Kubernetes 等。


In fact, AO is not the first to apply actor model to blockchain (or "decentralized infrastructure").

For example, smart contracts on [TON](https://docs.ton.org/learn/overviews/ton-blockchain) are built using the Actor model.

Speaking of TON, I personally find it quite similar to AO in some ways.

For Web2 developers who have not yet delved deeply into Web3, a convenient way to quickly grasp the most distinctive features of AO or TON, compared to other monolithic blockchains, is to think of the smart contracts (on-chain programs) running on them as [microservices](https://en.wikipedia.org/wiki/Microservices). AO or TON is the infrastructures that support these microservices, such as Kafka, Kubernetes, and so on.

---

我个人非常期待非单体区块链的发展。下面我想从一个应用开发者的视角，谈谈我对 AO 的看法，可能很多观点还不太成熟。
但作为一个 20 多年来主要专注于应用开发的一名资深 [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete) boy，也许部分应用开发者会心有戚戚焉，那就足矣。


Personally, I'm looking forward to the development of non-monolithic blockchains. Below I would like to talk about my views on AO from the perspective of an application developer, and many of my views may be immature.
But as a senior [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete) boy who has been mainly focusing on application development for more than 20 years, maybe some application developers will share my feelings, and then I will be very satisfied.

---

那么，将 Actor 模型应用于区块链，真的有必要吗？答案是肯定的。看看已经取得“大规模采用”的 Web2 应用，你就会明白。


Is the integration of the Actor model into blockchain technology truly essential? The answer is unequivocally affirmative. One only needs to observe the Web2 applications that have reached "mass adoption" to understand why.

---

太多的架构师已经知道如何将 Web2 应用“搞大”：微服务架构（MSA）、事件驱动的架构（EDA）、消息通信机制、最终一致性模型、分片……这些东西，不管叫什么，总是与 Actor 模型共生共存的。其中的一些概念，甚至可以说只是一个事物的不同方面。在下面的行文中，我们不对“微服务”和 Actor 做区分，你可以认为它们是同义词。

Numerous architects are already versed in making Web2 applications bigger and bigger through strategies such as Microservice Architecture (MSA), Event-Driven Architecture (EDA), messaging mechanisms, and the Eventual Consistency model, Sharding... These things, whatever they may be called, are always symbiotic with the Actor model.  Some of these concepts can even be described as just different aspects of one thing. In the ensuing discussion, we do not differentiate between "Microservice" and "Actor"; they may be regarded as synonymous.

---

今日互联网的繁荣，离不开这些架构师的智慧。他们不断地探索、实践、总结，最终形成了一套完整的工程实践体系。

The flourishing state of today's Internet owes much to the ingenuity of its architects. They have persistently explored, experimented, and reflected, culminating in the establishment of a comprehensive framework of engineering practices.

---

作为 Web3 基础设施，AO 做的很棒。
最少，AO 作为（我眼中的）当前 Web3 领域的最佳去中心化消息代理，已经展现出巨大的潜力。

我相信传统 Web2 应用的开发者由此可以马上理解其中的重大意义：

倘若没有 [Kafka](https://kafka.apache.org) 或者类 Kafka 的消息代理可用，你能想象现在很多大型的互联网应用“程序要怎么写”吗？


As a piece of Web3 infrastructure, AO has been outstanding.
At the very least, AO has shown great potential as what I consider to be the best decentralized messaging agent in the Web3 space today.

I believe that developers from the traditional Web2 space can immediately grasp the profound implications of this:

Can you imagine how the programming of many of today's large-scale internet applications would be without the availability of [Kafka](https://kafka.apache.org) or Kafka-like message brokers?


----

虽然 Actor 模型在很多方面具有理论上的优势，但是不管是 Actor 模型也好，微服务架构也好，在我看来，更多是开发者为了开发某些应用（特别是大型应用）所不得不承受之“恶”。

Although the Actor model has theoretical advantages in many respects, whether it's the Actor model or Microservice Architecture (MSA), in my view, they often represent a necessary "evil" that developers must contend with when building certain applications, particularly large-scale ones.

--------

让我们用一个简单的例子来向非技术读者说明这一点。假设世界上所有银行都基于一个“世界计算机”来开展业务，而这个世界计算机是一个单体架构的系统。那么，当工商银行的客户“张三”向在招商银行开设账户的“李四”汇款 100 元的时候，开发者可以这样编写转账程序的代码：

1. 开始一个事务（或者说“交易”，它们在英文中同一个词）；
2. 在张三的账户上扣减 100 元；
3. 在李四的账户上增加 100 元；
4. 提交事务。

以上步骤不管哪一步出现问题，比如说第三步，在李四的账户上增加金额，因为某种原因失败了，那么整个操作都会被回滚，就像什么都没有发生过一样。
对了，程序这样写，我们称之为采用“强一致性”模型。

Let's use a simple example to illustrate this point to the non-technical reader. Imagine all the banks in the world operated on a "World Computer," a monolithic system. In this scenario, when a customer from ICBC named "John Doe" transfers $100 to "Jane Doe," who has an account at China Merchants Bank, a developer might code the transfer process like this:

1. Start a transaction;
2. Deduct $100 from John Doe's account;
3. Credit $100 to Jane Doe's account;
4. Commit the transaction.

If any step encounters an issue, such as step 3 where crediting Jane Doe's account fails for some reason, the entire operation would be rolled back, as if nothing had happened.
By the way, when the program is written this way, we say that it adopts the Strong Consistency model.

--------

倘若这个世界计算机是个采用 MSA 的系统呢？那么，管理工商银行账户的那个微服务（或者说 Actor）与管理招商银行账户的那个微服务，几乎不太可能是同一个。我们先假设它们确实不是同一个，前者我们称为 Actor ICBC，后者我们称为 Actor CMB。此时，开发者可能需要这样编写转账的代码：

1. Actor ICBC 先记录好以下信息：“张三向李四转账100 元”；Actor ICBC 在张三的账户上扣减 100 元，并向 Actor CMB 发送一条消息：“张三向李四转账100 元”；
2. Actor CMB 收到消息，在李四的账户上增加 100 元，然后向 Actor ICBC 发送一条消息“李四已收到张三汇入的 100 元”；
3. Actor ICBC 收到消息，记录好：“张三向李四转账 100 元，已成功”。

上面只是“一切都好”的过程。但是，如果某个步骤，比如说第二个步骤，“在李四的账户上增加 100 元”，出现了问题，怎么办？

What if this World Computer were a system using a Microservice Architecture (MSA)? In that case, the microservice managing the ICBC accounts and the one managing the CMB accounts would almost certainly not be the same. Let's assume they are indeed different; the former is called Actor ICBC, and the latter is called Actor CMB. Under these circumstances, a developer might write the code for the transfer process as follows:

1. Actor ICBC records the following information: "John Doe transfers $100 to Jane Doe."; Actor ICBC deducts 100 yuan from John Doe's account and sends a message to Actor CMB: "John Doe transfers $100 to Jane Doe."
2. Upon receiving the message, Actor CMB adds $100 to Jane Doe's account and then sends a message back to Actor ICBC: "Jane Doe has received the $100 transferred by John Doe."
3. Actor ICBC, upon receiving the confirmation, records: "The transfer of $100 from John Doe to Jane Doe was successful."

The above describes the process when everything goes well. But what if there's a problem at some step, such as the step 2, "adds $100 to Jane Doe's account"?

---

开发者需要针对这个可能发生的问题，编写这样的处理逻辑：

* Actor CMB 向 Actor ICBC 发送一条消息：“张三向李四转账 100 元，处理失败”。  
* Actor ICBC 收到消息，在张三的账户上增加 100 元，并记录：“张三向李四转账 100 元，已失败”。

For this possible problem, developers need to write such processing logic:

*  Actor CMB sends a message to Actor ICBC: "John Doe's transfer of $100 to Jane Doe has failed."
* Upon receiving the message, Actor ICBC adds $100 back to John Doe's account and records: "John Doe's transfer of 100 yuan to Jane Doe has failed."

---


程序这样写，我们称之为采用最终一致性模型。

When the program is written in this way, we refer to it as adopting the Eventual Consistency model.

以上，非技术读者应该能直观感受到开发单体架构的应用与开发 MSA 应用之间的巨大差异了吧？
要知道，上面所说的转账示例只是一个非常简单的应用而已，如果我们把它称之为应用，而不是功能的话。大型应用里面的功能往往比这样的例子要复杂的太多。

With the above comparison, non-technical readers should be able to visualize the huge difference between developing monolithic architecture applications and developing MSA applications, right?
It should be noted that the aforementioned transfer example is merely a very simple application, if we choose to call it an application rather than a feature.
The features within large applications are often much more complex than this example.

---

采用 MSA 架构一个常见的问题是“这个微服务应该多大？”——或者换句话说，"这个微服务是不是太大了，应该一分为二？”

很不幸，这个问题没有标准答案，它是一门艺术😂。微服务越小，就越容易通过创建新实例并按需移动它们来优化系统。但是，微服务越小，开发人员就越难实施复杂的流程，正如上面展示的那样。


When adopting a Microservice Architecture (MSA), a common question arises: "How large should a microservice be?" or put another way, "Is this microservice too large and in need of division?"

Unfortunately, there's no definitive answer to this dilemma, it's more of an art😂. The smaller the microservice, the more manageable it becomes to optimize the system by spawning new instances and relocating them as needed. However, the trade-off is that developers may find it more challenging to implement complex processes within tinier services, as illustrated earlier.


---


对了，将一个应用拆分为多个微服务，从数据库设计角度看，即所谓的“分片（Sharding）”。微服务架构的最佳实践之一，就是每个微服务仅使用一个属于自己的本地数据库。简单来说，分片允许水平扩展。当数据集变得太大，无法通过传统方式处理时，除了将它们拆分成更小的片段以外，别无他法（来进行扩展）。

Incidentally, decomposing an application into multiple microservices is akin to what is termed "sharding" in the realm of database design. It is considered one of the best practices for MSA that each microservice operates exclusively with its own local database. In essence, sharding facilitates horizontal scaling. When datasets grow too voluminous to manage via conventional methods, the only recourse is to segment them into smaller, more manageable fragments.

---


回到微服务的拆分问题。为了更好地践行这门艺术，我们需要掌握一些思维工具的使用。
DDD（[领域驱动设计](https://en.wikipedia.org/wiki/Domain-driven_design)）的 “聚合（Aggregate）”就是这样一件你必须拥有的“大杀器”。
我的意思是，它能帮助你摧毁软件设计中的“核心复杂性”。


Returning to the subject of microservice decomposition, to truly master this art, it's crucial to wield certain mental tools adeptly.
The "Aggregate" concept in DDD ([Domain-Driven Design](https://en.wikipedia.org/wiki/Domain-driven_design)) is akin to a WMD (Weapon of Mass Destruction)—an indispensable weapon in your arsenal.
I mean, it helps you destroy "core complexity" in software design.

---

我认为聚合是 DDD 在战术层面最为重要的一个概念。

什么是聚合？聚合在对象之间，特别是实体与实体之间划出边界。一个聚合一定包含且仅包含一个*聚合根*实体，以及可能包含不定数量的*聚合内部实体*（或者叫*非聚合根实体*）。

I regard the Aggregate as one of the most significant concepts at the tactical level in DDD.

What is an Aggregate? Aggregates establish boundaries among objects, especially between entities. An Aggregate is characterized by a single "Aggregate Root" entity, along with a potentially variable number of "Intra-Aggregate Entities" (or "Non-Aggregate Root Entities").


---

我们可以使用聚合这一概念对应用所服务的领域进行分析和建模；然后在编码的时候，就可以按照聚合来切分微服务。
最简单的做法，就是将每个聚合实现为一个微服务。

The concept of Aggregate can be employed to analyze and model the domain that the application serves.
During the coding phase, microservices can be delineated based on these aggregates. 
The most straightforward method is to develop each aggregate as an individual microservice.

---

不过，即使你的手艺再娴熟，这种事情你也不能保证第一次就做对。
这个时候，一件让你可以尽快对建模结果进行验证、不行就推倒重来的工具，对你来说就弥足珍贵了。

However, even if you are adept in your craft, there's no guarantee of getting it right on the first try.
At such times, a tool that enables you to swiftly validate your modeling results—and if necessary, start over—is incredibly precious.


---

还有什么东西可能构成大型 Web2 应用迁移到 AO 生态的障碍？我想谈谈语言和程序运行时的问题。

AO 是一个数据协议。你可以认为它是一套定义 AO 网络中的各个“[单元](https://cookbook_ao.g8way.io/concepts/units.html)”如何实现协作的接口规范。

目前，AO 的官方实现包含了一个基于 WASM 的虚拟机环境，以及一个编译为WASM 的 Lua 运行时环境（ao-lib），旨在简化 AO 进程的开发。

Lua 是一种小而美的语言。

一般认为，Lua 的优势在于它的轻量级和易于嵌入其他语言，这使得它在特定场景（比如游戏开发）中特别有用。

但是，对于开发大型互联网应用来说，Lua 语言并不是主流的选择。大型的互联网应用开发通常倾向于使用如 Java、C#、PHP、Python、JavaScript、Ruby 等语言，因为这些语言提供了更全面的生态系统和工具链，以及更广泛的社区支持。

有人可能要争论，这些语言都可以编译成 WASM 字节码，在 WASM 虚拟机里运行。但是事实上，目前互联网应用采用 WASM 作为后端的运行环境并不是一个主流选择，虽然 WASM 在 Web 前端开发领域的表现很强势。注意，智能合约（链上程序）是 Web3 时代的“新后端”。


What other factors might pose obstacles to the migration of large Web2 applications to the AO ecosystem? I would like to discuss issues related to programming languages and runtime environments.

AO is a data protocol. Think of it as a set of interface standards that delineate how various [Units](https://cookbook_ao.g8way.io/concepts/units.html) within the AO network collaborate.

The official implementation of AO currently includes a WASM-based virtual machine environment, as well as a Lua runtime environment (ao-lib) that compiles to WASM, designed to allow for the easy development of processes in AO.

Lua is a compact and elegant language.

It is widely recognized that Lua's strengths are its lightweight design and its ease of embedding within other languages, making it particularly valuable in certain contexts, such as game development.

However, Lua is not the preferred language for developing large-scale internet applications. Development of substantial internet applications typically leans towards languages like Java, C#, PHP, Python, JavaScript, Ruby, etc., because these languages provide more extensive ecosystems and toolchains, along with broader community support.

Some might contend that all these languages can be compiled into WASM bytecode and executed within a WASM virtual machine. Yet, in reality, employing WASM as a backend runtime environment for internet applications is not a prevalent choice at present, despite WASM's strong performance in web frontend development. It's important to note that smart contracts (on-chain programs) represent the "new backend" in the Web3 era.





---

我们都知道，公链之争，其实是争夺应用开发者的战争。

我们之前已经讨论了采用微服务架构（或者说 Actor 模型）的优势，以及它为应用开发带来的复杂性。有些复杂性是不可避免的。

比如，即使在工程化更成熟的 Web2 环境中，基于消息通信来实现“最终一致性”对于许多开发者而言已经是不小的挑战。
在新生的 AO 平台上开发 Dapp，这个挑战似乎还要更加明显——当然这是完全可以理解的。
[这个链接](https://github.com/dddappp/A-AO-Demo?tab=readme-ov-file#an-ao-dapp-development-demo-with-a-low-code-approach)文章的开篇就展示了一个例子。

那么，在这种情况下 AO 要如何赢得开发者？

当然是继续向已经获得“大规模采用”的 Web2 学习。这不仅包括学习其基础设施，还包括开发方法论、开发工具和软件工程实践等各个方面。


We all understand that the competition among public blockchains is essentially a battle for the hearts and minds of application developers.

We have previously discussed the benefits of adopting a microservices architecture, or the Actor model, and the inherent complexities it introduces to application development. Some complexities are simply unavoidable.

Even within the more mature engineering landscape of Web2, implementing "eventual consistency" through messaging poses a significant challenge for many developers. 
This challenge seems even more daunting when developing Dapps on the nascent AO platform—understandably so.
The opening of [this linked article](https://github.com/dddappp/A-AO-Demo?tab=readme-ov-file#an-ao-dapp-development-demo-with-a-low-code-approach) provides a case in point.

So, how does AO win over developers in this context?

The answer lies in continuing to learn from Web2, which has already achieved mass adoption. This includes not only its infrastructure but also its development methodologies, tools, and software engineering practices.

---

低代码开发平台绝对是 Web3 领域值得大力投入的一个方向。

我首先想要澄清一下 Low-Code（低代码）和 No-Code（无代码）的区别——当然，这只是我的个人看法：

* 低代码是针对专业开发人员的。
    业界对低代码平台应具备的核心功能已达成共识（事实上的标准）。
    底线是它们必须采用 "模型驱动 "的方法。

* 无代码指的是一大类面向 "最终用户 "的工具。
    对于什么是 No-code 业界没有统一标准。
    它们允许用户创建简单的应用程序，如产品广告页、在线问卷调查、个人博客等。
    只要某项工作，以前大家认为需要开发人员才能完成，现在借助某个工具的帮助，可以由普通用户完成了，这个工具就会被称之为 No-code。


Low-code development platforms are undoubtedly an area where Web3 should invest heavily.

First, I'd like to clarify the difference between Low-code and No-code—of course, this is just my personal opinion:

* Low-code is intended for professional developers.
    There is a consensus  (de facto standard)  in the industry on what the core features of a Low-Code platform should have.
    At a minimum, they must adopt a "model-driven" approach.

* No-code refers to a large category of tools for "end-users".
    There is no unified standard for what is considered No-code.
    They allow users to create simple "applications" such as product advertisement pages, online questionnaires, personal blogs, etc.
    Whenever a task, which was previously thought to require a developer, can now be done by a regular user with the help of a tool, that tool will be called No-code.


---

那么，我所谈论的低代码平台的“事实上的标准”是什么呢？你可以参考[这里](https://www.dddappp.org/#what-is-a-true-low-code-development-platform)的阐述。

你可能听说过“表单驱动”的低代码平台或者“表格驱动”的低代码平台，但在这里，我特指的是“模型驱动”的低代码平台。你可以将我的描述理解为对“低代码平台”概念的狭义解释。


So, what do I refer to as the "de facto standard" for low-code platforms? You can refer to [this detailed explanation](https://www.dddappp.org/#what-is-a-true-low-code-development-platform) for more information.

You might have heard of "form-driven" or "table-driven" low-code platforms, but here, I am specifically referring to "model-driven" low-code platforms. You can consider my description as a narrow interpretation of the "low-code platform" concept.


---


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


Traditional low-code development platforms for conventional applications have entered the early stages of maturity. Some might say, "I haven't heard of a 'model-driven' Web3 low-code development platform."
Indeed, such platforms are relatively rare. Let's delve into the reasons.


Firstly, why haven't traditional low-code platforms penetrated the Web3 domain? I believe it's primarily because the modeling paradigms they utilize are not suitable for Web3.

Traditional enterprise platforms employ E-R models and/or relational models.
For example, [OutSystems](https://www.outsystems.com/) uses both E-R models and relational models; some platforms use only one of them. E-R modeling and relational modeling have similar concepts.
The code generated by these platforms can operate on conventional enterprise software infrastructures, like SQL databases.
However, they struggle to function on Web3 infrastructures such as blockchains, where "decentralized ledgers" differ fundamentally from SQL databases.


So, how do the existing decentralized application "low-code platforms" perform?

Developing an authentic low-code platform—particularly one that adopts a model-driven approach—is no simple feat. Some may attempt to shirk this arduous task.
Yet, the core features of a professional low-code platform offer unique values unmatched by other solutions.
For instance, "configurable smart contract templates" can expedite developers' ability to replicate "ready-made code," but they are of little use for innovative applications.
For platform developers, composing and maintaining a library of "smart contract templates" in various languages (such as Solidity, Move, etc.) suitable for multiple chains presents a significant challenge. 
Additionally, the "smart contract" is only the on-chain part of an application; larger decentralized applications usually require an off-chain part.

---

那么，是否存在一个不投机取巧、勇于直面挑战的“真正的”——采用“模型驱动”方法的——Web3 低代码开发平台？

我非常自豪地宣布，我所在的团队开发的 [dddappp](https://www.dddappp.org) 是一个真正的去中心化应用低代码开发平台。它很可能是目前唯一一个采用“模型驱动”方法的 Web3 低代码开发平台。

So, is there an authentic Web3 low-code development platform that doesn't cut corners and bravely faces challenges head-on—a platform that truly adopts a "model-driven" approach?

I am immensely proud to announce that [dddappp](https://www.dddappp.org), developed by my team, is a genuine decentralized application low-code development platform. It is likely the only Web3 low-code development platform to date that employs a "model-driven" approach.

---

那么，dddappp 到底有何独特之处？它为什么可以做到其他平台（最少是暂时）没有做到的事情？

关键是 dddappp 采用的建模范式。我们选择了 DDD 风格的领域模型。

DDD 风格的领域模型是一个相对高层次抽象的 OO（面向对象）模型。
自动化工具可以很容易地将这样的高层次的领域模型映射到低层次的实现模型，如面向对象编程模型、关系数据模型等。


So, what exactly sets dddappp apart? Why can it achieve what other platforms (at least for now) have not?

The key lies in the modeling paradigm adopted by dddappp. We have opted for DDD-style domain models.

DDD-style domain models are object-oriented (OO) models at a relatively high level of abstraction.
Automated tools can readily map such high-level domain models to lower-level implementation models, such as object-oriented programming models, relational data models, and so on.

---

什么是“高层次抽象”？
这么说吧，它尽可能多地帮助你表述你对领域的认知“是什么”，而不是技术细节上解决问题要“怎么做”。


What is "high-level abstraction"?
Put it this way, it assist you in articulating the "what" of your domain knowledge as much as possible, rather than the "how" of solving the problem in technical detail.


---


有经验的开发者马上能理解这是一件说起来容易做起来难的事情。
我们能做到这一点，完全是因为机缘巧合，我们在这个领域积累了丰富的经验——我们从 2016 年就开始做这个事情了。
我们甚至写了[一本书](https://item.jd.com/12834017.html)来向开发者们分享我们的经验。

关键在于，我们发明了一种用于领域建模的极具表现力的 DSL，名为 DDDML（“领域驱动设计建模语言”英文的首字母缩写）。
使用它，不仅可以准确地描述领域知识，还可以轻松地将这些模型映射到软件实现代码中。

对了，与其他 "竞争对手 "相比，我们的 DSL 更贴近问题领域和自然语言，我们相信这使得它能够与人工智能（AI）完美结合。


Experienced developers will immediately understand that this is easier said than done.
We have been able to achieve this because, by a fortunate coincidence, we have amassed extensive experience in this field—we've been at it since 2016.
We even wrote a [book](https://item.jd.com/12834017.html) to share our insights with other developers.

The key lies in the expressive domain modeling DSL we've invented, named DDDML (Domain-Driven Design Modeling Language).
With it, you can not only precisely describe domain knowledge but also effortlessly map these models to software implementation code.

Moreover, compared to other "competitors", our DSL is closer to the problem domain and natural language, which we believe allows for seamless integration with artificial intelligence.


---


我们自己一直把 DDDML 称为“DDD 原生 DSL”。

还记得我之前提到的来自 DDD 的“聚合”概念吗？
我们使用的 DSL 从一开始就支持定义聚合，打开任何一个 DDDML 模型文件，你几乎都能看到 `aggregates` 这个关键字。


We have always referred to DDDML as the "native DSL for DDD".

Remember the "Aggregate" concept from DDD we mentioned earlier? The DSL we use inherently supports defining aggregates, and you can find the keyword `aggregates` in almost any DDDML model file you open.


---


如果你熟悉 DDD 的相关概念，会很容易看明白 DDDML 所描述的模型；
如果你不熟悉，那也不要紧，DDD 既有经典著作的系统性的论述，更有拥趸们与时俱进的实践经验，
只要你愿意“拿来”，它们几乎是唾手可得。

If you're familiar with DDD concepts, you'll easily grasp the models described by DDDML;
if you're not, no worries—DDD is well-documented both in classic literature and through the evolving practical experiences of its advocates.
As long as you're willing to seek them out, they are readily accessible.


---


DDD 方法论的强大底蕴常常给我们带来惊喜。
我们在开发传统应用（其后端主要由 Java 或 C# 编写）时，就一直在使用“领域模型驱动”的方法，极大提升了开发效率。
当我们进入 Web3 的新天地后，我们发现，不用给 DDDML 增加太多的东西，就能够使用它来驱动去中心化应用的开发。


The profound foundation of the DDD methodology frequently brings us delightful surprises.
In developing traditional applications (whose backends are primarily written in Java or C#), we have consistently employed a "domain model-driven" approach, which has greatly enhanced our development efficiency.
As we stepped into the new realm of Web3, we found that without needing to make many additions to DDDML, it could be effectively used to drive the development of decentralized applications.



---

那么，dddappp 采用的技术方案能真正帮助到 AO 生态的开发者吗？
请看我们最近完成的一个[基于 AO 的概念验证](https://github.com/dddappp/A-AO-Demo)。


在这篇文章的前半部分，我们谈到了使用 AO 开发应用面临的一些挑战。
在这个演示里面，我们相信有些问题我们已经提供了非常有吸引力的解决方案。
我们演示了如何使用 DSL 定义聚合、值对象、服务（这些都是 DDD 的概念），展示了生成代码的大致样貌。你可以想象一下，如果不用工具，开发人员真的愿意手写这些代码？
特别是，我们还演示了生成的代码如何使用 [SAGA](https://microservices.io/patterns/data/saga.html) 模式优雅地实现“最终一致性”的处理。

我们把这个演示称为 PoC，但是实际上我认为它已经超越了 PoC。因为它现在就可以马上帮助到 AO 生态的开发者。
AO 生态的开发者现在就可以使用它来理清应用的设计思路、生成代码（这些代码最少可以作为实现参考）、提升效率。
从某种程度上来说，这个工具你已经可以说它是一个 MVP（最小可行产品）。
因为 MVP 的定义是，只要能够帮助到最终用户，对最终用户有价值，那就可以称之为 MVP。毕竟，开发者就是低代码工具的最终用户。


So, can the technical solution adopted by dddappp genuinely assist developers in the AO ecosystem?
Take a look at our recent [AO-based Proof of Concept](https://github.com/dddappp/A-AO-Demo).

In the first half of this article, we discussed some of the challenges faced when developing applications with AO.
In this demonstration, we believe we have provided very compelling solutions to certain issues.
We showed how to use DSL to define aggregates, value objects, and services (all DDD concepts), and what the generated code generally looks like. Can you imagine, without tools, would developers really be willing to manually write this code?
Especially, we also demonstrated how the generated code can elegantly handle "eventual consistency" with the [SAGA](https://microservices.io/patterns/data/saga.html) pattern.

We refer to this demonstration as a PoC, but in reality, I think it has surpassed just being a PoC. It is already capable of immediately assisting developers within the AO ecosystem.
Developers in the AO ecosystem can now use it to clarify their application design ideas, generate code (which at the very least can serve as a reference for implementation), and enhance efficiency.
To some extent, you could already consider this tool as an MVP (Minimum Viable Product).
Because an MVP is defined as something that provides value to the end-users, and as long as it helps them, it can be considered an MVP. After all, developers are the end-users of low-code tools.

---


我相信，大多数经验丰富的应用开发者都会认同这个 PoC 的说服力：模型驱动的低代码方式确实能解决去中心化应用开发者的“痛点”。

我们之前已经一次又一次地证明了这一点。

我们利用 DSL 解决了 Move（一种静态智能合约语言）缺乏“接口”抽象的限制，帮助开发者轻松实现“依赖注入”，
详情请见[此示例](https://github.com/dddappp/sui-interface-demo)。

我们可以通过简单的声明将 Move 合约拆分成多个包（即“项目”），见[此示例](https://github.com/wubuku/aptos-constantinople)。
需要注意的是，大多数 Move 公链对每次发布的包的大小都有限制。



I believe that most experienced application developers will agree that this PoC is very convincing: the model-driven low-code approach can indeed solve the "pain points" of dapp developers. As we have repeatedly proven.

We have used DSL to overcome the lack of "interface" abstraction in Move, a static smart contract language, facilitating easy "Dependency Injection" for developers;
see [this example](https://github.com/dddappp/sui-interface-demo).

We can split Move contracts into multiple packages (or "projects") with simple declarations, as shown in [this example](https://github.com/wubuku/aptos-constantinople). 
It's important to note that most Sui public chains have size limits for each package released.

---

如果你认为我们分享的只是一些“示例”，我们可能只是在制作一些玩具，那你就大错特错了。

我们深度参与了一些严肃的商业应用的开发（主要集中在 Move 生态）过程，在这个过程中，我们几乎就是一直在“吃自己的狗粮”。
我们可以非常自信地说，目前，至少在后端（我指的是链下合约和链下查询服务，后者有时候被称为 indexer）开发领域，我们兑现了 10 倍开发效率的承诺。

如果你联系我们，我们可以向你展示更多生产级的案例。


If you think that what we've shared are merely "examples," and we might just be creating toys, then you are greatly mistaken.

We have been deeply involved in the development of some serious commercial applications (primarily within the Move ecosystem), where we have consistently been "eating our own dog food."
We can say with confidence that, at present, we have fulfilled our promise of a tenfold increase in development efficiency, especially in the backend area (referring to off-chain contracts and off-chain query services, sometimes known as an "indexer").

If you reach out to us, we can show you more production-level cases.


---

## 是不是可以搞搞“AppCU”呢？

## Why not "AppCU"?


虽然 Lua 和 WASM 的组合很好，但是老实说，短时间内，我无法想象依靠它们能将那些用传统上以 Java、C#、PHP、Python 等语言编写的大型 Web2 互联网应用程序（如亚马逊、淘宝、eBay、Shopee 等）迁移到 AO 上。

正如之前所述，AO 是一个数据协议。理论上，任何人都可以使用自己喜欢的编程语言开发自己的“实现”，并接入 AO 网络，与其他单元进行交互和协作。

在 AO 网络中，应用的业务逻辑在计算单元（Compute Units）中执行。
因此，对于应用开发者而言，他们最希望看到的是计算单元在支持的开发栈方面更加多元化和包容。
据我所知，AO 开发者社区已经在这个方向上努力，例如支持在 AO 上运行 EVM 智能合约等。

然而，我认为这个问题也许可以从另一个方向取得突破。我相信 AppCU 是一个好主意。
AppCU，我指的是 Application-specific Compute Unit。
用 Appchain（[Application-specific blockchain](https://www.coinbase.com/learn/crypto-glossary/what-is-an-application-specific-blockchain-appchain)）做个类比，有助于理解我的意思。



Although the combination of Lua and WASM is promising, frankly, it's hard to envision migrating large-scale Web2 internet applications—like Amazon, Taobao, eBay, Shopee—traditionally written in languages such as Java, C#, PHP, Python, etc., to AO in the short term.

As previously mentioned, AO is a data protocol. In theory, anyone can develop their own implementation using their preferred programming language to integrate with the AO network, interacting and collaborating with other units.


Within the AO network, the business logic of applications is executed in Compute Units.
Therefore, for application developers, the most desirable aspect is likely the diversity and inclusiveness of the supported development stacks in Compute Units.
I've heard that the AO developer community is already working in this direction, with things like support for running EVM smart contracts on AO.

However, I think there might be another direction for a breakthrough with this issue. I believe AppCU is a good idea.
AppCU stands for Application-specific Compute Unit here.
An analogy with Appchain ([Application-specific blockchain](https://www.coinbase.com/learn/crypto-glossary/what-is-an-application-specific-blockchain-appchain)) may clarify this concept.


---

从零开始构建一个 AppCU 对大多数开发者来说可能并不容易，构建一个 Appchain 也同样如此。因此，在这种情况下，一个得心应手的工具是必不可少的。

我想，不必再强调 [Cosmos SDK](https://docs.cosmos.network)（用于构建 Appchain 的工具）在 [Cosmos](https://cosmos.network) 生态发展中所发挥的重要作用了吧？

那些尝试过 Cosmos SDK 的开发者，一定会对这个工具的便利性和强大功能印象深刻。如果 Cosmos SDK 能够做到，那么 AO 生态的开发者社区也没有理由做不到。

Cosmos SDK 确实是一个“高效率”工具，但严格来说，它并不是一个低代码平台。我们相信低代码平台在提升开发效率方面有着更大的潜力。


Building an AppCU from scratch can be a challenging task for most developers, and the same goes for constructing an Appchain. Therefore, having the right tools at hand is indispensable in such endeavors.

I suppose there's no need to reiterate the pivotal role that the [Cosmos SDK](https://docs.cosmos.network) (the tool for building Appchains) has played in the growth of the [Cosmos](https://cosmos.network) ecosystem, is there?

Developers who have experimented with the Cosmos SDK must have been struck by its convenience and power. If the Cosmos SDK can achieve this, then there's no reason the AO ecosystem's developer community can't do the same.

Indeed, the Cosmos SDK is a "high-efficiency" tool, but strictly speaking, it is not a low-code platform. We believe that low-code platforms hold even greater potential for enhancing development efficiency.


---



