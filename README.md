# 每个科研工作者在写高性能代码时都需了解的硬件知识

本教程的英文版位于 https://viralinstruction.com/posts/hardware/ 。
该教程的另一过时的英文版本位于 https://biojulia.net/。

本文使用 [Pluto notebook](https://github.com/fonsp/Pluto.jl) 编写。如果可以的话，推荐你使用 Pluto notebook 来运行代码，这样就可以一边体验一边学习。另外，你也可以选择在浏览器中阅读html 文件。

欢迎（关于 notebook 文件的） PR！

### 本 notebook 包含：
* 为什么应该限制硬盘读写
* 什么是 CPU 缓存以及如何高效利用它
* 内存对齐
* 如何阅读汇编代码以及为什么必须这样做
* 为什么应该减少内存分配
* 为什么不可变类型通常是最快的
* SIMD 向量化
* 数组结构体 vs 结构体数组
* 专用 CPU 指令
* 函数内联
* 循环展开
* 分支预测
* 内存依赖对 CPU 数据流的影响
* 多线程
* 为什么 GPU 在某些情况下很快而另一些情况却很慢