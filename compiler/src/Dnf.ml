open Formula

let rec to_nnf = function
   | Empty | Not(Empty) -> Empty
   | Var(_) as p -> p
   | Not(Var(_)) as p -> p
   | Not(Not(p)) -> to_nnf p
   | Not(And((Var(_) as p), (Var(_) as q))) -> Or(Not(p), Not(q))
   | Not(Or((Var(_) as p), (Var(_) as q))) -> And(Not(p), Not(q))
   | Not(And(p, q)) -> Or(to_nnf (Not(p)), to_nnf (Not(q)))
   | Not(Or(p, q)) -> And(to_nnf (Not(p)), to_nnf (Not(q)))
   | And(p, q) -> And(to_nnf p, to_nnf q)
   | Or(p, q) -> Or(to_nnf p, to_nnf q)


let rec conj_fold f acc conj = match conj with 
   | And(((And(_,_) as c1)), ((And(_,_) as c2))) ->
         conj_fold f (conj_fold f acc c1) c2
   | And(((And(_,_) as c)), a)
   | And(a, ((And(_,_) as c))) -> 
         conj_fold f (f acc a) c
   | And(a, b) -> 
         f (f acc a) b
   | a -> f acc a

let conj_contains conj p =
   conj_fold (fun acc q -> if acc then acc else p = q) false conj


let conj_dedup conj =
   let f acc p = match acc with
      | Empty -> p
      | c when conj_contains c p -> c
      | c -> And(p, c)
   in
   conj_fold f Empty conj


let is_conj_satisfiable conj =
   let is_opposite p q = match (p, q) with
      | (Not(Var(a)), Var(b)) when a = b -> true
      | (Var(a), Not(Var(b))) when a = b -> true
      | _ -> false
   in
   let contains_opposite acc p =
      if acc then acc else
         conj_fold (fun acc q -> if acc then acc else is_opposite p q) false conj
   in
   not (conj_fold contains_opposite false conj)


let conj_is_subset conj_sup conj_sub =
   conj_fold (fun acc p -> if acc then (conj_contains conj_sup p) else acc) true conj_sub

let conj_eq conj1 conj2 =
   (conj_is_subset conj1 conj2) && (conj_is_subset conj2 conj1)


let rec disj_fold f acc disj = match disj with 
   | Or(((Or(_,_) as d1)), ((Or(_,_) as d2))) ->
         disj_fold f (disj_fold f acc d1) d2
   | Or(((Or(_,_) as d)), a)
   | Or(a, ((Or(_,_) as d))) -> 
         disj_fold f (f acc a) d
   | Or(a, b) -> 
         f (f acc a) b
   | a -> f acc a


let disj_map f disj =
   let mapper acc x = match acc with
      | Empty -> f x
      | d -> Or(d, f x)
   in
   disj_fold mapper Empty disj


let disj_filter f disj =
   let filterer acc x = match (acc, f x) with
      | (Empty, true) -> x
      | (Empty, false) -> Empty
      | (y, true) -> Or(y, x)
      | (y, false) -> y
   in
   disj_fold filterer Empty disj


let disj_contains disj conj =
   let f acc conj2 = match acc with
      | true -> true
      | false -> 
            conj_eq conj conj2
   in
   disj_fold f false disj
      

let disj_dedup disj =
   let f acc conj = match acc with
      | Empty -> conj
      | d when disj_contains d conj -> d
      | d -> Or(d, conj)
   in
   disj_fold f Empty disj

let cmp_conj_atom a b = match (a, b) with
   | (Not(Var(x)), Var(y)) when x = y -> 1
   | (Var(x), Not(Var(y))) when x = y -> -1
   | (Not(Var(x)), Not(Var(y)))
   | (Var(x), Not(Var(y)))
   | (Not(Var(x)), Var(y))
   | (Var(x), Var(y)) -> cmp_vars x y
   | _ ->
         raise (Failure "Conj should only contain Var or Not(Var)")

let conj_to_list c =
   List.sort cmp_conj_atom
      (conj_fold
         (fun acc x -> (match x with 
            | Empty -> acc
            | _ -> x::acc)
         )
         [] c)
let disj_to_list d =
   disj_fold (fun acc c -> (match conj_to_list c with
      | [] -> acc
      | l -> l::acc))
   [] d

let dnf_canonicalize disj =
   let rec cmp_atom_list a b = match (a, b) with
      | (x::a2, y::b2) -> let c = cmp_conj_atom x y in
            if c = 0 then cmp_atom_list a2 b2 else c
      | ([], []) -> 0 | ([], _) -> -1 | (_, []) -> 1
   in
   let rec list_to_conj conj_atom_list = match conj_atom_list with
      | a::[] -> a
      | a::l2 -> And(a, list_to_conj l2)
      | [] -> Empty
   in
   let rec list_to_disj conj_list = match conj_list with
      | c::[] -> c
      | c::l2 -> Or(c, list_to_disj l2)
      | [] -> Empty
   in
   list_to_disj
      (List.map list_to_conj
         (List.sort cmp_atom_list
            (disj_to_list disj)))
   


let to_dnf t =
   let rec dist_left l r = match r with
      | Or(p, q) -> Or(dist_left l p, dist_left l q)
      | _ -> And(l, r)
   in
   let rec dist_right l r = match l with
      | Or(p, q) -> Or(dist_right p r, dist_right q r)
      | _ -> dist_left l r
   in
   let rec dist = function
      | Or(p, q) -> Or(dist p, dist q)
      | And(p, q) -> dist_right (dist p) (dist q)
      | t -> t
   in
   let unreduced_dnf = dist (to_nnf t) in
   dnf_canonicalize (                              (* canonicalize the tree structure *)
      disj_dedup (                                 (* remove duplicate conjunctions *)
         disj_filter is_conj_satisfiable           (* remove unsatisfiable conjunctions *)
            (disj_map conj_dedup unreduced_dnf)))  (* remove duplicate preds *)

