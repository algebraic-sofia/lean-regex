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

-- TODO: embed .none into Pos to remove allocations
inductive StackEntry (n : Nat) : Type where
  | explore (target : Fin n)
  | restore (save : Array (Option Pos))
deriving Repr

-- TODO: (eq : nfa[id] = e) → InboundsType nfa id eでInboundsTypeがeに依存して各種ごとに良い感じになってる奴作れるのでは

mutual

def exploreεClosure (nfa : NFA) (pos : Pos)
  (next : SparseSet nfa.nodes.size)
  (currentSave : Array (Option Pos)) (matched : Option (Array (Option Pos))) (saveSlots : Vec (Array (Option Pos)) nfa.nodes.size)
  (target : Fin nfa.nodes.size) (stack : Array (StackEntry nfa.nodes.size)) :
  (Option (Array (Option Pos)) × SparseSet nfa.nodes.size × Vec (Array (Option Pos)) nfa.nodes.size) :=
  if target ∈ next then
    εClosure nfa pos next currentSave matched saveSlots stack
  else
    let next' := next.insert target
    match hn : nfa[target] with
    | .epsilon target' =>
      have isLt : target' < nfa.nodes.size := by
        have := nfa.inBounds target
        simp [NFA.get_eq_nodes_get] at hn
        simp [Node.inBounds, hn] at this
        exact this
      exploreεClosure nfa pos next' currentSave matched saveSlots ⟨target', isLt⟩ stack
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
      exploreεClosure nfa pos next' currentSave matched saveSlots ⟨target₁, isLt₁⟩ (stack.push (.explore ⟨target₂, isLt₂⟩))
    | .save offset target' =>
      have isLt : target' < nfa.nodes.size := by
        have := nfa.inBounds target
        simp [NFA.get_eq_nodes_get] at hn
        simp [Node.inBounds, hn] at this
        exact this
      if h : offset < currentSave.size then
        let nextSave := currentSave.set ⟨offset, h⟩ pos
        let stack' := stack.push (.restore currentSave)
        exploreεClosure nfa pos next' nextSave matched saveSlots ⟨target', isLt⟩ stack'
      else
        exploreεClosure nfa pos next' currentSave matched saveSlots ⟨target', isLt⟩ stack
    | .done =>
      let matched' := matched <|> currentSave
      let saveSlots' := saveSlots.set target target.isLt currentSave
      εClosure nfa pos next' currentSave matched' saveSlots' stack
    | .char _ _ =>
      let saveSlots' := saveSlots.set target target.isLt currentSave
      εClosure nfa pos next' currentSave matched saveSlots' stack
    | .fail => εClosure nfa pos next' currentSave matched saveSlots stack
termination_by (next.measure, stack.size, 1)

def εClosure (nfa : NFA) (pos : Pos)
  (next : SparseSet nfa.nodes.size)
  (currentSave : Array (Option Pos)) (matched : Option (Array (Option Pos))) (saveSlots : Vec (Array (Option Pos)) nfa.nodes.size)
  (stack : Array (StackEntry nfa.nodes.size)) :
  (Option (Array (Option Pos)) × SparseSet nfa.nodes.size × Vec (Array (Option Pos)) nfa.nodes.size) :=
  if hemp : stack.isEmpty then
    (matched, next, saveSlots)
  else
    let entry := stack.back' hemp
    let stack' := stack.pop
    have : stack'.size < stack.size := Array.lt_size_of_pop_of_not_empty _ hemp
    match entry with
    | .explore target => exploreεClosure nfa pos next currentSave matched saveSlots target stack'
    | .restore save => εClosure nfa pos next save matched saveSlots stack'
termination_by (next.measure, stack.size, 0)

end

