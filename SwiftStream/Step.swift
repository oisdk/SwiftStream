//
//  Step.swift
//  SwiftStream
//
//  Created by Donnacha Oisín Kidney on 04/05/2016.
//  Copyright © 2016 Donnacha Oisín Kidney. All rights reserved.
//

public enum Step<Element> {
  case Skip, Stop, Continue(Element)
}

extension Step {
  func mapState<S,Result>(f: Element -> Stateful<S,Result>) -> Stateful<S,Step<Result>> {
    return Stateful<S,Step<Result>>{ s in
      switch self {
      case let .Continue(x):
        let (y,n) = f(x).runStateful(s)
        return (.Continue(y), n)
      case .Skip: return (.Skip, s)
      case .Stop: return (.Stop, s)
      }
    }
  }
  func conditionState<S>(def: Step, p: Element -> Stateful<S,Bool>) -> Stateful<S,Step> {
    return Stateful<S,Step> { s in
      switch self {
      case let .Continue(x):
        let (b,n) = p(x).runStateful(s)
        return (b ? .Continue(x) : def, n)
      case .Skip: return (.Skip, s)
      case .Stop: return (.Stop, s)
      }
    }
  }
  func filterState<S>(p: Element -> Stateful<S,Bool>) -> Stateful<S,Step> {
    return conditionState(.Skip, p: p)
  }
  func takeWhileState<S>(p: Element -> Stateful<S,Bool>) -> Stateful<S,Step> {
    return conditionState(.Stop, p: p)
  }
}

extension Step {
  func map<Result>(f: Element -> Result) -> Step<Result> {
    switch self {
    case let .Continue(x): return .Continue(f(x))
    case .Skip: return .Skip
    case .Stop: return .Stop
    }
  }
  func condition(def: Step, p: Element -> Bool) -> Step {
    if case let .Continue(x) = self where !p(x) {
      return def
    } else {
      return self
    }
  }
  func filter(p: Element -> Bool) -> Step {
    return condition(.Skip, p: p)
  }
  func takeWhile(p: Element -> Bool) -> Step {
    return condition(.Stop, p: p)
  }
}

extension Step {
  init(fromOptional: Element?) {
    self = fromOptional.map(Step.Continue) ?? .Stop
  }
}