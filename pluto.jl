### A Pluto.jl notebook ###
# v0.19.11

using Markdown
using InteractiveUtils

# ╔═╡ 675e66aa-8aef-11eb-27be-5fe273e33297
# Load packages
begin
    using BenchmarkTools
    using PlutoUI
end

# ╔═╡ 15f5c31a-8aef-11eb-3f19-cf0a4e456e7a
md"""
# 每个科研工作者都需要了解的关于高性能代码的硬件知识

**本教程的英文版位于 https://github.com/jakobnissen/hardware_introduction**

现如今，编程已经成为许多科研领域的一项基本技能，许多科学家都需要为他们的科研项目写一些特定代码。
不过，大部分科研工作者其实并不是科班出身的程序员，他们也仅仅只是因为需要才去学习编程。
我认为自己就是其中之一。
虽然从**软件**层面来说我们可能已经很熟悉编程了，但是对于**硬件**是如何影响代码性能这件事情，我们知之甚少。

本教程旨在提供一个关于现代硬件特性的**简明**概述，从而让像我这样的非科班程序员也知道如何写出高性能的代码。
这个教程的内容源于我对过于几年编程经验的总结。
本教程将使用 Julia， 因为它能够使用高级交互式语言轻松地演示这些来自于硬件底层的影响因素。

## 不会覆盖的内容
#### 关于 Julia 编程语言的指南 
为了编写快速代码，你必须首先了解你的编程语言及其特性。但这**不是**关于 Julia 编程语言的指南。我建议阅读 Julia 文档中的[性能建议](https://docs.juliacn.com/latest/manual/performance-tips/) 节。

#### 关于特定数据结构或算法的说明
为了加速代码，除了要弄明白编程语言，你也必须理解你自己的代码。你必须了解大 O 记号，为什么一些算法比其他算法快, 以及不同数据结构内部如何组织。若是不知道**什么是`Array`**，又怎么能够使用数组优化代码？

这同样超出了本文的范围。然而，我想说的是，一个编程选手至少应该了解：

* 二进制整数在内存中的表示方式
* 浮点数在内存中的表示方式 -- 学习这点也是必要的，因为这有助于理解浮点运算的计算误差，而浮点运算是科学计算中不可或缺的部分
* `String` 的内存布局，包括 ASCII 和 UTF-8 编码
* 关于`Array` 结构化的基本知识，以及由数构成的稠密数组与对象引用数组之间的区别
* 哈希表（如字典 `Dict` 和集合 `Set`）背后的工作原理

此外，我还建议熟悉：

* 堆（Heap）
* 双端队列（Deque）
* 元组（Tuple）

#### 这不是关于代码基准测试的教程
**实际**编写高性能代码时，测试代码查找瓶颈是非常有必要的，即找出机器消耗大多数时间的地方。通常必须需要对不同的函数和方法进行基准测试，才能找到最快实践。Julia（以及其他语言）为此提供了工具，但此处不做介绍。
"""

# ╔═╡ 5dd2329a-8aef-11eb-23a9-7f3c325bcf74
md"""## notebook 的初始化设置

如果你没有安装如下的软件包，请取消注释下面几行，并运行它们：
"""

# ╔═╡ 7490def0-8aef-11eb-19ce-4b11ce5a9328
# begin
#     using Pkg
#     Pkg.add(["BenchmarkTools", "PlutoUI"])
# end

# ╔═╡ 800d827e-8c20-11eb-136a-97a622a7c1e6
TableOfContents()

# ╔═╡ 9a24985a-8aef-11eb-104a-bd9abf0adc6d
md"""
## 计算机硬件的基本结构

现在，我们将从一个计算机体系的简化模型开始。在本教程中，我将在后续相关章节时增加更多模型细节。

$$[CPU] ↔ [RAM] ↔ [DISK]$$

上图中的箭头指示了数据流的方向。此图展示了计算机的三个重要组成部分：

* 中央处理器（CPU）是一个邮票大小的芯片。它是计算机的大脑，即进行运算的地方。
* 随机存取存储器（RAM，或简称“内存”）是计算机的短期存储器。该存储器需要电源来维持，而且当电脑关机时会遗失数据。RAM 临时地存储了在 CPU 和硬盘之间传输的数据。“加载”各种应用程序和操作系统所消耗的大部分时间都是用来将数据从硬盘转移到 RAM，并在RAM解压数据。典型的个人消费级笔记本电脑的 RAM 容量约为$10^{11}$ 比特。
* 硬盘是大容量存储单元。这些硬盘上的数据在断开电源后依然存在，因此它涵盖了计算机的长期存储。每GB的硬盘比 RAM 便宜很多，个人消费级电脑的硬盘容量约为 $10^{13}$ 比特。
"""

# ╔═╡ a2fad250-8aef-11eb-200f-e5f8caa57a67
md"""
## 避免频繁访问硬盘
在讨论软件性能时，区分 **吞吐量** 和 **延迟** 很有用。延迟是指事件开始到完成所花费的时间。吞吐量是指在一定时间内能够完成多少工作量的指标。

从表面来看，延迟和吞吐量之间的关系看起来很明显：如果一个操作需要进行 $N$ 秒的计算，那么每秒只能执行$1/N$个操作。所以你会朴素地认为：

$$吞吐量 = \frac{1}{延迟}$$

实际上并不是这么简单。例如，设想如下的操作：需要 1 秒用于在开始前预热，但预热后每次操作只需 0.1 秒。该操作的 延迟 是 1.1 秒，但他预热后的吞吐量是 10 操作/秒。

或者，设想如下的情形：需要 1 秒的 延迟，但是能够同时执行8个操作。当批量运行时，这些操作的吞吐量为 8 操作/秒。

硬盘读取是一个值得区分延迟和吞吐量的时机。大多数现代电脑使用的硬盘类型为**固态硬盘（SSD）**。粗略地讲，目前（2021年） SSD 的延迟约为 100 µs，同时读/写的吞吐量远远超过 1 GB/s。另一种相对较旧或者说廉价的大容量硬盘类型是 **机械硬盘（HDD）**。相比于SSD，它们的延迟要慢 100 倍，大约 10 ms，同时吞吐量也小 10 倍，约为 100 MB/s。

相比于RAM 100 ns 以下的延迟，即使是最新最快的 SSD，其延迟也比 RAM 慢上数千倍。 每一次读或写操作都会触发硬盘延迟。因此，为了编写高性能代码，必须不惜一切代价来避免重复的硬盘读写。

以下示例用于说明 延迟 的差异：第一个函数会打开一个文件，访问文件的一个字节，最后关闭文件。第二个函数则会随机访问 RAM 中的 1,000,000 个整数。
"""

# ╔═╡ cdde6fe8-8aef-11eb-0a3c-77e28f7a2c09
md"""
对文件访问的基准测试会显得有点绕。因为在 Julia 中**第一次**执行函数时会包含程序的编译时间，所以我们一般会用第二次执行的时间作为结果。
然而，在**第二次**执行函数时，虽然不需要再编译函数就可以执行，但由于**第一次**执行时操作系统已经缓存了该文件，所以**第二次**执行时会直接返回结果。换句话说，**第二次**
执行函数测试的实际上是缓存(RAM)的延迟而不是硬盘的延迟。
为了正确测量硬盘的读写延迟，我们需要先将函数运行一次来触发编译，然后再去读取另一个最近没有打开过的文件。
因此，事实上应该更新一下我们的计算机体系图：

$$[CPU] ↔ [RAM] ↔ [硬盘缓存] ↔ [硬盘]$$

在我的电脑上，访问文件的一个字节（包括打开和关闭文件）要花费 500 µs，而访问内存中的 1,000,000 个整数花费 200 毫秒。所以硬盘延迟大约是 RAM 延迟的 2500 倍。因此，高性能计算**必须**避免重复访问文件。

几年前， SSD 还不常见，并且 HDD 的吞吐量也要比今天小。因此，旧文本通常会警告人们，由于高吞吐量成本，一点也不要让你的程序依赖硬盘。但此建议在今天已经过时了，因为大多数程序都不能达到低价且现代的 SSD 的 1 GB/s 吞吐量瓶颈。此建议在今天只仍适用于那些**频繁**进行硬盘读写的程序，这会积累出高**延迟**。在这些情况下，你确实应该将数据保存在RAM 中。

如果你试图每次往一个大文件里只读写一小部分数据，比如说每次读写 1 Byte，那么你就会触发最差的读写性能了。
在这种情况下为了改善性能，一般会构造一个文件缓冲区来避免大量的读写操作。
相比于每次只读写 1 Byte 的很少的数据，借助缓冲区我们可以每次会读取一大块的连续数据到内存中（无论是否真的需要这么多）。
这样一来，每次进行读取的时候，我们都可以先手动检查一次数据是否在缓冲区中，因为如果在的话，就不需要再读取硬盘数据了。
这种方法可以将硬盘的延迟影响降到最低。
操作系统和编程语言都会自动利用缓存，但是有时候[手动构造文件缓冲区依然是必要的](https://github.com/JuliaLang/julia/issues/34195)。

"""

# ╔═╡ f58d428c-8aef-11eb-3127-89d729e23823
md"""
## 避免缓存未命中
RAM 比硬盘快，而 CPU 又比 RAM 快。CPU 滴答类似于时钟，速度约为 3 GHz，即每秒滴答30亿次。
CPU 时钟的一次**滴答**被称为**时钟周期**。
虽然这做了简化，但是你可以想象，在每个周期内，CPU都会执行一条简单的**指令**，该指令执行一次对小块数据的操作。
时钟速度可以作为计算机中其他计时器的参考。
了解时钟周期到底有多快是很值得的：光在一个时钟周期内只前进 10 cm。
在设计现代 CPU 时一个重要的限制因素就是线路延迟，即电子在 CPU 内部线路传输所花的时间。这恰恰是因为 CPU 运算的太快了。

在该尺度上，从 RAM 中读取数据需要花费 500 个时钟周期。
通过将数据拷贝到 RAM 可以减缓硬盘延迟。与之类似，RAM 上的数据也可以拷贝到 CPU 芯片上的一小块内存，称作**缓存（cache）**。
缓存比内存更快的原因有两点：一方面在于缓存本身位于 CPU 内部因此线路延迟是很低的，另一方面在于 CPU 缓存一般采用静态 RAM 这种更快的存储方案，而不是主流内存中所采用的便宜的动态 RAM 的方案。
因为缓存必须位于 CPU 上所带来的尺寸限制，以及由于更加昂贵的生产成本，所以经典 CPU 缓存大约仅包含  $10^8$ 比特， 这仅是 RAM 容量的 1/1000。
实际上，CPU 缓存由多个不同性能和容量的层级组成多级缓存，但在这里我们简单地将它们看作一个整体，并统称为 **CPU 缓存**。

$$[CPU] ↔ [CPU 缓存] ↔ [RAM] ↔ [硬盘缓存] ↔ [硬盘]$$

当 CPU 从 RAM 请求一段数据时，比如一个字节，会首先检查数据所处的内存是否已经在 CPU 缓存中。
如果是，那么将从 CPU 缓存读取。这相比从 RAM 访问更快，通常仅需要几个时钟周期。
如果否，那么将得到**缓存未命中** (cache miss)，你的程序会等待约 100 ns 直到计算机将数据从 RAM 拷贝到 CPU 缓存。

除了非常低层级的语言外，手动管理 CPU 缓存是不可能的。相反地，您必须确保有效使用缓存。

首先，你争取使用尽可能小的内存。使用的内存越小，当 CPU 需要数据时，它就越有可能在缓存上。 
请记住，在一次缓存未命中所浪费的时间内，CPU 可以执行约 500 次小操作。

缓存的有效使用最终体现在 **局部性** 这个概念上，分别是时间上和空间上的局部性：
* **时间局部性** 指的是你之前读取过的数据很可能已经存在缓存上了。因此，如果需要反复访问同一块内存数据，请确保这些访问操作在尽可能短的时间内进行。
* **空间局部性** 指的是你应该读取尽可能相邻位置的内存数据。
  因为 CPU 不仅仅只是把你需要的那些字节放到 CPU 缓存中，它实际上会将更大的一段数据存到 CPU 缓存中。
  这样一段数据被称为 **缓存线** (cache line)，它们大概是 512 个连续比特，依具体的 CPU 型号而定。

为了说明上述差别，让我们比较两种情况下随机读取函数 `random_access` 的性能：第一种访问 8 KiB 大小的短向量，第二种访问 16 MiB 大小的长向量。
在前者短向量的情况下，因为数据比较小所以几次访问过后全部数据都被存到 CPU 缓存中了。在后者长向量的情况下，因为数据比较大，进行新的索引时缓存几乎都没有命中。

请注意所花时间的巨大差别——大约是70倍。
"""

