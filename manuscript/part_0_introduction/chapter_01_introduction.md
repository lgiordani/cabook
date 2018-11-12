# Introduction

## On methodologies

This book is about a software design methodology. A methodology is a set of guidelines that help you reach your goal effectively, thus avoiding to waste time, implement short-sighted solutions, or in general rediscover the wheel again and again.

Other professionals around the world face problems and try to solve them, sometimes succeeding, sometimes failing. Some of those people, after many failures, and having discovered a good way to solve a problem, decide to share their experience, and this sharing usually takes the form of a "best practices" post on a blog, or talk at a conference. We also speak of _patterns_[^design-patterns-book], which are a more formalised version of it, and _anti-patterns_, when it comes to advice about what not to do and why it is better to avoid a certain solution.

[^design-patterns-book]: from the seminal book "Design Patterns: Elements of Reusable Object-Oriented Software" by Gamma, Vlissides, Johnson, and Helm.

Often, when the best practices encompass a wide scope, they are formalised and given the name of _methodology_. The name shows that the purpose of a methodology is that of conveying a method, more than a specific solution to a problem. The very nature of methodologies, thus, makes them lose the connection with specific cases, in favour of a wider and more generic approach to the subject matter.

This also means that applying methodologies without thinking is extremely dangerous. Doing so shows that one didn't grasp the nature of a methodology, which as I said it to help to find a solution and not to provide it.

This is why the main advice I have to give is: be reasonable. I want to give it at the very beginning of the book because this is how I'd like you to approach this work of mine. Try to understand why a methodology suggests a solution and adopt it if it fits your need.

The clean architecture, for example, pushes abstraction to its limits. One of the main concepts is that you should isolate parts of your system as much as possible, to be able to replace them without affecting the rest. This requires a lot of abstraction layers, which might affect the performances of the system, and which definitely lead to higher initial development effort. You might consider these shortcomings unacceptable, or perhaps be forced to sacrifice cleanliness in favour of execution speed, as you cannot afford wasting resources.

In these cases, break the rules. You are always free to keep the parts you consider good and discard the rest, but if you do this having understood the reason behind the methodology you will also be more aware of the reason that makes you do something different. My advice is to keep track of such reasons, either in design documents or simply in code comments, as a future reference for you or for any other programmer who might be surprised by a "wrong" solution and be tempted to fix it.

I will try as much as possible to give reasons for the proposed solutions, so you might judge if those reasons are valid in your case, but in general let's consider whatever I say as a possible contribution to your job, and definitely not as an attempt to dictate THE best way to do it.

Spoiler alert: there is no such a thing.

## What is a software architecture?

Every production system, be it a software, a mechanical device, or a simple procedure, is made of components and connections between them. The purpose of the connections is to use the output of some components as inputs of other components, in order to perform a certain action or set of actions.

Given a process, the architecture specifies which components are part of an implementation and how they are interconnected.

A simple example is the process of writing a document. The process, in this case, is the conversion of a set of ideas and sentences into a written text, and it can have multiple implementations. A very simple one is when someone writes with a pen on a sheet of paper, but it might become more complex if we add someone who is writing what another person dictates, multiple proof readers who can send back the text with corrections, and a designer who curates the visual rendering of the text. In both cases the process is the same, and the nature of inputs (ideas, sentences) and outputs (a document or a book) doesn't change. The different architecture, however, can greatly affect the quality of the output, or the speed with which it is produced.

An architecture can have multiple granularities, which are the "zoom level" we use to look at the components and their connections. The first level is the one that describes the whole process as a black box with inputs and outputs. At this level we are not even concerned with components, we don't know what's inside the system and how it works. We only know what it does.

As you zoom in, you start discovering the details of the architecture, that is, which components are in the formerly black box and how they are connected. These components are in turn black boxes, and you don't want to know specifically how they work, but you want to know what their input and outputs are, where the inputs come from, and how the outputs are used by other components.

This process is virtually unlimited, so there is never a single architecture that describes a complete system, but rather a set of architectures, each one covering the granularity we are interested in.

