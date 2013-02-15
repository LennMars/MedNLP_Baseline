let output filename lines =
  let ch = open_out filename in
  List.iter (Printf.fprintf ch "%s\n") lines;
  close_out ch

let main =
  let ch = stdin in
  let rec aux acc =
    try
      let raw_line = input_line ch in
      let tag_removed_line = Str.global_replace (Str.regexp "<[^<>]*>") "" raw_line in
      if tag_removed_line = "" then
        aux acc
      else
        let rand = Random.int max_int in
        aux ((rand, (raw_line, tag_removed_line)) :: acc)
    with
      | End_of_file ->
        let randomized = List.map snd (List.sort compare acc) in
        let raw_lines, tag_removed_lines = List.split randomized in
        output "raw.txt" raw_lines;
        output "notag.txt" tag_removed_lines in
  aux []
