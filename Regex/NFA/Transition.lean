import Regex.Lemmas
import Regex.NFA.Basic
import Regex.NFA.Compile

import Mathlib.Data.Set.Basic
import Mathlib.Data.Set.Lattice

open Set

-- TODO: we may want to prove that all indices are in bounds get rid of Option helpers.
-- def Option.charStep : Option NFA.Node → Char → Set Nat
--   | some n, c => n.charStep c
--   | none, _ => ∅

-- def Option.εStep : Option NFA.Node → Set Nat
--   | some n => n.εStep
--   | none => ∅

namespace NFA

-- def Option.charStep.simp {nfa : NFA} {i : Nat} {c : Char} :
--   nfa[i]?.charStep c = if h : i < nfa.nodes.size then nfa[i].charStep c else ∅ := by
--   simp [Option.charStep, getElem?]
--   cases Nat.decLt i nfa.nodes.size <;> simp [*]

-- theorem Option.charStep.subset_of_le {nfa₁ nfa₂ : NFA} {i : Nat} (le : nfa₁ ≤ nfa₂) :
--   nfa₁[i]?.charStep c ⊆ nfa₂[i]?.charStep c := by
--   simp [Option.charStep.simp]
--   cases Nat.decLt i nfa₁.nodes.size <;> simp [*]
--   case isTrue h =>
--     let ⟨h', le⟩ := le i h
--     simp [h']
--     exact le.left c

-- def Option.εStep.simp {nfa : NFA} {i : Nat} :
--   nfa[i]?.εStep = if h : i < nfa.nodes.size then nfa[i].εStep else ∅ := by
--   simp [Option.εStep, getElem?]
--   cases Nat.decLt i nfa.nodes.size <;> simp [*]

-- theorem Option.εStep.subset_of_le {nfa₁ nfa₂ : NFA} {i : Nat} (le : nfa₁ ≤ nfa₂) :
--   nfa₁[i]?.εStep ⊆ nfa₂[i]?.εStep := by
--   simp [Option.εStep.simp]
--   cases Nat.decLt i nfa₁.nodes.size <;> simp [*]
--   case isTrue h =>
--     let ⟨h', le⟩ := le i h
--     simp [h']
--     exact le.right

-- inductive NFA.εClosure (nfa : NFA) : Nat → Set Nat where
--   | base : εClosure nfa i i
--   | step {i j k : Nat} (head : j ∈ nfa[i]?.εStep) (tail : nfa.εClosure j k) :
--     εClosure nfa i k

-- theorem εClosure_of_le {nfa₁ nfa₂ : NFA} (le : nfa₁ ≤ nfa₂) (h : j ∈ nfa₁.εClosure i) :
--   j ∈ nfa₂.εClosure i := by
--   induction h with
--   | base => exact .base
--   | step head _ ih => exact .step (mem_of_subset_of_mem (Option.εStep.subset_of_le le) head) ih

-- theorem εClosure_subset_of_le {nfa₁ nfa₂ : NFA} (le : nfa₁ ≤ nfa₂) :
--   nfa₁.εClosure i ⊆ nfa₂.εClosure i := by
--   intro j h
--   exact εClosure_of_le le h

-- theorem εClosure_trans {nfa : NFA} (h₁ : i₂ ∈ nfa.εClosure i₁) (h₂ : i₃ ∈ nfa.εClosure i₂) :
--   i₃ ∈ nfa.εClosure i₁ := by
--   induction h₁ with
--   | base => exact h₂
--   | step head _ ih => exact .step head (ih h₂)

-- def NFA.εClosureSet (nfa : NFA) (S : Set Nat) : Set Nat :=
--   ⋃ i ∈ S, nfa.εClosure i

-- @[simp]
-- theorem subset_εClosureSet {nfa : NFA} : S ⊆ nfa.εClosureSet S := by
--   intro i h
--   apply mem_iUnion_of_mem i
--   simp
--   exact ⟨h, .base⟩

-- @[simp]
-- theorem εClosureSet_singleton_base {nfa : NFA} : i ∈ nfa.εClosureSet {i} := by
--   apply mem_iUnion_of_mem i
--   simp
--   exact .base

-- @[simp]
-- theorem εClosureSet_singleton_step {nfa : NFA} {i j : Nat} (h : j ∈ nfa[i]?.εStep) : j ∈ nfa.εClosureSet {i} := by
--   apply mem_iUnion_of_mem i
--   simp
--   exact .step h .base

-- @[simp]
-- theorem εClosureSet_singleton {nfa : NFA} {i j : Nat} (h : j ∈ nfa.εClosure i):
--   j ∈ nfa.εClosureSet {i} := by
--   apply mem_iUnion_of_mem i
--   simp [h]

-- @[simp]
-- theorem εClosureSet_empty {nfa : NFA} : nfa.εClosureSet ∅ = ∅ := by
--   simp [NFA.εClosureSet]

-- @[simp]
-- theorem εClosureSet_univ {nfa : NFA} : nfa.εClosureSet univ = univ :=
--   univ_subset_iff.mp subset_εClosureSet

-- theorem εClosureSet_subset {nfa₁ nfa₂ : NFA} (hn : nfa₁ ≤ nfa₂) (hs : S₁ ⊆ S₂) :
--   nfa₁.εClosureSet S₁ ⊆ nfa₂.εClosureSet S₂ := by
--   apply biUnion_mono hs
--   intro i _
--   exact εClosure_subset_of_le hn

-- @[simp]
-- theorem εClosureSet_idempotent {nfa : NFA} : nfa.εClosureSet (nfa.εClosureSet S) = nfa.εClosureSet S := by
--   apply eq_of_subset_of_subset
--   . simp [subset_def]
--     intro k h
--     simp [mem_iUnion, NFA.εClosureSet] at h
--     let ⟨i, h, j, cls, cls'⟩ := h
--     exact mem_iUnion_of_mem i (mem_iUnion_of_mem h (εClosure_trans cls cls'))
--   . apply subset_εClosureSet

-- theorem εClosureSet_iUnion_distrib {nfa : NFA} {S : Set α} {f : α → Set Nat} :
--   nfa.εClosureSet (⋃ i ∈ S, f i) = ⋃ i ∈ S, nfa.εClosureSet (f i) := by
--   simp [NFA.εClosureSet]

-- theorem εClosureSet_union_distrib {nfa : NFA} {S₁ S₂ : Set Nat} :
--   nfa.εClosureSet (S₁ ∪ S₂) = nfa.εClosureSet S₁ ∪ nfa.εClosureSet S₂ := by
--   apply eq_of_subset_of_subset
--   . simp [subset_def]
--     intro j h
--     simp [NFA.εClosureSet] at *
--     let ⟨i, h, cls⟩ := h
--     cases h with
--     | inl h => exact .inl ⟨i, h, cls⟩
--     | inr h => exact .inr ⟨i, h, cls⟩
--   . simp [subset_def]
--     intro j h
--     simp [NFA.εClosureSet] at *
--     cases h with
--     | inl h =>
--       let ⟨i, h, cls⟩ := h
--       exact ⟨i, .inl h, cls⟩
--     | inr h =>
--       let ⟨i, h, cls⟩ := h
--       exact ⟨i, .inr h, cls⟩

-- def NFA.stepSet (nfa : NFA) (S : Set Nat) (c : Char) : Set Nat :=
--   ⋃ i ∈ S, nfa.εClosureSet (nfa[i]?.charStep c)

-- @[simp]
-- def stepSet_empty {nfa : NFA} : nfa.stepSet ∅ c = ∅ := by
--   simp [NFA.stepSet]

-- @[simp]
-- theorem εClosureSet_stepSet {nfa : NFA} :
--   nfa.εClosureSet (nfa.stepSet S c) = nfa.stepSet S c := by
--   apply eq_of_subset_of_subset
--   . conv =>
--       lhs
--       simp [NFA.stepSet, εClosureSet_iUnion_distrib]
--   . exact subset_εClosureSet

-- theorem stepSet_subset {nfa₁ nfa₂ : NFA} (hn : nfa₁ ≤ nfa₂) (hs : S₁ ⊆ S₂) :
--   nfa₁.stepSet S₁ c ⊆ nfa₂.stepSet S₂ c := by
--   simp [subset_def, NFA.stepSet]
--   intro j i h₁ h₂

--   exact ⟨
--     i,
--     mem_of_subset_of_mem hs h₁,
--     mem_of_subset_of_mem (εClosureSet_subset hn (Option.charStep.subset_of_le hn)) h₂
--   ⟩

-- def NFA.evalFrom (nfa : NFA) (S : Set Nat) : List Char → Set Nat :=
--   List.foldl (nfa.stepSet) (nfa.εClosureSet S)

-- theorem evalFrom_cons {nfa : NFA} :
--   nfa.evalFrom S (c :: cs) = nfa.evalFrom (nfa.stepSet (nfa.εClosureSet S) c) cs := by
--   have h : nfa.stepSet (nfa.εClosureSet S) c = nfa.εClosureSet (nfa.stepSet (nfa.εClosureSet S) c) :=
--     εClosureSet_stepSet.symm
--   conv =>
--     lhs
--     simp [NFA.evalFrom]
--     rw [h]

-- theorem evalFrom_subset {nfa₁ nfa₂ : NFA} {S₁ S₂ : Set Nat} (hn : nfa₁ ≤ nfa₂) (hs : S₁ ⊆ S₂) :
--   nfa₁.evalFrom S₁ s ⊆ nfa₂.evalFrom S₂ s := by
--   apply le_foldl_of_le
--   . intro _ _ _ hs
--     exact stepSet_subset hn hs
--   . exact εClosureSet_subset hn hs

-- theorem εClosureSet_evalFrom {nfa : NFA} :
--   nfa.εClosureSet (nfa.evalFrom S s) = nfa.evalFrom S s := by
--   apply eq_of_subset_of_subset
--   . induction s generalizing S with
--     | nil => simp [NFA.evalFrom]; exact le_refl _
--     | cons c cs ih =>
--       rw [evalFrom_cons]
--       exact ih
--   . exact subset_εClosureSet

-- theorem mem_evalFrom_subset {nfa : NFA} (hmem : next ∈ nfa.evalFrom S₁ s) (hs : S₁ ⊆ nfa.εClosureSet S₂) :
--   next ∈ nfa.evalFrom S₂ s := by
--   apply mem_of_subset_of_mem _ hmem
--   apply le_foldl_of_le
--   . intro _ _ _ hs
--     exact stepSet_subset (le_refl _) hs
--   . suffices nfa.εClosureSet S₁ ⊆ nfa.εClosureSet (nfa.εClosureSet S₂) by
--       simp at this
--       exact this
--     exact εClosureSet_subset (le_refl _) hs

-- theorem evalFrom_append {nfa : NFA} (eq : s = s₁ ++ s₂) :
--   nfa.evalFrom S s = List.foldl (nfa.stepSet) (nfa.evalFrom S s₁) s₂ := by
--   conv =>
--     lhs
--     rw [eq, NFA.evalFrom, List.foldl_append]

-- theorem mem_evalFrom_le {nfa₁ nfa₂ : NFA} (le : nfa₁ ≤ nfa₂) (h : next ∈ nfa₁.evalFrom S s) :
--   next ∈ nfa₂.evalFrom S s :=
--   evalFrom_subset le (le_refl _) h

-- open NFA

-- theorem evalFrom_of_matches (eq : compile.loop r next nfa = nfa')
--   (m : r.matches s) : ∀ nfa'' : NFA, nfa' ≤ nfa'' → next ∈ nfa''.evalFrom {nfa'.val.start.val} s.data := by
--   induction m generalizing next nfa with
--   | @char s c eqs =>
--     intro nfa'' le
--     apply mem_evalFrom_le le
--     simp [eqs, evalFrom, List.foldl]
--     simp [compile.loop] at eq
--     apply mem_iUnion_of_mem nfa'.val.start.val
--     subst eq
--     simp [Option.charStep, Node.charStep]
--   | @epsilon s eqs =>
--     intro nfa'' le
--     apply mem_evalFrom_le le
--     simp [eqs, evalFrom, List.foldl]
--     simp [compile.loop] at eq
--     apply mem_iUnion_of_mem nfa'.val.start.val
--     subst eq
--     simp [Option.charStep, Node.charStep]
--     exact εClosure.step (by simp [Option.εStep, Node.εStep]) .base
--   | @alternateLeft s r₁ r₂ _ ih =>
--     intro nfa'' le
--     apply mem_evalFrom_le le

--     apply compile.loop.alternate eq
--     intro nfa₁ start₁ nfa₂ start₂ final property eq₁ eq₂ _ _ eq₅ eq

--     have property : nfa₁.val ≤ final.val :=
--       calc nfa₁.val
--         _ ≤ nfa₂.val := nfa₂.property
--         _ ≤ final.val := final.property

--     rw [eq]
--     simp

--     apply mem_evalFrom_subset (ih eq₁.symm final property)
--     simp
--     apply εClosureSet_singleton_step
--     rw [eq₅]
--     simp [Option.εStep, Node.εStep]
--     exact .inl (by rw [eq₂])
--   | @alternateRight s r₁ r₂ _ ih =>
--     intro nfa'' le
--     apply mem_evalFrom_le le

--     apply compile.loop.alternate eq
--     intro nfa₁ start₁ nfa₂ start₂ final property _ _ eq₃ eq₄ eq₅ eq

--     rw [eq]
--     simp

--     apply mem_evalFrom_subset (ih eq₃.symm final final.property)
--     simp
--     apply εClosureSet_singleton_step
--     rw [eq₅]
--     simp [Option.εStep, Node.εStep]
--     exact .inr (by rw [eq₄])
--   | concat s s₁ s₂ r₁ r₂ eqs _ _ ih₁ ih₂ =>
--     intro nfa'' le
--     apply mem_evalFrom_le le

--     apply compile.loop.concat eq
--     intro nfa₂ nfa₁ property eq₂ eq₁ eq

--     rw [eq]
--     simp

--     let ih₁ := ih₁ eq₁.symm nfa₁ (le_refl _)
--     let ih₂ := ih₂ eq₂.symm nfa₁ nfa₁.property

--     apply mem_of_mem_of_subset ih₂
--     rw [evalFrom_append (String.eq_of_append_of_eq_of_append eqs)]
--     apply le_foldl_of_le
--     . intro _ _ _ hs
--       exact stepSet_subset (le_refl _) hs
--     . have : {nfa₂.val.start.val} ⊆ nfa₁.val.evalFrom {nfa₁.val.start.val} s₁.data := by
--         rw [singleton_subset_iff]
--         exact ih₁
--       have : nfa₁.val.εClosureSet {nfa₂.val.start.val} ⊆ nfa₁.val.εClosureSet (nfa₁.val.evalFrom {nfa₁.val.start.val} s₁.data) :=
--         εClosureSet_subset (le_refl _) this
--       rw [εClosureSet_evalFrom] at this
--       exact this
--   | starEpsilon eqs =>
--     intro nfa'' le
--     apply mem_evalFrom_le le

--     apply compile.loop.star eq
--     intro nfa' start nfa'' nodes''' nfa''' isLt isLt' property'
--       _ _ _ eq₄ eq₅ eq'

--     rw [eq']
--     simp

--     simp [eqs, NFA.evalFrom, NFA.εClosureSet]

--     have : nfa'''[nfa'''.start.val] = .split nfa''.val.start next := by
--       rw [eq₅, NFA.eq_get]
--       simp [eq₄]
--     have head : next ∈ nfa'''[nfa'''.start]?.εStep := by
--       unfold getElem?
--       simp [this, Option.εStep, Node.εStep]
--     have tail : next ∈ nfa'''.εClosure next := .base
--     exact NFA.εClosure.step head tail
--   | starConcat s s₁ s₂ r eqs _ _ ih₁ ih₂ =>
--     intro nfa'' le
--     apply mem_evalFrom_le le

--     apply compile.loop.star eq
--     intro nfa' start nfa'' nodes''' nfa''' isLt isLt' property'
--       eq₁ eq₂ eq₃ eq₄ eq₅ eq'

--     rw [eq']
--     simp

--     have eq'' : compile.loop (.star r) next nfa = ⟨nfa''', property'⟩ := by
--       rw [eq'] at eq
--       exact eq
--     have : nfa''.val ≤ nfa''' := by
--       intro i h
--       have : nodes'''.size = nfa''.val.nodes.size := by
--         simp [eq₄]
--       have : i < nodes'''.size := by
--         simp [this, h]
--       have h' : i < nfa'''.nodes.size := by
--         simp [eq₅, this]
--       exists h'
--       cases Nat.decEq start i with
--       | isTrue eq =>
--         have lhs : nfa''.val[i] = .fail := by
--           simp [eq₃, eq.symm]
--           have : start.val < nfa'.val.nodes.size := by
--             rw [eq₂, eq₁]
--             simp
--           simp [compile.loop.get_lt rfl this]
--           have : start.val = (nfa.addNode .fail).val.start.val := by
--             rw [eq₂, eq₁]
--           simp [this, eq₁]
--         have rhs : nfa'''[i] = .split nfa''.val.start next := by
--           simp [NFA.eq_get, eq₅, eq₄, eq.symm]
--         simp [lhs, rhs]
--       | isFalse neq =>
--         have : nodes'''[i] = nfa''.val.nodes[i] := by
--           simp [eq₄]
--           apply Array.get_set_ne
--           exact neq
--         simp [NFA.eq_get, eq₅, this]
--     have ih₁ := ih₁ eq₃.symm nfa''' this
--     have ih₂ := ih₂ eq'' nfa''' (le_refl _)

--     rw [evalFrom_append (String.eq_of_append_of_eq_of_append eqs)]
--     suffices next ∈ nfa'''.evalFrom (nfa'''.evalFrom {nfa'''.start.val} s₁.data) s₂.data by
--       have : next ∈ List.foldl nfa'''.stepSet (nfa'''.εClosureSet (nfa'''.evalFrom {nfa'''.start.val} s₁.data)) s₂.data := by
--         exact this
--       simp [εClosureSet_evalFrom] at this
--       exact this
--     apply mem_evalFrom_subset ih₂
--     simp [εClosureSet_evalFrom]

--     have : nfa'''.start.val = start.val := by
--       rw [eq₅]
--     apply mem_evalFrom_subset (this.symm ▸ ih₁)
--     simp
--     apply εClosureSet_singleton_step
--     have : nfa'''[nfa'''.start.val] = .split nfa''.val.start next := by
--       rw [eq₅, NFA.eq_get]
--       simp [eq₄]
--     simp [this, getElem?, Option.εStep, Node.εStep]

-- -- こんな感じのが必要では
-- -- def NFA.evalFromUntil (nfa : NFA) (S : Set Nat) (next : Nat) (s : List Char) : Option (List Char) :=
-- --   if next ∈ S then
-- --     some s
-- --   else
-- --     match s with
-- --     | [] => none
-- --     | c :: s => nfa.evalFromUntil (nfa.stepSet S c) next s

-- def NFA.stepSet' (nfa : NFA) (S : Set Nat) (c : Char) : Set Nat :=
--   ⋃ i ∈ nfa.εClosureSet S, nfa.εClosureSet (nfa[i]?.charStep c)

-- theorem compile.loop.εClosure_subset (eq : compile.loop r next nfa = result)
--   (h : i ∈ NewNodesRange eq) (cls : j ∈ result.val.εClosure i) :
--   j ∈ result.val.εClosure next ∪ NewNodesRange eq := by
--   induction cls with
--   | base => exact Or.inr h
--   | @step i j k head tail ih =>
--     simp [Option.εStep.simp, h.right] at head
--     -- Use whatever char
--     let ⟨_, h⟩ := step_range (c := default) eq i h.left h.right
--     have : j = next ∨ j ∈ NewNodesRange eq := mem_insert_iff.mp (mem_of_mem_of_subset head h)
--     cases this with
--     | inl h => exact mem_union_left _ (h ▸ tail)
--     | inr h => exact ih h

-- theorem compile.loop.εClosureSet_NewNodesRange (eq : compile.loop r next nfa = result) :
--   result.val.εClosureSet (NewNodesRange eq) ⊆ result.val.εClosure next ∪ NewNodesRange eq := by
--   simp [NFA.εClosureSet]
--   intro i h
--   simp [subset_def]
--   intro j cls
--   exact εClosure_subset eq h cls

-- theorem compile.loop.εClosureSet_subset (eq : compile.loop r next nfa = result)
--   (h : S ⊆ {next} ∪ NewNodesRange eq) :
--   result.val.εClosureSet S ⊆ result.val.εClosure next ∪ NewNodesRange eq := by
--   calc result.val.εClosureSet S
--     _ ⊆ result.val.εClosureSet ({next} ∪ NewNodesRange eq) := by
--       apply NFA.εClosureSet_subset
--       . exact le_refl _
--       . exact h
--     _ = result.val.εClosureSet {next} ∪ result.val.εClosureSet (NewNodesRange eq) :=
--       εClosureSet_union_distrib
--     _ ⊆ result.val.εClosure next ∪ NewNodesRange eq := by
--       simp [εClosureSet_NewNodesRange]
--       simp [εClosureSet]

-- theorem compile.loop.stepSet_subset (eq : compile.loop r next nfa = result)
--   (h : S ⊆ NewNodesRange eq) :
--   result.val.stepSet S c ⊆ result.val.εClosure next ∪ NewNodesRange eq := by
--   simp [NFA.stepSet]
--   intro i h'
--   have : i ∈ NewNodesRange eq := mem_of_subset_of_mem h h'
--   have h'' : nfa.nodes.size ≤ i ∧ i < result.val.nodes.size := by
--     simp [NewNodesRange] at this
--     exact this
--   apply εClosureSet_subset eq
--   simp [Option.charStep.simp, h''.right]
--   let ⟨h, _⟩ := step_range c eq i h''.left h''.right
--   exact h

-- inductive NFA.eval (nfa : NFA) : Set Nat → List Char → Set Nat → List Char → Prop where
--   | base : nfa.eval S cs S cs
--   | step (rest : nfa.eval (nfa.stepSet' S c) cs S' cs') : nfa.eval S (c :: cs) S' cs'

inductive NFA.eval (nfa : NFA) : Nat → List Char → Nat → List Char → Prop where
  | base (eqi : i = j) (eqs : cs = cs') : nfa.eval i cs j cs'
  | charStep {i j k : Nat} {c : Char} {cs cs' : List Char}
    (h : i < nfa.nodes.size) (step : j ∈ nfa[i].charStep c) (rest : nfa.eval j cs k cs') :
    nfa.eval i (c :: cs) k cs'
  | εStep {i j k : Nat} {cs cs' : List Char}
    (h : i < nfa.nodes.size) (step : j ∈ nfa[i].εStep) (rest : nfa.eval j cs k cs') :
    nfa.eval i cs k cs'

-- TODO: is this useful?
theorem NFA.eval_prefix {nfa : NFA} (ev : nfa.eval i s j s₂) :
  ∃s₁, s = s₁ ++ s₂ := by
  induction ev with
  | base => exists []
  | @charStep _ _ _ c _ _ _ _ _ ih =>
    let ⟨s₁', h⟩ := ih
    exists c :: s₁'
    simp [h]
  | εStep _ _ _ ih => exact ih

notation:65 nfa " ⊢ (" i ", " s ") ⟶* (" j ", " s' ")" => NFA.eval nfa i s j s'

theorem eval_last {nfa : NFA} (inBounds : nfa.inBounds) (ev : nfa ⊢ (i, s) ⟶* (k, s')) :
  (i = k ∧ s = s') ∨
  (∃ (j : Fin nfa.nodes.size) (c : Char), nfa ⊢ (i, s) ⟶* (j, c :: s') ∧ k ∈ nfa[j].charStep c) ∨
  (∃ (j : Fin nfa.nodes.size), nfa ⊢ (i, s) ⟶* (j, s') ∧ k ∈ nfa[j].εStep) := by
  induction ev with
  | base eqi eqs => exact .inl ⟨eqi, eqs⟩
  | @charStep i j k c cs cs' h step _ ih =>
    match ih with
    | .inl ⟨eqj, eqs⟩ => exact .inr (.inl ⟨⟨i, h⟩, c, .base rfl (by simp [eqs]), eqj ▸ step⟩)
    | .inr (.inl ⟨j', c', ev', step'⟩) => exact .inr (.inl ⟨j', c', .charStep h step ev', step'⟩)
    | .inr (.inr ⟨j', ev', step'⟩) => exact .inr (.inr ⟨j', .charStep h step ev', step'⟩)
  | @εStep i j k cs cs' h step _ ih =>
    match ih with
    | .inl ⟨eqj, eqs⟩ => exact .inr (.inr ⟨⟨i, h⟩, .base rfl (by simp [eqs]), eqj ▸ step⟩)
    | .inr (.inl ⟨j', c', ev', step'⟩) => exact .inr (.inl ⟨j', c', .εStep h step ev', step'⟩)
    | .inr (.inr ⟨j', ev', step'⟩) => exact .inr (.inr ⟨j', .εStep h step ev', step'⟩)

-- When we expand the NFA by appending nodes, the evaluation relation is preserved in the original range.

theorem eval_ge_of_get_lt {nfa nfa' : NFA} (le : nfa.nodes.size ≤ nfa'.nodes.size)
  (get_lt : ∀ {i}, (h : i < nfa.nodes.size) → nfa'[i]'(Nat.lt_of_lt_of_le h le) = nfa[i])
  (ev : nfa ⊢ (i, s) ⟶* (j, s')) :
  nfa' ⊢ (i, s) ⟶* (j, s') := by
  induction ev with
  | base eqi eqs => exact .base eqi eqs
  | charStep h step _ ih =>
    have eqi := get_lt h
    exact .charStep
      (Nat.lt_of_lt_of_le h le) (eqi.symm ▸ step) ih
  | εStep h step _ ih =>
    have eqi := get_lt h
    exact .εStep
      (Nat.lt_of_lt_of_le h le) (eqi.symm ▸ step) ih

theorem eval_le_of_get_lt {nfa nfa' : NFA} (le : nfa.nodes.size ≤ nfa'.nodes.size)
  (get_lt : ∀ {i}, (h : i < nfa.nodes.size) → nfa'[i]'(Nat.lt_of_lt_of_le h le) = nfa[i])
  (h₁ : i < nfa.nodes.size) (h₂ : nfa.inBounds) (ev : nfa' ⊢ (i, s) ⟶* (j, s')) :
  nfa ⊢ (i, s) ⟶* (j, s') := by
  induction ev with
  | base eqi eqs => exact .base eqi eqs
  | @charStep i j _ c _ _ _ step _ ih =>
    have eqi := get_lt h₁
    rw [eqi] at step
    have : j < nfa.nodes.size := show j ∈ { j | j < nfa.nodes.size } by
      exact mem_of_mem_of_subset step ((h₂ ⟨i, h₁⟩).left c)
    exact .charStep h₁ step (ih this)
  | @εStep i j _ _ _ _ step _ ih =>
    have eqi := get_lt h₁
    rw [eqi] at step
    have : j < nfa.nodes.size := show j ∈ { j | j < nfa.nodes.size } by
      exact mem_of_mem_of_subset step (h₂ ⟨i, h₁⟩).right
    exact .εStep h₁ step (ih this)

theorem eval_addNode_of_eval (eq : NFA.addNode nfa node = result)
  (ev : nfa ⊢ (i, s) ⟶* (j, s')) : result ⊢ (i, s) ⟶* (j, s') :=
  eval_ge_of_get_lt (NFA.le_size_of_le result.property) (fun h => eq ▸ NFA.get_lt_addNode h) ev

theorem eval_compile_of_eval (eq : compile.loop r next nfa = result)
  (ev : nfa ⊢ (i, s) ⟶* (j, s')) : result ⊢ (i, s) ⟶* (j, s') :=
  eval_ge_of_get_lt (NFA.le_size_of_le result.property) (compile.loop.get_lt eq) ev

theorem eval_of_eval_addNode (eq : NFA.addNode nfa node = result)
  (h₁ : i < nfa.nodes.size) (h₂ : nfa.inBounds)
  (ev : result ⊢ (i, s) ⟶* (j, s')) : nfa ⊢ (i, s) ⟶* (j, s') :=
  eval_le_of_get_lt (NFA.le_size_of_le result.property) (fun h => eq ▸ NFA.get_lt_addNode h) h₁ h₂ ev

theorem eval_of_eval_compile (eq : compile.loop r next nfa = result)
  (h₁ : i < nfa.nodes.size) (h₂ : nfa.inBounds)
  (ev : result ⊢ (i, s) ⟶* (j, s')) : nfa ⊢ (i, s) ⟶* (j, s') :=
  eval_le_of_get_lt (NFA.le_size_of_le result.property) (compile.loop.get_lt eq) h₁ h₂ ev

-- The compiled NFA first circulates within the new nodes range,
-- then it must go to the next node before escaping to the original range.

theorem eval_to_next_of_eval (eq : compile.loop r next nfa = result)
  (h₁ : i ∈ compile.loop.NewNodesRange eq) (h₂ : k < nfa.nodes.size)
  (ev : result ⊢ (i, s) ⟶* (k, s'')) :
  ∃ s', result ⊢ (i, s) ⟶* (next, s') ∧ result ⊢ (next, s') ⟶* (k, s'') := by
  induction ev with
  | base eqi =>
    simp [compile.loop.NewNodesRange] at h₁
    exact (Nat.not_lt_of_ge h₁.left (eqi.symm ▸ h₂)).elim
  | @charStep i j k c cs cs' h step rest ih =>
    have mem : j ∈ {next} ∪ compile.loop.NewNodesRange eq := by
      apply mem_of_mem_of_subset step
      exact (compile.loop.step_range c eq i h₁.left h₁.right).left
    cases Nat.decEq j next with
    | isTrue eq =>
      rw [←eq]
      exact ⟨cs, .charStep h step (.base rfl rfl), rest⟩
    | isFalse neq =>
      have : j ∈ compile.loop.NewNodesRange eq := Set.mem_of_mem_insert_of_ne mem neq
      let ⟨s', ih₁, ih₂⟩ := ih this h₂
      exact ⟨s', .charStep h step ih₁, ih₂⟩
  | @εStep i j k cs cs' h step rest ih =>
    have mem : j ∈ {next} ∪ compile.loop.NewNodesRange eq := by
      apply mem_of_mem_of_subset step
      exact (compile.loop.step_range default eq i h₁.left h₁.right).right
    cases Nat.decEq j next with
    | isTrue eq =>
      rw [←eq]
      exact ⟨cs, .εStep h step (.base rfl rfl), rest⟩
    | isFalse neq =>
      have : j ∈ compile.loop.NewNodesRange eq := Set.mem_of_mem_insert_of_ne mem neq
      let ⟨s', ih₁, ih₂⟩ := ih this h₂
      exact ⟨s', .εStep h step ih₁, ih₂⟩

theorem eval_to_next_of_eval_from_start (eq : compile.loop r next nfa = result)
  (h : k < nfa.nodes.size) (ev : result ⊢ (result.val.start, s) ⟶* (k, s'')) :
  ∃ s', result ⊢ (result.val.start, s) ⟶* (next, s') ∧ result ⊢ (next, s') ⟶* (k, s'') := by
  have h₁ : result.val.start.val ∈ compile.loop.NewNodesRange eq := compile.loop.start_in_NewNodesRange eq
  exact eval_to_next_of_eval eq h₁ h ev

inductive evalStar (eq : compile.loop (.star r) next nfa = result) : List Char → List Char → Prop where
  | complete (eqs : s = s') : evalStar eq s s'
  | step (evR : result ⊢ (result.val.start, s) ⟶* (result.val.start, s'')) (evRest : result ⊢ (result.val.start, s'') ⟶* (next, s'))
    (rest : evalStar eq s'' s') : evalStar eq s s'

theorem matches_prefix_of_eval (eq : compile.loop r next nfa = nfa')
  (h₁ : next < nfa.nodes.size) (h₂ : nfa.inBounds)
  (ev : nfa' ⊢ (nfa'.val.start, s) ⟶* (next, s')) :
  ∃ p, s = p ++ s' ∧ r.matches ⟨p⟩ := by
  induction r generalizing next nfa s s' with
  | empty => sorry
  | epsilon => sorry
  | char c => sorry
  | alternate r₁ r₂ ih₁ ih₂ =>
    apply compile.loop.alternate eq
    intro nfa₁ start₁ nfa₂ start₂ final property eq₁ eq₂ eq₃ eq₄ eq₅ eq

    have inBounds₁ := compile.loop.inBounds eq₁.symm h₁ h₂
    have inBounds₂ :=
      compile.loop.inBounds eq₃.symm (Nat.lt_of_lt_of_le h₁ (NFA.le_size_of_le nfa₁.property)) inBounds₁
    have size₁ : next < nfa₁.val.nodes.size := Nat.lt_of_lt_of_le h₁ (NFA.le_size_of_le nfa₁.property)

    rw [eq] at ev
    simp at ev

    cases ev with
    | base eqi =>
      have : final.val.start.val ≠ next := by
        apply Nat.ne_of_gt
        calc next
          _ < nfa.nodes.size := h₁
          _ ≤ nfa₂.val.nodes.size := NFA.le_size_of_le (NFA.le_trans nfa₁.property nfa₂.property)
          _ = _ := by
            rw [eq₅]
            simp [NFA.addNode]
      contradiction
    | @charStep _ j _ c _ _ _ step =>
      have : final.val[final.val.start].charStep c = ∅ := by
        rw [eq₅]
        simp [Node.charStep]
      have : j ∈ ∅ := this ▸ step
      exact this.elim
    | @εStep i j k cs cs' h step rest =>
      have : j = start₁.val ∨ j = start₂.val := by
        subst eq₅
        simp [Node.εStep] at step
        exact step
      have ev₂ : nfa₂ ⊢ (j, s) ⟶* (next, s') := by
        apply eval_of_eval_addNode eq₅.symm _ inBounds₂ rest
        cases this with
        | inl h =>
          have lt₁ : start₁ < nfa₂.val.nodes.size :=
            Nat.lt_of_lt_of_le start₁.isLt (NFA.le_size_of_le nfa₂.property)
          simp [h, lt₁]
        | inr h => simp [h]
      cases this with
      | inl step₁ =>
        have ev₁ : nfa₁ ⊢ (j, s) ⟶* (next, s') := by
          apply eval_of_eval_compile eq₃.symm _ inBounds₁ ev₂
          simp [step₁]
        let ⟨p, eqs, m₁⟩ := ih₁ eq₁.symm h₁ h₂ (eq₂ ▸ step₁ ▸ ev₁)
        exact ⟨p, eqs, .alternateLeft m₁⟩
      | inr step₂ =>
        let ⟨p, eqs, m₂⟩ := ih₂ eq₃.symm size₁ inBounds₁ (eq₄ ▸ step₂ ▸ ev₂)
        exact ⟨p, eqs, .alternateRight m₂⟩
  | concat r₁ r₂ ih₁ ih₂ =>
    apply compile.loop.concat eq
    intro nfa₂ nfa₁ property eq₂ eq₁ eq

    have inBounds₂ := compile.loop.inBounds eq₂.symm h₁ h₂
    have inBounds₁ := compile.loop.inBounds eq₁.symm nfa₂.val.start.isLt inBounds₂

    rw [eq] at ev
    simp at ev
    have : next < nfa₂.val.nodes.size := Nat.lt_of_lt_of_le h₁ (NFA.le_size_of_le nfa₂.property)
    let ⟨s₂s', ev₁, ev'⟩ := eval_to_next_of_eval_from_start eq₁.symm this ev
    let ⟨s₁, eqs₁, m₁⟩ := ih₁ eq₁.symm nfa₂.val.start.isLt inBounds₂ ev₁

    have ev₂ : nfa₂ ⊢ (nfa₂.val.start, s₂s') ⟶* (next, s') :=
      eval_of_eval_compile eq₁.symm nfa₂.val.start.isLt inBounds₂ ev'
    let ⟨s₂, eqs₂, m₂⟩ := ih₂ eq₂.symm h₁ h₂ ev₂

    exact ⟨s₁ ++ s₂, by simp [eqs₁, eqs₂], .concat ⟨s₁ ++ s₂⟩ ⟨s₁⟩ ⟨s₂⟩ r₁ r₂ rfl m₁ m₂⟩
  | star r ih =>
    apply compile.loop.star eq
    intro placeholder start compiled nodes final isLt isLt' property'
      eq₁ eq₂ eq₃ eq₄ eq₅ eq'

    have placeholder.inBounds : placeholder.val.inBounds := by
      intro i
      cases Nat.lt_or_ge i nfa.nodes.size with
      | inl lt =>
        have : placeholder.val[i] = nfa[i] := by
          simp [eq₁, NFA.get_lt_addNode lt]
        rw [this]
        exact Node.inBounds_of_inBounds_of_le (h₂ ⟨i, lt⟩) (NFA.le_size_of_le placeholder.property)
      | inr ge =>
        have : i < nfa.nodes.size + 1 := by
          have : i < placeholder.val.nodes.size := i.isLt
          simp [eq₁, NFA.addNode] at this
          exact this
        have : i = nfa.nodes.size := Nat.eq_of_ge_of_lt ge this
        have : placeholder.val[i] = .fail := by
          simp [eq₁, this]
        rw [this]
        simp
    have inBounds' : nfa'.val.inBounds := compile.loop.inBounds eq h₁ h₂

    have tmp := eval_last inBounds' ev
    match eval_last inBounds' ev with
    | .inl ⟨eqi, _⟩ =>
      -- contradiction
      sorry
    -- TODO: here, we want to establish that `next` can be reached only by εStep from the split node.
    -- Then, we can eliminate the charStep case. For the εStep case, we now have the "loop" evaluation.
    -- We'll construct evalStar from the loop evaluation and induct on it.
    | _ => sorry

    -- have evStar : evalStar eq s s' := by
    --   have ev : final ⊢ (final.start, s) ⟶* (next, s') := by
    --     subst eq'
    --     exact ev
    --   have split : final[final.start.val] = .split compiled.val.start next := by
    --     subst eq₅
    --     simp [NFA.eq_get, eq₄]
    --   cases ev with
    --   | base _ eqs => exact .complete eqs
    --   | charStep _ step => simp [split, Node.charStep] at step
    --   | @εStep i j k s s' _ step rest =>
    --     simp [split, Node.εStep] at step
    --     -- NOTE: It's actually possible to step away from the node range of `star r`.
    --     -- For example, when we compile `(a*)*`, we can escape the region of `(a*)` to the first node of
    --     -- `(a*)*` by taking an εStep, and then go back to the first node by another εStep.
    --     -- Such a case cannot be handled by this setup.
    --     sorry
    -- induction evStar with
    -- | complete eqs => exact ⟨[], by simp [eqs], .starEpsilon rfl⟩
    -- | @step s s'' s' evR evRest rest ih' =>
    --   let ⟨p, eqsr, m⟩ : ∃ p, s = p ++ s'' ∧ r.matches ⟨p⟩ := by
    --     suffices compiled ⊢ (compiled.val.start, s) ⟶* (start, s'') from
    --       ih eq₃.symm start.isLt placeholder.inBounds this
    --     have evR : nfa' ⊢ (start, s) ⟶* (start, s'') := by
    --       have : nfa'.val.start.val = start.val := by
    --         subst eq' eq₅
    --         rfl
    --       exact this ▸ evR
    --     -- ここでevRの第一歩について場合分けするのduplicationじゃないか？後で考える
    --     sorry
    --   let ⟨p', eqsr', m'⟩ := ih' evRest
    --   exact ⟨p ++ p', by simp [eqsr, eqsr'], .starConcat _ _ _ _ rfl m m'⟩

-- theorem matches_of_eval (eq : compile.loop r next nfa = nfa') (assm : next < nfa.nodes.size)
--   (ev : nfa' ⊢ ({nfa'.val.start.val}, s) ⟶* (S', s')) (h : next ∈ S') : ∃p, s = p ++ s' ∧ r.matches ⟨p⟩ := by
--   induction r generalizing next nfa s S' s' with
--   | empty =>
--     apply compile.loop.empty eq
--     intro eq

--     sorry
--   | epsilon => sorry
--   | char c => sorry
--   | alternate r₁ r₂ => sorry
--   | concat r₁ r₂ ih₁ ih₂ =>
--     apply compile.loop.concat eq
--     intro nfa₂ nfa₁ property eq₂ eq₁ eq

--     -- ここでS₁はnfa₂.val.start.valを含むような奴が実はとれる
--     have ev₁ : ∃S₁ s₂_s', nfa₁ ⊢ ({nfa₁.val.start.val}, s) ⟶* (S₁, s₂_s') := sorry
--     let ⟨S₁, s₂_s', ev₁⟩ := ev₁
--     have h₁ : nfa₂.val.start.val ∈ S₁ := sorry
--     have ⟨s₁, eqs₁, m₁⟩ := ih₁ eq₁.symm nfa₂.val.start.isLt ev₁ h₁

--     have ev₂ : nfa₂ ⊢ ({nfa₂.val.start.val}, s₂_s') ⟶* (S', s') := sorry
--     have h₂ : next ∈ S' := sorry
--     have ⟨s₂, eqs₂, m₂⟩ := ih₂ eq₂.symm assm ev₂ h₂

--     have eqs : s = s₁ ++ s₂ ++ s' := by
--       rw [List.append_assoc]
--       exact eqs₂ ▸ eqs₁

--     exact ⟨s₁ ++ s₂, eqs, .concat ⟨s₁ ++ s₂⟩ ⟨s₁⟩ ⟨s₂⟩ r₁ r₂ rfl m₁ m₂⟩
--   | star r => sorry

end NFA
