(* graph playground *)

open Graph
open Bc
open ExtString
   

module G = Pack.Digraph

let int_to_blockname fu i = (List.nth fu.fblocks i).bname
  
	     
(*
 *
 * This hashtbl maps the block name v to its index.
 *
 *)
let create_indices fu n =
  let indices = Hashtbl.create n in
    List.iter (fun blk -> Hashtbl.add indices blk.bname blk.bindex) fu.fblocks;
    indices

let print_node fu e =
  Printf.eprintf "node %s [%s]\n" (Llvm_pp.string_of_var fu.fname) (Llvm_pp.string_of_var (int_to_blockname fu (G.V.label e)))

      
let fu_to_graph fu =
  (* the number of blocks a.k.a nodes *)
  let nodecount = (List.length fu.fblocks) in
  (* maps the name of the block to its index *)
  let indices = create_indices fu nodecount in
  let nodes = Array.init nodecount G.V.create in
  let edges = fu.successors in
  let g = (G.create ?size:(Some(Hashtbl.length edges)) ()) in
  let get_index = (fun v -> nodes.(Hashtbl.find indices v)) in
  let add_edge = (fun v0 v1 -> (G.add_edge g (get_index v0)(get_index v1))) in
    Hashtbl.iter add_edge  edges;
    (* (Trevor.iter (fun e -> print_node fu e) g); *)
    g


		     

let show_cycles b fu ll =
  let length = (List.length ll) in
    Printf.bprintf  b
      ";; Function %s contains %d cycle%s\n"
      (Llvm_pp.string_of_var fu.fname)
      length
      (if length > 1 then "s" else "");
    let show_cycle l = 
      Printf.bprintf b ";; ";
      List.iter (fun e -> (Printf.bprintf b "%s -> " (Llvm_pp.string_of_var (int_to_blockname fu (G.V.label e))))) l;
      Printf.bprintf b "\n";
    in
      List.iter show_cycle ll;
      Printf.bprintf b ";;\n"

let dump_cycles fu ll =
  let length = (List.length ll) in
    Printf.eprintf  
      ";; Function %s contains %d cycle%s\n"
      (Llvm_pp.string_of_var fu.fname)
      length
      (if length > 1 then "s" else "");
    let dump_cycle l = 
      Printf.eprintf  ";; ";
      List.iter (fun e -> (Printf.eprintf "%s -> " (Llvm_pp.string_of_var (int_to_blockname fu (G.V.label e))))) l;
      Printf.eprintf  "\n";
    in
      List.iter dump_cycle ll;
      Printf.eprintf ";;\n"

let cycle_to_edge fu l =
  let len = List.length l in
  let first = List.nth l 0 in
  let last = List.nth l (len - 1) in
    ((int_to_blockname fu (G.V.label last)), (int_to_blockname fu (G.V.label first)))
       
let cycles_to_edges fu ll =
  List.map (fun l -> cycle_to_edge fu l) ll;
  
    
		
