```swift
import SwiftStream
```
A stream is a different way of looking at sequences.
To turn a sequence into a stream, the `toStream()` method is available:
```swift
let a = [1, 4, 2, 5, 3, 6, 4, 7, 1, 8]
let s = a.toStream()
```
The type of a stream looks like this: `Stream<Source, State, Element>`. The `Source` is the 
sequence the stream is being generated from. The state is the type of state the stream uses.
For normal streams, it will be the `Unit` type, meaning that no state is used. The `Element`
is the type of thing the stream contains. The usual functions are all available:
```swift
s.map(String.init)
```
The type of the above is `Stream<[Int], Unit, String>`. You can also filter:
```swift
s
  .filter { n in n % 2 == 0 }
  .map(String.init)
```
The type of this version is the same as the one before. `Stream<[Int], Unit, String>`
So what about stateful functions? As a simple example, here's how you would make a stream
of running totals:
```swift
let ss = a.mapAccum { (t,n) in (t+n,t+n) }
// or
let sm = a.mapWithState { n in modify { t in t + n } ^> get() }
```
The type of this is `StatefulStream<[Int], Int, Int>`. The standard functions are also available
on these streams:
```swift
ss.filter { n in n % 2 == 0 }
```
To get back to a normal stream, you have to give it some initial state:
```swift
ss.toStream(0)
```
The normal `Stream` type conforms to `SequenceType`.
```swift
a
  .filterAccum { (n,s) in (s < n, n) } // filter a into ascending order
  .toArray(0)
  .1

a
  .filterWithState { n in gets { p in p < n } <^ put(n) }
  .toArray(0)
  .1
```
The result of the above is `[1, 4, 5, 6, 7, 8]`
Every computation is lazy until the stream is converted into some other form. Also, streams guess
their size:
```swift
a.toStream().size // Exactly 10
a // Smaller than 10
  .toStream()
  .filter { n in n % 2 == 0 }
  .size

let i = InfiniteSequence().toStream()

let fibs = i
  .mapAccum { (_,t) in
    let n = t.0 + t.1
    return (n,(t.1,n))
  }.takeWhile { n in
    n < 1000
  }.toStream((0,1))

Array(fibs)

let skips = [1, 2, 3, 4, 5, 6, 7, 8].filterWithState { _ in modify(!) ^> get() }

skips.toArray(true ).1
skips.toArray(false).1
```