def stepChar (nfa : NFA) (c : Char) (pos : Pos)
  (next : SparseSet nfa.nodes.size)
  (saveSlots : Vec (Array (Option Pos)) nfa.nodes.size)
  (target : Fin nfa.nodes.size) :
  (Option (Array (Option Pos)) × SparseSet nfa.nodes.size × Vec (Array (Option Pos)) nfa.nodes.size) :=
  match hn : nfa[target] with
  | .char c' target' =>
    if c = c' then
      have isLt : target' < nfa.nodes.size := by
        have := nfa.inBounds target
        simp [NFA.get_eq_nodes_get] at hn
        simp [Node.inBounds, hn] at this
        exact this
      let currentSave := saveSlots.get target target.isLt
      exploreεClosure nfa pos next currentSave .none saveSlots ⟨target', isLt⟩ .empty
    else
      (.none, next, saveSlots)
  -- We don't need this as εClosure figures it out if there is a match
  -- | .done =>
  --   -- Return saved positions at the match
  --   (.some saveSlots[target], next, saveSlots)
  | _ => (.none, next, saveSlots)

def eachStepChar (nfa : NFA) (c : Char) (pos : Pos)
  (current : SparseSet nfa.nodes.size) (next : SparseSet nfa.nodes.size)
  (saveSlots : Vec (Array (Option Pos)) nfa.nodes.size) :
  (Option (Array (Option Pos)) × SparseSet nfa.nodes.size × Vec (Array (Option Pos)) nfa.nodes.size) :=
  go 0 (Nat.zero_le _) next saveSlots
where
  go (i : Nat) (hle : i ≤ current.count) (next : SparseSet nfa.nodes.size) (saveSlots : Vec (Array (Option Pos)) nfa.nodes.size) :
    (Option (Array (Option Pos)) × SparseSet nfa.nodes.size × Vec (Array (Option Pos)) nfa.nodes.size) :=
    if h : i = current.count then
      (.none, next, saveSlots)
    else
      have hlt : i < current.count := Nat.lt_of_le_of_ne hle h
      let result := stepChar nfa c pos next saveSlots current[i]
      match result.1 with
      | .none => go (i + 1) hlt result.2.1 result.2.2
      | .some _ => result
  termination_by current.count - i

end NFA.VM

def NFA.search' (nfa : NFA) (s : String) (saveSize : Nat) : Option (Array (Option String.Pos) × String.Pos) :=
  let saveSlots := Vec.ofFn (fun _ => initSave)
  let (matched, init, saveSlots) :=
    NFA.VM.exploreεClosure nfa 0 .empty initSave .none saveSlots nfa.start #[]
  go s.iter init .empty saveSlots (matched.map (fun s => (s, 0)))
where
  initSave : Array (Option String.Pos) := Array.ofFn (fun _ : Fin saveSize => none)
  go (it : String.Iterator)
    (current : SparseSet nfa.nodes.size) (next : SparseSet nfa.nodes.size)
    (saveSlots : Vec (Array (Option String.Pos)) nfa.nodes.size)
    (lastMatch : Option (Array (Option String.Pos) × String.Pos))
    : Id (Option (Array (Option String.Pos) × String.Pos)) := do
    dbgTrace s!"lastMatch = {lastMatch}" fun () =>
    if it.atEnd then
      lastMatch
    else
      if current.isEmpty && lastMatch.isSome then
        lastMatch
      else
        let c := it.curr
        let pos := it.pos
        -- I think ignoring the match here is fine because the match must have happened at the initial exploration
        -- and `lastMatch` must have already captured that.
        let (_, current', saveSlots) := NFA.VM.exploreεClosure nfa pos current initSave .none saveSlots nfa.start #[]
        dbgTrace s!"by εClosure: {current} → {current'}" fun () =>
        let (matched, next, saveSlots) := NFA.VM.eachStepChar nfa c pos current' next saveSlots
        dbgTrace s!"matched = {matched}" fun () =>
        go it.next next current.clear saveSlots (matched.map (fun s => (s, it.next.pos)) <|> lastMatch)
