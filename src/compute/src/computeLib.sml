structure computeLib :> computeLib =
struct 

open HolKernel clauses rules equations;

(* reexporting types from clauses *)
type rewrite = rewrite;
type comp_rws = comp_rws;


type cbv_stack =
  ((thm->thm->thm) * (thm * db fterm),
   (thm->thm->thm) * bool * (thm * db fterm),
   (thm->thm)) stack;

fun stack_out (th, Ztop) = th
  | stack_out (th, Zrator{Rand=(mka,(thb,_)), Ctx}) =
      stack_out (mka th thb, Ctx)
  | stack_out (th, Zrand{Rator=(mka,_,(tha,_)), Ctx}) =
      stack_out (mka tha th, Ctx)
  | stack_out (th, Zabs{Bvar=mkl, Ctx}) = stack_out (mkl th, Ctx)
;


fun initial_state rws t =
  ((REFL t, mk_clos([],from_term (rws,[],t))), Ztop : cbv_stack);


(* Precondition: f(arg) is a closure corresponding to b.
 * Given   (arg,(|- M = (a b), Stk)),
 * returns (|- a = a, (<fun>,(|- b = b, f(arg)))::Stk)
 * where   <fun> =  (|- a = a' , |- b = b') |-> |- M = (a' b')
 *)
fun push_in_stk f (arg,(th,stk)) =
      let val (tha,thb,mka) = Mk_comb th in
      (tha, Zrator{Rand=(mka,(thb,f arg)), Ctx=stk})
      end
;

(* [cbv_wk (rws,(th,cl),stk)] puts the closure cl (useful information about
 * the rhs of th) in head normal form (weak reduction). It returns either
 * a closure which term is an abstraction, in a context other than Zappl,
 * a variable applied to strongly
 * reduced arguments, or a constant applied to weakly reduced arguments
 * which does not match any rewriting rule.
 * 
 * - substitution is propagated through applications.
 * - if the rhs is an abstraction and there is one arg on the stack,
 *   this means we found a beta redex. mka rebuilds the application of
 *   the function to its argument, and Beta does the actual beta step.
 * - for an applied constant, we look for a rewrite matching it.
 *   If we found one, then we apply the instanciated rule, and go on.
 *   Otherwise, we try to rebuild the thm.
 * - for an already strongly normalized term or an unapplied abstraction,
 *   we try to rebuild the thm.
 *)
fun build_machines rws =
let
fun cbv_wk ((th,CLOS{Env, Term=App(a,args)}), stk) = 
      let val (tha,stka) =
            foldl (push_in_stk (curry mk_clos Env)) (th,stk) args in
      cbv_wk ((tha, mk_clos(Env,a)), stka)
      end
  | cbv_wk ((th,CLOS{Env, Term=Abs body}),
	    Zrator{Rand=(mka,(thb,cl)), Ctx=s'}) =
      cbv_wk ((Beta(mka th thb), mk_clos(cl :: Env, body)), s')
  | cbv_wk ((th,CST cargs), stk) =
      let val (reduced,clos) = reduce_cst (rws,th,cargs) in
      if reduced then cbv_wk (clos,stk) else cbv_up (clos,stk)
      end
  | cbv_wk (clos, stk) = cbv_up (clos,stk)


(* Tries to rebuild the thm, knowing that the closure has been weakly
 * normalized, until it finds term still to reduce, or if a strong reduction
 * may be required.
 *  - if we are done with a Rator, we start reducing the Rand
 *  - if we are done with the Rand of a const, we rebuild the application
 *    and look if it created a redex
 *  - an application to a NEUTR can be rebuilt only if the argument has been
 *    strongly reduced, which we now for sure only if itself is a NEUTR.
 *)
and cbv_up (hcl, Zrator{Rand=(mka,clos), Ctx=stk})  =
      cbv_wk (clos,Zrand{Rator=(mka,false,hcl), Ctx=stk})
  | cbv_up ((thb,v), Zrand{Rator=(mka,false,(th,CST cargs)), Ctx=stk}) =
      cbv_wk ((mka th thb, comb_ct cargs (rand (concl thb),v)), stk)
  | cbv_up ((thb,NEUTR), Zrand{Rator=(mka,false,(th,NEUTR)), Ctx=stk}) =
      cbv_up ((mka th thb, NEUTR), stk)
  | cbv_up (clos, stk) = (clos,stk)


(* [strong] continues the reduction of a term in head normal form under
 * abstractions, and in the arguments of non reduced constant.
 * precondition: the closure should be the output of cbv_wk
 *) 
fun strong ((th, CLOS{Env,Term=Abs t}), stk) =
      let val (_,thb,mkl) = Mk_abs th in
      strong (cbv_wk((thb, mk_clos(NEUTR :: Env, t)), Zabs{Bvar=mkl, Ctx=stk}))
      end
  | strong (clos as (_,CLOS _), stk) = raise DEAD_CODE "strong"
  | strong ((th,CST {Args,...}), stk) =
      let val (th',stk') = foldl (push_in_stk snd) (th,stk) Args in
      strong_up (th',stk')
      end
  | strong ((th, NEUTR), stk) = strong_up (th,stk)

and strong_up (th, Ztop) = th
  | strong_up (th, Zrand{Rator=(mka,false,(tha,NEUTR)), Ctx}) =
      strong (cbv_wk((mka tha th,NEUTR), Ctx))
  | strong_up (th,  Zrand{Rator=(mka,false,clos), Ctx}) =
      raise DEAD_CODE "strong_up"
  | strong_up (th, Zrator{Rand=(mka,clos), Ctx}) =
      strong (cbv_wk(clos, Zrand{Rator=(mka,true,(th,NEUTR)), Ctx=Ctx}))
  | strong_up (th, Zrand{Rator=(mka,true,(tha,_)), Ctx}) =
      strong_up (mka tha th, Ctx)
  | strong_up (th, Zabs{Bvar=mkl, Ctx}) = strong_up (try_eta (mkl th), Ctx)

in
{Weak=cbv_wk, Strong=strong o cbv_wk}
end;



(* [CBV_CONV rws t] is a conversion that does the full normalization of t,
 * using rewrites rws.
 *)
fun CBV_CONV rws = #Strong (build_machines rws) o initial_state rws;

(* WEAK_CBV_CONV is the same as CBV_CONV except that it does not reduce
 * under abstractions, and reduce weakly the arguments of constants.
 * Reduction whenever we reach a state where a strong reduction is needed.
 *)
fun WEAK_CBV_CONV rws =
      (fn ((th,_),stk) => stack_out(th,stk))
    o #Weak(build_machines rws)
    o initial_state rws;

end;
