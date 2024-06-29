
# 也许是 AO 生态的胜利之匙：以低代码赢得开发者青睐

# Perhaps the Key to Victory for the AO Ecosystem: Winning Over Developers with Low-Code Solutions


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

In fact, AO is not the first to apply actor model to blockchain (or "decentralized infrastructure").

比如，[TON](https://docs.ton.org/learn/overviews/ton-blockchain) 的智能合约就是使用 Actor 模型构建的。

For example, smart contracts on [TON](https://docs.ton.org/learn/overviews/ton-blockchain) are built using the Actor model.

说到 TON，我个人觉得它和 AO 在某些方面颇有相似之处。

Speaking of TON, I personally find it quite similar to AO in some ways.

对于尚未深入了解 Web3 的 Web2 开发者来说，想要迅速理解 AO 或 TON 相对其他“单体区块链”的最大特色，一个方便的抓手是：把运行在它们之上的智能合约（链上程序）想成是“[微服务](https://en.wikipedia.org/wiki/Microservices)”。而 AO 或 TON 是支持这些微服务运行的基础设施，比如 Kafka、Kubernetes 等。

For Web2 developers who have not yet delved deeply into Web3, a convenient way to quickly grasp the most distinctive features of AO or TON, compared to other monolithic blockchains, is to think of the smart contracts (on-chain programs) running on them as [microservices](https://en.wikipedia.org/wiki/Microservices). AO or TON is the infrastructures that support these microservices, such as Kafka, Kubernetes, and so on.


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


回到微服务的拆分问题。为了更好地践行这门艺术，我们需要掌握一些思维工具的使用。DDD 的 “聚合（Aggregate）”就是这样一件你必须拥有的“大杀器”。

我认为聚合是 DDD 在战术层面最为重要的一个概念。它是 DDD 可以在战术设计上应对“软件核心复杂性”的关键。

什么是聚合？聚合在对象之间，特别是实体与实体之间划出边界。一个聚合一定包含且仅包含一个*聚合根*实体，以及可能包含不定数量的*聚合内部实体*（或者叫*非聚合根实体*）。


Returning to the subject of microservice decomposition, to truly master this art, it's crucial to wield certain mental tools adeptly. In DDD, the "Aggregate" concept is comparable to a WMD (weapon of mass destruction)—an essential tool in your armory.

I regard the Aggregate as one of the most significant concepts at the tactical level in DDD. It's key to tackling "core software complexity" within its tactical design framework.

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

--

~~低代码工具，最少我们自信 dddappp，可以帮你做到这一点。~~

~~Low-code tools, and dddappp in particular, we believe, can offer you this capability.~~

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
那么 AO 要如何赢得开发者呢？

We all understand that the competition among public blockchains is essentially a battle to win over application developers.
So how does AO win over developers?

---

即使在工程化更成熟的 Web2 环境中，基于消息通信来实现“最终一致性”，对于许多开发者而言都是不小的挑战。在新生的 AO 平台上开发 Dapp，这个挑战似乎还要更加凸显一些。[这个链接](https://github.com/dddappp/A-AO-Demo?tab=readme-ov-file#an-ao-dapp-development-demo-with-a-low-code-approach)就展示了一个例子。

Even within the more mature engineering landscape of Web2, implementing "eventual consistency" through message communication poses a significant challenge for numerous developers. This hurdle appears to be even more pronounced when developing Dapps on the emerging AO platform. The following [link](https://github.com/dddappp/A-AO-Demo?tab=readme-ov-file#an-ao-dapp-development-demo-with-a-low-code-approach) provides an illustrative example.

---

那么，怎么办呢？当然是向已经获得“大规模采用”的 Web2 学习。学习它的基础设施、开发工具、工程实践，凡此种种。

So, what's the next step? Naturally, it's to learn from Web2, which has already seen mass adoption. This includes understanding its infrastructure, development tools, engineering practices, and the like.

---

## 是不是可以搞搞“AppCU”呢？

AppCU，我指的是 Application-specific Compute Unit。
用 Appchain（[Application-specific blockchain](https://www.coinbase.com/learn/crypto-glossary/what-is-an-application-specific-blockchain-appchain)）做个类比，有助于理解我的意思。

虽然 Lua 和 WASM 的组合很好，但是老实说，短时间内，我无法想象依靠它们能将那些用传统上以 Java、C#、PHP、Python 等语言编写的大型 Web2 互联网应用程序（如亚马逊、淘宝、eBay、Shopee 等）迁移到 AO 上。

正如上面说过的，AO 是个数据协议。理论上，每个人都可以用自己喜欢的语言开发自己的“实现”，接入到 AO 网络，与其他单元进行交互和协作。

我们可以建立一个低代码开发平台，帮助开发人员做到这一点。


## Why not "AppCU"?

AppCU stands for Application-specific Compute Unit here.
An analogy with Appchain ([Application-specific blockchain](https://www.coinbase.com/learn/crypto-glossary/what-is-an-application-specific-blockchain-appchain)) may clarify this concept.

Although the combination of Lua and WASM is promising, frankly, it's hard to envision migrating large-scale Web2 internet applications—like Amazon, Taobao, eBay, Shopee—traditionally written in languages such as Java, C#, PHP, Python, etc., to AO in the short term.

As previously mentioned, AO is a data protocol. In theory, anyone can develop their own implementation using their preferred programming language to integrate with the AO network, interacting and collaborating with other units.

We could establish a low-code development platform to facilitate developers in achieving this transition.



---

我们使用的 DSL 从一开始就支持定义聚合，几乎是随便打开一个 DDDML 模型文件，你都可以看到这个关键字（aggregates）。

The DSL we employ inherently supports the definition of aggregates; this key term (aggregates) is evident in virtually any DDDML model file you examine.

---


