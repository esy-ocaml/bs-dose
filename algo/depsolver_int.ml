(**************************************************************************************)
(*  Copyright (C) 2009 Pietro Abate <pietro.abate@pps.jussieu.fr>                     *)
(*  Copyright (C) 2009 Mancoosi Project                                               *)
(*                                                                                    *)
(*  This library is free software: you can redistribute it and/or modify              *)
(*  it under the terms of the GNU Lesser General Public License as                    *)
(*  published by the Free Software Foundation, either version 3 of the                *)
(*  License, or (at your option) any later version.  A special linking                *)
(*  exception to the GNU Lesser General Public License applies to this                *)
(*  library, see the COPYING file for more information.                               *)
(**************************************************************************************)

(** Dependency solver. Low Level API *)

(** Implementation of the EDOS algorithms (and more). This module respect the cudf semantic. *)

open ExtLib
open Common

(** progress bar *)
let progressbar_init = Util.Progress.create "Depsolver_int.init_solver"
let progressbar_univcheck = Util.Progress.create "Depsolver_int.univcheck"

include Util.Logging(struct let label = __FILE__ end) ;;

module R = struct type reason = Diagnostic_int.reason end
module S = EdosSolver.M(R)

(** associate a sat solver variable to a package id *)
class intprojection size = object

  val vartoint = Util.IntHashtbl.create (2 * size)
  val inttovar = Array.create size 0
  val mutable counter = 0

  (** add a package id to the map *)
  method add v =
    if (size = 0) then assert false ;
    if (counter > size - 1) then assert false;
    debug "intprojection : var %d -> int %d" v counter;
    Util.IntHashtbl.add vartoint v counter;
    inttovar.(counter) <- v;
    counter <- counter + 1

  (** given a package id return a sat solver variable 
      raise Not_found if the package id is not known *)
  method vartoint v = Util.IntHashtbl.find vartoint v

  (* given a sat solver variable return a package id *)
  method inttovar i =
    if (i >= size) then fatal "out of boundary i = %d size = %d" i size;
    inttovar.(i)
end

class identity = object
  method add (v : int) = ()
  method vartoint (v : int) = v
  method inttovar (v : int) = v
end

(* return a conversion function. If the closure is empty, 
 * then we return the identity function, otherwise we 
 * return a function to renumber cudf uids to solver ids *)
let init_map closure univ =
  if List.length closure > 0 then begin
    let map = new intprojection (List.length closure) in
    List.iter map#add closure;
    map
  end
  else new identity

(** low level solver data type *)
type solver = {
  constraints : S.state; (** the sat problem *)
  map : intprojection
}

type pool_t =
  ((Cudf_types.vpkg list * S.var list) list * 
   (Cudf_types.vpkg * S.var list) list * bool) array
and pool = SolverPool of pool_t | CudfPool of pool_t

type result =
  |Success of (unit -> int list)
  |Failure of (unit -> Diagnostic_int.reason list)

(* two functions to make sure we alway manipulate the correct data type *)
let strip_solver_pool = function SolverPool p -> p | _ -> assert false
let strip_cudf_pool = function CudfPool p -> p | _ -> assert false

(* cudf uid -> cudf uid array . Here we assume cudf uid are sequential
 * and we can use them as an array index *)
