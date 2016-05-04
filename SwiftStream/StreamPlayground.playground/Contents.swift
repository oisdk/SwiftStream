import SwiftStream

//: A stream is a different way of looking at sequences.
//: To turn a sequence into a stream, the `toStream()` method is available:
let a = [1, 4, 2, 5, 3, 6, 4, 7, 1, 8]
let s = a.toStream()
//: The type of a stream looks like this: `Stream<Source, State, Element>`. The `Source` is the 
//: sequence the stream is being generated from. The state is the type of state the stream uses.
//: For normal streams, it will be the `Unit` type, meaning that no state is used. The `Element`
//: is the type of thing the stream contains. The usual functions are all available:
s.map(String.init)
//: The type of the above is `Stream<[Int], Unit, String>`. You can also filter:
s
  .filter { n in n % 2 == 0 }
  .map(String.init)
//: The type of this version is the same as the one before. `Stream<[Int], Unit, String>`
//: So what about stateful functions? As a simple example, here's how you would make a stream
//: of running totals:
let ss = a.mapAccum { (t,n) in (t+n,t+n) }
//: The type of this is `StatefulStream<[Int], Int, Int>`. The standard functions are also available
//: on these streams:
ss.filter { n in n % 2 == 0 }
//: To get back to a normal stream, you have to give it some initial state:
ss.toStream(0)
//: The normal `Stream` type conforms to `SequenceType`.
Array(
  a
    .filterAccum { (s,n) in (n, s < n) } // filter a into ascending order
    .toStream(0)
)
//: The result of the above is `[1, 4, 5, 6, 7, 8]`
//: Every computation is lazy until the stream is converted into some other form. Also, streams guess
//: their size:

a.toStream().size // Exactly 10
a // Smaller than 10
  .toStream()
  .filter { n in n % 2 == 0 }
  .size

let i = InfiniteSequence().toStream()

let fibs = i
  .mapAccum { (t,_) in
    let n = t.0 + t.1
    return ((t.1,n), n)
  }.takeWhile { n in
    n < 1000
  }.toStream((0,1))

Array(fibs)

