open Core

module type BddVar = sig
  type t
  type assignments

  val compare : t -> t -> int
  val equal : t -> t -> bool
  val disjoint : t -> t -> bool
  val subset : t -> t -> bool
  val independent : t -> t -> bool

  val eval : assignments -> t -> bool

  val hash : t -> int
  val format_t : t -> string
end

module type BddLabel = sig
  type t
    [@@deriving compare, sexp]
  val format_t : t -> string
end
  
module Conjunction (V: BddVar) : sig
  type true_or_false =
    | T of V.t
    | F of V.t
  type t =
    true_or_false list
  val format_t : t -> string
  val implies : t -> t -> bool
  val eval : V.assignments -> t -> bool
end
  

module Bdd (V: BddVar) (L: BddLabel) : sig

  module LabelSet : module type of Set.Make(L)

  module Conj : module type of Conjunction(V)

  type node =
  | L of leaf
  | N of decision
  and leaf = {leaf_uid: uid; labels: LabelSet.t}
  and decision = {uid: uid; var: V.t; low: node; high: node}
  and uid = int

  val getuid : node -> uid

  val node_equal : node -> node -> bool

  module NodeH : sig
    type t = node
    val equal : t -> t -> bool
    val hash : t -> int
  end

  module NodeWeakHS : module type of Caml.Weak.Make(NodeH)


  type t = {
    table: NodeWeakHS.t;
    next_uid: int ref;
    root: node ref;
    empty_leaf: node;
  }


  val merge_nodes : t -> node -> node -> node
  val dump_dot : t -> string -> unit
  val conj_to_bdd : t -> Conj.t -> L.t -> node
  
  val eval_bdd : t -> V.assignments -> node -> LabelSet.t
  val find_paths : ?path:Conj.t -> node -> ((Conj.t * LabelSet.t) list)

  val init : unit -> t
end
