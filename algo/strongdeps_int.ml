(***************************************************************************************)
(*  Copyright (C) 2009  Pietro Abate <pietro.abate@pps.jussieu.fr>                     *)
(*                                                                                     *)
(*  This library is free software: you can redistribute it and/or modify               *)
(*  it under the terms of the GNU Lesser General Public License as                     *)
(*  published by the Free Software Foundation, either version 3 of the                 *)
(*  License, or (at your option) any later version.  A special linking                 *)
(*  exception to the GNU Lesser General Public License applies to this                 *)
(*  library, see the COPYING file for more information.                                *)
(***************************************************************************************)

(** Strong Dependencies *)

open Graph
open ExtLib
open Common
open CudfAdd

(** progress bar *)
let mainbar = Util.Progress.create "Algo.Strongdep.main"

(** progress bar *)
let conjbar = Util.Progress.create "Algo.Strongdep.conj"

module PkgV = struct
    type t = int
    let compare = Pervasives.compare
    let hash = Hashtbl.hash
    let equal = (=)
end

module G = Imperative.Digraph.ConcreteBidirectional(PkgV)

open Depsolver_int
open G

(** check if p strong dependens on q.
    We check if it is possible to install p without q.
 *)
(* ATT: this function makes a copy of the solver to add a clause to it *)
let strong_depends solver p q =
  Depsolver_int.S.reset solver.constraints; 
  let solver = Depsolver_int.copy_solver solver in 
  let lit = Depsolver_int.S.lit_of_var (solver.map#vartoint q) false in
  Depsolver_int.S.add_un_rule solver.constraints lit [];
  match Depsolver_int.solve solver (Diagnostic_int.Sng p) with
  |Diagnostic_int.Failure _ -> true
  |Diagnostic_int.Success _ -> false

(** check if [p] strong depends on any packages in [l] *)
let check_strong graph solver p l =
  List.iter (fun q ->
    if not(p = q) then
      if not(G.mem_edge graph p q) then
        if strong_depends solver p q then 
          G.add_edge graph p q
  ) l

let conj_dependencies graph index l =
  let disj = ref false in
  let rec __conj_dependencies path =
    let id = List.hd path in
    let altlist = index.(id).Mdf.depends in
    Array.iter (function
      |(_,pa,_) when Array.length pa = 1 ->
          let p = pa.(0) in
          if G.mem_edge graph id p then begin
            List.iter (fun id1 ->
              G.iter_succ (fun id2 ->
                if not(id1 = id2) then 
                  G.add_edge graph id1 id2
              ) graph p
            ) path 
          end else begin
            List.iter (fun id1 ->
              if not(id1 = p) then
                G.add_edge graph id1 p
            ) path;
            if not(List.mem p path) then
              __conj_dependencies (p::path)
          end
      |_ -> disj := true
    ) altlist
  in
  try ( __conj_dependencies l ; !disj ) with _ -> assert false
;;

(** [strongdeps l] build the strong dependency graph of l *)
let strongdeps_int graph mdf available =
  let size = List.length available in

  Util.Progress.set_total mainbar size;
  let strongtimer = Util.Timer.create "Algo.Strongdep.strong" in

  Util.Timer.start strongtimer;
  List.iter (fun (pkg1,_,closure) ->
    let pkg1_id = pkg1.Mdf.id in
    Util.Progress.progress mainbar;
    if Array.length pkg1.Mdf.depends > 0 then begin
      (* we don't bother to call the solver if the package does not have
       * any real disjunction *)
      let anydisjuctions = conj_dependencies graph mdf.Mdf.index [pkg1_id] in
      if anydisjuctions then begin 
        let solver = Depsolver_int.init_solver ~idlist:closure mdf.Mdf.index in
        match Depsolver_int.solve solver (Diagnostic_int.Sng pkg1_id) with
        |Diagnostic_int.Failure(_) -> ()
        |Diagnostic_int.Success(f) -> begin
          check_strong graph solver pkg1_id (f ())
        end
      end
    end
  ) available ;
  Util.Timer.stop strongtimer graph

(* XXX this can be refactored in a better way ... *)
let strongdeps mdf idlist =
  let graph = G.create () in
  let size = List.length idlist in
  Util.Progress.set_total conjbar size;
  let conjtimer = Util.Timer.create "Algo.Strongdep.conjdep" in

  Util.Timer.start conjtimer;
  let l = 
    List.fold_left (fun acc id ->
      let pkg = mdf.Mdf.index.(id) in
      Util.Progress.progress conjbar;
      (* conj_dependencies graph mdf.Mdf.index [id]; *)
      let closure = dependency_closure mdf [id] in
      (pkg,List.length closure,closure) :: acc
    ) [] idlist
  in
  let l = List.sort ~cmp:(fun (_,n,_) (_,m,_) -> m - n) l in
  Util.Timer.stop conjtimer ();
  strongdeps_int graph mdf l

(* XXX this can be refactored in a better way ... *)
let strongdeps_univ mdf =
  let graph = G.create () in
  let size = Array.length mdf.Mdf.index in
  Util.Progress.set_total conjbar size;
  let conjtimer = Util.Timer.create "Algo.Strongdep.conjdep" in

  Util.Timer.start conjtimer;
  let l = 
    let id = ref 0 in
    Array.fold_left (fun acc pkg ->
      Util.Progress.progress conjbar;
      (* conj_dependencies graph mdf.Mdf.index [!id]; *)
      let closure = dependency_closure mdf [!id] in
      incr id ;
      (pkg,List.length closure,closure) :: acc
    ) [] mdf.Mdf.index
  in
  let l = List.sort ~cmp:(fun (_,n,_) (_,m,_) -> m - n) l in
  Util.Timer.stop conjtimer ();
  strongdeps_int graph mdf l


(* 
let strong_pred graph q =
  G.iter_pred_e (fun edge ->
    let p = G.E.src edge in
    let in_d = G.in_degree graph p in
    Printf.printf "%s with In degree of %d\n" (CudfAdd.print_package p) in_d
  ) graph q

let dependency_graph available =
let gr = G.make (List.length available) in
List.iter (fun (pid,dl,cl) ->
  G.add_vertex gr pid ;
  List.iter (function
    |[p] -> G.add_vertex gr p 
    |l -> List.iter (fun p -> G.add_vertex gr p ) l
  ) dl
) available
;
gr

let sensitivity h f graph =
  let ht = Hashtbl.create (G.nb_vertex graph) in
  G.iter_vertex (fun v ->
    G.iter_succ (fun v' ->
      try Hashtbl.replace ht v' ((Hashtbl.find ht v') + 1)
      with Not_found -> Hashtbl.add ht v' 1
    ) graph v
  ) graph;
  Hashtbl.iter (fun p _ ->
    if Hashtbl.mem ht p then
      Printf.printf "%d %s\n" (Hashtbl.find ht p) (pr p)
    else begin
      let dom = dominator pr (dependency_graph (f h p)) p in
      let d =
        List.filter (fun x ->
          try ((Hashtbl.find ht x) >= 5000) && x <> p
          with Not_found -> false
        ) dom
      in
      if d <> [] then begin
        let s = String.concat "," (List.map pr d) in
        Printf.printf "%s is dominated by %s \n" (pr p) s;
        flush_all ()
      end
    end
  ) h

          (*
          let inter a b =
            if List.length a < List.length b then
              List.filter (fun i -> List.mem i b) a 
            else
              List.filter (fun i -> List.mem i a) b
          in
          let is = f () in
          List.iter (fun p ->
            if not(processed.(p)) then begin
              let closure = let (_,_,c) = available.(p) in c in
              processed.(p) <- true;
              Util.Progress.progress mainbar;
              check_strong graph solver p (inter closure is)
            end
          ) is
          *)

*)
