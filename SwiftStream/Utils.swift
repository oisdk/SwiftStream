//
//  Utils.swift
//  SwiftStream
//
//  Created by Donnacha Oisín Kidney on 04/05/2016.
//  Copyright © 2016 Donnacha Oisín Kidney. All rights reserved.
//

public func curry<A,B,C>(f: (A,B) -> C) -> A -> B -> C {
  return { x in { y in f(x,y) } }
}

public func const<A,B>(x: A) -> B -> A {
  return { _ in x }
}