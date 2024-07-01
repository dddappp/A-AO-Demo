# Perhaps the Key to Victory for the AO Ecosystem: Winning Over Developers with Low-code Solutions


English | [中文版](./WinningOverDevelopersWithLowCodeSolutions_CN.md)


What's holding back the mass adoption of Web3?

Simply put, there are too few decentralized applications (dapps) that are worth using.

Given the current state of Web3 infrastructure, development tools, and software engineering practices, many types of dapps are nearly impossible to implement at present.

In terms of infrastructure, I believe the emergence of AO has filled a significant void. However, the engineering complexity of building large-scale decentralized applications remains daunting.

This complexity prevents us from developing a more diverse array of larger-scale dapps, which often means they would be more impressive and feature-rich, especially with limited resources—as is often the case in the initial stages of things.

Don't fall for the fallacy that "smart contracts/blockchain programs should be simple; there's no need to overcomplicate things!"

Such statements often misrepresent the engineering reality.
The reality is not "I don't want to" but "I can’t".


## AO Through My Eyes

AO is a computing system running on Arweave, aimed at achieving verifiable infinite computational power.

AO stands for Actor Oriented. As the name suggests, this implies that decentralized applications running on AO need to adopt design and programming methods based on the [actor model](https://en.wikipedia.org/wiki/Actor_model).


In fact, AO is not the first to apply actor model to blockchain (or "decentralized infrastructure").

For example, smart contracts on [TON](https://docs.ton.org/learn/overviews/ton-blockchain) are built using the Actor model.

Speaking of TON, I personally find it quite similar to AO in some ways.
For Web2 developers who have not yet delved deeply into Web3, a convenient way to quickly grasp the most distinctive features of AO or TON, compared to other monolithic blockchains, is to think of the smart contracts (on-chain programs) running on them as [microservices](https://en.wikipedia.org/wiki/Microservices). AO or TON is the infrastructures that support these microservices, such as Kafka, Kubernetes, and so on.

As a seasoned [**CRUD**](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete)  boy who has been primarily focused on application development for over two decades,
I am personally thrilled by the emergence of non-monolithic blockchains like TON and AO, and I am filled with anticipation for their development.
From the perspective of an application developer, I'd like to share my thoughts on AO, acknowledging that many of my views may still be nascent.
If some of my fellow application developers find resonance with these thoughts, that would be gratifying.


Is the integration of the Actor model into blockchain technology truly essential? The answer is unequivocally affirmative. One only needs to observe the Web2 applications that have reached "mass adoption" to understand why.

Numerous architects are already versed in making Web2 applications bigger and bigger through strategies such as Microservice Architecture (MSA), Event-Driven Architecture (EDA), messaging mechanisms, and the Eventual Consistency model, Sharding... These things, whatever they may be called, are always symbiotic with the Actor model.  Some of these concepts can even be described as just different aspects of one thing. In the ensuing discussion, we do not differentiate between "Microservice" and "Actor"; they may be regarded as synonymous.

The flourishing state of today's Internet owes much to the ingenuity of its architects. They have persistently explored, experimented, and reflected, culminating in the establishment of a comprehensive framework of engineering practices.


As a piece of Web3 infrastructure, AO has been outstanding.
At the very least, AO has shown great potential as what I consider to be the best decentralized messaging agent in the Web3 space today.
I believe that developers from the traditional Web2 space can immediately grasp the profound implications of this:
Can you imagine how the programming of many of today's large-scale internet applications would be without the availability of [Kafka](https://kafka.apache.org) or Kafka-like message brokers?


### The Tricky "Eventual Consistency" Model

Although the Actor model has theoretical advantages in many respects, whether it's the Actor model or Microservice Architecture (MSA), in my view, they often represent a necessary "evil" that developers must contend with when building certain applications, particularly large-scale ones.


Let's use a simple example to illustrate this point to the non-technical reader. Imagine all the banks in the world operated on a "World Computer," a monolithic system. In this scenario, when a customer from ICBC named "John Doe" transfers $100 to "Jane Doe," who has an account at China Merchants Bank, a developer might code the transfer process like this:

1. Start a transaction;
2. Deduct $100 from John Doe's account;
3. Credit $100 to Jane Doe's account;
4. Commit the transaction.

If any step encounters an issue, such as step 3 where crediting Jane Doe's account fails for some reason, the entire operation would be rolled back, as if nothing had happened.
By the way, when the program is written this way, we say that it adopts the Strong Consistency model.


What if this World Computer were a system using a Microservice Architecture (MSA)? In that case, the microservice managing the ICBC accounts and the one managing the CMB accounts would almost certainly not be the same. Let's assume they are indeed different; the former is called Actor ICBC, and the latter is called Actor CMB. Under these circumstances, a developer might write the code for the transfer process as follows:

1. Actor ICBC records the following information: "John Doe transfers $100 to Jane Doe."; Actor ICBC deducts $100 from John Doe's account and sends a message to Actor CMB: "John Doe transfers $100 to Jane Doe."
2. Upon receiving the message, Actor CMB adds $100 to Jane Doe's account and then sends a message back to Actor ICBC: "Jane Doe has received the $100 transferred by John Doe."
3. Actor ICBC, upon receiving the confirmation, records: "The transfer of $100 from John Doe to Jane Doe was successful."

The above describes the process when everything goes well. But what if there's a problem at some step, such as the step 2, "adds $100 to Jane Doe's account"?

For this possible problem, developers need to write such processing logic:

* Actor CMB sends a message to Actor ICBC: "John Doe's transfer of $100 to Jane Doe has failed."
* Upon receiving the message, Actor ICBC adds $100 back to John Doe's account and records: "John Doe's transfer of $100 to Jane Doe has failed."

When the program is written in this way, we refer to it as adopting the Eventual Consistency model.


With the above comparison, non-technical readers should be able to visualize the huge difference between developing monolithic architecture applications and developing MSA applications, right?
It should be noted that the aforementioned transfer example is merely a very simple application, if we choose to call it an application rather than a feature.
The features within large applications are often much more complex than this example.


### "How big is the right size?"

When adopting a Microservice Architecture (MSA), a common question arises: "How large should a microservice be?" or put another way, "Is this microservice too large and in need of division?"

Unfortunately, there's no definitive answer to this dilemma, it's more of an art😂. The smaller the microservice, the more manageable it becomes to optimize the system by spawning new instances and relocating them as needed. However, the trade-off is that developers may find it more challenging to implement complex processes within tinier services, as illustrated earlier.

Incidentally, decomposing an application into multiple microservices is akin to what is termed "sharding" in the realm of database design. It is considered one of the best practices for MSA that each microservice operates exclusively with its own local database. In essence, sharding facilitates horizontal scaling. When datasets grow too voluminous to manage via conventional methods, the only recourse is to segment them into smaller, more manageable fragments.

Returning to the subject of microservice decomposition, to truly master this art, it's crucial to wield certain mental tools adeptly.
The "Aggregate" concept in DDD ([Domain-Driven Design](https://en.wikipedia.org/wiki/Domain-driven_design)) is akin to a WMD (Weapon of Mass Destruction)—an indispensable weapon in your arsenal.
I mean, it helps you destroy "core complexity" in software design.


I regard the Aggregate as one of the most significant concepts at the tactical level in DDD.

What is an Aggregate? Aggregates establish boundaries among objects, especially between entities. An Aggregate is characterized by a single "Aggregate Root" entity, along with a potentially variable number of "Intra-Aggregate Entities" (or "Non-Aggregate Root Entities").


The concept of Aggregate can be employed to analyze and model the domain that the application serves.
During the coding phase, microservices can be delineated based on these aggregates. 
The most straightforward method is to develop each aggregate as an individual microservice.


However, even if you are adept in your craft, there's no guarantee of getting it right on the first try.
At such times, a tool that enables you to swiftly validate your modeling results—and if necessary, start over—is incredibly precious.


### “Do I really have to learn this?” 


What other factors might pose obstacles to the migration of large Web2 applications to the AO ecosystem? I would like to discuss issues related to programming languages and runtime environments.

AO is a data protocol. Think of it as a set of interface standards that delineate how various [Units](https://cookbook_ao.g8way.io/concepts/units.html) within the AO network collaborate.

The official implementation of AO currently includes a WASM-based virtual machine environment, as well as a Lua runtime environment (ao-lib) that compiles to WASM, designed to allow for the easy development of processes in AO.

Lua is a compact and elegant language.

It is widely recognized that Lua's strengths are its lightweight design and its ease of embedding within other languages, making it particularly valuable in certain contexts, such as game development.

However, Lua is not the preferred language for developing large-scale internet applications. Development of substantial internet applications typically leans towards languages like Java, C#, PHP, Python, JavaScript, Ruby, etc., because these languages provide more extensive ecosystems and toolchains, along with broader community support.

Some might contend that all these languages can be compiled into WASM bytecode and executed within a WASM virtual machine. Yet, in reality, employing WASM as a backend runtime environment for internet applications is not a prevalent choice at present, despite WASM's strong performance in web frontend development. It's important to note that smart contracts (on-chain programs) represent the "new backend" in the Web3 era.


## "I keep this close to the chest"


We all understand that the competition among public blockchains is essentially a battle for the hearts and minds of application developers.

We have previously discussed the benefits of adopting a Microservices Architecture, or the Actor model, and the inherent complexities it introduces to application development. Some complexities are simply unavoidable. How does the saying go?

> Complexity is not reduced, it is shifted.

Even within the more mature engineering landscape of Web2, implementing "eventual consistency" through messaging poses a significant challenge for many developers. 
This challenge seems even more daunting when developing Dapps on the nascent AO platform—understandably so.
The opening of [this linked article](https://github.com/dddappp/A-AO-Demo?tab=readme-ov-file#an-ao-dapp-development-demo-with-a-low-code-approach) provides a case in point.

So, how does AO win over developers in this context?

The answer lies in continuing to learn from Web2, which has already achieved mass adoption. This includes not only its infrastructure but also its development methodologies, tools, and software engineering practices.


Low-code development platforms are undoubtedly an area where Web3 should invest heavily. What I mean is that we can shift a significant portion of the "complexity" of application development to low-code platforms.

First, I'd like to clarify the difference between Low-code and No-code—of course, this is just my personal opinion:

* Low-code is intended for professional developers.
    There is a consensus  (de facto standard)  in the industry on what the core features of a Low-Code platform should have.
    At a minimum, they must adopt a "model-driven" approach.

* No-code refers to a large category of tools for "end-users".
    There is no unified standard for what is considered No-code.
    They allow users to create simple "applications" such as product advertisement pages, online questionnaires, personal blogs, etc.
    Whenever a task, which was previously thought to require a developer, can now be done by a regular user with the help of a tool, that tool will be called No-code.


So, what do I refer to as the "de facto standard" for low-code platforms? You can refer to [this detailed explanation](https://www.dddappp.org/#what-is-a-true-low-code-development-platform) for more information.

You might have heard of "form-driven" or "table-driven" low-code platforms, but here, I am specifically referring to "model-driven" low-code platforms. You can consider my description as a narrow interpretation of the "low-code platform" concept.


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


### dddappp: A Authentic Web3 Low-code Platform

So, is there an authentic Web3 low-code development platform that doesn't cut corners and bravely faces challenges head-on—a platform that truly adopts a "model-driven" approach?

I am immensely proud to announce that [dddappp](https://www.dddappp.org), developed by my team, is a genuine decentralized application low-code development platform. It is likely the only Web3 low-code development platform to date that employs a "model-driven" approach.


So, what exactly sets dddappp apart? Why can it achieve what other platforms (at least for now) have not?

The key lies in the modeling paradigm adopted by dddappp. We have opted for DDD-style domain models.

DDD-style domain models are object-oriented (OO) models at a relatively high level of abstraction.
Automated tools can readily map such high-level domain models to lower-level implementation models, such as object-oriented programming models, relational data models, and so on.


What is "high-level abstraction"?
Put it this way, it assist you in articulating the "what" of your domain knowledge as much as possible, rather than the "how" of solving the problem in technical detail.


Experienced developers will immediately understand that this is easier said than done.
We have been able to achieve this because, by a fortunate coincidence, we have amassed extensive experience in this field—we've been at it since 2016.
We even wrote a [book](https://item.jd.com/12834017.html) to share our insights with other developers.

The key lies in the expressive domain modeling DSL we've invented, named DDDML (Domain-Driven Design Modeling Language).
With it, you can not only precisely describe domain knowledge but also effortlessly map these models to software implementation code.

Moreover, compared to other "competitors", our DSL is closer to the problem domain and natural language, which we believe allows for seamless integration with artificial intelligence.

We have always referred to DDDML as the "native DSL for DDD".

Remember the "Aggregate" concept from DDD we mentioned earlier? The DSL we use inherently supports defining aggregates, and you can find the keyword `aggregates` in almost any DDDML model file you open.

If you're familiar with DDD concepts, you'll easily grasp the models described by DDDML;
if you're not, no worries—DDD is well-documented both in classic literature and through the evolving practical experiences of its advocates.
As long as you're willing to seek them out, they are readily accessible.


The profound foundation of the DDD methodology frequently brings us delightful surprises.
In developing traditional applications (whose backends are primarily written in Java or C#), we have consistently employed a "domain model-driven" approach, which has greatly enhanced our development efficiency.
As we stepped into the new realm of Web3, we found that without needing to make many additions to DDDML, it could be effectively used to drive the development of decentralized applications.


### The First Cut of a Master's Blade

In the first half of this article, we discussed some of the challenges faced when developing applications with AO.

So, can the technical solution adopted by dddappp genuinely assist developers in the AO ecosystem?
Take a look at our recent [AO-based Proof of Concept](https://github.com/dddappp/A-AO-Demo).

In this demonstration, we believe we have provided very compelling solutions to certain issues.
We showed how to use DSL to define aggregates, value objects, and services (all DDD concepts), and what the generated code generally looks like. Can you imagine, without tools, would developers really be willing to manually write this code?
Especially, we also demonstrated how the generated code can elegantly handle "eventual consistency" with the [SAGA](https://microservices.io/patterns/data/saga.html) pattern.

We refer to this demonstration as a PoC, but in reality, I think it has surpassed just being a PoC. It is already capable of immediately assisting developers within the AO ecosystem.
Developers in the AO ecosystem can now use it to clarify their application design ideas, generate code (which at the very least can serve as a reference for implementation), and enhance efficiency.
To some extent, you could already consider this tool as an MVP (Minimum Viable Product).
Because an MVP is defined as something that provides value to the end-users, and as long as it helps them, it can be considered an MVP. After all, developers are the end-users of low-code tools.




Experienced application developers who have thoroughly examined this PoC should no longer harbor any doubts about the immense potential of low-code approaches to enhance app development efficiency.
After all, we have repeatedly validated this point beyond the AO ecosystem.
Even if we set aside our history of developing complex commercial applications with the same methodology during the Web2 era, our current practices within the Move ecosystem are enough to convince anyone.




We have used DSL to overcome the lack of "interface" abstraction in Move, a static smart contract language, facilitating easy "Dependency Injection" for developers;
see [this example](https://github.com/dddappp/sui-interface-demo).

We can split Move contracts into multiple packages (or "projects") with simple declarations, as shown in [this example](https://github.com/wubuku/aptos-constantinople). 
It's important to note that most Sui public chains have size limits for each package released.



If you think that what we've shared are merely "examples," and we might just be creating toys, then you are greatly mistaken.

We have been deeply involved in the development of some serious commercial applications (primarily within the Move ecosystem), where we have consistently been "eating our own dog food."
We can say with confidence that, at present, we have fulfilled our promise of a tenfold increase in development efficiency, especially in the backend area (referring to off-chain contracts and off-chain query services, sometimes known as an "indexer").


We even develop "No-code" applications based on "Low-code" (to reiterate: no-code tools are designed for end-users).
At the Aptos Singapore Hackathon, we created a side project named Move Forms, which secured the second place in the competition.
We plan to continue developing this Web3 native form tool in our "spare time."



If you reach out to us, we can show you more production-level cases, which include social, DeFi, fully on-chain games, among others.



Many people may be curious about the types of dapps that can be developed on low-code platforms.
Frankly, we have not yet encountered any significant limitations on the types of applications that can be developed using the low-code approach.
During the application development process, what we have felt more acutely is the limitations of the current Web3 infrastructure, not the limitations of low-code itself.

I wonder if you have noticed an interesting phenomenon: traditional low-code platforms are generally considered more suitable for developing enterprise software (such as OA, CRM, ERP, etc.), rather than for developing internet applications;
However, from what we have demonstrated, it seems that dddappp has indeed broken through this limitation, and your feeling is correct.
The motivation for doing this in the Web2 era—a DDD domain model-driven low-code platform , which was a very bold attempt in the Web2 era—was to "enable low-code platforms to develop large-scale internet applications".


### "Why not 'AppCU'?"

Although the combination of Lua and WASM is promising, frankly, it's hard to envision migrating large-scale Web2 internet applications—like Amazon, Taobao, eBay, Shopee—traditionally written in languages such as Java, C#, PHP, Python, etc., to AO in the short term.

As previously mentioned, AO is a data protocol. In theory, anyone can develop their own implementation using their preferred programming language to integrate with the AO network, interacting and collaborating with other units.


Within the AO network, the business logic of applications is executed in Compute Units.
Therefore, for application developers, the most desirable aspect is likely the diversity and inclusiveness of the supported development stacks in Compute Units.
I've heard that the AO developer community is already working in this direction, with things like support for running EVM smart contracts on AO.

However, I think there might be another direction for a breakthrough with this issue. I believe AppCU is a good idea.
AppCU stands for Application-specific Compute Unit here.
An analogy with Appchain ([Application-specific blockchain](https://www.coinbase.com/learn/crypto-glossary/what-is-an-application-specific-blockchain-appchain)) may clarify this concept.


If you exclude the compute unit, the other components of AO can, to some extent, be regarded as a Web3 version of Kafka—a decentralized message broker.
This setup allows traditional application developers to use their familiar languages and tools to develop MSA applications based on a Kafka-like message broker—“haha, I know this drill.”


Building an AppCU from scratch can be a challenging task for most developers, and the same goes for constructing an Appchain. Therefore, having the right tools at hand is indispensable in such endeavors.

I suppose there's no need to reiterate the pivotal role that the [Cosmos SDK](https://docs.cosmos.network) (the tool for building Appchains) has played in the growth of the [Cosmos](https://cosmos.network) ecosystem, is there?

Developers who have experimented with the Cosmos SDK must have been struck by its convenience and power. If the Cosmos SDK can achieve this, then there's no reason the AO ecosystem's developer community can't do the same.
Anyway, it's always easier to develop a computing unit than a blockchain, right?

Indeed, the Cosmos SDK is a "high-efficiency" tool, but strictly speaking, it is not a low-code platform. We believe that low-code platforms hold even greater potential for enhancing development efficiency.


## "Will AI eliminate low-code?"

At last, I'd like to address a question I've answered countless times: "Will AI eliminate low-code platforms?"

In my view, the significant advancements AI has made in recent years haven't fundamentally altered the methodologies for complex software development.
Even when AI is integrated into the development process of complex applications, adherence to the "right" methodologies is necessary—just as it is for humans.

Each level of abstraction in software engineering holds its value.
The first correct "stance" in developing complex software is to conduct thorough business analysis and domain modeling.
The inefficiency of using natural language to accurately describe "domain knowledge" greatly hinders the efficiency of "translating it into software code".

The most distinctive aspect of dddappp lies in its use of DSL. It is this feature that allows dddappp to enable AI to concentrate on what it excels at:

* AI suggests reference models and helps us iterate them.
  * Chat with AI in natural language and let it analyze requirements and propose models. AI has a lot of knowledge, which is its advantage.
  * AI produces DSL domain model. The output is validated using the DSL schema.
  * If DSL and tool are correct, code from model is 100% accurate. No word chain game here!
  * Low-code tool creates app from model. Skip "object methods" (operation business logic details) for now. 
  * Run app and verify "data model". If problem, ask AI to modify model and recreate app.
* AI helps implement "operation business logic".
  * After modeling, code logic in specific context. IDE provides high-quality prompts to AI, and AI responds with high-accuracy snippets.

Therefore, my response to this question is: No. We believe that the two will be mutually beneficial—at least that's the case for dddappp.



