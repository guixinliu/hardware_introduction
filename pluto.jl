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

#### Not all objects need to be allocated
Inside RAM, data is kept on either the *stack* or the *heap*. The stack is a simple data structure with a beginning and end, similar to a `Vector` in Julia. The stack can only be modified by adding or subtracting elements from the end, analogous to a `Vector` with only the two mutating operations `push!` and `pop!`. These operations on the stack are very fast. When we talk about "allocations", however, we talk about data on the heap. Unlike the stack, the heap has an unlimited size (well, it has the size of your computer's RAM), and can be modified arbitrarily, deleting and accessing any objects. You can think of the stack like a `Vector`, and the heap like a `Dict`.

Intuitively, it may seem obvious that all objects need to be placed in RAM, must be able to be retrieved and deleted at any time by the program, and therefore need to be allocated on the heap. And for some languages, like Python, this is true. However, this is not true in Julia and other efficient, compiled languages. Integers, for example, can often be placed on the stack.

Why do some objects need to be heap allocated, while others can be stack allocated? To be stack-allocated, the compiler needs to know for certain that:

* The object is a reasonably small size, so it fits on the stack. For technical reasons, the stack can't just be hundreds of megabytes in size.
* The compiler can predict exactly *when* it needs to create and destroy the object so it can destroy it timely by simply popping the stack (similar to calling `pop!` on a `Vector`). This is usually the case for local variables in compiled languages.

Julia has even more constrains on stack-allocated objects.
* The object should have a fixed size known at compile time.
* The compiler must know that object never changes. The CPU is free to copy stack-allocated objects, and for immutable objects, there is no way to distinguish a copy from the original. This bears repeating: *With immutable objects, there is no way to distinguish a copy from the original*. This gives the compiler and the CPU certain freedoms when operating on it. The latter point is also why objects are immutable by default in Julia, and leads to one other performance tip: Use immutable objects wherever possible.

What does this mean in practice? In Julia, it means if you want fast stack-allocated objects:
* Your object must be created, used and destroyed in a fully compiled function so the compiler knows for certain when it needs to create, use and destroy the object. If the object is returned for later use (and not immediately returned to another, fully compiled function), we say that the object *escapes*, and must be allocated.
* Your type must be limited in size. I don't know exactly how large it has to be, but 100 bytes is fine.
* The exact memory layout of your type must be known by the compiler (it nearly always is).
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
md"We can inspect the code needed to instantiate a `HeapAllocated` object with the code needed to instantiate a `StackAllocated` one:"

# ╔═╡ 33350038-8af1-11eb-1ff5-6d42d86491a3
@code_native debuginfo=:none dump_module=false HeapAllocated(1)

# ╔═╡ 3713a8da-8af1-11eb-2cb2-1957455227d0
md"Notice the `callq` instruction in the `HeapAllocated` one. This instruction calls out to other functions, meaning that in fact, much more code is really needed to create a `HeapAllocated` object that what is displayed. In constrast, the `StackAllocated` really only needs a few instructions:"

# ╔═╡ 59f58f1c-8af1-11eb-2e88-997e9d4bcc48
@code_native debuginfo=:none dump_module=false StackAllocated(1)

# ╔═╡ 5c86e276-8af1-11eb-2b2e-3386e6795f37
md"
Because immutable objects dont need to be stored on the heap and can be copied freely, immutables are stored *inline* in arrays. This means that immutable objects can be stored directly inside the array's memory. Mutable objects have a unique identity and location on the heap. They are distinguishable from copies, so cannot be freely copied, and so arrays contain reference to the memory location on the heap where they are stored. Accessing such an object from an array then means first accessing the array to get the memory location, and then accessing the object itself using that memory location. Beside the double memory access, objects are stored less efficiently on the heap, meaning that more memory needs to be copied to CPU caches, meaning more cache misses. Hence, even when stored on the heap in an array, immutables can be stored more effectively.
"

# ╔═╡ 6849d9ec-8af1-11eb-06d6-db49af4796bc
md"We can verify that, indeed, the array in the `data_stack` stores the actual data of a `StackAllocated` object, whereas the `data_heap` contains pointers (i.e. memory addresses):"

# ╔═╡ 74a3ddb4-8af1-11eb-186e-4d80402adfcf
md"## Registers and SIMD
It is time yet again to update our simplified computer schematic. A CPU operates only on data present in *registers*. These are small, fixed size slots (e.g. 8 bytes in size) inside the CPU itself. A register is meant to hold one single piece of data, like an integer or a floating point number. As hinted in the section on assembly code, each instruction usually refers to one or two registers which contain the data the operation works on:

$$[CPU] ↔ [REGISTERS] ↔ [CACHE] ↔ [RAM] ↔ [DISK CACHE] ↔ [DISK]$$

To operate on data structures larger than one register, the data must be broken up into smaller pieces that fits inside the register. For example, when adding two 128-bit integers on my computer:"

# ╔═╡ 7a88c4ba-8af1-11eb-242c-a1813a9e6741
@code_native debuginfo=:none dump_module=false UInt128(5) + UInt128(11)

# ╔═╡ 7d3fcbd6-8af1-11eb-0441-2f88a9d59966
md"""There is no register that can do 128-bit additions. First the lower 64 bits must be added using a `addq` instruction, fitting in a register. Then the upper bits are added with a `adcq` instruction, which adds the digits, but also uses the carry bit from the previous instruction. Finally, the results are moved 64 bits at a time using `movq` instructions.

The small size of the registers serves as a bottleneck for CPU throughput: It can only operate on one integer/float at a time. In order to sidestep this, modern CPUs contain specialized 256-bit registers (or 128-bit in older CPUs, or 512-bit in the brand new ones) than can hold 4 64-bit integers/floats at once, or 8 32-bit integers, etc. Confusingly, the data in such wide registers are termed "vectors." The CPU have access to instructions that can perform various CPU operations on vectors, operating on 4 64-bit integers in one instruction. This is called "single instruction, multiple data," *SIMD*, or *vectorization*. Notably, a 4x64 bit operation is *not* the same as a 256-bit operation, e.g. there is no carry-over with between the 4 64-bit integers when you add two vectors. Instead, a 256-bit vector operation is equivalent to 4 individual 64-bit operations.

We can illustrate this with the following example:"""

# ╔═╡ 8c2ed15a-8af1-11eb-2e96-1df34510e773
md"""
Here, two 8×32 bit vectors are added together in one single instruction. You can see the CPU makes use of a single `vpaddd` (vector packed add double) instruction to add 8 32-bit integers, as well as the corresponding move instruction `vmovdqu`. Note that vector CPU instructions begin with `v`.

It's worth mentioning the interaction between SIMD and alignment: If a series of 256-bit (32-byte) SIMD loads are misaligned, then up to half the loads could cross cache line boundaries, as opposed to just 1/8th of 8-byte loads. Thus, alignment is a much more serious issue when using SIMD. Since array beginnings are always aligned, this is usually not an issue, but in cases where you are not guaranteed to start from an aligned starting point, such as with matrix operations, this may make a significant difference. In brand new CPUs with 512-bit registers, the issues is even worse as the SIMD size is the same as the cache line size, so *all* loads would be misaligned if the initial load is.

SIMD vectorization of e.g. 64-bit integers may increase throughput by almost 4x, so it is of huge importance in high-performance programming. Compilers will automatically vectorize operations if they can. What can prevent this automatic vectorization?

#### SIMD needs uninterrupted iteration of fixed length
Because vectorized operations operate on multiple data at once, it is not possible to interrupt the loop at an arbitrary point. For example, if 4 64-bit integers are processed in one clock cycle, it is not possible to stop a SIMD loop after 3 integers have been processed. Suppose you had a loop like this:

```julia
for i in 1:8
    if foo()
        break
    end
    # do stuff with my_vector[i]
end
```

Here, the loop could end on any iteration due to the break statement. Therefore, any SIMD instruction which loaded in multiple integers could operate on data *after* the loop is supposed to break, i.e. data which is never supposed to be read. This would be wrong behaviour, and so, the compiler cannot use SIMD instructions.

A good rule of thumb is that SIMD needs:
* A loop with a predetermined length, so it knows when to stop, and
* A loop with no branches (i.e. if-statements) in the loop

In fact, even boundschecking, i.e. checking that you are not indexing outside the bounds of a vector, causes a branch. After all, if the code is supposed to raise a bounds error after 3 iterations, even a single SIMD operation would be wrong! To achieve SIMD vectorization then, all boundschecks must be disabled.

Fortunately, in the latest versions of Julia, the compiler has been pretty smart at figuring out when it can SIMD even when boundschecking.

To demonstrate the significant impact of SIMDd, we can use a function that uses an input function to break a loop. We can then compare the speed of the function when given a function that the compiler knows will never break the loop and so can SIMDd, with a function that might break the loop."""

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
On my computer, the SIMD code is 10x faster than the non-SIMD code. SIMD alone accounts for only about 4x improvements (since we moved from 64-bits per iteration to 256 bits per iteration). The rest of the gain comes from not spending time checking the bounds and from automatic loop unrolling (explained later), which is also made possible by the `@inbounds` annotation.

#### SIMD needs a loop where loop order doesn't matter
SIMD can change the order in which elements in an array is processed. If the result of any iteration depends on any previous iteration such that the elements can't be re-ordered, the compiler will usually not SIMD-vectorize. Often when a loop won't auto-vectorize, it's due to subtleties in which data moves around in registers means that there will be some hidden memory dependency between elements in an array.

Imagine we want to sum some 64-bit integers in an array using SIMD. For simplicity, let's say the array has 8 elements, `A`, `B`, `C` ... `H`. In an ordinary non-SIMD loop, the additions would be done like so:

$$(((((((A + B) + C) + D) + E) + F) + G) + H)$$

Whereas when loading the integers using SIMD, four 64-bit integers would be loaded into one vector `<A, B, C, D>`, and the other four into another `<E, F, G, H>`. The two vectors would be added: `<A+E, B+F, C+G, D+H>`. After the loop, the four integers in the resulting vector would be added. So the overall order would be:

$$((((A + E) + (B + F)) + (C + G)) + (D + H))$$

Perhaps surprisingly, addition of floating point numbers can give different results depending on the order (i.e. float addition is not associative):
"""

# ╔═╡ c01bf4b6-8af1-11eb-2f17-bfe0c93d48f9
begin
    x = eps(1.0) * 0.4
    1.0 + (x + x) == (1.0 + x) + x
end

# ╔═╡ c80e05ba-8af1-11eb-20fc-235b45f2eb4b
md"for this reason, float addition will not auto-vectorize:"

# ╔═╡ e3931226-8af1-11eb-0da5-fb3c1c22d12e
md"However, high-performance programming languages usually provide a command to tell the compiler it's alright to re-order the loop, even for non-associative loops. In Julia, this command is the `@simd` macro:"

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
Julia also provides the macro `@simd ivdep` which further tells the compiler that there are no memory-dependencies in the loop order. However, I *strongly discourage* the use of this macro, unless you *really* know what you're doing. In general, the compiler knows best when a loop has memory dependencies, and misuse of `@simd ivdep` can very easily lead to bugs that are hard to detect.
"""

# ╔═╡ f5c28c92-8af1-11eb-318f-5fa059d8fd80
md"""
## Struct of arrays
If we create an array containing four `AlignmentTest` objects `A`, `B`, `C` and `D`, the objects will lie end to end in the array, like this:

    Objects: |      A        |       B       |       C       |        D      |
    Fields:  |   a   | b |c| |   a   | b |c| |   a   | b |c| |   a   | b |c| |
    Byte:     1               9              17              25              33

Note again that byte no. 8, 16, 24 and 32 are empty to preserve alignment, wasting memory.
Now suppose you want to do an operation on all the `.a` fields of the structs. Because the `.a` fields are scattered 8 bytes apart, SIMD operations are much less efficient (loading up to 4 fields at a time) than if all the `.a` fields were stored together (where 8 fields could fit in a 256-bit register). When working with the `.a` fields only, the entire 64-byte cache lines would be read in, of which only half, or 32 bytes would be useful. Not only does this cause more cache misses, we also need instructions to pick out the half of the data from the SIMD registers we need.

The memory structure we have above is termed an "array of structs," because, well, it is an array filled with structs. Instead we can strucure our 4 objects `A` to `D` as a "struct of arrays." Conceptually, it could look like:
"""

# ╔═╡ fc2d2f1a-8af1-11eb-11a4-8700f94e866e
struct AlignmentTestVector
    a::Vector{UInt32}
    b::Vector{UInt16}
    c::Vector{UInt8}
end

# ╔═╡ 007cd39a-8af2-11eb-053d-f584d68f7d2f
md"""
With the following memory layout for each field:

    Object: AlignmentTestVector
    .a |   A   |   B   |   C   |   D   |
    .b | A | B | C | D |
    .c |A|B|C|D|

Alignment is no longer a problem, no space is wasted on padding. When running through all the `a` fields, all cache lines contain full 64 bytes of relevant data, so SIMD operations do not need extra operations to pick out the relevant data:
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
## Specialized CPU instructions

Most code makes use of only a score of simple CPU instructions like move, add, multiply, bitshift, and, or, xor, jumps, and so on. However, CPUs in the typical modern laptop support a *lot* of CPU instructions. Usually, if an operation is used heavily in consumer laptops, CPU manufacturers will add specialized instructions to speed up these operations. Depending on the hardware implementation of the instructions, the speed gain from using these instructions can be significant.

Julia only exposes a few specialized instructions, including:

* The number of set bits in an integer is effectively counted with the `popcnt` instruction, exposed via the `count_ones` function.
* The `tzcnt` instructions counts the number of trailing zeros in the bits an integer, exposed via the `trailing_zeros` function
* The order of individual bytes in a multi-byte integer can be reversed using the `bswap` instruction, exposed via the `bswap` function. This can be useful when having to deal with [endianness](https://en.wikipedia.org/wiki/Endianness).

The following example illustrates the performance difference between a manual implementation of the `count_ones` function, and the built-in version, which uses the `popcnt` instruction:
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
The timings you observe here will depend on whether your compiler is clever enough to realize that the computation in the first function can be expressed as a `popcnt` instruction, and thus will be compiled to that. On my computer, the compiler is not able to make that inference, and the second function achieves the same result more than 100x faster.

#### Call any CPU instruction
Julia makes it possible to call CPU instructions direcly. This is not generally advised, since not all your users will have access to the same CPU with the same instructions, and so your code will crash on users working on computers of different brands.

The latest CPUs contain specialized instructions for AES encryption and SHA256 hashing. If you wish to call these instructions, you can call Julia's backend compiler, LLVM, directly. In the example below, I create a function which calls the `vaesenc` (one round of AES encryption) instruction directly:
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
md"(Thanks to Kristoffer Carlsson for [the example](http://kristofferc.github.io/post/intrinsics/)). We can verify it works by checking the assembly of the function, which should contain only a single `vaesenc` instruction, as well as the `retq` (return) and the `nopw` (do nothing, used as a filler to align the CPU instructions in memory) instruction:"

# ╔═╡ 76a4e83c-8af2-11eb-16d7-75eaabcb21b6
@code_native debuginfo=:none dump_module=false aesenc(
	__m128i((1, 1)), __m128i((1, 1))
)

# ╔═╡ 797264de-8af2-11eb-0cb0-adf3fbc95c90
md"""Algorithms which makes use of specialized instructions can be extremely fast. [In a blog post](https://mollyrocket.com/meowhash), the video game company Molly Rocket unveiled a new non-cryptographic hash function using AES instructions which reached unprecedented speeds."""

# ╔═╡ 80179748-8af2-11eb-0910-2b825104159d
md"## Inlining
Consider the assembly of this function:"

# ╔═╡ 36b723fc-8ee9-11eb-1b92-451b992acc0c
f() = error();

# ╔═╡ 8af63980-8af2-11eb-3028-83a935bac0db
md"""
This code contains the `callq` instruction, which calls another function. A function call comes with some overhead depending on the arguments of the function and other things. While the time spent on a function call is measured in nanoseconds, it can add up if the function called is in a tight loop.

However, if we show the assembly of this function:
"""

# ╔═╡ 50ab0cf6-8ee9-11eb-3e04-af5fef7f2850
call_plus(x) = x + 1;

# ╔═╡ 93af6754-8af2-11eb-0fe6-216d76e683de
@code_native debuginfo=:none dump_module=false call_plus(1)

# ╔═╡ a105bd68-8af2-11eb-31f6-3335b4fb0f08
md"""
The function `call_plus` calls `+`, and is compiled to a single `leaq` instruction (as well as some filler `retq` and `nopw`). But `+` is a normal Julia function, so `call_plus` is an example of one regular Julia function calling another. Why is there no `callq` instruction to call `+`?

The compiler has chosen to *inline* the function `+` into `call_plus`. That means that instead of calling `+`, it has copied the *content* of `+` directly into `call_plus`. The advantages of this is:
* There is no overhead from the function call
* There is no need to construct a `Tuple` to hold the arguments of the `+` function
* Whatever computations happens in `+` is compiled together with `call_plus`, allowing the compiler to use information from one in the other and possibly simplify some calculations.

So why aren't *all* functions inlined then? Inlining copies code, increases the size of it and consuming RAM. Furthermore, the *CPU instructions themselves* also needs to fit into the CPU cache (although CPU instructions have their own cache) in order to be efficiently retrieved. If everything was inlined, programs would be enormous and grind to a halt. Inlining is only an improvement if the inlined function is small.

Instead, the compiler uses heuristics (rules of thumb) to determine when a function is small enough for inlining to increase performance. These heuristics are not bulletproof, so Julia provides the macros `@noinline`, which prevents inlining of small functions (useful for e.g. functions that raises errors, which must be assumed to be called rarely), and `@inline`, which does not *force* the compiler to inline, but *strongly suggests* to the compiler that it ought to inline the function.

If code contains a time-sensitive section, for example an inner loop, it is important to look at the assembly code to verify that small functions in the loop is inlined. For example, in [this line in my kmer hashing code](https://github.com/jakobnissen/Kash.jl/blob/b9a6e71acf9651d3614f92d5d4b29ffd136bcb5c/src/kmersketch.jl#L41), overall minhashing performance drops by a factor of two if this `@inline` annotation is removed.

An extreme difference between inlining and no inlining can be demonstrated thus:
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
## Unrolling
Consider a function that sums a vector of 64-bit integers. If the vector's data's memory offset is stored in register `%r9`, the length of the vector is stored in register `%r8`, the current index of the vector in `%rcx` and the running total in `%rax`, the assembly of the inner loop could look like this:

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

For a total of 4 instructions per element of the vector. The actual code generated by Julia will be similar to this, but also incluce extra instructions related to bounds checking that are not relevant here (and of course will include different comments).

However, if the function is written like this:

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

The result is obviously the same if we assume the length of the vector is divisible by four. If the length is not divisible by four, we could simply use the function above to sum the first $N - rem(N, 4)$ elements and add the last few elements in another loop. Despite the functionally identical result, the assembly of the loop is different and may look something like:

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

For a total of 7 instructions per 4 additions, or 1.75 instructions per addition. This is less than half the number of instructions per integer! The speed gain comes from simply checking less often when we're at the end of the loop. We call this process *unrolling* the loop, here by a factor of four. Naturally, unrolling can only be done if we know the number of iterations beforehand, so we don't "overshoot" the number of iterations. Often, the compiler will unroll loops automatically for extra performance, but it can be worth looking at the assembly. For example, this is the assembly for the innermost loop generated on my computer for `sum([1])`:

    L144:
        vpaddq  16(%rcx,%rax,8), %ymm0, %ymm0
        vpaddq  48(%rcx,%rax,8), %ymm1, %ymm1
        vpaddq  80(%rcx,%rax,8), %ymm2, %ymm2
        vpaddq  112(%rcx,%rax,8), %ymm3, %ymm3
        addq    $16, %rax
        cmpq    %rax, %rdi
        jne L144

Where you can see it is both unrolled by a factor of four, and uses 256-bit SIMD instructions, for a total of 128 bytes, 16 integers added per iteration, or 0.44 instructions per integer.

Notice also that the compiler chooses to use 4 different `ymm` SIMD registers, `ymm0` to `ymm3`, whereas in my example assembly code, I just used one register `rax`. This is because, if you use 4 independent registers, then you don't need to wait for one `vpaddq` to complete (remember, it had a ~3 clock cycle latency) before the CPU can begin the next.

The story for unrolling is similar to that for SIMD: The compiler will only unroll a loop if it can tell _for sure_ that it will not overshoot the number of iterations. For example, compare the two following functions:
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
The _first_ function stops and returns as soon as it finds a `true` value - but this break in the loop disables SIMD and unrolling. The _second_ function continues throughout the entire array, even if the very first value is `true`. While this enables SIMD and unrolling, it's obviously wasteful if it sees a `true` right in the beginning. Hence, the first is better when we expect to see the first `true` before around 1/4th of the way though the array, the latter better otherwise.

We can create a compromise by manually unrolling. In the functions below, `check128` checks 128 entries using `inbounds`, without stopping underway to check if it's found a `true`, and is thus unrolled and SIMDd. `unroll_compromise` then uses `check128`, but breaks out of the loop as soon as it finds a `true.`
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
We see excellent performance for both arrays with no `trues`, and for the one with a `true` right in the beginning.

Unfortunately, I'm not aware of any way to automatically generate this kind of unrolling, where you want a compromise between unrolling smaller chunks, and including branches in between each chunk. Perhaps in the future, this desire can be communicated to the compiler, such that the optimal code is automatically generated.
"""

# ╔═╡ c36dc5f8-8af2-11eb-3f35-fb86143a54d2
md"""
## Avoid unpredicable branches
As mentioned previously, CPU instructions take multiple cycles to complete, but may be queued into the CPU before the previous instruction has finished computing. So what happens when the CPU encounters a branch (i.e. a jump instruction)? It can't know which instruction to queue next, because that depends on the instruction that it just put into the queue and which has yet to be executed.

Modern CPUs make use of *branch prediction*. The CPU has a *branch predictor* circuit, which guesses the correct branch based on which branches were recently taken. In essense, the branch predictor attempts to learn simple patterns in which branches are taken in code, while the code is running. After queueing a branch, the CPU immediately queues instructions from whatever branch predicted by the branch predictor. The correctness of the guess is verified later, when the queued branch is being executed. If the guess was correct, great, the CPU saved time by guessing. If not, the CPU has to empty the pipeline and discard all computations since the initial guess, and then start over. This process causes a delay of a few nanoseconds.

For the programmer, this means that the speed of an if-statement depends on how easy it is to guess. If it is trivially easy to guess, the branch predictor will be correct almost all the time, and the if statement will take no longer than a simple instruction, typically 1 clock cycle. In a situation where the branching is random, it will be wrong about 50% of the time, and each misprediction may cost many clock cycles.

Branches caused by loops are among the easiest to guess. If you have a loop with 1000 elements, the code will loop back 999 times and break out of the loop just once. Hence the branch predictor can simply always predict "loop back", and get a 99.9% accuracy.

We can demonstrate the performance of branch misprediction with a simple function:
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
In the first case, the integers are random, and about half the branches will be mispredicted causing delays. In the second case, the branch is always taken, the branch predictor is quickly able to pick up the pattern and will reach near 100% correct prediction. As a result, on my computer, the latter is around 8x faster.

Note that if you use smaller vectors and repeat the computation many times, as the `@btime` macro does, the branch predictor is able to learn the pattern of the small random vectors by heart, and will reach much better than random prediction. This is especially pronounced in the most modern CPUs (and in particular the CPUs sold by AMD, I hear) where the branch predictors have gotten much better. This "learning by heart" is an artifact of the loop in the benchmarking process. You would not expect to run the exact same computation repeatedly on real-life data:
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
Because branches are very fast if they are predicted correctly, highly predictable branches caused by error checks are not of much performance concern, assuming that the code essensially never errors. Hence a branch like bounds checking is very fast. You should only remove bounds checks if absolutely maximal performance is critical, or if the bounds check happens in a loop which would otherwise SIMD-vectorize.

If branches cannot be easily predicted, it is often possible to re-phrase the function to avoid branches all together. For example, in the `copy_odds!` example above, we could instead write it like so:
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
Which contains no other branches than the one caused by the loop itself (which is easily predictable), and results in speeds slightly worse than the perfectly predicted one, but much better for random data.

The compiler will often remove branches in your code when the same computation can be done using other instructions. When the compiler fails to do so, Julia offers the `ifelse` function, which sometimes can help elide branching.
"""

# ╔═╡ 72e1b146-8c1c-11eb-2c56-b1342271c2f6
md"""
## Be aware of memory dependencies

Thinking about it more deeply, why *is* the perfectly predicted example above faster than the solution that avoids having that extra branch there at all?

Let's look at the assembly code. Here, I've just cut out the assembly for the loop (since almost all time is spent there)

For the branch-ful version, we have:
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

And for the branch-less, we have:
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

The branch-ful executes 9 instructions per iteration (remember, all iterations had uneven numbers), whereas the branch-less executes only 7. Looking at the table for how long instructions take, you will find all these instructions are fast. So what gives?

To understand what is happening, we need to go a little deeper into the CPU. In fact, the CPU does not execute CPU instructions in a linear fashion as the assembly code would have you believe. Instead, a more accurate (but still simplified) picture is the following:

1. The CPU reads in CPU instructions. It then on-the-fly translates these CPU instructions to a set of even lower-level instructions called _micro-operations_ or _µops_. The important difference between µops and CPU instructions is that while only a few different registers can be referred to by the instructions, the actual processor has many more registers, which can be addressed by µops. Code written with µops is called _microcode_.

2. This microcode is loaded into an internal array called the *reorder buffer* for storage. A CPU may hold more than 200 instructions in the reorder buffer at a time. The purpose of this storage is to allow execution of microcode in a highly parallel way. The code is then sent to execution in bulk.

3. Finally, results from the reorder buffer is then shipped out to memory in the correct order.

The existance of a re-order buffer has two important implications (that I know about) for how you should think about your code:

First, your code is executed in large chunks often in parallel, not necessarily in the same order as it was loaded in. Therefore, _a program with more, slower CPU instructions can be faster than a program with fewer, faster instructions_, if the former program manages to execute more of them in parallel.

Second, branch prediction (as discussed in the previous section) does not happen just for the upcoming branch, but instead for a large amount of future branches, simultaneously.

When visualizing how the code of the small `copy_odds_branches!` loop above is executed, you may imagine that the branch predictor predicts all branches, say, 6 iterations of the loop into the future, loads the microcode of all 6 future iterations into the reorder buffer, executes them all in parallel, and _then_ verifies - still in parallel - that its branches were guessed correctly.

 Indicentally, this bulk processing is why a branch mispredict is so bad for performance - if a branch turns out to be mispredicted, all the work in the reorder buffer must be scrapped, the and the CPU must start over with fetching new instructions, compile them to microcode, fill the buffer et cetera.

Let's think about the implications re-order buffer for a moment. Other than creating hard-to-predict branches, what kind of code can re write that messes up that workflow for the CPU?

What if we do this?
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
If you think about it, `read_indices` does strictly less work than any of the `copy_odds` functions. It doesn't even check if the numbers it copies are odd. Yet it's more than three times slower than `copy_odds_branches`!

The difference is *memory dependencies*. We humans, seeing that the input data is simply a range of numbers, can tell _precisely_ what the function should do at every iteration: Simply copy the next number over. But the compiler _can't_ predict what the next number it loads will be, and therefore where it needs to store the loaded number. We say that the code has a memory dependency on the number it loads from `src`.

In that case, the reorder buffer is of no use. All the instructions get loaded in, but are simply kept idle in the reorder buffer, because they simply *cannot* be executed until it's "their turn".

Going back to the original example, that is why the perfectly predicted `copy_odds_branches!` performs better than `code_odds_branchless!`. Even though the latter has fewer instructions, it has a memory dependency: The index of `dst` where the odd number gets stored to depends on the last loop iteration. So fewer instructions can be executed at a time compared to the former function, where the branch predictor predicts several iterations ahead and allow for the parallel computation of multiple iterations.
"""

# ╔═╡ 0b6d234e-8af3-11eb-1ba9-a1dcf1497785
md"""
## Variable clock speed

A modern laptop CPU optimized for low power consumption consumes roughly 25 watts of power on a chip as small as a stamp (and thinner than a human hair). Without proper cooling, this will cause the temperature of the CPU to skyrocket and melting the plastic of the chip, destroying it. Typically, CPUs have a maximal operating temperature of about 100 degrees C. Power consumption, and therefore heat generation, depends among many factors on clock speed, higher clock speeds generate more heat.

Modern CPUs are able to adjust their clock speeds according to the CPU temperature to prevent the chip from destroying itself. Often, CPU temperature will be the limiting factor in how quick a CPU is able to run. In these situations, better physical cooling for your computer translates directly to a faster CPU. Old computers can often be revitalized simply by removing dust from the interior, and replacing the cooling fans and [CPU thermal paste](https://en.wikipedia.org/wiki/Thermal_grease)!

As a programmer, there is not much you can do to take CPU temperature into account, but it is good to know. In particular, variations in CPU temperature often explain observed difference in performance:

* CPUs usually work fastest at the beginning of a workload, and then drop in performance as it reaches maximal temperature
* SIMD instructions usually require more power than ordinary instructions, generating more heat, and lowering the clock frequency. This can offset some performance gains of SIMD, but SIMD will nearly always be more efficient when applicable. One exception is the relatively recent 512-bit SIMD instructions. In current (2021) CPUs, these instructions draw so much power that the resulting clock frequency lowering actually leads to overall performance decrease for some workloads. This problem will probably be solved in the near future, either by the power draw begin reduced, by consumer chips abandoning 512-bit SIMD, or by compilers refusing to compile to these instructions.
"""

# ╔═╡ 119d269c-8af3-11eb-1fdc-b7ac75b89cf2
md"""
## Multithreading
In the bad old days, CPU clock speed would increase every year as new processors were brought onto the market. Partially because of heat generation, this acceleration slowed down once CPUs hit the 3 GHz mark. Now we see only minor clock speed increments every processor generation. Instead of raw speed of execution, the focus has shifted on getting more computation done per clock cycle. CPU caches, CPU pipelining (i.e. the entire re-order buffer "workflow"), branch prediction and SIMD instructions are all important contibutions in this area, and have all been covered here.

Another important area where CPUs have improved is simply in numbers: Almost all CPU chips contain multiple smaller CPUs, or *cores* inside them. Each core has their own small CPU cache, and does computations in parallel. Furthermore, many CPUs have a feature called *hyper-threading*, where two *threads* (i.e. streams of instructions) are able to run on each core. The idea is that whenever one process is stalled (e.g. because it experiences a cache miss or a branch misprediction), the other process can continue on the same core. The CPU "pretends" to have twice the amount of processors.

Hyperthreading only really matters when your threads are sometimes prevented from doing work. Besides CPU-internal causes like cache misses, a thread can also be paused because it is waiting for an external resource like a webserver or data from a disk. If you are writing a program where some threads spend a significant time idling, the core can be used by the other thread, and hyperthreading can show its value.

Let's see our first parallel program in action. First, we need to make sure that Julia actually was started with the correct number of threads. To do this, start Julia with the `-t` option - e.g. `-t 8` for 8 threads. I have set Julia to have 4 threads:
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
You can see that with this task, my computer can run 8 jobs in parallel almost as fast as it can run 1. But 16 jobs takes much longer. This is because 4 can run at the same time, and 4 more can sleep for a total of 8 concurrent jobs.

For CPU-constrained programs, the core is kept busy with only one thread, and there is not much to do as a programmer to leverage hyperthreading. Actually, for the most optimized programs, it usually leads to better performance to *disable* hyperthreading. Most workloads are not that optimized and can really benefit from hyperthreading, however.

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
