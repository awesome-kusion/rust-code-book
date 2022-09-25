# 排序算法: Timsort 和 pdqsort

## 前言

Rust 中排序算法的实现可以分为稳定和不稳定的两类。其中稳定的排序算法是一种受 Tim Peters 的 [Timsort](https://en.wikipedia.org/wiki/Timsort) 算法启发的自适应、迭代归并排序；而不稳定的排序算法则是基于 Orson Peters 的 [pdqsort](https://github.com/orlp/pdqsort)[pattern-defeating quicksort]。本文将介绍这两个算法在 Rust 中的实现。

## 稳定排序： Timsort

稳定排序是指在排序过程中不改变相等的元素的顺序。 Rust 中的稳定排序的实现是一种改进的 timsort 算法。可以在 `libray:alloc:src:slice.rs` 中看到它的实现。

### Timsort 简介

Timsort 算法由 Tim Peters 在 2002 年设计，是一种归并和插入排序的混合的排序算法。在最坏的情况，它的时间复杂度为 *O*(*n* \* log(*n*))，需要分配排序的数组一半大小的内存空间，所以空间复杂度为 *O*(*n*)，所以在各个方面都优于*O*(*n*)空间和稳定*O*(*n* \* log(*n*))时间的归并排序算法。由于其出色的性能，在 Python 中最先引入，作为 list.sort 的默认实现，后续 Java 也在 JDK1.7 中使用了 Timsort 算法。

Timsort 算法的基本流程是：

1. 确定数组的单调上升段和严格单调下降段，并将严格下降段反转
2. 定义最小片段(run)长度，低于此长度的片段通过插入排序合并到较长的段中
3. 反复归并相邻片段，直到整个排序完成

因此，Timsort 基本上是一种归并排序，但是在一些小片段的合并中使用了插入排序。

### 算法实现

可以在 `libray:alloc:src:slice.rs` 中看到 Rust 中 Timsort 算法的实现。

#### 空数组和短数组处理

首先是一些特殊情况的处理：

```rust
fn merge_sort<T, F>(v: &mut [T], mut is_less: F)
where
    F: FnMut(&T, &T) -> bool,
{
    // Slices of up to this length get sorted using insertion sort.
    const MAX_INSERTION: usize = 20;
        // Sorting has no meaningful behavior on zero-sized types.
    if T::IS_ZST {
        return;
    }
    let len = v.len();
    // Short arrays get sorted in-place via insertion sort to avoid allocations.
    if len <= MAX_INSERTION {
        if len >= 2 {
            for i in (0..len - 1).rev() {
                insert_head(&mut v[i..], &mut is_less);
            }
        }
        return;
    }
}
```

这段非常容易理解，如果是空数组就直接返回；如果是比较短的数组（低于20），就直接用简单的插入排序。

#### 扫描数组，确定单调片段

Timsort 算法的第一步是识别单调片段(run)：单调递增片段和严格单调递减片段，并将严格单调递减片段反转。

```rust
fn merge_sort<T, F>(v: &mut [T], mut is_less: F)
where
    F: FnMut(&T, &T) -> bool,
{
    let mut end = len;
    while end > 0 {
        let mut start = end - 1;
        if start > 0 {
            start -= 1;
            unsafe {
                if is_less(v.get_unchecked(start + 1), v.get_unchecked(start)) {
                    while start > 0 && is_less(v.get_unchecked(start), v.get_unchecked(start - 1)) {
                        start -= 1;
                    }
                    v[start..end].reverse();
                } else {
                    while start > 0 && !is_less(v.get_unchecked(start), v.get_unchecked(start - 1))
                    {
                        start -= 1;
                    }
                }
            }
        }
    ...
    }
}


```

首先从后向前遍历数组，找到单调递增或严格单调递减的段的起点，并将严格单调递减的段反转。以数组`[4，5，6, 7, 3(1), 3(2), 1, 0]`为例（为了简化掩饰，暂不考虑`MAX_INSERTION`），首先找到第一个严格单调递减段`[3(2), 1, 0]`，并将其反转为`[0, 1, 3(2)]`。

#### 合并较短的段

在较短的数组上，插入排序的性能优于归并排序。所以 Timsort 算法的第二步是定义最短段长度，并利用插入排序合并较短的段。

```rust
fn merge_sort<T, F>(v: &mut [T], mut is_less: F)
where
    F: FnMut(&T, &T) -> bool,
{
    const MIN_RUN: usize = 10;
    while end > 0 {
        // omit step 1

        while start > 0 && end - start < MIN_RUN {
            start -= 1;
            insert_head(&mut v[start..end], &mut is_less);
        }
        runs.push(Run { start, len: end - start });
    }
}
```

上述的例子中，同样为了方便演示，假设 `MIN_RUN` 的值为5。则根据上述代码，使用插入排序在段中插入 `7` 和 `3(1)`，则段变为 `[0, 1, 3(1), 3(2), 7]`。最后将这个段入栈。

#### 合并相邻段

```rust
fn merge_sort<T, F>(v: &mut [T], mut is_less: F)
where
    F: FnMut(&T, &T) -> bool,
{
    const MIN_RUN: usize = 10;
    while end > 0 {
        // omit step 1 and step 2
        while let Some(r) = collapse(&runs) {
            let left = runs[r + 1];
            let right = runs[r];
            unsafe {
                merge(
                    &mut v[left.start..right.start + right.len],
                    left.len,
                    buf.as_mut_ptr(),
                    &mut is_less,
                );
            }
            runs[r] = Run { start: left.start, len: left.len + right.len };
            runs.remove(r + 1);
        }
    }
    fn collapse(runs: &[Run]) -> Option<usize> {
        let n = runs.len();
        if n >= 2
            && (runs[n - 1].start == 0
                || runs[n - 2].len <= runs[n - 1].len
                || (n >= 3 && runs[n - 3].len <= runs[n - 2].len + runs[n - 1].len)
                || (n >= 4 && runs[n - 4].len <= runs[n - 3].len + runs[n - 2].len))
        {
            if n >= 3 && runs[n - 3].len < runs[n - 1].len { Some(n - 3) } else { Some(n - 2) }
        } else {
            None
        }
    }

}
```

首先看 `collapse` 函数。这里用 `collapse` 判断是否有能够合并的段，如果有，则返回其下标 `r`，如果没有，则返回 `None`。具体判断的逻辑稍后说明。

步骤3中根据 `collapse` 函数的返回结果，使用归并排序合并 `runs[r]`和 `runs[r + 1]`，或者重复步骤 1 和步骤 2，继续在栈 `runs` 中构建新的段。

刚刚的例子中，栈 `runs` 中只有一个段 `[0, 1, 3(1), 3(2), 7]`，显然不能合并，因此重复步骤 1 和步骤 2，在 `runs` 中添加第二个段，使其变为 `[[0, 1, 3(1), 3(2), 7], [4, 5, 6]]`(用 `[]` 表示一个段)。此时 `collapse` 会返回下标 `0`，然后使用归并合并 `[0, 1, 3(1), 3(2), 7]` 和 `[4, 5, 6]`。得到结果 `[0, 1, 3(1), 3(2), 4, 5, 6, 7]`，完成整个遍历。

### Timsort 算法的 bug

Rust 中的实现并非默认的 Timsort 的算法，这是因为 Timsort 算法存在 bug(http://envisage-project.eu/timsort-specification-and-verification/)。Rust 的实现在 `collapse` 这个函数做了修改。

Timsort 算法在 JDK1.7 中引入 Java，但在 1.8 版本仍未修复这个 bug。 比较 Java JDK1.8中对应的实现。Java的实现中只比较了栈顶3个元素，但 Rust 的现实比较了栈顶 4 个元素。

```java
private void mergeCollapse() {
    while (stackSize > 1) {
        int n = stackSize - 2;
        if (n > 0 && runLen[n - 1] <= runLen[n] + runLen[n + 1]) {
            if (runLen[n - 1] < runLen[n + 1])
                n--;
            mergeAt(n);
        } else if (runLen[n] <= runLen[n + 1]) {
            mergeAt(n);
        } else {
            break; // Invariant is established
        }
    }
}
```

出于性能原因，Timsort 要维护尽可能少的 run。因此在每次新的 `run` 入栈时，会运行 `mergeCollapse` 函数合并栈顶 3 个元素,又因为每次入栈都会执行，所以栈中所有 run 的长度都满足以下两个条件：

1. runLen[n - 2] > runLen[n - 1] + runLen[n]
2. runLen[n - 1] > runLen[n]

如果不满足规则 1，则将 run[n - 1] 与 run[n] 和 run[n - 2] 较短的合并。例如，runs 中存在两个长度分别为 12 和 7 的 run，此时入栈一个长度为 6 的run，则合并长度为 7 和 6 两个 run，栈变为 [12, 13]。
如果不满足规则 2，则将 run[n - 1] 与 run[n] 合并。如上面的例子，继续合并 12 和 13，此时 runs 中仅剩一个长度为 25 的 run。就可以继续执行 Timsort 算法的第一步和第二步构造新的 run 或完成排序。

但问题在哪呢？考虑一个例子：

```
120, 80, 25, 20, 30
```

因为 25 < 20 + 30， 所以合并为

```
120, 80, 45, 30
```

此时， `120, 80, 45` 已经不满足规则。这个bug在[这里](http://www.envisage-project.eu/proving-android-java-and-python-sorting-algorithm-is-broken-and-how-to-fix-it)有更为详细的描述以及解决方法。

## 不稳定排序： pdqsort
todo

## Ref

+ Timsort: <https://github.com/python/cpython/blob/main/Objects/listsort.txt>
+ OpenJDK’s java.utils.Collection.sort() is broken: The good, the bad and the worst case: <http://envisage-project.eu/timsort-specification-and-verification/>
+ Proving that Android’s, Java’s and Python’s sorting algorithm is broken (and showing how to fix it): <http://www.envisage-project.eu/proving-android-java-and-python-sorting-algorithm-is-broken-and-how-to-fix-it/>
+ Java bug track: <https://bugs.openjdk.org/browse/JDK-8072909>
