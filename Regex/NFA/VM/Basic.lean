import Regex.NFA.Basic
import Regex.NFA.VM.NodeSet
import Regex.NFA.VM.SparseSet

def Array.back' (a : Array α) (hemp : ¬ a.isEmpty) : α :=
  have : 0 < a.size := by
    simp [isEmpty] at hemp
    exact Nat.zero_lt_of_ne_zero hemp
  have : a.size - 1 < a.size := Nat.sub_lt_of_pos_le (by decide) this
  a[a.size - 1]

theorem Array.lt_size_of_pop_of_not_empty (a : Array α) (hemp : ¬ a.isEmpty) :
  (a.pop).size < a.size := by
  have : 0 < a.size := by
    simp [isEmpty] at hemp
    exact Nat.zero_lt_of_ne_zero hemp
  have : a.size - 1 < a.size := Nat.sub_lt_of_pos_le (by decide) this
  simp [Array.pop]
  exact this

namespace NFA.VM

-- TODO: check if the modifications don't cause copying
def εClosureTR (nfa : NFA) (visited : NodeSet nfa.nodes.size) (stack : Array (Fin nfa.nodes.size)) :
  NodeSet nfa.nodes.size :=
  if hemp : stack.isEmpty then
    visited
  else
    let i := stack.back' hemp
    let stack' := stack.pop
    have : stack'.size < stack.size := Array.lt_size_of_pop_of_not_empty _ hemp
    if hvis : visited.get i then
      εClosureTR nfa visited stack'
    else
      let visited' := visited.set i
      have : visited'.count_unset < visited.count_unset := visited.lt_count_unset i.isLt hvis
      have inBounds' := nfa.inBounds i
      let stack'' :=
        match hn : nfa.nodes[i.val] with
        | .epsilon next =>
          have h : next < nfa.nodes.size := by
            rw [hn] at inBounds'
            simp [Node.inBounds] at inBounds'
            exact inBounds'

          stack'.push ⟨next, h⟩
        | .split next₁ next₂ =>
          have h₁ : next₁ < nfa.nodes.size := by
            rw [hn] at inBounds'
            simp [Node.inBounds] at inBounds'
            exact inBounds'.left
          have h₂ : next₂ < nfa.nodes.size := by
            rw [hn] at inBounds'
            simp [Node.inBounds] at inBounds'
            exact inBounds'.right

          (stack'.push ⟨next₁, h₁⟩).push ⟨next₂, h₂⟩
        | _ => stack'
      εClosureTR nfa visited' stack''
termination_by (visited.count_unset, stack.size)

def charStepTR (nfa : NFA) (c : Char) (init : NodeSet nfa.nodes.size) :
  NodeSet nfa.nodes.size := go nfa c init .empty 0 (Nat.zero_le _)
where
  go (nfa : NFA) (c : Char) (init : NodeSet nfa.nodes.size)
    (accum : NodeSet nfa.nodes.size) (i : Nat) (hle : i ≤ nfa.nodes.size) :
    NodeSet nfa.nodes.size :=
    if h : i = nfa.nodes.size then
      accum
    else
      have hlt : i < nfa.nodes.size := Nat.lt_of_le_of_ne hle h
      let accum := if init.get ⟨i, hlt⟩ then
        match hn : nfa.nodes[i] with
        | .char c' next =>
          if c = c' then
            have : next < nfa.nodes.size := by
              have := nfa.inBounds ⟨i, hlt⟩
              simp [hn, Node.inBounds] at this
              exact this
            -- TODO: reuse visited and stack
            accum.merge (εClosureTR nfa .empty #[⟨next, this⟩])
          else
            accum
        | _ => accum
      else accum
      go nfa c init accum (i + 1) hlt
  termination_by nfa.nodes.size - i

end NFA.VM

open NFA.VM

@[export lean_regex_nfa_match]
def NFA.match (nfa : NFA) (s : String) : Bool :=
  let ns := εClosureTR nfa .empty #[nfa.start]
  let ns := go nfa s.iter ns
  -- This assumes that the first node is the accepting node
  ns.get ⟨0, nfa.zero_lt_size⟩
where
  go (nfa : NFA) (iter : String.Iterator) (ns : NodeSet nfa.nodes.size) : NodeSet nfa.nodes.size :=
    if iter.atEnd then
      ns
    else
      -- Move if here to avoid confusing termination checker
      if ns.count_set = 0 then
        ns
      else
        let ns' := charStepTR nfa iter.curr ns
        go nfa iter.next ns'

def NFA.search_prefix (nfa : NFA) (s : String) : Option String.Iterator :=
  let ns := εClosureTR nfa .empty #[nfa.start]
  go s.iter ns .none
where
  go (it : String.Iterator) (ns : NodeSet nfa.nodes.size) (lastMatch : Option String.Iterator) :
    Option String.Iterator :=
    -- Prioritize the later match
    let lastMatch := if ns.get ⟨0, nfa.zero_lt_size⟩ then
      some it
    else
      lastMatch
    if it.atEnd then
      lastMatch
    else
      if ns.count_set = 0 then
        lastMatch
      else
        let ns' := charStepTR nfa it.curr ns
        go it.next ns' lastMatch

/-
  The following implementation is heavily inspired by burntsushi's regex-lite crate.
  https://github.com/rust-lang/regex/tree/master/regex-lite
-/
namespace NFA.VM

open String (Pos)

mutual

def exploreεClosure (nfa : NFA) (pos : Pos) (next : SparseSet nfa.nodes.size)
  (target : Fin nfa.nodes.size) (stack : Array (Fin nfa.nodes.size)) :
  SparseSet nfa.nodes.size :=
  if target ∈ next then
    εClosure nfa pos next stack
  else
    let next' := next.insert target
    match hn : nfa[target] with
    | .epsilon target' =>
      have isLt : target' < nfa.nodes.size := by
        have := nfa.inBounds target
        simp [NFA.get_eq_nodes_get] at hn
        simp [Node.inBounds, hn] at this
        exact this
      exploreεClosure nfa pos next' ⟨target', isLt⟩ stack
    | .split target₁ target₂ =>
      have isLt₁ : target₁ < nfa.nodes.size := by
        have := nfa.inBounds target
        simp [NFA.get_eq_nodes_get] at hn
        simp [Node.inBounds, hn] at this
        exact this.left
      have isLt₂ : target₂ < nfa.nodes.size := by
        have := nfa.inBounds target
        simp [NFA.get_eq_nodes_get] at hn
        simp [Node.inBounds, hn] at this
        exact this.right
      exploreεClosure nfa pos next' ⟨target₁, isLt₁⟩ (stack.push ⟨target₂, isLt₂⟩)
    | _ => εClosure nfa pos next' stack
termination_by (next.measure, stack.size, 1)

def εClosure (nfa : NFA) (pos : Pos) (next : SparseSet nfa.nodes.size) (stack : Array (Fin nfa.nodes.size)) :
  SparseSet nfa.nodes.size :=
  if hemp : stack.isEmpty then
    next
  else
    let target := stack.back' hemp
    let stack' := stack.pop
    have : stack'.size < stack.size := Array.lt_size_of_pop_of_not_empty _ hemp
    exploreεClosure nfa pos next target stack'
termination_by (next.measure, stack.size, 0)

def stepChar (nfa : NFA) (c : Char) (pos : Pos) (next : SparseSet nfa.nodes.size) (target : Fin nfa.nodes.size) :
  SparseSet nfa.nodes.size :=
  match hn : nfa[target] with
  | .char c' target' =>
    if c = c' then
      have isLt : target' < nfa.nodes.size := by
        have := nfa.inBounds target
        simp [NFA.get_eq_nodes_get] at hn
        simp [Node.inBounds, hn] at this
        exact this
      exploreεClosure nfa pos next ⟨target', isLt⟩ .empty
    else
      next
  | .done =>
    -- TODO: early termination
    next
  | _ => next

def eachStepChar (nfa : NFA) (c : Char) (pos : Pos) (current : SparseSet nfa.nodes.size) (next : SparseSet nfa.nodes.size) :
  SparseSet nfa.nodes.size :=
  go 0 (Nat.zero_le _) next
where
  go (i : Nat) (hle : i ≤ current.count) (next : SparseSet nfa.nodes.size) : SparseSet nfa.nodes.size :=
    if h : i = current.count then
      next
    else
      have hlt : i < current.count := Nat.lt_of_le_of_ne hle h
      let next' := stepChar nfa c pos next current[i]
      go (i + 1) hlt next'
  termination_by current.count - i

end

end NFA.VM

def NFA.match' (nfa : NFA) (s : String) : Bool :=
  let init := NFA.VM.exploreεClosure nfa 0 .empty nfa.start #[]
  go s.iter init .empty
where
  go (it : String.Iterator) (current : SparseSet nfa.nodes.size) (next : SparseSet nfa.nodes.size) : Bool :=
    if it.atEnd then
      ⟨0, nfa.zero_lt_size⟩ ∈ current
    else
      if current.isEmpty then
        false
      else
        let c := it.curr
        let pos := it.pos
        let next' := NFA.VM.eachStepChar nfa c pos current next
        go it.next next' current.clear