# ╔═╡ c6da4248-8c19-11eb-1c16-093695add9a9
md"""
对于之前的 `random_access` 函数，如果我们不是随机访问数组，而是以最糟糕的情况访问，会发生些什么呢？

例如，我们可以使用如下的函数：
"""

# ╔═╡ d4c67b82-8c1a-11eb-302f-b79c86412ce5
md"""
线性读取函数 `linear_access` 进行与 `random_access` 几乎相同的操作，但每次只访问第 15 个元素。
Julia 中 `UInt` 类型的长度为 8 字节（64比特），所以步长为 15 表示每两次访问的元素间的距离为 $15 * 8 = 120$ 字节，这超过了 64 字节的缓存线所能存储的内容。 
这意味着每次访问都会触发缓存未命中—— 这与访问大向量的 `random_access` 函数不同，其也只在多数情况下导致缓存未命中。
"""

# ╔═╡ 0f2ac53c-8c1b-11eb-3841-27f4ea1e9617
md"""
惊不惊喜？意不意外？线性访问模式竟然比随机访问要快 20 倍！聪明的小脑袋瓜肯定在好奇这是为什么了。

CPU 缓存旁边有一个叫做**预取器（prefetcher）**的小型电路。这个电路会收集CPU所访问的内存上的数据，并寻找特殊模式。
当检测到这些模式时，它会根据这个模式去预测并提前取出不久后可能会被访问到的数据。因此，当 CPU 向内存请求数据时，数据其实已经保存在缓存中了。

我们的线性读取函数 `linear_access` 相比于随机读取函数 `random_access`，虽然在**缓存利用率** (cache usage) 上要更差，但因为它的访问模式是可预测的，这就使得预存器发挥了作用。

综上，我们已经知道：
* 一次**缓存未命中**会带来大约 500 次 CPU 操作的性能损失，因此避免它们是至关重要的。
* 减少缓存未命中的措施有：
  - 使用更小的数据从而更容易被塞进缓存里
  - 以可预测的、规律的模式访问数据，以便于预取器发挥作用；
  - 访问的数据应该尽可能在一段连续内存中，而不是分散在不同的地方
  - 尽量在短时间内访问临近的数据，因为这样的话它可能还在缓存上

缓存利用率也体现在你使用的数据结构上。字典 `Dict` 和 集合 `Set 这种哈希表结构的缓存利用率都很低，缓存也几乎总是未命中。相比而言数组的缓存利用率就比较高。
因此，虽然哈希表的许多操作都是$O(1)$ 的复杂度（即在常数时间内完成），但是每次操作成本依然很高。

本教程中的许多优化都会间接影响缓存使用，因此记住这一点很重要。
"""

# ╔═╡ 12f1228a-8af0-11eb-0449-230ae20bfa7a
md"""
## 让数据在内存中保持对齐
如上面所说，CPU 会一次性把 512 连续比特（即 64 字节）的“缓存线”数据从 RAM 移动到 CPU 缓存中。那么，主内存整体就会被相对分成一个又以一个缓存线。
例如，内存地址 0 到 63 对应一条缓存线，紧接着下一条是内存地址 64 到 127，再接着是内存地址 128 到 191 等等。
CPU 只会从内存中请求某条缓存线，而不是内存地址 30 到 93 所对应的 64 字节。

这意味着一些数据结构会穿过缓存线的边界。如果我想要访问一个位于地址 60 的 64 位（8 字节）整数，那么 CPU 必须首先根据单次请求地址生成两次内存请求（即缓存线 0-63 和 64-127），然后从两条缓存线中检索该整数，这显然会浪费时间。

浪费的时间可能会很显著。在证明缓存访问是瓶颈的情况下，相较于不存在对齐问题的情况，程序性能会下降 1/2。
在接下来的例子中，我将使用指针在缓存线边界的给定偏移处重复访问数组。
如果偏移位于范围 `0:56`，那么所有的整数都将位于一条缓存线上，函数运行起来也快。
如果偏移位于范围 `57:63`，那么将会有整数穿过缓存线。
"""

# ╔═╡ 3a1efd5a-8af0-11eb-21a2-d1011f16555c
md"未对齐内存访问的后果依 CPU 型号而定。在我现在的 CPU 上，会存在约 15% 的性能下降。
 在我最初写这本教程的旧电脑上，性能下降接近百分百。