let init_pool_univ univ =
  let pool = 
    Array.init (Cudf.universe_size univ) (fun uid ->
      let pkg = Cudf.package_by_uid univ uid in
      let dll = 
        List.map (fun vpkgs ->
          (vpkgs, CudfAdd.resolve_vpkgs_int univ vpkgs)
        ) pkg.Cudf.depends 
      in
      let cl = 
        List.map (fun vpkg ->
          (vpkg, CudfAdd.resolve_vpkg_int univ vpkg)
        ) pkg.Cudf.conflicts
      in
      (dll,cl,pkg.Cudf.keep = `Keep_package)
    )
  in CudfPool pool
;;

(* this function creates an array indexed by solver
 * ids that can be used to init the edos solver *)
let init_solver_pool map pool closure =
  let cudfpool = strip_cudf_pool pool in
  let solverpool = 
    Array.init (List.length closure) (fun sid ->
      let uid = map#inttovar sid in
      let (dll,cl,e) = cudfpool.(uid) in
      let sdll = 
        List.map (fun (vpkgs,uidl) ->
          (vpkgs,List.map map#vartoint uidl)
        ) dll
      in
      let scl = 
      (* ignore conflicts that are not in the closure.
       * if nobody depends on a conflict package, then it is irrelevant.
       * This requires a leap of faith in the user ability to build an
       * appropriate closure. If the closure is wrong, you are on your own *)
        List.map (fun (vpkg,uidl) ->
          let l =
            List.filter_map (fun uid -> 
              try Some(map#vartoint uid)
              with Not_found -> begin
                debug "Dropping Conflict %s" (Cudf_types_pp.string_of_vpkg vpkg) ;
                None
              end
            ) uidl
          in
          (vpkg, l)
        ) cl 
      in
      (sdll,scl,e)
    )
  in SolverPool solverpool
;;

(* initalise the sat solver. operate only on solver ids *)
let init_solver_cache ?(buffer=false) pool =
  let pool = strip_solver_pool pool in
  let num_conflicts = ref 0 in
  let num_disjunctions = ref 0 in
  let num_dependencies = ref 0 in
  let size = Array.length pool in

  let add_depend constraints vpkgs pkg_id l =
    let lit = S.lit_of_var pkg_id false in 
    if (List.length l) = 0 then 
      S.add_rule constraints [|lit|] [Diagnostic_int.Missing(pkg_id,vpkgs)]
    else begin
      let lits = List.map (fun id -> S.lit_of_var id true) l in
      num_disjunctions := !num_disjunctions + (List.length lits);
      S.add_rule constraints (Array.of_list (lit :: lits))
        [Diagnostic_int.Dependency (pkg_id, vpkgs, l)];
      if (List.length lits) > 1 then
        S.associate_vars constraints (S.lit_of_var pkg_id true) l;
    end
  in

  let conflicts = Hashtbl.create (size / 10) in
  let add_conflict constraints vpkg (i,j) =
    if i <> j then begin
      let pair = (min i j,max i j) in
      (* we get rid of simmetric conflicts *)
      if not(Hashtbl.mem conflicts pair) then begin
        incr num_conflicts;
        Hashtbl.add conflicts pair ();
        let p = S.lit_of_var i false in
        let q = S.lit_of_var j false in
        S.add_rule constraints [|p;q|] [Diagnostic_int.Conflict(i,j,vpkg)];
      end
    end
  in

  let exec_depends constraints pkg_id dll =
    List.iter (fun (vpkgs,dl) ->
      incr num_dependencies;
      add_depend constraints vpkgs pkg_id dl
    ) dll
  in 

  let exec_conflicts constraints pkg_id cl =
    List.iter (fun (vpkg,l) ->
      List.iter (fun id ->
        add_conflict constraints vpkg (pkg_id, id)
      ) l
    ) cl
  in

  Util.Progress.set_total progressbar_init size ;
  let constraints = S.initialize_problem ~buffer size in

  Array.iteri (fun id (dll,cl,essential) ->
    Util.Progress.progress progressbar_init;
    exec_depends constraints id dll;
    exec_conflicts constraints id cl;
    if essential then S.add_rule constraints [|S.lit_of_var id true|] [];
  ) pool;
    
  Hashtbl.clear conflicts;

  debug "n. disjunctions %d" !num_disjunctions;
  debug "n. dependencies %d" !num_dependencies;
  debug "n. conflicts %d" !num_conflicts;

  S.propagate constraints ;
  constraints
;;

(** low level constraint solver initialization
 
    @param buffer debug buffer to print out debug messages
    @param univ cudf package universe
*)
let init_solver_univ ?(buffer=false) univ =
  let map = new identity in
  let pool = SolverPool (strip_cudf_pool (init_pool_univ univ)) in
  { constraints = init_solver_cache ~buffer pool ; map = map }
;;

(** low level constraint solver initialization
 
    @param buffer debug buffer to print out debug messages
    @param pool dependencies and conflicts array idexed by package id
    @param closure subset of packages used to initialize the solver
*)
(* pool = cudf pool - closure = dependency clousure . cudf uid list *)
let init_solver_closure ?(buffer=false) pool closure =
  let map = new intprojection (List.length closure) in
  List.iter map#add closure;
  let pool = init_solver_pool map pool closure in
  { constraints = init_solver_cache ~buffer pool ; map = map }
;;

(** return a copy of the state of the solver *)
let copy_solver solver =
  { solver with constraints = S.copy solver.constraints }

(** low level call to the sat solver *)
let solve solver request =
  (* XXX this function gets called a zillion times ! *)
  S.reset solver.constraints;

  let result solve collect var =
    if solve solver.constraints var then
      let get_assignent () =
        let a = S.assignment solver.constraints in
        let size = Array.length a in
        let rec aux (i,acc) =
          if i < size then
            let acc = 
              if (Array.unsafe_get a i) = S.True then i :: acc 
              else acc
            in aux (i+1,acc)
          else acc
        in
        aux (0,[])
      in
      Success(get_assignent)
    else
      let get_reasons () = collect solver.constraints var in
      Failure(get_reasons)
  in

  match request with
  |Diagnostic_int.Sng i ->
      result S.solve S.collect_reasons (solver.map#vartoint i)
  |Diagnostic_int.Lst il -> 
      result S.solve_lst S.collect_reasons_lst (List.map solver.map#vartoint il)
;;

let pkgcheck callback solver failed tested id =
  let memo (tested,failed) res = 
    begin
      match res with
      |Success(f_int) ->
          List.iter (fun i -> Array.unsafe_set tested i true) (f_int ());
          Diagnostic_int.Success(fun ?all () -> f_int ())
      |Failure r ->
          incr failed;
          Diagnostic_int.Failure(r)

    end 
  in
  let req = Diagnostic_int.Sng id in
  let res =
    Util.Progress.progress progressbar_univcheck;
    if not(tested.(id)) then begin
      memo (tested,failed) (solve solver req)
    end
    else begin
      (* this branch is true only if the package was previously
       * added to the tested packages and therefore it is installable *)
      (* if all = true then the solver is called again to provide the list
       * of installed packages despite the fact the the package was already
       * tested. This is done to provide one installation set for each package
       * in the universe *)
      let f ?(all=false) () =
        if all then begin
          match solve solver req with
          |Success(f_int) -> List.map solver.map#inttovar (f_int ())
          |Failure _ -> assert false (* impossible *)
        end else []
      in Diagnostic_int.Success(f) 
    end
  in
  match callback with
  |None -> ()
  |Some f -> f (res,req)
;;

(** [univcheck ?callback (mdf,solver)] check if all packages known by 
    the solver are installable. XXX

    @param mdf package index 
    @param solver dependency solver
    @return the number of packages that cannot be installed
*)
let univcheck ?callback univ =
  let timer = Util.Timer.create "Algo.Depsolver.univcheck" in
  Util.Timer.start timer;
  let solver = init_solver_univ univ in
  let failed = ref 0 in
  let size = Cudf.universe_size univ in
  let tested = Array.make size false in
  Util.Progress.set_total progressbar_univcheck size ;
  let check = pkgcheck callback solver failed tested in
  for i = 0 to size - 1 do check i done;
  Util.Timer.stop timer !failed
;;

(** [listcheck ?callback idlist mdf] check if a subset of packages 
    known by the solver [idlist] are installable

    @param idlist list of packages id to be checked
    @param maps package index
    @return the number of packages that cannot be installed
*)
let listcheck ?callback univ idlist =
  let solver = init_solver_univ univ in
  let timer = Util.Timer.create "Algo.Depsolver.listcheck" in
  Util.Timer.start timer;
  let failed = ref 0 in
  let size = Cudf.universe_size univ in
  Util.Progress.set_total progressbar_univcheck size ;
  let tested = Array.make size false in
  let check = pkgcheck callback solver failed tested in
  List.iter check idlist ;
  Util.Timer.stop timer !failed
;;

(***********************************************************)

(** [reverse_dependencies index] return an array that associates to a package id
    [i] the list of all packages ids that have a dependency on [i].

    @param mdf the package universe
*)
let reverse_dependencies univ =
  let size = Cudf.universe_size univ in
  let reverse = Array.create size [] in
  Cudf.iteri_packages (fun i p ->
    List.iter (fun ll ->
      List.iter (fun q ->
        let j = CudfAdd.vartoint univ q in
        if i <> j then
          if not(List.mem i reverse.(j)) then
            reverse.(j) <- i::reverse.(j)
      ) ll
    ) (CudfAdd.who_depends univ p)
  ) univ;
  reverse

let dependency_closure_cache ?(maxdepth=max_int) ?(conjunctive=false) pool idlist =
  let cudfpool = strip_cudf_pool pool in
  let queue = Queue.create () in
  let visited = Hashtbl.create (2 * (List.length idlist)) in
  List.iter (fun e -> Queue.add (e,0) queue) (CudfAdd.normalize_set idlist);
  while (Queue.length queue > 0) do
    let (id,level) = Queue.take queue in
    if not(Hashtbl.mem visited id) && level < maxdepth then begin
      Hashtbl.add visited id ();
      let (l,_,_) = cudfpool.(id) in
      List.iter (function
        |(_,[i]) when conjunctive = true ->
          if not(Hashtbl.mem visited i) then
            Queue.add (i,level+1) queue
        |(_,dsj) when conjunctive = false ->
          List.iter (fun i ->
            if not(Hashtbl.mem visited i) then
              if not(Hashtbl.mem visited i) then
                Queue.add (i,level+1) queue
          ) dsj
        |_ -> ()
      ) l
    end
  done;
  Hashtbl.fold (fun k _ l -> k::l) visited []

(** [dependency_closure index l] return the union of the dependency closure of
    all packages in [l] .

    @param maxdepth the maximum cone depth (infinite by default)
    @param conjunctive consider only conjunctive dependencies (false by default)
    @param index the package universe
    @param l a subset of [index]
*)
let dependency_closure ?(maxdepth=max_int) ?(conjunctive=false) univ idlist =
  let pool = init_pool_univ univ in
  dependency_closure_cache ~maxdepth ~conjunctive pool idlist
;;

(*    XXX : elements in idlist should be included only if because
 *    of circular dependencies *)
(** return the dependency closure of the reverse dependency graph.
    The visit is bfs.    

    @param maxdepth the maximum cone depth (infinite by default)
    @param index the package universe
    @param idlist a subset of [index]

    This function has in a memoization strategy.
*)
let reverse_dependency_closure ?(maxdepth=max_int) reverse =
  let h = Hashtbl.create (Array.length reverse) in
  let cmp : int -> int -> bool = (=) in
  fun idlist ->
    try Hashtbl.find h (idlist,maxdepth)
    with Not_found -> begin
      let queue = Queue.create () in
      let visited = Hashtbl.create (List.length idlist) in
      List.iter (fun e -> Queue.add (e,0) queue) (List.unique ~cmp idlist);
      while (Queue.length queue > 0) do
        let (id,level) = Queue.take queue in
        if not(Hashtbl.mem visited id) && level < maxdepth then begin
          Hashtbl.add visited id ();
          List.iter (fun i ->
            if not(Hashtbl.mem visited i) then
              Queue.add (i,level+1) queue
          ) reverse.(id)
        end
      done;
      let result = Hashtbl.fold (fun k _ l -> k::l) visited [] in
      Hashtbl.add h (idlist,maxdepth) result;
      result
    end

