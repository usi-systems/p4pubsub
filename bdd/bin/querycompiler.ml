open Core
open Core_extended
open Camus
open Query_Bdd

let mk_queries_bdd ?slices:(slices=100) queries =
  let bdd = QueryBdd.init () in
  let cnt = ref 0 in
  let last_time = ref (Unix.gettimeofday ()) in
  let rec split l n =
    if n = 1 then [l]
    else if l = [] then []
    else
      let h, t = List.split_n l ((List.length queries)/slices) in
      h::(split t (n-1))
  in
  let queries_slices = split queries slices in
  let merge_query m (c, i) =
      cnt := !cnt + 1;
      if !cnt mod 1000 = 0
      then
        begin
          let time_now = Unix.gettimeofday () in
          Printf.printf "%d\t%f\n" !cnt (time_now -. !last_time);
          Out_channel.flush stdout;
          last_time := time_now;
        end;
      QueryBdd.merge_nodes bdd m (QueryBdd.conj_to_bdd bdd c i)
  in
  let bdd_for_slice queries_slice =
    List.fold_left ~init:bdd.empty_leaf ~f:merge_query queries_slice
  in
  let slice_bdds =
    List.map ~f:bdd_for_slice queries_slices
  in
  bdd.root := List.fold_left ~init:bdd.empty_leaf ~f:(QueryBdd.merge_nodes bdd) slice_bdds;
  bdd

let verify_bdd (bdd:QueryBdd.t) (queries:(QueryBdd.Conj.t * QueryLabel.t) list) =
  let paths = QueryBdd.find_paths !(bdd.root) in
  let all_terminal_lbls = List.fold_left ~init:QueryBdd.LabelSet.empty ~f:QueryBdd.LabelSet.union (List.map ~f:snd paths) in
  let query_lbls = List.map ~f:snd queries in
  List.iter (* all query labels should be found in the BDD's terminals *)
    query_lbls
    ~f:(fun lbl -> assert (QueryBdd.LabelSet.mem all_terminal_lbls lbl));
  let check_conj (path, lbls) (conj, lbl) : unit =
    if QueryBdd.Conj.implies path conj
    then
      assert (QueryBdd.LabelSet.mem lbls lbl)
    else
      assert (not (QueryBdd.LabelSet.mem lbls lbl))
  in
  let check_path (path, lbls) : unit =
    List.iter queries ~f:(check_conj (path, lbls))
  in
  List.iter paths ~f:check_path

let fmt_query ((conj:QueryBdd.Conj.t), (lbl:QueryLabel.t)) : string =
  (QueryBdd.Conj.format_t conj) ^ " : " ^ (QueryLabel.format_t lbl)

let fmt_queries (queries:(QueryBdd.Conj.t * QueryLabel.t) list) : string =
  String.concat ~sep:"\n" (List.map ~f:fmt_query queries)

let mk_queries ?unique_lbl:(unique_lbl=true) ?random_op:(random_op=false) num_queries =
  let open QueryPred in
  let open QueryBdd.Conj in
  let randop () = match Random.int 3 with 0 -> Lt | 1 -> Gt | _ -> Eq in
  let queries =
    List.fold_left
      ~init:[]
      ~f:(fun queries i ->
        let lbl = if unique_lbl then i else Random.int 101 in
        let a, b = Random.int 101, Random.int 1001 in
        let opa, opb = if random_op then (randop (), randop ()) else (Eq, Gt) in
        ([T("a", opa, a); T("b", opb, b)], lbl)::queries)
      (List.range 1 (num_queries+1))
  in
  queries

let main dot_fname random_seed =
  (*
  let a = ([T("a", Eq, 3); T("b", Eq, 3)], 1) in
  let b = ([T("a", Gt, 1); T("b", Eq, 4)], 2) in
  let c = ([T("a", Gt, 2); T("b", Gt, 2)], 3) in
  let d = ([T("a", Lt, 2); T("b", Lt, 1)], 4) in
  let queries = [a; b; c; d] in
  Printf.printf "%s\n" (fmt_queries queries);
  *)
  let seed = match random_seed with Some s -> s | _ -> 1337 in
  Random.init seed;

  let num_queries = 10000 in
  let queries = mk_queries num_queries in

  Printf.printf "Generated %d queries.\n" num_queries; Out_channel.flush stdout;
  let bdd = mk_queries_bdd queries in
  Printf.printf "Built BDD.\n"; Out_channel.flush stdout;

  (match dot_fname with
  | Some fname -> QueryBdd.dump_dot bdd fname
  | _ -> ());
  verify_bdd bdd queries;
  ()


let spec =
  let open Command.Spec in
  empty
  +> flag "-dot" (optional string) ~doc:("o Output file")
  +> flag "-seed" (optional int) ~doc:("s Random seed")
    
let command =
  Command.basic_spec
    ~summary:"compile queries to BDD tables"
    spec
    (fun o s () ->
      main o s
     )

let () =
  Command.run ~version:"0.1" command