旧的处理器甚至会出现[更差的情况](https://www.kernel.org/doc/Documentation/unaligned-memory-access.txt) —— 难以置信的是，2001 年 Game Boy Advance 的 CPU 竟然会**静默执行不同的读取！** 😱

幸运的是，一些编译器端的技巧能够降低访问未对齐数据的可能性。首先，Julia（以及其他编译型语言）通常会把新对象放在缓存线内存的边界处。当对象正好放在边界时，我们认为数据是对齐的。Julia 也会把大型数组的开头对齐："

# ╔═╡ 5b10a2b6-8af0-11eb-3fe7-4b78b4c22550
md"如果数组开头是对齐的，那么 1-, 2-, 4-, 或者 8 字节的对象都不可能穿过缓存线的边界。并且一切都是对齐的。

但是若数组中有 7 字节对象，仍然可能存在对齐不了的情况。在一个由 7 字节对象组成的数组中，第 10 个对象的偏移地址是 $7 \times (10-1) = 63$ 字节，这将会产生穿过缓存线的情况。然而，编译器通常因此不允许非标准内存大小的结构体。如果定义一个 7 字节结构体："

# ╔═╡ 6061dc94-8af0-11eb-215a-4f3af731774e
struct AlignmentTest
    a::UInt32 # 4 bytes +
    b::UInt16 # 2 bytes +
    c::UInt8  # 1 byte = 7 bytes?
end;

# ╔═╡ 624eae74-8af0-11eb-025b-8b68dc55f31e
md"然后可以使用 Julia 的内省函数获得 `AlignmentTest` 中三个对象在内存中的相对位置："

# ╔═╡ d4c8c38c-8ee6-11eb-0b49-33fbfbd214f3
let
    T = AlignmentTest
    println("Size of $T: ", sizeof(T), "bytes")
    for fieldno in 1:fieldcount(T)
        print("Name: ", fieldname(T, fieldno), '\t')
        print("Size: ", sizeof(fieldtype(T, fieldno)), '\t')
        print("Offset: ", fieldoffset(T, fieldno), '\n')
    end
end

# ╔═╡ 7b979410-8af0-11eb-299c-af0a5d740c24
md"""
我们可以看到，尽管 `AlignmentTest` 只有 4 + 2 + 1 = 7 字节的真实数据，但是却分配了 8 字节的内存。
这样的话，访问数组中的 `AlignmentTest` 对象时，内存仍然是对齐的。

作为一名程序员，其实只有极少数情况会遇到内存对齐问题。这里提供两个例子：

1. 若创建的对象具有奇怪的尺寸，例如使用指针访问稠密的整数数组。这种操作虽然可以节约内存，但是会浪费时间。我实现的[Cuckoo filter](https://github.com/jakobnissen/Probably.jl) 就使用了这种方式节约空间。 
2. 矩阵操作的过程。因为数组元素在内存中紧靠着存储，所以有时数组的列会是未对齐的。例如，在一个 15x15 的 `Float32` 矩阵中，仅仅只有第一列是对齐的，其他列都存在未对齐问题。这会对矩阵操作造成严重的后果：[在链接里的基准测试中](https://juliasimd.github.io/LoopVectorization.jl/latest/examples/matrix_vector_ops/)，由于对齐问题，80x80 矩阵/向量的乘法会比 79x79 矩阵/向量的乘法快上两倍。
"""

# ╔═╡ 8802ff60-8af0-11eb-21ac-b9fdbeac7c24
md"""
## 题外话：汇编代码
任何程序想要运行，都需要先翻译或者说**编译**为 CPU 指令。
使用编程语言写下的代码仅仅是程序的一种**描述**，与之相反的是，CPU 指令是真真切切运行在电脑上的。
人们通常用 **汇编** 语言描述 CPU 指令。也就是说，汇编语言的语句是与 CPU 指令一一对应的。

查看汇编代码将有助于理解下文中那些关于 CPU 指令的章节。

在 Julia 中，可以使用  `code_native` 函数或者 `@code_native` 宏方便地查看编译后的汇编代码。
我们将将其应用到一个简单的函数上：
"""

# ╔═╡ a36582d4-8af0-11eb-2b5a-e577c5ed07e2
# View assembly code generated from this function call
function foo(x)
    s = zero(eltype(x))
    @inbounds for i in eachindex(x)
        s = x[i ⊻ s]
    end
    return s
end;

# ╔═╡ a74a9966-8af0-11eb-350f-6787d2759eba
 @code_native foo([UInt(1)])

# ╔═╡ ae9ee028-8af0-11eb-10c0-6f2db3ab8025
md"""
让我们来分析一下：

以 `;` 开头的行是注释，这些行会解释说明以下代码来自哪些部分。
它们会展示嵌套的函数调用，以及函数在源代码中的位置。
你可以看到，`eachindex` 调用了 `axes1`，`axes1` 又调用了 `axes`，然后 `axes` 又调用了 `size`。
在 `size` 那行注释下面，我们看到了第一条 CPU 指令。
指令名位于最左侧，即 `movq`。
名称由两部分组成，第一部分为 `mov`，它是指令的类型（即将数据移出或移入寄存器）；第二部分是后缀 `q`，这是 "quad" 的缩写，对应了 64-bit 整数。
全部的后缀如下：`b` (byte, 8 位), `w` (word, 16 位), `l`, (long, 32 位) 和 `q` (quad, 64 位)。

指令中接着的两列，`24(%rdi)` 和 `%rax` 是 `movq` 的参数。
它们都是存储待操作数据的寄存器的名字。后文将会详细讨论寄存器。

查看大程序的汇编代码可以发现，汇编代码被分成了不同的节，并且这些节的命名都以“L”开头。
例如，当运行上面的函数时，我们会看到 `L32` 节。这些节在 if 语句或者**代码分支**间跳转。这里的 `L32` 节对应了循环操作。你可以在 `L32` 节看到如下两条指令：

```
; ││┌ @ promotion.jl:401 within `=='
     cmpq    $1, %rdi
; │└└
     jne     L32
```

第一条指令 `cmpq`（compare quad） 会将寄存器 `rdi` 中的数据与数字 1 进行比较，然后根据结果在 CPU 中设定一些 flag。
其中，寄存器 `rdi` 中的数据对应了剩余的迭代次数（加 1）。
下一条指令 `jne`（jump if not equal， 如果不等则跳转）会在 CPU 未设置 "equal" flag 时发生跳转。即当还有一次或多次迭代未执行时，程序发生跳转。这条指令会跳转到 'L32' 节，这意味着会重复执行该部分。
"""

# ╔═╡ b73b5eaa-8af0-11eb-191f-cd15de19bc38
md"""
#### 快指令与慢指令
并不是所有的 CPU 指令都很快。下表展示了一些 CPU 指令，并粗略估计了运行它们所要消耗的时钟周期数。
了解更多细节请查看[此文档](https://www.agner.org/optimize/instruction_tables.pdf) 。
下文将总结现代 Intel CPU 的指令速度。现代 CPU 的指令速度都差不多。

可以看到，表中时间的衡量标准是延迟和吞吐量倒数（即，$1/吞吐量$）。
这样做的原因是 CPU 包含有多个电路，并且这些电路可以并行地运行操作。
因此，尽管浮点数乘法有 5 个时钟周期的延迟，但是10个浮点数操作可以在10个不同的电路并行地计算。
此时吞吐量为 2 操作/秒，所以吞吐量倒数为 0.5。

下表以时钟周期为时间单位：

|Instruction             |Latency|Rec. throughp.|
|------------------------|-------|--------------|
|move data               |  1 |  0.25
|and/or/xor              |  1 |  0.25
|test/compare            |  1 |  0.25
|do nothing              |  1 |  0.25
|int add/subtract        |  1 |  0.25
|bitshift                |  1 |  0.5
|float multiplication    |  5 |  0.5
|vector int and/or/xor   |  1 |  0.5
|vector int add/sub      |  1 |  0.5
|vector float add/sub    |  4 |  0.5
|vector float multiplic. |  5 |  0.5
|lea                     |  3 |  1
|int multiplic           |  3 |  1
|float add/sub           |  3 |  1
|float multiplic.        |  5 |  1
|float division          | 15 |  5
|vector float division   | 13 |  8
|integer division        | 50 | 40


`lea`指令接收 3 个参数，A，B 和 C。其中 A 必须为1, 2，4 或 8，然后计算 AB + C。
稍后会讨论 "vector" 指令干了什么。

为了进行比较，一些其他延迟来源的**粗略估计**补充如下：

|Delay                  |Cycles|
|-----------------------|----|
|move memory from cache |        1
|misaligned memory read |       10
|cache miss             |      500
|read from disk         | 5000000
"""

# ╔═╡ c0c757b2-8af0-11eb-38f1-3bc3ec4c43bc
md"如果你的内层循环需要执行上百万次，那么就要检查生成的汇编代码是否可以转化为 CPU 快指令表示，这项操作很可能是有收益的。例如，如果你有一个大于等于 0 的整数，打算用 8 除以它（忽略余数），也可以使用位偏移操作，因为位偏移操作要比整数除法快："

# ╔═╡ c5472fb0-8af0-11eb-04f1-95a1f7b6b9e0
begin
    divide_slow(x) = div(x, 8)
    divide_fast(x) = x >>> 3;
end;

# ╔═╡ ce0e65d4-8af0-11eb-0c86-2105c26b62eb
md"然而，现代编译器非常智能，常常能够在保证结果相同的情况下找出函数所对应的最佳指令。例如，整除指令 `idivq`会被替换为右位移指令（`shrq`），后者在合适的时候运算更快。你需要自行查看汇编代码："

# ╔═╡ d376016a-8af0-11eb-3a15-4322759143d1
# Calling it with debuginfo=:none removes the comments in the assembly code
@code_native debuginfo=:none dump_module=false divide_slow(UInt(1))

# ╔═╡ d70c56bc-8af0-11eb-1220-09e78dba26f7
md"## 内存分配和不可变性
如前文所述，主 RAM 要比 CPU 缓存慢。然而，在主 RAM 中工作还有另外的缺点：操作系统（operating system，OS）会给多个应用提供不同的RAM。在内存块中，程序自己需要追踪对象正在使用哪些RAM。若不追踪， 一个对象的分配内存就可能覆盖另一个，这则会数据丢失。因此，RAM需要花时间记录每份数据的产生和销毁。

RAM 中创建新对象称为 **分配（allocation）**，对应地，销毁对象称为 **释放（deallocation）**。实际上，分配（释放）本质上并不是真的在 **创造** 或 **销毁** ，而是开始或停止追踪指定的内存。未被追踪的内存将会被其他数据覆盖。分配和释放所花费的时间取决于对象的大小，每次操作的数量级在数十 ns 到几 ms 之间。

Julia、Python、R 和 Java 等语言使用名为“垃圾回收器（garbage collector，GC）”的程序自动实现释放操作。此程序会追踪那些被程序员标记为不可访问的对象，然后释放它们。例如若这样写："

# ╔═╡ dc24f5a0-8af0-11eb-0332-2bc0834d426c
begin
    thing = [1,2,3]
    thing = nothing
end

# ╔═╡ e3c136de-8af0-11eb-06f1-9393c0f95fbb
md"那么你将无法找回原来的数组 `[1,2,3]` ，它已经无法访问。这什么也没有做，只是在浪费 RAM。它是**垃圾**。分配和释放有时会导致 GC 开始扫描所有内存中的对象并释放无法访问的对象，而这样会带来显著的延迟。因此你也可以手动开始垃圾回收："

# ╔═╡ e836dac8-8af0-11eb-1865-e3feeb011fc4
GC.gc()

# ╔═╡ ecfd04e4-8af0-11eb-0962-f548d2eabad3
md"下面的例子展示了为结果分配新内存的程序和直接在原向量上更改的程序之间的用时差异："

# ╔═╡ f0e24b50-8af0-11eb-1a0e-5d925f3743e0
begin
    function increment(x::Vector{<:Integer})
        y = similar(x)
        @inbounds for i in eachindex(x)
            y[i] = x[i] + 1
        end
        return y
    end

    function increment!(x::Vector{<:Integer})
        @inbounds for i in eachindex(x)
            x[i] = x[i] + 1
        end
        return x
    end
end;

# ╔═╡ 22512ab2-8af1-11eb-260b-8d6c16762547
md"""
在我的电脑上，需要分配新内存的程序平均相比之下要慢15倍。另外，我们也需要关注函数内存分配所花费时间的最大值。这是因为代码具有以下性质：
* 首先，分配动作本身需要花费时间；
* 其次，已分配对象的销毁也需要花费时间；
* 第三，重复的分配会触发垃圾回收，这又会带来额外的开销
* 第四，越多的分配有时意味着越低效的缓存利用，因为使用了更多的内存 

注意到，我使用的是时间的平均值，而不是中位数，这是因为大约每 30 次函数调用才会触发 1 次GC，每次GC花费 30-40 µs。综上，高性能代码应将内存分配保持在最低限度。

我们可以使用 `@btime` 宏或者其他基准测试工具获取到内存分配的次数。提供此信息的原因是通常认为给代码做基准测试的开发者都会对减少内存分配感兴趣。

#### 并非需要分配所有对象
在 RAM 中，数据通常保存在 **栈** 或 **堆** 上。栈是具有起头和结尾的简单数据结构，类似于 Julia 中的 `Vector`。栈的修改方式只能是在结尾添加或移除元素，可类比于只支持可变操作 `push!` 和 `pop!` 的 `Vector`。这些在栈上的操作非常快。然而，当我们讨论“分配”时，我们讨论的是堆上的数据。与栈不同的是，堆具有无限制的大小（实际上限是计算机 RAM 的大小），并且可以随意更改、删除和访问任何对象。你可以认为栈像 `Vector`，而堆像 `Dict`。

直观地讲，很明显我们需要将所有的对象放在 RAM 中，并且要让程序随时能够检索和删除对象，因此我们需要将对象都分配在堆上。某些语言，比如 Python，正是这样做的。然而，这不适用于 Julia 以及其他高效的编译型语言。例如，整数类型（Integer）通常放在栈上。

为什么有的对象需要分配在堆上，而有的对象又需要分配在栈上呢？对于分配在栈上的对象，编译器需要确定的是：

* 对象所占内存应适当地小，因此才能放进栈中。考虑一些技术因素，栈不能只有数百 MB 大小。  
* 编译器应该能够准确预测对象的创建和销毁时机，因此可以通过简单的弹栈操作来及时销毁对象（类似于调用 `pop!` 函数操作 `Vector`）。编译型语言中的局部变量通常就是这类情形。

Julia 语言对分配在栈上的对象有更多的限制。
* 对象的大小固定，且能够在编译时已知。
* 编译器必须确定对象永不改变。CPU 能够自由复制栈上分配的对象，然而对于不可变对象，我们无法区分原始对象和其副本。这需要重复一遍：**对于不可变对象，我们无法区分原始对象和其副本**。这使得编译器和 CPU 在操作对象时具有确定的自由度。这也就是为什么 Julia 中的对象默认都是不可变的，这引出了一条性能建议：尽可能使用不可变对象。

实际上这意味着什么呢？在 Julia 中，这意味着如果想要得到快速的栈分配对象，那么需要满足以下条件：
* 对象应该由完全编译的函数创建、使用和销毁，从而让编译器能够知道创建、使用和销毁该对象的准确时机。如果对象需要返回供以后使用（而不是即刻返回到另一个完全编译的函数），这称为**逃逸**，则需要在内存中分配。
* 必须限制类型的大小。我不知道到底应该多大，但 100 比特是可以的。
* 编译器必须（几乎总是）知道类型的准确内存布局。
"""

# ╔═╡ 2a7c1fc6-8af1-11eb-2909-554597aa2949
begin
    abstract type AllocatedInteger end

    struct StackAllocated <: AllocatedInteger
        x::Int
    end

    mutable struct HeapAllocated <: AllocatedInteger
        x::Int
    end
end

# ╔═╡ 2e3304fe-8af1-11eb-0f6a-0f84d58326bf
md"我们可以分别检查初始化 `HeapAllocated` 对象和 `StackAllocated` 对象的代码："

# ╔═╡ 33350038-8af1-11eb-1ff5-6d42d86491a3
@code_native debuginfo=:none dump_module=false HeapAllocated(1)

# ╔═╡ 3713a8da-8af1-11eb-2cb2-1957455227d0
md"注意上述 `HeapAllocated` 代码中的 `callq` 指令。这条指令调用了另一函数，这实际上意味着需要更多的代码来创建如上所示的 `HeapAllocated` 对象。相反，`StackAllocated` 对象的分配只需要几条指令："

# ╔═╡ 59f58f1c-8af1-11eb-2e88-997e9d4bcc48
@code_native debuginfo=:none dump_module=false StackAllocated(1)

# ╔═╡ 5c86e276-8af1-11eb-2b2e-3386e6795f37
md"
因为不可变对象不需要存储在堆上，并且可以被自由复制，所以不可变对象串联存储在数组中。这意味着不可变对象可以直接存储在数组的内存中。可变对象则需要在堆上具有唯一的标识符和存储位置。可变对象和其副本间是可分辨的，因此不能自由复制，所以数组内包含的是对其堆上存储位置的引用。从数组访问这类对象的流程是，首先访问数组获得存储位置，然后利用存储位置访问对象本身。除了两次内存访问外，在堆上存储对象也相对低效，因为需要 CPU 缓存拷贝了更多的内存，而这意味着更多的缓存未命中。因此，即使是存储在堆上的数组里，不可变对象的存储也相对更高效。
"

# ╔═╡ 6849d9ec-8af1-11eb-06d6-db49af4796bc
md"我们可以验证，实际上，`data_stack` 中的数组存储着 `StackAllocated` 对象的真实数据，而 `data_heap` 保存的是指针（即内存地址）："

# ╔═╡ 74a3ddb4-8af1-11eb-186e-4d80402adfcf
md"## 寄存器与 SIMD
现在我们要再次更新简化版的计算机模型。CPU 仅能操作**寄存器（registers）**中的数据。寄存器是CPU内大小固定（例如8字节）的小型数据槽（slots）。寄存器用于保存单个数据，比如一个整数或浮点数。正如汇编代码那节所示，每条指令都会引用一个或两个寄存器，其中包含了要操作的数据：

$$[CPU] ↔ [REGISTERS] ↔ [CACHE] ↔ [RAM] ↔ [DISK CACHE] ↔ [DISK]$$

如果要操作大于单个寄存器的数据结构，那么数据必须被拆分成多个寄存器大小的小数据块。例如，当在我的电脑上将两个 128-bit 整数相加时："

# ╔═╡ 7a88c4ba-8af1-11eb-242c-a1813a9e6741
@code_native UInt128(5) + UInt128(11)

# ╔═╡ 7d3fcbd6-8af1-11eb-0441-2f88a9d59966
md"""目前没有寄存器能够直接处理 128-bit 的情况。首先，使用 `addq` 指令将低位的 64 比特加起来，存入一个寄存器。然后，使用 `adcq` 指令计算高位比特的加法，该指令不仅将数组相加，还会使用前一指令的进位比特。最后，使用 `movq` 指令一次将结果移动 64 位。

寄存器的小尺寸是 CPU 吞吐量的瓶颈之一：它一次性仅能处理 1 个整数/浮点数。为了避免这类情形，现代 CPU 包含了专用的 256 位寄存器（旧 CPU 为 128 位，最新的 CPU 为 512 位），故能同时处理 4 个 64 位整数/浮点数，或者 8 个 32 位整数/浮点数等等。令人迷惑的是，这类宽寄存器中的数据被称为“向量”。CPU 使用特定的指令对向量实现多种 CPU 操作，即一条指令操作 4 个 64 位整数。这被称为“单指令，多数据（single instruction, multiple data）”， 简称为 **SIMD**，或**向量化**。特别地， 4 个 64 位的操作并不与一个 256 位的操作相同，例如 4 个 64 位整数相加时不存在进位。与之相反，一个 256 位向量的操作等价于 4 个单独的 64 位运算。

可以通过下面的例子说明这一点："""

# ╔═╡ 8c2ed15a-8af1-11eb-2e96-1df34510e773
md"""
在此处代码中，两个 8x32 位的向量使用单条指令相加。可以看到，CPU 使用了单个 `vpaddd` （vector packed add double，矢量聚合双精度加法）指令来对 8 个 32 位整数做加法，对应的移动指令也就是 `vmovdqu`。注意到，向量化的 CPU 指令都以 `v` 开头。

值得一提的是，SIMD 和内存对齐的相互影响：如果一系列 256 位（ 32 字节） SIMD 加载未对齐，那么可能最多会有一半的加载将跨越缓存线边界，而不是仅为 8 字节的 1/8。因此，在使用 SIMD 时，对齐是一个相当严重的问题。由于数组的起头总是对齐的，所以这对数组通常不是问题。但是，在无法保证从对齐起点开始的情况下，例如矩阵运算，这可能会产生显著的性能差异。在包含 512 位寄存器的最新 CPU 中，问题更为严重，因为 SIMD 大小与缓存线大小相同，因此如果初始的加载存在偏移，则所有的加载都会发生偏移。

64 位整数的 SIMD 向量化可以将 CPU 吞吐量提高 4倍，所以此种方法在高性能编程中具有巨大的重要性。编译器会尽其所能地自动向量化操作。那什么可以阻止这种自动向量化呢？

#### SIMD 需要不中断的固定长度循环
因为向量化操作一次处理多条数据，因此不能在任意点中断循环。例如，如果能在 1 个时钟周期内处理4 个 64 位整数，那么不可能在处理了 3 个整数后停止 SIMD 循环。假设你有如下的循环：

```julia
for i in 1:8
    if foo()
        break
    end
    # do stuff with my_vector[i]
end
```

由于存在 break 语句，此处的循环能够在任意迭代次数结束。因此，任何加载多个整数的 SIMD 指令都能处理循环中断后的数据，即永远不应被读取的数据。这是错误的行为，并且会导致编译器不能使用 SIMD 指令。

根据经验来看，SIMD 需要：
* 循环长度预先指定，因此停止时机可知
* 以及循环体内不存在分支（即 if 语句）

实际上，甚至边界检查，即检查你的索引是否超出向量的边界，都会导致分支。毕竟，如果代码在 3 次迭代后引发越界错误，那么即使是单个 SIMD 指令都会出错！如果要实现 SIMD 向量化，那么所有的边界检查都应该被禁止掉。

幸运的是，在最新版本的 Julia 中，编译器已经聪明到可以指出能够 SIMD 的时机，即使存在边界检查也可以。 

为了说明 SIMD 的影响，我们可以使用一个输入函来中断循环。然后比较两函数的速度，一个是可能中断循环的函数，另一个是编译器知道不存在循环中断并以SIMD方式执行的函数。"""

# ╔═╡ 94182f88-8af1-11eb-207a-37083c1ead68
begin
	# The loop in the function breaks if pred(x[i])
	# returns `true`, and therefore cannot be SIMDd
    function sum_predicate(pred, x::Vector)
        n = zero(eltype(x))
        for i in eachindex(x)
			y = x[i]
			pred(y) && break
			n += y
        end
        return n
    end
end;

# ╔═╡ aa3931fc-8af1-11eb-2f42-f582b8e639ad
md"""
在我的电脑上， SIMD 版本的代码要比非 SIMD 版本的代码快上 10 倍。单凭 SIMD 能提供约 4 倍的性能提升（因为我们将每次迭代 64 位提升到了每次迭代 256 位）。其余的提升来自于未耗时做边界检查和自动循环展开（后续将说明），这都是通过 `@inbounds` 实现的。

#### SIMD 需要顺序无关的循环
SIMD 能够改变数组元素的处理顺序。如果任何的迭代依赖于任何的先前迭代，那么元素不能够被重新排序，编译器通常也就不会进行 SIMD 向量化。通常，不能对循环自动向量化是由于一些数据在寄存器中移动的细微差别，即数组元素间存在某些隐藏的内存依赖关系。

想象需要使用 SIMD 对数组中的一些 64 位整数求和。简单起见，我们使数组只有 8 个元素，`A`，`B`，`C` ... `H`。在通常的非 SIMD 循环中，加法将像下面这样完成：

$$(((((((A + B) + C) + D) + E) + F) + G) + H)$$

而当使用 SIMD 加载整数时，四个 64 位整数将被加载到一个向量 `<A, B, C, D>`，另外四个整数加载到另一个向量 `<E, F, G, H>`。然后将两个向量相加：`<A+E, B+F, C+G, D+H>`。循环完成后，将结果向量中的四个整数加起来。所以，总的顺序如下：

$$((((A + E) + (B + F)) + (C + G)) + (D + H))$$

也许令人惊讶的是，浮点数加法可以根据顺序给出不同的结果（即浮点数加法不满足结合律）：
"""

# ╔═╡ c01bf4b6-8af1-11eb-2f17-bfe0c93d48f9
begin
    x = eps(1.0) * 0.4
    1.0 + (x + x) == (1.0 + x) + x
end

# ╔═╡ c80e05ba-8af1-11eb-20fc-235b45f2eb4b
md"因此，不会对浮点数加法自动向量化:"

# ╔═╡ e3931226-8af1-11eb-0da5-fb3c1c22d12e
md"然而，高性能编程语言通常会提供一条命令来告诉编译器，即使对于不满足交换律的循环也可以重排循环。在 Julia 中， 这条命令是 `@simd` 宏："

# ╔═╡ e793e300-8af1-11eb-2c89-e7bc1be249f0
function sum_simd(x::Vector)
    n = zero(eltype(x))
    # Here we add the `@simd` macro to allow SIMD of floats
    @inbounds @simd for i in eachindex(x)
        n += x[i]
    end
    return n
end;

# ╔═╡ f0a4cb58-8af1-11eb-054c-03192285b5e2
md"""
Julia 还提供了 `@simd ivdep` 宏，它进一步告诉编译器循环顺序不存在内存依赖性。然而，我**强烈地不建议**使用此宏，除非你**真的**知道自己在做什么。一般来说，编译器最能知道何时循环会存在内存依赖性，而 `@simd ivdep` 宏的滥用可能会很容易导致难以排查的 bug。
"""

# ╔═╡ f5c28c92-8af1-11eb-318f-5fa059d8fd80
md"""
## 数组结构体
如果创造一个数组，其中包含四个 `AlignmentTest` 对象 `A`、`B`、`C` 和 `D`，对象将会在数组中首尾相接，如下所示：

    对象:  |      A        |       B       |       C       |        D      |
    字段:  |   a   | b |c| |   a   | b |c| |   a   | b |c| |   a   | b |c| |
    字节:   1               9              17              25              33

再次注意，为了保持对齐，第8、16、24 和 32 字节是空闲的，这就会浪费内存。
现在假设要对所有结构体的 ".a" 字段执行操作。由于两 ".a" 字段相隔8字节，因此 SIMD 操作的效率（一次最多加载4个字段）远低于所有 `.a` 存储在一起的情形（8个字段刚好可以存入 256 位寄存器）。当仅使用 ".a" 字段时，我们会读取全部的 64 字节缓存线，但其中只有一半即 32 字节有用。这不仅会导致更多的缓存未命中，而且还需要用指令来从 SIMD 寄存器中提取一半的数据。

上面的内存结构被称为“结构体数组”，因为它是一个由结构体组成的数组。相反，我们可以将4个对象 "A" 到 "D" 构造为 "数组结构体"。根据概念，它看起来像是：
"""

# ╔═╡ fc2d2f1a-8af1-11eb-11a4-8700f94e866e
struct AlignmentTestVector
    a::Vector{UInt32}
    b::Vector{UInt16}
    c::Vector{UInt8}
end

# ╔═╡ 007cd39a-8af2-11eb-053d-f584d68f7d2f
md"""
每个字段的内存布局如下：

    对象: AlignmentTestVector
    .a |   A   |   B   |   C   |   D   |
    .b | A | B | C | D |
    .c |A|B|C|D|

内存对齐不再是问题，不会浪费任何空间用于填充。当遍历操作所有 ".a" 字段时，所有缓存线包含全部 64 字节的相关数据，因此 SIMD 不需要额外的操作来提取相关数据：
"""

# ╔═╡ 72fbb3ec-8ee8-11eb-3836-11092ef74e86
function Base.rand(::Type{AlignmentTest})
    AlignmentTest(rand(UInt32), rand(UInt16), rand(UInt8))
end;

# ╔═╡ abb45d6a-8aef-11eb-37a4-7b10847b39b4
begin
    # Open a file
    function test_file(path)
        open(path) do file
            # Go to 1000'th byte of file and read it
            seek(file, 1000)
            read(file, UInt8)
        end
    end

    # Randomly access data N times
    function random_access(data::Vector{UInt}, N::Integer)
        n = rand(UInt)
        mask = length(data) - 1
        @inbounds for i in 1:N
            n = (n >>> 7) ⊻ data[n & mask + 1]
        end
        return n
    end
end;

# ╔═╡ bff99828-8aef-11eb-107b-a5c67101c735
let
    data = rand(UInt, 2^24)
    @time test_file("../alen/src/main.rs")
    @time random_access(data, 1000000)
    nothing
end

# ╔═╡ b73605ca-8ee4-11eb-1a0d-bb6678de91c6
begin
    @btime random_access($(rand(UInt, 1024)), 2^20) seconds=1
    @btime random_access($(rand(UInt, 2^24)), 2^20) seconds=1
    nothing
end

# ╔═╡ ffca4c72-8aef-11eb-07ac-6d5c58715a71
function linear_access(data::Vector{UInt}, N::Integer)
    n = rand(UInt)
    mask = length(data) - 1
    for i in 1:N
        n = (n >>> 7) ⊻ data[(15 * i) & mask + 1]
    end
    return n
end;

# ╔═╡ e71e4798-8ee4-11eb-3ea2-fdbbcdcf7410
let
    data = rand(UInt, 2^24)
    @btime random_access($data, 2^20) seconds=1
    @btime linear_access($data, 2^20) seconds=1
    nothing
end

# ╔═╡ 18e8e4b6-8af0-11eb-2f17-2726f162e9b0
function alignment_test(data::Vector{UInt}, offset::Integer)
    # Jump randomly around the memory.
    n = rand(UInt)
    mask = (length(data) - 9) ⊻ 7
    GC.@preserve data begin # protect the array from moving in memory
        ptr = pointer(data)
        iszero(UInt(ptr) & 63) || error("Array not aligned")
        ptr += (offset & 63)
        for i in 1:4096
            n = (n >>> 7) ⊻ unsafe_load(ptr, (n & mask + 1) % Int)
        end
    end
    return n
end;

# ╔═╡ 1f38f8c6-8ee5-11eb-1c01-f3706534a9cf
let
    data = rand(UInt, 256 + 8)
    @btime alignment_test($data, 0) seconds=1
    @btime alignment_test($data, 60) seconds=1
    nothing
end

# ╔═╡ 3fae31a0-8af0-11eb-1ea8-7980e7875039
let
    memory_address = reinterpret(UInt, pointer(rand(1024)))
    @assert iszero(memory_address % 64) # should not error!
end

# ╔═╡ 11c500e8-8ee2-11eb-3291-4382b60c5a2b
let
    data = rand(UInt, 2^10)
    show(stdout, MIME"text/plain"(), @benchmark increment($data) seconds=1)
    println('\n')
    show(stdout, MIME"text/plain"(), @benchmark increment!($data) seconds=1)
end

# ╔═╡ 61ee9ace-8af1-11eb-34bd-c5af962c8d82
let
    Base.:+(x::Int, y::AllocatedInteger) = x + y.x
    Base.:+(x::AllocatedInteger, y::AllocatedInteger) = x.x + y.x

    data_stack = [StackAllocated(i) for i in rand(UInt16, 1000000)]
    data_heap = [HeapAllocated(i.x) for i in data_stack]

    @btime sum($data_stack) seconds=1
    @btime sum($data_heap) seconds=1
    nothing
end

# ╔═╡ 6ba266f4-8af1-11eb-10a3-3daf6e473142
let
    data_stack = [StackAllocated(i) for i in rand(UInt16, 1)]
    data_heap = [HeapAllocated(i.x) for i in data_stack]

    println(rpad("First object of data_stack:", 36), data_stack[1])
    println(
        rpad("First data in data_stack array:", 36),
        unsafe_load(pointer(data_stack)),
        '\n'
    )

    println(rpad("First object of data_heap:", 36), data_heap[1])
    first_data = unsafe_load(Ptr{UInt}(pointer(data_heap)))
    println(rpad("First data in data_heap array:", 36), repr(first_data))
    println(
        "Data at address ",
        repr(first_data), ": ",
        unsafe_load(Ptr{HeapAllocated}(first_data))
    )
end

# ╔═╡ 84c0d56a-8af1-11eb-30f3-d137b377c31f
let
    add_tuple(a, b) = a .+ b

    # Create a tuple of 8 32-bit integers.
    # could also have created 4 64-bit numbers etc.
    numbers = ntuple(i -> rand(UInt32), 8)
    @code_native debuginfo=:none dump_module=false add_tuple(numbers, numbers)
    nothing
end

# ╔═╡ a0286cdc-8af1-11eb-050e-072acdd4f0a0
let
    # Make sure the vector is small so we don't time cache misses
    data = rand(UInt64, 4096)

	# For a function that always returns false, the compiler
	# knows it can never break, and so will SIMD
    @btime sum_predicate(Returns(false), $data) seconds=1

	# This function has a 1/2^64 risk of returning true;
	# while practically impossible, the compiler cannot
	# guarantee it won't break the loop, and so will not SIMD
    @btime sum_predicate(iszero, $data) seconds=1
    nothing
end

# ╔═╡ cc99d9ce-8af1-11eb-12ec-fbd6df3becc8
let
    data = rand(Float64, 4096)
    @btime sum_predicate(Returns(false), $data) seconds=1
    @btime sum_predicate(iszero, $data) seconds=1
    nothing
end

# ╔═╡ e8d2ec8e-8af1-11eb-2018-1fa4df5b47ad
let
    data = rand(Float64, 4096)
    @btime sum_predicate(Returns(false), $data) seconds=1
    @btime sum_simd($data) seconds=1
    nothing
end

# ╔═╡ 054d848a-8af2-11eb-1f98-67f5d0b9f4ec
let
    N  = 1_000_000
    array_of_structs = [rand(AlignmentTest) for i in 1:N]
    struct_of_arrays = AlignmentTestVector(
        rand(UInt32, N),
        rand(UInt16, N),
        rand(UInt8, N)
    )

    @btime sum(x -> x.a, $array_of_structs) seconds=1
    @btime sum($struct_of_arrays.a) seconds=1
    nothing
end

# ╔═╡ 0dfc5054-8af2-11eb-098d-35f4e69ae544
md"""
## 专用 CPU 指令

大多数代码只会使用一些简单的 CPU 指令，例如 move、add、multiply、bitshift、and、or、xor、jump 等等。然而，典型现代笔记本电脑中的 CPU 支持 **大量** 的 CPU 指令。通常，如果某个指令在消费者的电脑中频繁用到，那么 CPU 制造商将会添加专用的指令来加速这些操作。凭借指令的硬件层级实现，使用专用指令获得的加速效果非常显著。

Julia仅支持一小部分专用指令，包括：

* 通过 `popcnt` 指令对整数中的 set bits 进行高效计数，对应的函数为 `count_ones`。
* 通过 `tzcnt` 指令统计整数中 trailing zeros 的数目，对应的函数为 `trailing_zeros` 。
* 通过 `bswap` 指令反转多字节整数中各字节的顺序，对应的函数为 `bswap`。此函数在处理[端序](https://en.wikipedia.org/wiki/Endianness)时很有用。

下面的例子展现了手动实现的 `count_ones` 函数和使用内置版 `popcnt` 指令之间的性能差异：
"""

# ╔═╡ 126300a2-8af2-11eb-00ea-e76a979aef45
function manual_count_ones(x)
    n = 0
    while x != 0
        n += x & 1
        x >>>= 1
    end
    return n
end;

# ╔═╡ 14e46866-8af2-11eb-0894-bba824f266f0
let
    data = rand(UInt, 10000)
    @btime sum(manual_count_ones, $data) seconds=1
    @btime sum(count_ones, $data) seconds=1
    nothing
end

# ╔═╡ 1e7edfdc-8af2-11eb-1429-4d4220bad0f0
md"""
此处观察到的时间取决于编译器是否足够聪明，从而明白第一个函数中的计算能被表示为 `popcnt` 指令，并将此函数编译为该指令。在我的电脑上，编译器不能够实现这样的推断，因此在实现相同效果的情况下，第二个函数要快100倍。 

#### 调用任意 CPU 指令
Julia 能够直接调用 CPU 指令。通常不建议这样做，因为不是所有的用户能够使用相同的指令来访问相同的 CPU，所以当运行在不同品牌的电脑上时代码将会崩溃。

最新的 CPU 包含 AES 加密和 SHA256 哈希的专用指令。如果你想调用这些指令，那么可以直接调用 Julia 的编译器后端 LLVM。下面的例子创建了一个直接调用 `vaesenc` （一轮AES加密）指令的函数：
"""

# ╔═╡ 25a47c54-8af2-11eb-270a-5b58c3aafe6e
begin
    # This is a 128-bit CPU "vector" in Julia
    const __m128i = NTuple{2, VecElement{Int64}}

    # Define the function in terms of LLVM instructions
    aesenc(a, roundkey) = ccall(
        "llvm.x86.aesni.aesenc", llvmcall, __m128i,
        (__m128i, __m128i), a, roundkey
    )
end;

# ╔═╡ 2dc4f936-8af2-11eb-1117-9bc10e619ec6
md"（感谢 Kristoffer Carlsson 提供的[例子](http://kristofferc.github.io/post/intrinsics/) ）。我们可通过检查函数的汇编码来验证它是有效的，即汇编码只包含一条 `vaesenc` 指令及 `retq` 与 `nopw` 指令（后两条指令不进行任何操作，仅用于填充以使CPU中的指令对齐）："

# ╔═╡ 76a4e83c-8af2-11eb-16d7-75eaabcb21b6
@code_native debuginfo=:none dump_module=false aesenc(
	__m128i((1, 1)), __m128i((1, 1))
)

# ╔═╡ 797264de-8af2-11eb-0cb0-adf3fbc95c90
md"""使用专用指令的算法能够非常快。[在一篇博客中](https://mollyrocket.com/meowhash)，电子游戏公司 Molly Rocket 推出了一种用于 AES 指令的新型非加密哈希函数，从而获得了前所未有的速度。"""

# ╔═╡ 80179748-8af2-11eb-0910-2b825104159d
md"## 内联（Inlining）  
考虑此函数的汇编码："

# ╔═╡ 36b723fc-8ee9-11eb-1b92-451b992acc0c
f() = error();

# ╔═╡ 8af63980-8af2-11eb-3028-83a935bac0db
md"""
此段代码包含用于调用其他函数的 `callq` 指令。 函数调用会产生一些开销，其取决于函数的参数与其他内容。虽然函数调用的耗时在 ns 数量级，但是若在小循环中调用函数，时间则会累加。 

然而，如果我们查看如下函数的的汇编码：
"""

# ╔═╡ 50ab0cf6-8ee9-11eb-3e04-af5fef7f2850
call_plus(x) = x + 1;

# ╔═╡ 93af6754-8af2-11eb-0fe6-216d76e683de
@code_native debuginfo=:none dump_module=false call_plus(1)

# ╔═╡ a105bd68-8af2-11eb-31f6-3335b4fb0f08
md"""
`call_plus` 函数调用了 `+`，并被编译为单条 `leaq` 指令（也包含 `retq` 与 `nopw`）。但是 `+` 是一般的 Julia 函数，因此 `call_plus`是一个常规 Julia 函数调用另一个函数的例子。那为什么未使用 `callq` 指令来调用 `+`？   

因为，编译已经选择将 `+` 函数**内联**进 `call_plus` 函数。这表明函数不是调用`+`， 而是已经将 `+` 的**内容**直接复制进了 `call_plus`。这样做的好处有：
* 没有函数调用产生的开销
* 不需要构造 `Tuple` 来接收 `+` 函数的参数
* 发生在 `+` 中的任何计算都与 `call_plus` 一起编译，这使得编译器能够结合利用两函数的信息以简化某些计算。 

那么为什么不将**所有**函数内联起来呢？因为，内联复制代码的操作既增加了代码的体积又消耗了内存。另外，为了能被高效地检索，**CPU 指令本身**也需能放进 CPU 缓存（尽管 CPU 指令有自己的缓存）。如果一切都是内联的，那么程序将会拥有非常庞大的体积并陷入瘫痪。仅当内联函数很小时，内联操作才会是提升。

相反，编译器使用启发式方法（经验法则）来确定函数何时足够小，以便内联能够提高性能。这些启发式方法并非万无一失，因此 Julia 提供了 `@noinline` 宏，它能够阻止小函数的内联（例如，对于引发错误的函数很有用，必须假设不常调用）；以及 `@inline` 宏， 它不会**强制**编译器进行内联，但会**强烈地建议**编译器应该内联此函数。

如果代码包含时间敏感的部分，比如内循环，那么查看汇编码就变得非常重要，即通过汇编码验证循环中的小函数是否是内联的。例如，在[我的 kmer 哈希代码的这行](https://github.com/jakobnissen/Kash.jl/blob/b9a6e71acf9651d3614f92d5d4b29ffd136bcb5c/src/kmersketch.jl#L41) 中，若去除 `@inline` 标注，minhashing 的总体性能将会下降一半。

以下方式证明了内联和无内联函数版本间的极端性能差异：
"""

# ╔═╡ a843a0c2-8af2-11eb-2435-17e2c36ec253
begin
    @noinline noninline_poly(x) = x^3 - 4x^2 + 9x - 11
    inline_poly(x) = x^3 - 4x^2 + 9x - 11

    function time_function(F, x::AbstractVector)
        n = 0
        for i in x
            n += F(i)
        end
        return n
    end
end;

# ╔═╡ b4d9cbb8-8af2-11eb-247c-d5b16e0de13f
let
    data = rand(UInt, 1024)
    @btime time_function(noninline_poly, $data) seconds=1
    @btime time_function(inline_poly, $data) seconds=1
    nothing
end

# ╔═╡ bc0a2f22-8af2-11eb-3803-f54f84ddfc46
md"""
## 展开
考虑一个对64位整数向量求和的函数。如果向量数据的内存偏移存储在寄存器 `%r9`，向量的长度存储在寄存器 `%r8`，向量当前元素的索引存储在 `%rcx`，以及使用 `%rax` 遍历计算向量所有元素，那么内循环的汇编码就像下面这样：

```
L1:
    ; add the integer at location %r9 + %rcx * 8 to %rax
    addq   (%r9,%rcx,8), %rax

    ; increment index by 1
    addq   $1, %rcx

    ; compare index to length of vector
    cmpq   %r8, %rcx

    ; repeat loop if index is smaller
    jb     L1
```

每个向量元素对应 4 条指令。Julia 生成的汇编码与此相似，但是还应该包含与边界检查有关的的指令。不过这些指令与本节无关（但应包含不同的注解）。

然而，如果函数写作下面这样：

```julia
function sum_vector(v::Vector{Int})
    n = 0
    i = 1
    for chunk in 1:div(length(v), 4)
        n += v[i + 0]
        n += v[i + 1]
        n += v[i + 2]
        n += v[i + 3]
        i += 4
    end
    return n
end
```

如果假设向量长度刚好能被4整除，那么结果显然一致。若长度不能被4整除，我们很容易先使用此函数求和向量的前 $N - rem(N, 4)$ 元素，然后在另一循环求和剩余元素。尽管两种函数的结果相同，但是两种循环对应的汇编码却不同，后者看起来是：

```
L1:
    addq   (%r9,%rcx,8), %rax
    addq   8(%r9,%rcx,8), %rax
    addq   16(%r9,%rcx,8), %rax
    addq   24(%r9,%rcx,8), %rax
    addq   $4, %rcx
    cmpq   %r8, %rcx
    jb     L1
```

每 4 个条件共使用 7 条指令，或者说每个条件使用 1.75 条指令。这少于每个整数所使用指令的一半！性能加速来自于循环末尾检查次数的减少。我们称此过程为**展开**（Unrolling）循环，在此例中即为除以4。当然，展开只有在提前知道循环次数时可行，因此不会过多执行迭代。通常，编译器会自动展开循环以获得额外的性能，但是汇编码也是值得看一看的。例如，这是在我的电脑上为最内层循环的 `sum([1])` 生成的汇编码：

    L144:
        vpaddq  16(%rcx,%rax,8), %ymm0, %ymm0
        vpaddq  48(%rcx,%rax,8), %ymm1, %ymm1
        vpaddq  80(%rcx,%rax,8), %ymm2, %ymm2
        vpaddq  112(%rcx,%rax,8), %ymm3, %ymm3
        addq    $16, %rax
        cmpq    %rax, %rdi
        jne L144

此处可以看到，不仅以4为因数展开，而且使用了 256 位 SIMD 指令，总共 128 比特，每次迭代相加16个整数，或者说每个整数平均使用 0.44 条指令。

同时注意到，编译器使用了 4 个不同的 `ymm` SIMD 寄存器，`ymm0` 到 `ymm3`， 而我所示例的汇编码只使用了一个寄存器 `rax`。这是因为，如果使用4个独立的寄存器，那么在 CPU 执行下一次操作时不需要等待 `vpaddq` 操作完成（记住，它有 ~3 时钟周期的延迟）。

展开的情况与SIMD类似：只有在**确定**不会超出迭代次数时，编译器才会展开循环。例如，比较如下两函数：
"""

# ╔═╡ f0bc1fdc-8ee9-11eb-2916-d71e1cf36375
let
    data = fill(false, 2^20)

    # any: Stops as soon as it finds a `true`
    @btime any($data) seconds=1

    # foldl: Loops over all values in the array
    @btime foldl(|, $data) seconds=1

    data[1] = true
    @btime any($data) seconds=1
    @btime foldl(|, $data) seconds=1
    nothing
end

# ╔═╡ 36a2872e-8eeb-11eb-0999-4153ced71678
md"""
第一个函数只要发现一个 `true` 值就会停下并返回 —— 但循环中断禁止了 SIMD 与展开。 第二个函数会持续遍历整个数组，即使第一个值为 `true`。尽管这种方法允许了 SIMD 与展开，但是若 `true` 值在非常靠前的位置，这也就显然会存在性能浪费。因此，当我们期望在数组的前 1/4 发现第一个 `true` 值时，第一个函数更好，否则后者更好。 

我们还可以创建基于手动展开的折中方案。在下面的函数中，`check128` 使用 `inbounds` 检查 128 元素，而不是停下来检查是否找到 `true` 值，故此函数允许 SIMD 与展开。 然后 `unroll_compromise` 调用 `check128`， 只要找到 `true` 值就跳出循环。
"""

# ╔═╡ 9ca70cfc-8eeb-11eb-361b-b929089ca109
begin
    @inline function check128(data, i)
        n = false
        @inbounds for j in 0:127
            n |= data[i+j]
        end
        n
    end

    function unroll_compromise(data)
        found = false
        i = 1
        while !found & (i ≤ length(data))
            check128(data, i) && return true
            i += 128
        end
        return false
    end
end;

# ╔═╡ d4a43094-8eeb-11eb-106f-3b54253aa663
let
    data = fill(false, 2^20)
    @btime foldl(|, $data) seconds=1
    @btime unroll_compromise($data) seconds=1

    data[1] = true
    @btime any($data) seconds=1
    @btime unroll_compromise($data) seconds=1
    nothing
end

# ╔═╡ 270950ac-8eed-11eb-365d-df9d36d090bc
md"""
可以看到，当数组无 `true` 和 `true` 非常靠前时，函数拥有极好的性能。

不幸的是，当我们想要在展开较小数据块和迭代不同数据块间做出折中时，我想不到什么方法可以自动生成这种展开。也许将来，这种想法能够交给编译器，让编译器能够自动生成这种优化过的代码。
"""

# ╔═╡ c36dc5f8-8af2-11eb-3f35-fb86143a54d2
md"""
## 避免不可预测的分支
如前所述，CPU 指令需要花费多个时钟周期，但可能要在前面的指令完成计算前放入队列。那么当 CPU 遇到分支时会发生什么（例如，跳转指令）？它会不知道接下来将哪条指令放入队列，因为这取决于前面刚刚放入队列的指令以及那些还未执行的指令。

现代 CPU 会使用 **分支预测**。 CPU 中有一个 **分支预测器** 电路，它能够基于最近选择的分支猜测接下来的正确分支。实际上，当代码运行时，分支预测器会尝试从代码中已执行的分支中学习一些简单模式。在将之前的分支放入队列后，CPU 立即将分支预测器预测的所有分支的指令放入队列。然后在执行队列中的分支时验证猜测的正确性。如果猜测正确，这很棒，CPU 借助猜测节省了时间。如果猜测错误， 那么 CPU 不得不清空计算管道，并丢弃自最初的猜测开始以来的所有计算过程。这个过程会导致大约几纳秒的延迟。

对于程序员来说，这意味着 if 语句的速度取决于它的分支有多容易被猜测。如果非常容易猜测，那么分支预测器将几乎一直是正确的，同时 if 语句将只需要 1 条指令，一般为 1 时钟周期。在分支完全随机的情形中，它将在整个过程中大约具有 50% 的正确率，同时每次错误预测都会导致消耗很多时钟周期。

循环中的分支是最容易猜测的。如果有一个迭代 1000 元素的循环，代码循环 999 次而只返回 1 次。因此分支预测器通常能简单地预测为 “循环”，并且有 99.9% 的准确率。

可以使用如下的简单函数演示分支预测错误的性能：
"""

# ╔═╡ c96f7f50-8af2-11eb-0513-d538cf6bc619
# Copy all odd numbers from src to dst.
function copy_odds_branches!(dst::Vector{T}, src::Vector{T}) where {T <: Integer}
    write_index = 1
    @inbounds for i in eachindex(src) # <--- this branch is trivially easy to predict
        v = src[i]
        if isodd(v)  # <--- this is the branch we want to predict
            dst[write_index] = v
            write_index += 1
        end
    end
    return dst
end;

# ╔═╡ cf90c600-8af2-11eb-262a-2763ae29b428
let
    dst = rand(UInt32, 2^18)
    src_random = rand(UInt32, 2^18)
    src_all_odd = [(2*i+1) % UInt32 for i in src_random]
    @btime copy_odds_branches!($dst, $src_random) seconds=1
    @btime copy_odds_branches!($dst, $src_all_odd) seconds=1
    nothing
end

# ╔═╡ d53422a0-8af2-11eb-0417-b9740c4a571c
md"""
在第一个例子中，整数是随机的，并且大约一半的分支预测错误从而引起延迟。在第二个例子中，总是选择该分支，分支预测器能够迅速习得预测模式，并将具有接近 100% 的预测正确率。因此，在我的电脑上，后者大约快 8 倍。

要注意的是，若你使用更小的向量并多次重复计算，就像 `@btime` 做的那样，那么分支预测器将能通过记忆学习小向量的模式，并取得比随机预测更好的性能。这在现代 CPU （我听说特别是 AMD 出售的 CPU）中特别明显，因为它们的分支预测器做得更好。这种 “记忆学习” 模式是基准测试过程中循环的产物。你不会期望对真实数据重复执行完全相同的计算：
"""

# ╔═╡ dc5b9bbc-8af2-11eb-0197-9b5da5087f0d
let
    src_random = rand(UInt32, 128)
    dst = similar(src_random)
    src_all_odd = [(2i+1) % UInt32 for i in src_random]

    @btime copy_odds_branches!($dst, $src_random) seconds=1
    @btime copy_odds_branches!($dst, $src_all_odd) seconds=1
    nothing
end

# ╔═╡ e735a302-8af2-11eb-2ce7-01435b60fdd9
md"""
若预测正确，这些分支会非常快。假设代码本质上不存在错误，那么错误检查引起的高可预测性分支不会带来太多的性能损失。因此边界检查这样的分支会非常快。然而，只有获得最佳性能非常重要时，或者出现在可 SIMD 向量化的循环中，边界检查才应该被去除。

若分支不能简单地预测，那么通常应该改写代码以避免所有的分支。例如，对于上面的`copy_odds!` 函数例子，可以像下面这样改写：
"""

# ╔═╡ eb158e60-8af2-11eb-2227-59d6404e3335
function copy_odds_branchless!(dst::Vector{T}, src::Vector{T}) where {T <: Integer}
    write_index = 1
    @inbounds for i in eachindex(src)
        v = src[i]
        dst[write_index] = v
        write_index += isodd(v)
    end
    return dst
end;

# ╔═╡ ee579dca-8af2-11eb-140f-a96778b7b39f
let
    dst = rand(UInt32, 2^18)
    src_random = rand(UInt32, 2^18)
    src_all_odd = [(2*i+1) % UInt32 for i in src_random]
    @btime copy_odds_branchless!($dst, $src_random) seconds=1
    @btime copy_odds_branchless!($dst, $src_all_odd) seconds=1
    nothing
end

# ╔═╡ f969eed2-8af2-11eb-1e78-5b322a7f4ebd
md"""
上述代码除了一个由循环本身引起的分支（容易预测）外不含任何分支。另外，速度上稍差于完美预测的情况，但是比随机数据要好很多。

当可以使用其他指令执行相同的计算时，编译器通常会移除分支。若编译器不能做到这一点，Julia 提供的 `ifelse` 函数有时也能帮助删除分支。
"""

# ╔═╡ 72e1b146-8c1c-11eb-2c56-b1342271c2f6
md"""
## 注意内存依赖

考虑更深一点，上面完美预测的例子 **为什么** 比完全避免了额外分支的解决方法还要快?

我们来看一下汇编码。此处只展示了循环部分的汇编码（因为几乎所有的时间都花费在此）

对于多分支的版本，我们有：
```julia
1 L48:
2     incq	%rsi
3     cmpq	%rsi, %r9
4     je	L75
5 L56:
6     movq	(%rdx,%rsi,8), %rcx
7     testb	$1, %cl
8     je	L48
9     movq	%rcx, -8(%r8,%rdi,8)
10	incq	%rdi
11	jmp	L48
```

对于少分支的版本，我们有：
```julia
1 L48:
2	movq	(%r9,%rcx,8), %rdx
3	incq	%rcx
4	movq	%rdx, -8(%rsi,%rdi,8)
5	andl	$1, %edx
6	addq	%rdx, %rdi
7	cmpq	%rcx, %r8
8	jne	L48
```

多分支版本每次迭代执行 9 条指令（记住，所有的迭代都是无规律的数），而少分支版本每次只执行 7 条指令。查看指令耗时的表格，你就会发现这些指令都很快。那么这是什么呢？

为了理解发生了什么，我们需要研究 CPU 的更深层次。实际上，CPU 不会像汇编码那样以线性顺序执行这些 CPU 指令。反而，一个更精确（但仍做简化）的流程如下：

1. CPU 读入所有的 CPU 指令。然后立即将这些 CPU 指令翻译为更低级的指令，它们被称为 _micro-operations_ 或 _µops_。 µops 和 CPU 指令的重要区别是 CPU 指令只能引用少数几个不同的寄存器，然而真实的处理器拥有更多的寄存器，这些寄存器可以被 µops 访问。使用 µops 编写的代码称为**微指令**（microcode）。

2. 这些微指令被加载到名为 **重排缓冲区**（reorder buffer）的内部数组中。CPU 一次性可在重排缓冲区保存 200 多条指令。这种存储方式是为了以高度并行的方式执行微指令。然后批量发送代码到执行部分。

3. 最后， 然后以正确的顺序将重排缓冲区的结果发送到内存。

重排缓冲区的存在对你应该如何思考代码有两个重要影响（我所知道的）：

首先，通常以并行方式执行大块代码，并不需要与加载的顺序相同。因此，如果使用较多、较慢 CPU 指令的程序能够并行执行更多 CPU 指令，那么它能比使用较少、较快 CPU 指令的程序更快。

其次，分支预测（参见上节的讨论）不仅会发生在紧接着的分支，还会同时发生在大量的未来分支上。

在可视化小循环 `copy_odds_branches!` 代码的执行过程时，你可以想象分支预测器预测了所有分支，即循环中未来的 6 次迭代， 将6次迭代的微指令加载到重排缓冲区，并行执行它们，**然后** 验证（仍然是并行的）分支是否猜测正确。

很明显，这种批处理正是分支预测错误导致性能糟糕的原因 —- 如果某个分支被发现是错误预测的，那么重排缓冲区的所有的工作都应被抛弃，然后 CPU 必须重新开始拉取新指令，并将其编译为微指令等等。

然后继续考虑重排缓冲区的影响。除了创建难以预测的分支外，我们能够编写什么样的代码来打乱CPU的工作流程？

我们这样做会发生什么？
"""

# ╔═╡ 7732b6d8-8dab-11eb-0bc2-19690386ec27
function read_indices(dst::Vector{T}, src::Vector{T}) where {T <: Integer}
    i = 1
    while i ≤ lastindex(src) - 1
        i = src[i] + 1
        dst[i] = i
    end
    return dst
end;

# ╔═╡ 29463b02-8dab-11eb-0bf5-23a3f4075b32
let
    dst = rand(UInt32, 2^18)
    src = UInt32.(eachindex(dst))
    @btime read_indices($dst, $src) seconds=1
    nothing
end

# ╔═╡ a5d93434-8dac-11eb-34bf-91061089f0ef
md"""
仔细想想， `read_indices` 要比任何版本的 `copy_odds` 函数进行的操作都少。它甚至不检查复制的数是否为奇数。然而，它要比 `copy_odds_branches` 慢 3 倍！

区别正是 **内存依赖**。看见输入数据是一组简单的数字，我们人类就能准确地明白函数在每次迭代时执行的操作：简单地拷贝下一个数而已。但是，编译器**不能** 预测下一个即将加载的数，因此需要存储已加载的数。故称代码在从 `src` 加载数这部分产生了内存依赖。

在此例中，重排缓冲区排不上用场。所有的指令都被加载进 CPU，但只能在重排缓冲区处于闲置状态，因为在“轮到它们”之前，他们**不能**被执行。

Going back to the original example, that is why the perfectly predicted `copy_odds_branches!` performs better than `code_odds_branchless!`. Even though the latter has fewer instructions, it has a memory dependency: The index of `dst` where the odd number gets stored to depends on the last loop iteration. So fewer instructions can be executed at a time compared to the former function, where the branch predictor predicts several iterations ahead and allow for the parallel computation of multiple iterations.
回到最初的例子，这就是为什么完美预测的 `copy_odds_branches!` 比 `code_odds_branchless!` 还要快。即使后者具有更少的指令，但是它具有内存依赖性：保存奇数的 `dst` 的索引取决于上一次迭代。而在前者执行时，分支预测器预测几次迭代，并且允许并行计算多次迭代。所以，相比前者一次只能执行更少的指令。
"""

# ╔═╡ 0b6d234e-8af3-11eb-1ba9-a1dcf1497785
md"""
## 变化的时钟速度

做了功耗优化的现代笔记本电脑 CPU 大约只消耗 25W 的功率，但是芯片只有邮票大小（比人的头发丝还薄）。如果没有适当的散热，那么 CPU 的温度将会飙升，CPU 芯片中的塑料将会融化，芯片也就被毁坏了。一般情况下，CPU 的最高工作温度大约在 100 摄氏度。功耗和发热取决于诸多由时钟速度影响的因素，更高的时钟速度往往产生更多的热量。    

为了避免自毁，现代 CPU 能够根据工作温度来调整其时钟速度。通常，CPU 工作温度会限制 CPU 的运行速度。在这些情景中，更好的物理散热直接意味着更快的 CPU。对于旧电脑，简单清理内部灰尘并替换散热扇和[CPU 导热膏](https://zh.wikipedia.org/wiki/%E5%B0%8E%E7%86%B1%E8%86%8F) 即可使其重获新生！

作为程序员，我们在 CPU 温度这件事上能做的不多，但了解的话更好。特别是，可观测到的性能差异通常可以用CPU 温度的改变来解释：

* CPU 通常在负载刚开始时工作得最快，然后在达到最高温度时出现性能下降。
* 与普通指令相比， SIMD 指令需要更多能量，产生更多的热量，并且会降低时钟频率。这会降低由 SIMD 带来的性能提升，但SIMD在其能生效时总是更高效的。一个例外是最近较新的 512 位 SIMD 指令。在现在（2021）的 CPU 上，这些指令消耗更多能量从而导致时钟频率降低，实际上会在某些负载中出现总体上的性能下降。这个问题可能会在不远的将来解决。要么降低指令功耗，要么消费者放弃 512 位 SIMD, 抑或是编译器拒绝编译这些指令。
"""

# ╔═╡ 119d269c-8af3-11eb-1fdc-b7ac75b89cf2
md"""
## 多线程
在古早年代，随着新处理器上市，CPU 时钟速度每年都会增长。部分提升是因为散热，但当 CPU 达到 3 GHz 后，这种加速效果就会减弱。现在，我们可以看到处理器代际间的时钟速度增量很小。现在的重点已经转移到了在每个时钟周期内执行更多的计算，而不是关注真实的执行速度。CPU 缓存、CPU 指令流水线（即重排缓冲区“工作流”）、分支预测以及 SIMD 指令都是这一领域的重要贡献，这些也都包含在本文。

另一 CPU 改进的重要方向是增加数量：几乎所有的 CPU 芯片都包含多个小型 CPU, 或者说 **核**。每个核都有它们自己的小型 CPU 缓存，并且能够并行地进行计算。另外，许多CPU 都支持一种叫做 **超线程** 的特性，它使得两个 **线程** （即指令流）能够运行在一个内核上。其思想是，当一个进程停止时（比如因为遭遇了缓存未命中或分支预测错误），另一个进程能够在同一个核上继续执行。CPU “假装“ 拥有两倍的处理器。

仅当线程可能会停止工作时，超线程技术才有意义。线程暂停的原因除了 CPU 内部的如缓存未命中，还可能是是等待外部资源，比如 web 服务器返回的数据或从硬盘读取的数据。如果在你编写的程序中部分线程花费大量的时间空转，那么内核即可被其他线程使用，此时超线程体现出了它的价值。

接下来看看第一个并行程序。首先，我们需要确保 Julia 启动了正确数量的线程。实现方式是启动时添加 `-t` 选项 —— 例如`-t 8`对应 8 线程。 我的 Julia 设置为了 4 线程：  
"""

# ╔═╡ 1886f60e-8af3-11eb-2117-eb0014d2fca1
Threads.nthreads()

# ╔═╡ 1a0e2998-8af3-11eb-031b-a3448fd65041
# Spend about half the time waiting, half time computing
function half_asleep(start::Bool)
    a, b = 1, 0
    for iteration in 1:5
        start && sleep(0.1)
		t1 = time()
		while time() - t1 < 0.1
			for i in 1:100000
                a, b = a + b, a
            end
        end
        start || sleep(0.1)
    end
    return a
end;

# ╔═╡ 1ecf434a-8af3-11eb-3c49-cb21c6a80bfc
function parallel_sleep(n_jobs)
    jobs = []
    for job in 1:n_jobs
        push!(jobs, Threads.@spawn half_asleep(isodd(job)))
    end
    return sum(fetch, jobs)
end;

# ╔═╡ 2192c228-8af3-11eb-19d8-81db4f3c0d81
let
    parallel_sleep(1); # run once to compile it
    for njobs in (1, 4, 8, 16, 32)
        @time parallel_sleep(njobs);
    end
end

# ╔═╡ 2d0bb0a6-8af3-11eb-384d-29fbb0f66f24
md"""
可以看到在此任务中，我的电脑并行运行 8 项任务几乎和运行一项任务一样快。但是16 项任务花费的时间多些。这是因为 4 个任务可以同时运行，另外 4 个任务处于休眠状态，总共同时运行8个程序。

对于 CPU 密集型程序，内存总是忙于一个线程，程序员并不能利用超线程做太多事。实际上，对于多数已经优化过的程序，**禁用** 超线程通常会带来更好的性能。然而，大多数程序是未被优化的，故可以从超线程中获益。

#### Parallelizability
Multithreading is more difficult that any of the other optimizations, and should be one of the last tools a programmer reaches for. However, it is also an impactful optimization. Scientific compute clusters usually contain many (e.g. hundreds, or thousands) of CPUs with tens of CPU cores each, offering a massive potential speed boost ripe for picking.

A prerequisite for efficient use of multithreading is that your computation is able to be broken up into multiple chunks that can be worked on independently. Luckily the majority of compute-heavy tasks (at least in my field of work, bioinformatics), contain sub-problems that are *embarassingly parallel*. This means that there is a natural and easy way to break it into sub-problems that can be processed independently. For example, if a certain __independent__ computation is required for 100 genes, it is natural to use one thread for each gene. The size of the problem is also important. There is a small overhead involved with spawning (creating) a thread, and fetching the result from the computation of a thread. Therefore, for it to pay off, each thread should have a task that takes at least a few microseconds to complete.

Let's have an example of a small embarrasingly parallel problem. We want to construct a [Julia set](https://en.wikipedia.org/wiki/Julia_set). Julia sets are named after Gaston Julia, and have nothing to do with the Julia language. Julia sets are (often) fractal sets of complex numbers. By mapping the real and complex component of the set's members to the X and Y pixel value of a screen, one can generate the LSD-trippy images associated with fractals.

The Julia set I create below is defined thus: We define a function $f(z) = z^2 + C$, where $C$ is some constant. We then record the number of times $f$ can be applied to any given complex number $z$ before $|z| > 2$. The number of iterations correspond to the brightness of one pixel in the image. We simply repeat this for a range of real and imaginary values in a grid to create an image.

First, let's see a non-parallel solution:
"""

# ╔═╡ 316e5074-8af3-11eb-256b-c5b212f7e0d3
begin
    const SHIFT = Complex{Float32}(-0.221, -0.713)

    f(z::Complex) = z^2 + SHIFT

    "Set the brightness of a particular pixel represented by a complex number"
    function mandel(z)
        n = 0
        while ((abs2(z) < 4) & (n < 255))
            n += 1
            z = f(z)
        end
        return n
    end

    "Set brightness of pixels in one column of pixels"
    function fill_column!(M::Matrix, x, real)
        for (y, im) in enumerate(range(-1.0f0, 1.0f0, length=size(M, 1)))
            M[y, x] = mandel(Complex{Float32}(real, im))
        end
    end

    "Create a Julia fractal image"
    function julia_single_threaded()
        M = Matrix{UInt8}(undef, 5000, 5000)
        for (x, real) in enumerate(range(-1.0f0, 1.0f0, length=size(M, 2)))
            fill_column!(M, x, real)
        end
        return M
    end
end;

# ╔═╡ 37cd1f1c-8ee9-11eb-015c-ade9efc27708
@code_native debuginfo=:none dump_module=false f()

# ╔═╡ 39a85a58-8af3-11eb-1334-6f50ed9acd31
@time julia_single_threaded();

# ╔═╡ 3e83981a-8af3-11eb-3c87-77797adb7e1f
md"That took around 2 seconds on my computer. Now for a parallel one:"

# ╔═╡ 3e1c4090-8af3-11eb-33d0-b9c299fef20d
begin
    function recursive_fill_columns!(M::Matrix, cols::UnitRange)
        F, L = first(cols), last(cols)
        # If only one column, fill it using fill_column!
        if F == L
            r = range(-1.0f0,1.0f0,length=size(M, 1))[F]
            fill_column!(M, F, r)
        # Else divide the range of columns in two, spawning a new task for each half
        else
            mid = div(L+F,2)
            p = Threads.@spawn recursive_fill_columns!(M, F:mid)
            recursive_fill_columns!(M, mid+1:L)
            wait(p)
        end
    end

    function julia_multi_threaded()
        M = Matrix{UInt8}(undef, 5000, 5000)
        recursive_fill_columns!(M, 1:size(M, 2))
        return M
    end
end;

# ╔═╡ 4be905b4-8af3-11eb-0344-dbdc7e94ddf3
@time julia_multi_threaded();

# ╔═╡ 4e8f6cb8-8af3-11eb-1746-9384995d7022
md"""
This is almost exactly 4 times as fast! With 4 threads, this is close to the best case scenario, only possible for near-perfect embarrasingly parallel tasks.

Despite the potential for great gains, in my opinion, multithreading should be one of the last resorts for performance improvements, for three reasons:

1. Implementing multithreading is harder than other optimization methods in many cases. In the example shown, it was very easy. In a complicated workflow, it can get messy quickly.
2. Multithreading can cause hard-to-diagnose and erratic bugs. These are almost always related to multiple threads reading from, and writing to the same memory. For example, if two threads both increment an integer with value `N` at the same time, the two threads will both read `N` from memory and write `N+1` back to memory, where the correct result of two increments should be `N+2`! Infuriatingly, these bugs appear and disappear unpredictably, since they are causing by unlucky timing. These bugs of course have solutions, but it is tricky subject outside the scope of this document.
3. Finally, achieving performance by using multiple threads is really achieving performance by consuming more resources, instead of gaining something from nothing. Often, you pay for using more threads, either literally when buying cloud compute time, or when paying the bill of increased electricity consumption from multiple CPU cores, or metaphorically by laying claim to more of your users' CPU resources they could use somewhere else. In contrast, more *efficent* computation costs nothing.
"""

# ╔═╡ 54d2a5b8-8af3-11eb-3273-85d551fceb7b
md"""
## GPUs
So far, we've covered only the most important kind of computing chip, the CPU. But there are many other kind of chips out there. The most common kind of alternative chip is the *graphical processing unit* or GPU.

As shown in the above example with the Julia set, the task of creating computer images are often embarassingly parallel with an extremely high degree of parallelizability. In the limit, the value of each pixel is an independent task. This calls for a chip with a high number of cores to do effectively. Because generating graphics is a fundamental part of what computers do, nearly all commercial computers contain a GPU. Often, it's a smaller chip integrated into the motherboard (*integrated graphics*, popular in small laptops). Other times, it's a large, bulky card.

GPUs have sacrificed many of the bells and whistles of CPUs covered in this document such as specialized instructions, SIMD and branch prediction. They also usually run at lower frequencies than CPUs. This means that their raw compute power is many times slower than a CPU. To make up for this, they have a high number of cores. For example, the high-end gaming GPU NVIDIA RTX 2080Ti has 4,352 cores. Hence, some tasks can experience 10s or even 100s of times speedup using a GPU. Most notably for scientific applications, matrix and vector operations are highly parallelizable.

Unfortunately, the laptop I'm writing this document on has only integrated graphics, and there is not yet a stable way to interface with integrated graphics using Julia, so I cannot show examples.

There are also more esoteric chips like TPUs (explicitly designed for low-precision tensor operations common in deep learning) and ASICs (an umbrella term for highly specialized chips intended for one single application). At the time of writing, these chips are uncommon, expensive, poorly supported and have limited uses, and are therefore not of any interest for non-computer science researchers.
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"

[compat]
BenchmarkTools = "~1.1.3"
PlutoUI = "~0.7.39"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

[[AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "8eaf9f1b4921132a4cff3f36a1d9ba923b14a481"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.4"

[[ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Statistics", "UUIDs"]
git-tree-sha1 = "42ac5e523869a84eac9669eaceed9e4aa0e1587b"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.1.4"

[[ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "0.5.2+0"

[[Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "c47c5fa4c5308f27ccaac35504858d8914e102f9"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.4"

[[IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "3c837543ddb02250ef42f4738347454f95079d4e"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.3"

[[LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.0+0"

[[Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.2.1"

[[NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.20+0"

[[Parsers]]
deps = ["Dates"]
git-tree-sha1 = "3d5bf43e3e8b412656404ed9466f1dcbf7c50269"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.4.0"

[[Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.8.0"

[[PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "UUIDs"]
git-tree-sha1 = "8d1f54886b9037091edf146b517989fc4a09efec"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.39"

[[Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.0"

[[Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[Tricks]]
git-tree-sha1 = "6bac775f2d42a611cdfcd1fb217ee719630c4175"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.6"

[[UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.12+3"

[[libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.1.1+0"

[[nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"
"""

# ╔═╡ Cell order:
# ╟─15f5c31a-8aef-11eb-3f19-cf0a4e456e7a
# ╟─5dd2329a-8aef-11eb-23a9-7f3c325bcf74
# ╠═7490def0-8aef-11eb-19ce-4b11ce5a9328
# ╠═675e66aa-8aef-11eb-27be-5fe273e33297
# ╟─800d827e-8c20-11eb-136a-97a622a7c1e6
# ╟─9a24985a-8aef-11eb-104a-bd9abf0adc6d
# ╟─a2fad250-8aef-11eb-200f-e5f8caa57a67
# ╠═abb45d6a-8aef-11eb-37a4-7b10847b39b4
# ╠═bff99828-8aef-11eb-107b-a5c67101c735
# ╟─cdde6fe8-8aef-11eb-0a3c-77e28f7a2c09
# ╟─f58d428c-8aef-11eb-3127-89d729e23823
# ╠═b73605ca-8ee4-11eb-1a0d-bb6678de91c6
# ╟─c6da4248-8c19-11eb-1c16-093695add9a9
# ╠═ffca4c72-8aef-11eb-07ac-6d5c58715a71
# ╟─d4c67b82-8c1a-11eb-302f-b79c86412ce5
# ╠═e71e4798-8ee4-11eb-3ea2-fdbbcdcf7410
# ╟─0f2ac53c-8c1b-11eb-3841-27f4ea1e9617
# ╟─12f1228a-8af0-11eb-0449-230ae20bfa7a
# ╠═18e8e4b6-8af0-11eb-2f17-2726f162e9b0
# ╠═1f38f8c6-8ee5-11eb-1c01-f3706534a9cf
# ╟─3a1efd5a-8af0-11eb-21a2-d1011f16555c
# ╠═3fae31a0-8af0-11eb-1ea8-7980e7875039
# ╟─5b10a2b6-8af0-11eb-3fe7-4b78b4c22550
# ╠═6061dc94-8af0-11eb-215a-4f3af731774e
# ╟─624eae74-8af0-11eb-025b-8b68dc55f31e
# ╠═d4c8c38c-8ee6-11eb-0b49-33fbfbd214f3
# ╟─7b979410-8af0-11eb-299c-af0a5d740c24
# ╟─8802ff60-8af0-11eb-21ac-b9fdbeac7c24
# ╠═a36582d4-8af0-11eb-2b5a-e577c5ed07e2
# ╠═a74a9966-8af0-11eb-350f-6787d2759eba
# ╟─ae9ee028-8af0-11eb-10c0-6f2db3ab8025
# ╟─b73b5eaa-8af0-11eb-191f-cd15de19bc38
# ╟─c0c757b2-8af0-11eb-38f1-3bc3ec4c43bc
# ╠═c5472fb0-8af0-11eb-04f1-95a1f7b6b9e0
# ╟─ce0e65d4-8af0-11eb-0c86-2105c26b62eb
# ╠═d376016a-8af0-11eb-3a15-4322759143d1
# ╟─d70c56bc-8af0-11eb-1220-09e78dba26f7
# ╠═dc24f5a0-8af0-11eb-0332-2bc0834d426c
# ╟─e3c136de-8af0-11eb-06f1-9393c0f95fbb
# ╠═e836dac8-8af0-11eb-1865-e3feeb011fc4
# ╟─ecfd04e4-8af0-11eb-0962-f548d2eabad3
# ╠═f0e24b50-8af0-11eb-1a0e-5d925f3743e0
# ╠═11c500e8-8ee2-11eb-3291-4382b60c5a2b
# ╟─22512ab2-8af1-11eb-260b-8d6c16762547
# ╠═2a7c1fc6-8af1-11eb-2909-554597aa2949
# ╟─2e3304fe-8af1-11eb-0f6a-0f84d58326bf
# ╠═33350038-8af1-11eb-1ff5-6d42d86491a3
# ╟─3713a8da-8af1-11eb-2cb2-1957455227d0
# ╠═59f58f1c-8af1-11eb-2e88-997e9d4bcc48
# ╟─5c86e276-8af1-11eb-2b2e-3386e6795f37
# ╠═61ee9ace-8af1-11eb-34bd-c5af962c8d82
# ╟─6849d9ec-8af1-11eb-06d6-db49af4796bc
# ╠═6ba266f4-8af1-11eb-10a3-3daf6e473142
# ╟─74a3ddb4-8af1-11eb-186e-4d80402adfcf
# ╠═7a88c4ba-8af1-11eb-242c-a1813a9e6741
# ╟─7d3fcbd6-8af1-11eb-0441-2f88a9d59966
# ╠═84c0d56a-8af1-11eb-30f3-d137b377c31f
# ╟─8c2ed15a-8af1-11eb-2e96-1df34510e773
# ╠═94182f88-8af1-11eb-207a-37083c1ead68
# ╠═a0286cdc-8af1-11eb-050e-072acdd4f0a0
# ╟─aa3931fc-8af1-11eb-2f42-f582b8e639ad
# ╠═c01bf4b6-8af1-11eb-2f17-bfe0c93d48f9
# ╟─c80e05ba-8af1-11eb-20fc-235b45f2eb4b
# ╠═cc99d9ce-8af1-11eb-12ec-fbd6df3becc8
# ╟─e3931226-8af1-11eb-0da5-fb3c1c22d12e
# ╠═e793e300-8af1-11eb-2c89-e7bc1be249f0
# ╠═e8d2ec8e-8af1-11eb-2018-1fa4df5b47ad
# ╟─f0a4cb58-8af1-11eb-054c-03192285b5e2
# ╟─f5c28c92-8af1-11eb-318f-5fa059d8fd80
# ╠═fc2d2f1a-8af1-11eb-11a4-8700f94e866e
# ╟─007cd39a-8af2-11eb-053d-f584d68f7d2f
# ╠═72fbb3ec-8ee8-11eb-3836-11092ef74e86
# ╠═054d848a-8af2-11eb-1f98-67f5d0b9f4ec
# ╟─0dfc5054-8af2-11eb-098d-35f4e69ae544
# ╠═126300a2-8af2-11eb-00ea-e76a979aef45
# ╠═14e46866-8af2-11eb-0894-bba824f266f0
# ╟─1e7edfdc-8af2-11eb-1429-4d4220bad0f0
# ╠═25a47c54-8af2-11eb-270a-5b58c3aafe6e
# ╟─2dc4f936-8af2-11eb-1117-9bc10e619ec6
# ╠═76a4e83c-8af2-11eb-16d7-75eaabcb21b6
# ╟─797264de-8af2-11eb-0cb0-adf3fbc95c90
# ╟─80179748-8af2-11eb-0910-2b825104159d
# ╠═36b723fc-8ee9-11eb-1b92-451b992acc0c
# ╠═37cd1f1c-8ee9-11eb-015c-ade9efc27708
# ╟─8af63980-8af2-11eb-3028-83a935bac0db
# ╠═50ab0cf6-8ee9-11eb-3e04-af5fef7f2850
# ╠═93af6754-8af2-11eb-0fe6-216d76e683de
# ╟─a105bd68-8af2-11eb-31f6-3335b4fb0f08
# ╠═a843a0c2-8af2-11eb-2435-17e2c36ec253
# ╠═b4d9cbb8-8af2-11eb-247c-d5b16e0de13f
# ╟─bc0a2f22-8af2-11eb-3803-f54f84ddfc46
# ╠═f0bc1fdc-8ee9-11eb-2916-d71e1cf36375
# ╟─36a2872e-8eeb-11eb-0999-4153ced71678
# ╠═9ca70cfc-8eeb-11eb-361b-b929089ca109
# ╠═d4a43094-8eeb-11eb-106f-3b54253aa663
# ╟─270950ac-8eed-11eb-365d-df9d36d090bc
# ╟─c36dc5f8-8af2-11eb-3f35-fb86143a54d2
# ╠═c96f7f50-8af2-11eb-0513-d538cf6bc619
# ╠═cf90c600-8af2-11eb-262a-2763ae29b428
# ╟─d53422a0-8af2-11eb-0417-b9740c4a571c
# ╠═dc5b9bbc-8af2-11eb-0197-9b5da5087f0d
# ╟─e735a302-8af2-11eb-2ce7-01435b60fdd9
# ╠═eb158e60-8af2-11eb-2227-59d6404e3335
# ╠═ee579dca-8af2-11eb-140f-a96778b7b39f
# ╟─f969eed2-8af2-11eb-1e78-5b322a7f4ebd
# ╟─72e1b146-8c1c-11eb-2c56-b1342271c2f6
# ╠═7732b6d8-8dab-11eb-0bc2-19690386ec27
# ╠═29463b02-8dab-11eb-0bf5-23a3f4075b32
# ╟─a5d93434-8dac-11eb-34bf-91061089f0ef
# ╟─0b6d234e-8af3-11eb-1ba9-a1dcf1497785
# ╟─119d269c-8af3-11eb-1fdc-b7ac75b89cf2
# ╠═1886f60e-8af3-11eb-2117-eb0014d2fca1
# ╠═1a0e2998-8af3-11eb-031b-a3448fd65041
# ╠═1ecf434a-8af3-11eb-3c49-cb21c6a80bfc
# ╠═2192c228-8af3-11eb-19d8-81db4f3c0d81
# ╟─2d0bb0a6-8af3-11eb-384d-29fbb0f66f24
# ╠═316e5074-8af3-11eb-256b-c5b212f7e0d3
# ╠═39a85a58-8af3-11eb-1334-6f50ed9acd31
# ╟─3e83981a-8af3-11eb-3c87-77797adb7e1f
# ╠═3e1c4090-8af3-11eb-33d0-b9c299fef20d
# ╠═4be905b4-8af3-11eb-0344-dbdc7e94ddf3
# ╟─4e8f6cb8-8af3-11eb-1746-9384995d7022
# ╟─54d2a5b8-8af3-11eb-3273-85d551fceb7b
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
