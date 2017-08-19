(* Parser and surface language types *)
type info = (int * int) * (int * int)

type content =
| Blob of string
| Quoted of string
| Curlied of content
| Concat of content * content

type name = string

type tag = Tag of name * content

type tags = tag list

type etype = 
| InProceedings
| Article
| Misc
| Unknown of string

type key = string

type entry =
| StringEntry of tags
| PreambleEntry of string
| RecordEntry of etype * key * tags
| CommentEntry of string

type entries = entry list

type database = Database of entries
