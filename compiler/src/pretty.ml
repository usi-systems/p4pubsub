(* open Core.Std *)
open Ast
open Format

let rec format_value fmt = function
  | Quoted(s) -> Format.fprintf fmt "%s" s
  | Curlied(s) ->  Format.fprintf fmt "{%a}" format_value s
  | Concat(l,r) ->  Format.fprintf fmt "%a # %a" format_value l format_value r
  | Blob(s) -> Format.fprintf fmt "%s" s 

let format_tag fmt (Tag(k,v)) = 
  Format.fprintf fmt "@[<h 2>%10s = @[<hov 2> %a@]@]" k format_value v

let rec format_tags fmt = function
  |[h] -> Format.fprintf fmt "%a" format_tag h
  |h::t ->
    Format.fprintf fmt "%a,@\n%a"
      format_tag h format_tags t
  |[] -> ()

let format_kind fmt = function 
  | InProceedings -> Format.fprintf fmt "%s" "InProceedings" 
  | Article -> Format.fprintf fmt "%s" "Article" 
  | Misc -> Format.fprintf fmt "%s" "Misc" 
  | Unknown(s) -> Format.fprintf fmt "%s" s

let format_key fmt ast =
  Format.fprintf fmt "%s" ast
    
let format_entry fmt ast = 
  match ast with 
  | StringEntry(fs) -> 
    Format.fprintf fmt "STRING{%a}" format_tags fs
  | PreambleEntry(s) -> 
    Format.fprintf fmt "Preamble{%s}" "xxx"
  | RecordEntry(kind,key,fs) -> 
    Format.fprintf fmt "@@%a{%a,@\n%a@\n}" 
      format_kind kind
      format_key key
      format_tags fs
  | CommentEntry(s) -> 
    Format.fprintf fmt "Comment %s" s 

let rec format_database fmt = function
  |[h] -> Format.fprintf fmt "%a" format_entry h
  |h::t ->
    Format.fprintf fmt "%a@\n@\n%a"
      format_entry h format_database t
  |[] -> ()
    
let format ast = 
  let fmt = Format.std_formatter in 
(*
  let buf = Buffer.create 100 in
  let fmt = formatter_of_buffer buf in *)
  (* pp_set_margin fmt 80; *)
  let (Database(es)) = ast in 
  format_database fmt es