Let me give you a very simple example that has nothing to do with software. Let's consider a shop as a system and let's discuss its architecture.

A shop, as a black box, is a place where people enter with money and exit with things. The input of the system are people and their money, and the outputs are the same people and things. The shop itself needs to buy what it sells first, so another input is represented by the things the shop buys from the wholesaler and another output by the money it pays for them. At this level the internal structure of the shop is unknown, we don't even know what it sells. We can however already devise a simple performance analysis, for example comparing the amount of money that goes out (to pay the wholesale) and the amount of money that comes in (from the customers). If the former is higher than the latter the business is not profitable.

Even in the case of a shop that has positive results we might want to increase its performances, and to do this chances are that we need to understand its internal structure and what we can change to increase its productivity. This may reveal, for example, that the shop has too many workers, that are idle waiting for clients because we overestimated the size of the business. Or it might show that the serving time is too high and that many clients just walk away without buying anything. Or maybe there are not enough shelves to display goods and the staff is busy moving things around the whole day trying to find space for everything we want to sell, and leaving the shop in a chaotic situation that prevents clients to find what they need.

At this level, however, workers are pure entities, and still we don't really know what the shop sells in detail. To better understand the reasons behind a problem we might need to increase the zoom level and look at workers for what they are, human beings, and start understanding what their needs are and how to help them work better.

This example can easily be translated into the software realm. Our shop is a processing unit in the cloud, for example, input and output being the money we pay for it and the amount of requests the system serves per second, which is probably connected with the income of the business. The internal processes are revealed by a deeper analysis of the resources we allocated (storage, processors, memory), which breaks the abstraction of the "processing unit" and reveals details like the hardware architecture or the operating system. We might go deeper, discussing the framework or the library we used to implement a certain service, the programming language we used, or the specific TODO

Remember that an architecture tries to detail how a process is implemented at a certain granularity, given certain assumptions or requirements. The quality of an architecture can then be judged on the basis of parameters like its cost, the quality of the outputs, its simplicity or "elegance", the amount of effort required to change it, and so on.

## Why is it called "clean" architecture?

The architecture explained in this book has many names, but the one that is mainly in use nowadays is "clean architecture". This is the name used by Robert Martin in his seminal post [^robert-martin-post] where he clearly states this structure is not a novelty, but has been pushed by many software designers through the years. I believe the adjective "clean" describes one of the fundamental aspects of both the software structure and the development approach pushed by this architecture. It is clean, that is, it is easy to understand what happens.

[^robert-martin-post]: http://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html

The clean architecture is the opposite of spaghetti code, where everything is interlaced and not a single element can be easily detached from the rest and replaced without making the whole system collapse. The main point of the clean architecture is to make clear "what is where and why", and this should be your first concern while you design and implement a software system, whatever architecture or development methodology you want to follow.

The clean architecture is not the perfect architecture and cannot be applied without thinking. As any other solution, it addresses a set of problems and tries to solve them, but there is no panacea that will solve all issues. As already stated you have to understand how the clean architecture solves some problems and decide if the solution suits your need.

## Why Python?

I have been working with Python for 20 years, along with other languages, but I got to love its simplicity and power and so I ended up using it in many projects. When I was first introduced to the clean architecture I was working on a Python application that was meant to glue together the steps of a processing chain for satellite imagery, so my journey with the concepts I will explain started with this language.

I will thus use Python in this book, but the main concepts are valid for any other language, especially object-oriented ones. I will not introduce Python here, so a minimal knowledge of the language syntax is needed to understand the examples and the projects I will discuss.

The clean architecture concepts are independent from the language, but the implementation obviously leverages what a specific language allows to do, so this book is about the clean architecture and an implementation of it that I devised using Python. I really look forward to seeing more books about the clean architecture that explore other implementations in Python and in other languages.

_Cover photograph by pxhere (https://pxhere.com/en/photo/760437)_
_Cover font Lato by Łukasz Dziedzic (http://www.latofonts.com)_